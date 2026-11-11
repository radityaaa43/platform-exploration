# Lensa inventory for final-design (keys, contracts, deploy) — fe, 2026-11-11

Skills loaded first: `superpowers:verification-before-completion` (each claim = command + cited line; unproven = [unverified]), `ecc:evm-token-decimals` (units, section 3), `ecc:deployment-patterns` (section 4). `ecc:code-explorer` is an agent type here, not a skill: skipped; the path:line map is built by hand (grep/sed) plus 2 read-only sonnet subagents whose lines I re-read (sampled 15 cites, all matched).
Rules kept: field and file NAMES only; no key, token, seed or kubeconfig content printed. Paths relative to `frontend/` unless prefixed `besu/`, `iroha3/`. Contract addresses are public chain data and are listed.

## 0. One-screen summary
- Lensa holds NO private ledger key for Zeto, Noto, Fabric-X. It holds raw private keys for Stealth (all banks + BI) and the Iroha 3 party/operator toml keys on disk. It also holds 4 OPA bundle-signing keys and a cluster kubeconfig (admin-style, one for all namespaces).
- Zeto/Noto "signing as bank X" = Lensa calls bank X's Paladin node (keys live in the node, HD wallet). The only credential Lensa presents is ONE mTLS client cert (`lensa.crt/key`) accepted by all four `bank-gw-N` gateways: that cert is the de-facto key to all four parties.
- Under principle 1 (Lensa = relay/UI): Stealth keys, Iroha toml keys + APS wallets, bundle signing keys, kubeconfigs, and every "bank-side" call move to a per-bank component. Two multi-party flows (Zeto `swap`, Noto `executeOutright`) drive seller AND buyer in one function: they need a coordinator or a split protocol (hard part).

## 1. Key and credential inventory
### 1.1 Host level (one Lensa host, user `ecs-user`)
| Item | Where | Used for |
|---|---|---|
| `~/.config/lensa/lensa.env` (mode 600, `deploy/install.sh:10-12`) names: `LENSA_ROOT PATH PORT NODE_ENV KUBECONFIG FABRICX_KUBECONFIG OPA_BIN OPA_KEYS_DIR LENSA_BESU_RPC LENSA_GW_MTLS_DIR LENSA_FABRICX_GW LENSA_BESU_RPC_BANKS` | `deploy/lensa.service:10` EnvironmentFile; `deploy/lensa-pf@.service:7` | all env the server reads (`grep process.env server/src`: `gateway.ts:11,23`, `adapters/fabricx.ts:486,490`, `adapters/stealth.ts:114,197`, `adapters/besu-network.ts:20`, `policy/boot.ts:22-26`, `main.ts:7`) |
| `KUBECONFIG` (shell/env) | used by every `kubectl port-forward` unit (`deploy/pf.sh:14`) and `policy/kube.ts:27` (NS `paladin`, `kube.ts:3`; wired `policy/boot.ts:28`) | forwards; Publisher: ConfigMap read/apply of `<name>-gw-N-bundles` (`kube.ts:5-12,60-65`) and bundle status via the API-server proxy of `bundle-server:sink` (`kube.ts:65`) |
| `FABRICX_KUBECONFIG` or `state/fabricx.json` field `kubeconfig` | `adapters/fabricx.ts:486`, `adapters/besu-network.ts:18-20` | Fabric-X kubectl exec (ns from `state/fabricx.json` `namespace`); ALSO Besu validator pod listing in ns `besu` for zeto/noto/stealth network view (`besu-network.ts:57`) |
| `LENSA_GW_MTLS_DIR` → `ca.crt lensa.crt lensa.key` | `gateway.ts:8-17`, `besu/zeto/src/common.ts:17-23`, `besu/noto+pente/common/src/config.ts:62-70` | client identity into `bank-gw-N` (Paladin 31548+, Besu 38545+) and `fx-gw-N` (39441-4) |
| `OPA_KEYS_DIR/<keyId>.pem` (4 owner keys, README "custody not separated") | `policy/opa.ts:20,71-74` (`opa build --signing-key`) | signing the BI and bank policy bundles (Halaman Kebijakan Publisher) |
| `state/*.json` all mode 600, dir 700 (`ls -l server/state`; `state.ts` writeState 0600/0700) | see 1.2 | per-model addresses AND (stealth, iroha3) secrets |

