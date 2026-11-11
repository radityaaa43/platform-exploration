# CURRENT: Lensa as it runs now (one host service, user `ecs-user`)

Written by `fe`, 2026-11-11 (night). Read-only study. Names and paths only: no key, token, seed or kubeconfig content. Sources: `final-design/LENSA.md` (inventory, merged #58), `docs/in-cluster-facts.md` in `rd-lensa-frontend` (merged #22, `09cfad4`), re-checked below at `rd-lensa-frontend@28c8bdb`.
Skills: superpowers:using-superpowers, superpowers:using-git-worktrees, superpowers:writing-plans, superpowers:verification-before-completion (each fact = command or `path:line`), ecc:deployment-patterns, ecc:docker-patterns, ecc:kubernetes-patterns. Not run as skills: `ecc:code-explorer` (agent type; the map was built by hand with `grep`).
Tags: [L] live read-only command on the host, output quoted; [R] repo `path:line` at `rd-lensa-frontend@28c8bdb`; [U] not verified, says why. Nothing here touches a cluster.

## 1. Process and bind
| Fact | Evidence |
|---|---|
| One Node process, `tsx src/main.ts`, started by `lensa.service` (`cd $LENSA_ROOT/frontend && npm start -w server`), no build step for the server | [R] `server/package.json` `start`; `deploy/lensa.service:11` |
| Listens on `127.0.0.1` only, host hard-coded; port `PORT` (default 8790) | [R] `server/src/main.ts:7,15` (`await app.listen({ host: '127.0.0.1', port: PORT })`) |
| The same process serves the web build `web/dist` when it exists; no other web server | [R] `main.ts:8,13` (`webDist: existsSync(dist) ? dist : undefined`) |
| Access today: loopback plus `ssh -L`; no authentication in the API | [R] `main.ts:17` (log line "Dari laptop: ssh -L ..."); no auth hook in `server/src/app.ts` [U: only the route list was read, not every hook] |
| Node on the host `v22.23.4`; no `Dockerfile`, no `.dockerignore` in the repo | [L] `node --version` -> `v22.23.4`; `ls Dockerfile* .dockerignore` -> `No such file or directory` |
| Health: `GET /api/health` always 200, per-model readiness and node booleans in the body; no separate liveness or readiness route | [R] `server/src/app.ts:166`; `ExecStartPost` `deploy/healthwait.sh` polls it up to 90 s |
| Startup order: `assertGatewayEnv()` (exit 1 on bad gateway env), `loadAdaptersWithFailures()` (a failing model is listed, server still starts), `bootPolicy(env)` | [R] `main.ts`; `server/src/gateway.ts`; facts doc section 5 |
| Single replica by construction: in-memory tx slot (`busy`), stress run and caches; a restart drops the in-flight run | [R] facts doc section 5 (`app.ts` busy slot) |

## 2. Build inputs
| Fact | Evidence |
|---|---|
| Sibling code is runtime code: the server imports `besu/` and `iroha3/` by relative path `../../../../` (22 lines in 11 files under `server/src`, including `cli/`); the sibling checkouts must sit next to `frontend/` | [L] `grep -rln "\.\./\.\./\.\./\.\./\(besu\|iroha3\)" server/src \| wc -l` -> `11`; `grep -rn ... \| wc -l` -> `22`; `ls ../iroha3` succeeds |
| Siblings carry their own `package.json` and need their own `npm ci` (paladin SDK, ethers, circomlibjs, noble curves); stealth needs Node >=22.18 | facts doc section 1 [R at rd-besu@main] |
| Foundry output `besu/stealth-address/out/<Name>.sol/<Name>.json` is read at runtime and is git-ignored | facts doc section 1 (`stealth-address/ts/chain.ts:23-24`) |
| CI cannot run the ~15 sibling-importing test files: sibling repos are private, `ci.yml` carries an `--exclude` list | [R] `.github/workflows/ci.yml`; full-suite CI via deploy key = option A with the user, not decided |
| Web: `tsc --noEmit && vite build` to `web/dist` (308K) | facts doc section 1 |
| Processes the server spawns: `kubectl`, `docker run` (APS driver), `python3 -I iroha3-intent.py`, the `iroha` CLI, `opa` (only with `OPA_BIN`) | facts doc section 1 [R] `policy/kube.ts:30`, `iroha3-aps.ts:37`, `iroha3.ts:72,89`, `policy/opa.ts:10` |

## 3. State that must survive a restart (`server/state/`, dir 700, files 600)
| Fact | Evidence |
|---|---|
| Total 155M, of which 154M is `iroha3/bin` (host-built binaries); everything else is 1.2M | [L] `du -sh server/state` -> `155M`; `du -sh server/state/iroha3/bin` -> `154M`; `du -sh --exclude=bin server/state` -> `1.2M` |
| Files that stay when the keys leave: `zeto.json`, `noto.json` + `noto/` (incl. append-only `trades.jsonl`), `iroha3.json`, `stealth.json` (public fields only after stealth S21), `fabricx.json` (until fabricx S19), `policy/<owner>/` (versions, `pending.json`, `audit.jsonl`) | facts doc section 2 |
| Outside the repo: `~/iroha3-pools/` (880K: `pools.json`, `lensa-journal.json`, `receipts/`), `~/.config/lensa/lensa.env`, `~/iroha3-keys/` | [L] `du -sh ~/iroha3-pools` -> `880K`; `ls ~/iroha3-pools` -> `receipts/ lensa-journal.json pools.json pools.json.lock` |
| `writeState` is atomic (temp + rename); a crash can leave `<model>.json.<pid>.tmp` | [R] `server/src/state.ts:20-47` |
| Not reconstructable from the chain: `trades.jsonl` (PENDING recovery), `policy/*/audit.jsonl`, `lensa-journal.json` (payer's record of whom it paid). Contract addresses in the other files are public and also in CONTRACTS.md | facts doc section 2; LENSA.md section 2 |

## 4. Network and credentials today
| Fact | Evidence |
|---|---|
| 17 `lensa-pf@*` units (`kubectl port-forward`, loopback), all listed in `lensa.service` `Wants=`; one kubeconfig for all | [L] `systemctl --user show lensa.service -p Wants --value \| tr ' ' '\n' \| grep -c 'lensa-pf@'` -> `17`; [R] `deploy/pf.sh:14`, `deploy/forwards.conf` |
| Gateway env (L5, merged): `LENSA_GW_PALADIN_<BI\|A\|B\|C>`, `LENSA_GW_FABRICX_<...>`, `LENSA_GW_MTLS_DIR/<party>/{ca.crt,lensa.crt,lensa.key}`, `LENSA_BESU_RPC`, `LENSA_BESU_RPC_BANKS`; `assertGatewayEnv()` refuses duplicate or malformed endpoints | [R] `server/src/gateway.ts`, `server/test/gateway-env.test.ts` (21 tests), `deploy/lensa.env.example` |
| Not replaced by env yet: 5 Iroha forwards (`torii.*`, `aps.auditor` live in `state/iroha3.json`); Publisher sink status and Besu pod list still need a kube credential (`policy/kube.ts:3,65`, `adapters/besu-network.ts:20`) | facts doc section 4 |
| Secrets Lensa holds today: `lensa.key` (one client cert for all four gateways), `stealth.json` key fields, Iroha toml and seeds, 4 OPA signing keys, kubeconfigs | LENSA.md section 1.1-1.2 (names only) |

## 5. Gaps against a pod
Numbered as in `docs/in-cluster-facts.md` section 6. Status at `28c8bdb`: all nine still open.
1. Sibling source in the build context (private repos). 2. Foundry `out/` artifacts. 3. Four `npm ci` trees. 4. `tsx` is a devDependency. 5. Bind host and liveness. 6. `docker run` for the Iroha APS driver cannot run in a pod. 7. kube credential for Publisher and Besu view. 8. `state/` persistence. 9. Secrets in the process today (the keyless steps of the platform plans must land first).
Extra finding, not in the facts doc: `dvp-shared` is the one Iroha op outside the keyless contract until README row 18 (iroha3 PLAN S16). It needs all Iroha seeds and `docker run` in one process, so it has no home in a keyless pod. See PLAN.md decision L4.

## 6. What this file does not cover
[U] image build time and size (nothing built); pod CPU and memory (never measured); which `besu/zeto/config.json` and `noto+pente/common` config lookups the live code path hits; whether `package-lock.json` at the repo root reproduces the sibling installs; Alibaba `cloud_essd` PL0 minimum disk size on cluster 1.