### 1.2 Per adapter (S=`server/src/adapters/stealth.ts`, F=`fabricx.ts`, Z=`zeto.ts`, N=`noto.ts`, I=`iroha3.ts`)
| Model | Secrets Lensa holds | Who signs | Endpoints (local forwards, `deploy/forwards.conf`) |
|---|---|---|---|
| Zeto | none (state has public BabyJubJub `owners`, eth `addresses`) | Paladin node of the party; Lensa creates `PaladinClient` for all 4 nodes (`Z:280`), identities by lookup `bi@node1 bankA@node2 bankB@node3 bankC@node4` (`Z:34`) | Paladin JSON-RPC `127.0.0.1:31548/31648/31748/31848` (`besu/zeto/config.json`; forwards `:3-6`), Besu receipts `LENSA_BESU_RPC` (38545, `:8`) |
| Noto | none (`state/noto.json` = `dataDir` only; `state/noto/contract-data-*.json`, `trades.jsonl`) | Paladin node of the party (`besu/noto+pente/bond/src/lib/platform.ts:55-69`; notary = node1) | same 4 Paladin ports; client options from `besu/noto+pente/common/src/config.ts` (may carry `bearer` header, `config.ts:23,53-56`; live value [unverified]) |
| Stealth | YES, in `state/stealth.json`: `deployerKey` (= BI wallet, `S:117`), `banks.{A,B,C}.{spendKey,viewKey,identityKey}` (`S:22,122,204`), `biMeta.{spendKey,viewKey}` (`S:23,121`), `pool[].privateKey` (one per stealth address, `S:565,637`), plus non-secret `sent`, `escrowed`, `chainId` | Lensa itself (ethers `Wallet`): BI txs on `LENSA_BESU_RPC`; bank-signed txs on per-bank doors `LENSA_BESU_RPC_BANKS` 38546-38548 (`S:195-198`) | Besu via `bank-gw-1..4` Besu doors, forwards `:8,10-12` |
| Fabric-X | none; kubeconfig path (`kubeconfig`, `namespace`, `funded` in `state/fabricx.json`, `F:19`) | the party's `fx-gw-N` → `rdbi-driver serve` holding only that party's key (`F:15`; not verified in cluster [unverified]); exec fallback = `rdbi-driver` pod | gateway `127.0.0.1:39441-39444` (`F:113`, forwards `:20-23`); ledger reads by `kubectl exec` into `committer-db-0` / `deploy/rdbi-<node>` db container (`F:188-189,323-324`) |
| Iroha 3 | party keys on disk: `state/iroha3/{bi,bank-a,bank-b,bank-c}.toml` (read by the `iroha` CLI, `I:72`; Lensa reads only `public_key`, `iroha3-auth.ts:40-43`), operator keys `op-{bi,bank-a,bank-b,bank-c}.toml` (private seed parsed into an in-memory ed25519 key to sign Torii GETs, `iroha3-auth.ts:48-62`), `admin.toml` (fee sponsor), `rd-dfabi.toml` (driver config), `genesis.expected_hash`; APS wallet seeds/note keys in `aps.mounts.keys` (`~/iroha3-keys`, mounted `:ro` into the driver container, `iroha3-aps.ts:39`; Lensa never reads it) | `iroha` CLI process (key from Lensa's disk) for non-APS flows; `docker run iroha3-rd-driver` for APS private DvP/pay (`iroha3-aps.ts:37`, holds wallets + proofs) | Torii `127.0.0.1:38080-38083` (BI,A,B,C), auditor `38090` (`aps.auditor`; `GET records` `iroha3-aps.ts:88-92,148-152`) |

### 1.3 Writes: signed or submitted, and as which party
- Zeto (all via Paladin SDK): BI `mintUtxos` (`Z:357` issue, award top-up `:354`, `fund` `:333`, `prepareLoad` `:550`); bank `transfer` as `req.from` (`Z:378`); load users `stress-nN-ii@nodeN` (`Z:504-510,567`); `swap` creates the Atom as seller, locks both legs, executes as buyer (`besu/zeto/src/flows.ts:118-133`); every bank also `reportTo` BI over a Pente group (`flows.ts:90`, `Z:329`).
- Noto: `issueCash`/`issueBond` as BI (`N:315-316`, `lib/issue.ts:7-19`); `transferNoto` as the sending bank, notary node1 endorses (`N:317`, `lib/transfer.ts:5-16`); `executeOutright` locks and settles with seller+buyer in one call (`N:294`, `lib/outright.ts:125-154`).
- Stealth: BI mint/issue/escrow create/certificates (`S:338,382-386,403-404,560`); bank `sendStealth`, DvP legs (`S:368-369,387-388,408-412`); load `sendStealth` (`S:636-638`).
- Fabric-X: initiator's gateway: BI for `issue`/`award`, sending bank for `transfer`/`swap` (`gwRequest` `F:124-136`; `run` `F:239-253`); counterparties only get `finality` (`F:174`).
- Iroha 3: BI `mint` (`I:644`; used `:253,676,692`); buyer grant + seller settle for non-APS DvP (`I:261-265`); bank transfer (`I:274,689`); APS `runPay/runDvpShared/runDvp` in the driver (`iroha3-aps.ts:68,122,129`).
- Policy: Lensa applies ConfigMaps in ns `paladin` and signs bundles (`kube.ts`, `opa.ts`); guard allows only `<name>-gw-N[-bundles]` (`kube.ts:22`).

### 1.4 Reads that need a party secret (cannot be done by a pure relay without that party's component)
- Stealth: bank holdings/history scan with the bank's view+spend key (`S:204,284,465,539,563`); BI scans traffic of ALL banks with the banks' view keys (`S:120,421,470,520`).
- Iroha 3: `op-<party>.toml` signed GETs and CLI reads (`I:158,213,486,570,597,422`); APS wallet reads in the driver (`iroha3-aps.ts:138`).
- Zeto/Noto: balances/UTXOs at the party's own node (`Z:321`, `N:213-219`); BI ledger `BiLedger(P.BI.c)` (`Z:286`).
- Fabric-X: per-party `balance/records/history` via that party's gateway (`F:211,270,368`); the public ledger via BI's committer DB (`F:183-189`).

### 1.5 What would move under principle 1 (Lensa holds no bank key)
| Moves to per-bank component | Stays in Lensa |
|---|---|
| Stealth `banks.*` keys, `pool[]`, bank scans, bank-side signing, `sent` log; BI needs a "disclosure" call or the banks' view keys (`S:120`) | BI `deployerKey`+`biMeta` (BI component), public reads (`network`, `receipt`) |
| Iroha `<bank>.toml`, `op-<bank>.toml`, `aps.mounts.keys` wallets, `bin/iroha`, docker driver per bank | `iroha3-intent.py`, `iroha3-norito.ts`, `health/network`, `FLOWS`, journal (`pools/lensa-journal.json`, records counterparties) |
| Zeto/Noto: bank `PaladinClient`s, `transfer`, bank half of `swap`/`executeOutright`, `reportTo`, bank mTLS cert | BI client, `BiLedger`, `state/zeto.json`, `state/noto/*` (no keys) |
| Fabric-X: nothing key-wise (already per-party gateway); drop the kubectl paths (`F:86-102,169,188,323-324,399`) = need gateway ops for ledger/history/health | orchestration, `exclusive()` locks, `recoverCut`, deadlines, lens assembly |
| Policy: each owner signs its own bundle (README "Not done" #3) and applies its own ConfigMap | Publisher UI + status read |
- Cross-cutting: `besu-network.ts:18-20` reuses the Fabric-X kubeconfig for ns `besu`; removing it breaks the Besu network view of 3 models.
- Hard: Zeto `swap` (`flows.ts:118-133`) and Noto `executeOutright` (`outright.ts:125`) need both parties' clients in one call; Stealth DvP needs a BI certificate before the bank's tx (`S:382-386,411`).

## 2. Contract and token inventory as Lensa knows it (addresses are public)
| Model | Field (file) | Value |
|---|---|---|
| Zeto | `rd` (`state/zeto.json`) | `0x0b91f511a3c9ca8144a5422734a2db42bb86e8f6` (RD, `Zeto_AnonNullifier` v1) |
| Zeto | `dfabi` | `0x374725a4c44c58d01f4f05739b257be6c71b6b9d` (DFABI) |
| Zeto | `atomFactory` | `0x0ff537f240fa6e168db5bbdb176dcdd2a769f5ac` |
| Zeto | `groups.{A,B,C}` | Pente privacy group ids (hex64), carry BI reports |
| Zeto | `owners.{BI,A,B,C}` | BabyJubJub public keys (hex64); `addresses.{BI,A,B,C}` eth: `0xc77e80b8…`, `0xea2bc1af…`, `0x33e556e2…`, `0xe438f0c5…` |
| Zeto | `fromBlock`, `privateMint`, `funded` | scan start; flags. Token name constant `ZETO_V1.tokenName = "Zeto_AnonNullifier"` (`besu/zeto/src/zeto-v1.ts:15`) |
| Noto | `dataDir` → `contract-data-2026-10-19T04-08-49-199Z.json` | fields: `notoCashAddress 0xf4571ab3…`, `notoBondAddress 0xf0735bed…`, `cashGroupId`, `cashGroupAddress 0xece3d19e…`, `cashTrackerAddress 0xc6bb619f…`, `issuerCustodianGroupId`, `issuerCustodianGroupAddress 0x2a195eda…`, `bondTrackerAddress 0x900bb5b2…`, `bondTrackerPublicAddress 0xb6adb924…`, `restrictedAtomFactoryAddress 0xf1f90c20…`, `bondDetails investors custodianFinalBalances participants timestamp` |
| Noto | `trades.jsonl` line fields | `tradeId notoBondAddress notoCashAddress seller buyer units price consideration status timestamp atomAddress bondLockId cashLockId` (status SETTLED/ROLLED_BACK/FAILED/PENDING) |
| Stealth | `deployed.*` (`state/stealth.json`) | `announcer 0x0EB83CC6…`, `registry 0xeC5F15d7…`, `validator 0x7DFb0AE3…`, `bond 0x0cF64D52…` (DFABI, ERC-1400 partition `TRANCHE_A`), `rd 0x91f5D0F0…` (RupiahDigital), `dvpFactory 0x6B78f114…`, `instrumentRegistry 0x3f81eF61…`, `fromBlock 1341410`; `chainId` (bigint) |
| Fabric-X | `state/fabricx.json` | no contract: namespace `ns_rd_dfabi_v2` is read in SQL (`F:185,320`), token names `RD`, `DFABI-2027A` (`F:40`); `namespace`=k8s ns |
| Iroha 3 | `assets.{RD,DFABI}` (`state/iroha3.json`) | asset definition ids `7onbjg2gRXveoAAUFsohCZyGW98t` (RD), `4mBWK1JCwQdHLDPpuVKc56eLsXka` (DFABI); `accounts.{BI,A,B,C}` ids; `torii` ports 38080-83; `aps{image,config,mounts{state,keys,public,pools},auditor,wallets}` (image repo `iroha3-rd-driver`) |
Backups also in `state/`: `zeto.v0-backup-20261021.json`, `zeto.anon-v1-backup-20261109.json`, `zeto.nullifier-partial-20261109.json`, `zeto.broken-smt-rd-20261109.json` (old RD ids; not read by code).

## 3. Units (RD / DFABI), `ecc:evm-token-decimals`
| Where | Fact (command/cite) |
|---|---|
| Lensa | `PRICE_PER_UNIT = 1_000_000n` RD per DFABI unit (`server/src/domain.ts:14`); `MAX_AMOUNT = 10n ** 15n` (`domain.ts:15`); `LOAD_AMOUNT = 1000n` (`adapter.ts:95`); UI `formatRupiah` = `Rp n`, `formatUnits` = `n unit DFABI`, no decimals (`web/src/format.ts:4-5`) |
| Stealth RD | `decimals()` returns 0 (`besu/stealth-address/src/RupiahDigital.sol:29-31`) |
| Stealth DFABI | ERC-1400 `decimals()` forced to 18 (`.../vendor/universal-token/ERC1400.sol:676-681`) but Lensa treats amounts as whole units; whether the deployed bond stores whole units despite `decimals()=18` is [unverified]. Live `eth_call decimals()` failed: the Besu door needs the mTLS cert (plain http closed) and I did not use the key |
| Zeto | no decimals of its own: integer unit, 1 unit = 1 rupiah (`besu/zeto/src/instrument.ts:146-147`); the old backing SampleERC20 would show 18 (`:148-149`, not verified on the deployed token) |
| Fabric-X | token names only; amounts 64-bit (ns `rd_dfabi_v2`, per team notes [unverified in code]); `MAX_AMOUNT` caps at 1e15 anyway |
| Iroha 3 | asset amounts are integer strings (`wallet items amount`, `I:361`), scale not read by Lensa [unverified] |
Rule for the new design: never hardcode 1e6/1e18; carry unit + scale per token in CONTRACTS.md and query `decimals()` where an ERC-20 exists.

## 4. Deploy path today and a per-bank namespace world
### 4.1 Today (cite)
1. Code: ONE live checkout `frontend/` of repo `rd-lensa-frontend` inside a monorepo layout: the server imports siblings by relative path (`../../../../besu/...`, `../../../../iroha3/network/public`: 27 files) so `besu/` and `iroha3/` must sit next to `frontend/` on disk (this is why CI cannot run those tests).
2. Run: `deploy/lensa.service:11` `cd $LENSA_ROOT/frontend && npm start -w server` (`tsx src/main.ts`, `server/package.json:7`); `ExecStartPost` `deploy/healthwait.sh` waits for `/api/health` 200 (90 s); `Restart=on-failure`, `WantedBy=default.target` (user linger).
3. Network: 17 `lensa-pf@<name>` units (`deploy/forwards.conf`: 4 Paladin `:3-6`, Besu `:8`, 3 per-bank Besu `:10-12`, 4 Iroha `:13-16`, auditor `:18`, 4 Fabric-X gw `:20-23`); each = `kubectl port-forward -n <ns> svc/<svc>` with ONE kubeconfig (`deploy/pf.sh:14`), loopback only; the template has no `[Install]`: units start only if listed in `lensa.service` `Wants=/After=` (README note). Namespaces touched: `paladin`, `besu`, `iroha3`, `fabricx`.
4. Web: `deploy/update.sh:5-15` builds `web/dist.new` (`tsc --noEmit`, `vite build`), swaps `web/dist`, `systemctl --user restart lensa`; `server/src/main.ts:8` serves `web/dist` itself (no separate web server). Rollback = old dist + `git checkout` + restart (done on 2026-11-11, 28c8bdb).
5. Install: `deploy/install.sh:7-14` symlinks units into `~/.config/systemd/user`, creates `lensa.env` (umask 077) if missing, `enable` only.
6. Release flow: PR to `rd-lensa-frontend` main, `lead` merges, host step by `lead`/`fe` (pull ff-only, build, restart). CI = web + self-contained server tests (siblings are private repos).
### 4.2 What a per-bank namespace world changes (analysis, not verified in cluster)
- Forwards: today the 4 Paladin and 4 Fabric-X forwards are already per party; Besu is one shared door plus 3 per-bank doors; Iroha is per party. Per bank namespace: one forward set per bank namespace (and `kubectl` context/kubeconfig per bank, namespace-scoped), so `forwards.conf` gains a kubeconfig column or the unit gets `KUBECONFIG` per name; 17 → ≥ 4 per-bank groups plus BI.
- Credentials: replace the single admin-style `KUBECONFIG` by one namespace-scoped credential per bank held by that bank's component; Lensa keeps only an mTLS client cert per bank (or one relay token), no kubeconfig, no toml/stealth keys. `OPA_KEYS_DIR` goes to each owner.
- Config: `lensa.env` per bank (ports, gateway URLs, cert dir) or a registry file Lensa reads; `state/*.json` keeps only public addresses (section 2); secret fields in 1.2 leave.
- Release: one Lensa unit stays (UI + fan-out for the 4-party side-by-side view); each bank component gets its own deploy/rollback in its namespace (rolling/blue-green per `ecc:deployment-patterns`; backward-compatible relay API versioned, since Lensa and bank components roll separately). Health: Lensa `/api/health` already aggregates per model (`app.ts`); needs per-bank health + a "relay API version" field.
- Repo layout: the relative sibling imports must go (CONTRACTS.md: ABI/config as data or a package), otherwise Lensa cannot be built or tested without the chain repos.
- Risk: the demo's outsider/other-bank views need each bank component to answer "what can bank X see of this tx"; Lensa must not hold a bank's secret to compute it.

## 5. Open / unverified
- [unverified] live `config.json` `bearer`/`tlsInsecure` for Paladin clients; cluster-side enforcement that each `fx-gw` holds only its party's key; whether `~/iroha3-keys` equals `state/iroha3/keys`; bi-auditor caller authentication; `cert()` body in `besu/stealth-address/ts/chain.ts`; DFABI stealth bond scale; Iroha asset scale.
- Not touched: any value of a key/token/kubeconfig; no cluster command except none (state field names read locally; one failed plain `eth_call`).

## 6. Namespace references (for "Decommission <old namespace>": what in Lensa, lensa-pf@*, OPA bundle server, CI still points at it)
Read-only grep over `frontend/`, `besu/opa`, `fabric-x/opa`, `iroha3/deploy`; cluster namespaces named by code are only the five below plus 3 selector-only ones. CI: `.github/workflows/ci.yml` names NO namespace, kubeconfig or cluster (only test file names, `ci.yml:25-60`): nothing to change there.
| Namespace | lensa-pf@* units (`deploy/forwards.conf`) | Env var / state key | Code and manifests naming it |
|---|---|---|---|
| `paladin` | `paladin-node1..4` → svc `bank-gw-1..4:8548` (`:3-6`); `besu` → `bank-gw-1:8545` (`:8`); `besu-bank-a/b/c` → `bank-gw-2..4:8545` (`:10-12`) = 8 units | env: `KUBECONFIG` (forwards, `pf.sh:14`), `LENSA_BESU_RPC` 38545, `LENSA_BESU_RPC_BANKS` 38546-8 (point at those forwards); state: none (ports hardcoded `gateway.ts:24`: 31548+100*(n-1); `besu/zeto/config.json` urls 31548/31648/31748/31848) | `policy/kube.ts:3` `NS='paladin'` (ConfigMaps `<name>-gw-N-bundles` apply `:60`, status via API-server proxy `bundle-server:sink` `:65`, `-n` `:30`); gateway Deployments `bank-gw-1..4` + `bundle-server` + sink (`policy/platforms.ts:16-28`, `BANK_GATEWAYS`); OPA manifests `besu/opa/k8s/{bank-gw-1..4,bundle-server,networkpolicy}.yaml` (`namespace: paladin`); `besu-network.ts:11-12` reads configmap `paladin-nodeN` of ns paladin by comment, `:71-73` probes Paladin ports; README `opa/README.md` |
| `besu` | none (reads go through the `paladin` door, not a besu-ns forward; `README.md:14` documents a manual `-n besu` forward only) | env `FABRICX_KUBECONFIG` (kubeconfig of the Fabric-X state, reused) / state `fabricx.json` `kubeconfig` | `adapters/besu-network.ts:20` hardcoded `namespace: 'besu'` (pods `besu-node-validator-N-0`, `:57`, comment `:11`); `ARCHITECTURE.md:319` |
| `fabricx` | `fabricx-gw-1..4` → svc `fx-gw-1..4:8443` (`forwards.conf:20-23`) = 4 units | state `fabricx.json` field `namespace` (= `fabricx`) and `kubeconfig`; env `FABRICX_KUBECONFIG` (`fabricx.ts:486`, `bootstrap-fabricx.ts:12`); `LENSA_FABRICX_GW=1` selects the fx-gw forwards | `fabricx.ts:88` `kubectl -n <state.namespace>` (exec into `deploy/rdbi-*`, `committer-db-0`, pods `:399`); `fabricx.ts:19` interface; `bootstrap-fabricx.ts:9`; `ARCHITECTURE.md:271`; `fabric-x/opa/DESIGN.md:18-30` (fx-gw pods in ns fabricx; NetworkPolicy selector `besu/opa/k8s/networkpolicy.yaml` allows fx-gw to the bundle-server per rd-besu #9) |
| `iroha3` | `iroha-bi/bank-a/bank-b/bank-c` → svc `bi/bank-a/bank-b/bank-c:8080` (`:13-16`); `iroha-auditor` → `bi-auditor:8090` (`:18`) = 5 units | state `iroha3.json` fields `torii.{BI,A,B,C}` (38080-83) and `aps.auditor` (38090), `dir`; no env var | `cli/bootstrap-iroha3.ts:19,47` (comments `-n iroha3`); `README.md:22` manual forwards; `iroha3/deploy/k8s/kustomization.yaml:3` `namespace: iroha3` |
| `kaleido` | none | none | no namespace of this name anywhere in `frontend/`, `besu/opa`, `fabric-x/opa` (grep `kaleido` = 0 hits in code/manifests). Only the PUBLIC ingress hosts `paladin-node1..4.apse5.kld.bi-sandbox.com` (`besu/opa/k8s/ingress-via-gateway.yaml:21-71`, `networkpolicy.yaml:107`) |
| `dfabi` | none | none | selector only: `besu/opa/k8s/networkpolicy.yaml:24,49,74,99` allow ns `dfabi` (DFABI `bankN-backend`) into the Paladin nodes; not used by Lensa |
| `kube-system`, `ingress-nginx`, `default` | none | none | selectors/lookups only: `networkpolicy.yaml:122` (kube-system), `:113-125` (`paladin-rpc-from-ingress-nginx`, apps `ingress-nginx` / `ack-ingress-nginx-v1`), `kubernetes` endpoints in `default` for the bundle-server policy (rd-besu #9) |
| `fabricx-bi`, `fabricx-bank-a/b/c` | none | none | NOT used by Lensa (`fabric-x/opa/DESIGN.md:18-20`: separate fabricx-transfer-v2 stack) |
Also hardcoded outside namespaces: `forwards.conf` is the only place a unit-to-namespace mapping lives (one line per forward; unit name = first column, used in `lensa.service:3-4` Wants/After for 17 units).
Decommission prerequisite, checkable in one pass (read-only, from the repo root of the old layout):
- `grep -nE "^\S+\s+<ns>\s" frontend/deploy/forwards.conf` = 0 lines, and `systemctl --user list-units 'lensa-pf@*' --no-legend` shows none of those units; `lensa.service:3-4` no longer lists them.
- `grep -rn "'<ns>'\|-n <ns>\|namespace: <ns>" frontend/server/src frontend/deploy besu/opa/k8s fabric-x/opa iroha3/deploy` = 0 (watch `policy/kube.ts:3`, `besu-network.ts:20`, `fabricx.ts:88`).
- `python3 -c "import json;print(json.load(open('frontend/server/state/fabricx.json'))['namespace'])"` ≠ `<ns>`; `state/iroha3.json` `torii`/`aps.auditor` ports must target the NEW forwards; `~/.config/lensa/lensa.env` `KUBECONFIG`/`FABRICX_KUBECONFIG` context must not need the old namespace.
- OPA: no `<name>-gw-N` Deployment, `bundle-server` or ConfigMap left in `<ns>` that Lensa's Publisher reads (`kube.ts:22` guard allows only `*-gw-[1-4]` and `*-gw-[1-4]-bundles`; `kube.ts:65` reads the sink).
- CI: nothing (`ci.yml` has no cluster reference); the siblings' own CI [unverified].
