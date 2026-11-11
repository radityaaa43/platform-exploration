# lensa: plan CURRENT -> one keyless Lensa in namespace `rd-lensa` on cluster 1

Draft by `fe`, 2026-11-11 (night), for `lead` to read and own. Nothing here executes anything: every CLUSTER-OP, spend and user-only item waits for the user's approval of this plan and then for its own GO (TEAM.md section 5).
Skills used: superpowers:using-superpowers, superpowers:using-git-worktrees, superpowers:writing-plans (step shape), superpowers:verification-before-completion (RED proofs; every claim cites a file or CURRENT.md section), ecc:kubernetes-patterns (pod security, probes, RBAC, NetworkPolicy), ecc:deployment-patterns (blue/green, health, rollback), ecc:docker-patterns (image). Not applied: ecc:architecture-decision-records (decisions are rows below, not ADRs; `lead` may promote L7 to an ADR).
Scope: the in-cluster Lensa comes from the user's order 2026-11-11; no analyst DELTA names it; AFTER rows honoured: 'Lensa: relay + UI, only shared part, NO keys' (ARCHITECTURE-iroha3.md:127, ARCHITECTURE-fabricx.md:179) and zeto S19/S20 (no kubeconfig)
Start: `final-design/lensa/CURRENT.md`. Pins: `rd-lensa-frontend@28c8bdb`, `rd-besu@main` (storage and snapshot classes, S8 node affinity pattern), Node 22, `tsx` as in `server/package.json`.
Namespace: `rd-lensa` on cluster 1 only. Bank C is reached over its public gateway endpoints (mTLS), not by a Lensa pod on cluster 2. Cluster 2 is not touched by this plan.

## Design in six lines
1. Image: server + web in ONE image, built in CI from `rd-lensa-frontend`, pushed to `ghcr.io/radityaaa43/rd-lensa-frontend`, referenced by digest. No secret, no state, no `kubectl`, `docker`, `opa` or `iroha` binary inside.
2. Runtime: keep `tsx` (the server has no build step today). Move `tsx` to `dependencies`; `npm ci --omit=dev`. Rejected: compiling or bundling the server (new build pipeline and risk with `.ts` import paths, no gain for a single-replica demo relay); revisit if image size or start time hurts.
3. Siblings: the code Lensa really imports is copied into the repo (`server/vendor/`) with a provenance file (sibling repo + commit); relative `../../../../besu|iroha3` imports go to zero. Side effect: the full test suite runs in CI without a deploy key.
4. State: one PVC mounted at `server/state` (and a sub-path for the Iroha journal); only files that stay after the keyless steps. The 154M of `iroha3/bin` is not state and stays out.
5. Credentials: per-party gateway URLs in a ConfigMap, per-party client certs in Secrets (names below). No kubeconfig, no ServiceAccount token in the pod, no port-forward, no cluster-admin credential anywhere near `rd-lensa`.
6. Rollout: blue/green beside the host service on the same gateways; one cutover window; rollback = switch back to the host service; the host service is retired last, under its own GO.

## Names (no values)
| Object | Name | Notes |
|---|---|---|
| Namespace | `rd-lensa` | labels `part-of=rd-lensa`, `pod-security.kubernetes.io/enforce=restricted` (same level as the fabricx namespaces, `agents/analyst/design/ARCHITECTURE-fabricx.md:161`) |
| Deployment, Service | `lensa` (port 8790) | replicas 1, strategy `Recreate` (RWO volume, in-memory tx slot) |
| ServiceAccount | `lensa` (`automountServiceAccountToken: false`) | pod identity, no API access |
| ServiceAccount, Role | `lensa-admin` | operator-side, same shape as `party-admin`: `secrets` create/update/patch only (decision 25), workloads in the namespace; no get/list on Secrets, no `pods/exec` |
| ServiceAccount, Role | `lensa-access` | only for L1 option A: `pods` get/list, `pods/portforward` create, in `rd-lensa` |
| ConfigMap | `lensa-env` | `PORT`, `HOST`, `LENSA_GW_MTLS_DIR`, `LENSA_GW_PALADIN_<BI,A,B,C>`, `LENSA_GW_FABRICX_<BI,A,B,C>`, `LENSA_FABRICX_GW`, `LENSA_BESU_RPC`, `LENSA_BESU_RPC_BANKS` (names only; URLs are config, not secret) |
| Secrets | `lensa-gw-mtls-bi`, `lensa-gw-mtls-a`, `lensa-gw-mtls-b`, `lensa-gw-mtls-c` | keys `ca.crt`, `lensa.crt`, `lensa.key`; mounted at `$LENSA_GW_MTLS_DIR/<BI\|A\|B\|C>/` as `gateway.ts` expects |
| Secret | `ghcr-pull` | image pull; same name as the existing one in `dfabi` (`stealth/CURRENT.md` row `dfabi`) |
| Secret (only if L7 = B) | `lensa-iroha-interim-seeds` | see L7 |
| Secret (only if L2 = basic auth) | `lensa-basic-auth` | |
| PVC | `lensa-state` | 5Gi, StorageClass `rd-retain-essd` (rd-besu #15). Cluster 1 today has no such class (S4b, 2026-11-11): the PVC runs on `alicloud-essd-wffc` (WaitForFirstConsumer, PL0) and, the moment the S6 pod binds it, only that PV's `spec.persistentVolumeReclaimPolicy` is patched Delete -> Retain and verified |
| NetworkPolicies | `default-deny-all`, `allow-dns-egress`, `egress-party-gateways`, `allow-ingress-entry` | S4 |
| Snapshot | `lensa-state-<date>` | class `rd-retain-snapshot` (rd-besu #15) |
Cert scope is an open question to `besu` (not settled by the platform plans): `gateway.ts` supports one cert set per party. If a platform gateway needs its own client cert, the Secret key set grows to `<platform>.crt/.key` and `gwAgent` needs a platform argument (fe code change inside S2).

## Order and dependencies
Layer: L5b, after all L5 keyless steps (zeto S19/S20, noto-pente S12, stealth S18/S19/S21, fabricx S4/S19, iroha3 S16). The code steps S1-S3 can start now in a worktree.
1. S1 (none; wait is only for the keyless L5 code to be merged before S3's RED proof)  2. S2 after S1  3. S3 after S1, S2, L6  4. S4 after S3 (image exists), L1  5. S5 after S4 and each platform's gateway step  6. S6 after S4, S5, S3  7. S7 after S6, L1, L2, L3  8. S8 after S6, S7, restore test, L7  9. S9 after S8 + soak  (S9 is LAST)

## Steps
### S1: Fold the sibling imports into the package
- DELTA: none (see header). AFTER row: "Lensa: relay + UI, only shared part" (a deployable artifact needs a self-contained source tree)
- Owner: fe  Size: M
- Prerequisites: L5 (user decision on the sibling source: row L5 below)
- Flags: none (repo work only)
- Does: copy the files `server/src` actually imports (CURRENT.md section 2: 22 import lines in 11 files) from `rd-besu@<sha>` (`zeto/src`, `noto+pente/bond/src/lib`, `noto+pente/common`, `stealth-address/ts`, ABIs and the Foundry output files the code reads) and `iroha3/network/public` into `server/vendor/<name>/` with `server/vendor/PROVENANCE.md` (repo, commit, file list, date; no key). Their runtime dependencies move into `server/package.json` (one lockfile, one `npm ci`). A script `scripts/vendor-siblings.sh <besu-sha> <iroha3-sha>` re-copies from local sibling checkouts; a test fails if `PROVENANCE.md` lists a file that is missing. Imports become relative to `vendor/`. The Foundry `out/` files Lensa reads are committed as data (ABI and bytecode only if read at runtime: the RED proof lists exactly which). The 15 CI-excluded test files join the normal run; `ci.yml` `--exclude` list is emptied. Not done: git submodules and a private npm package (both need CI credentials for private repos).
- RED proof: `grep -rn "\.\./\.\./\.\./\.\./\(besu\|iroha3\)" server/src \| wc -l` -> `0` (22 before); in a clean clone of `rd-lensa-frontend` with no sibling directories next to it, `npm ci && npm test -w server` passes (fails with import errors before); `ci.yml` has no `--exclude` and the CI run is green (run id quoted in the PR body); `git ls-files server/vendor \| grep -ci '\.env\|\.key\|seed\|kubeconfig'` -> `0`.
- Rollback: `git revert` (siblings stay the source until the revert).
- Sources: CURRENT.md section 2; `docs/in-cluster-facts.md` section 6 blockers 1-3; zeto PLAN S19 (the Lensa pointer steps this follows).

### S2: Server runtime for a pod: bind host, liveness, readiness
- DELTA: none. AFTER row as S1
- Owner: fe  Size: S
- Prerequisites: S1
- Flags: none (repo work only)
- Does: (a) `main.ts:15` reads `HOST` (default `127.0.0.1`, so the host service is unchanged; the pod sets `0.0.0.0`). (b) `GET /api/livez` -> 200 `{ok:true}` while the event loop answers. (c) `GET /api/readyz` -> 200 when at least one model loaded, else 503 with the load failures. `main.ts` runs `assertGatewayEnv()`, `loadAdaptersWithFailures()` and `bootPolicy()` BEFORE it listens, so that phase is not visible over HTTP: the pod's `startupProbe` (connection refused until listening) covers it, and readyz 503 means "up but no model loaded" (amended 2026-11-11, rd-lensa-frontend #24). Readiness does NOT depend on gateway reachability or on any bank being up (a bank outage must show in the UI body of `/api/health`, not remove the only UI from the Service). (d) `tsx` moves from `devDependencies` to `dependencies` in `server/package.json` (done in S1, #23). (e) The log line "Dari laptop: ssh -L" (`main.ts:17`) becomes English and prints the real bind (an English-only rule fix on touch). (f) Confirm after zeto S20 that `bootPolicy` does not need `OPA_BIN` or `OPA_KEYS_DIR` for the unsigned-upload Publisher path; if it does, file it to `lead` as a zeto S20 defect, do not work around it here.
- RED proof: vitest, written first and failing: `HOST` unset -> `listen` called with `127.0.0.1`; `HOST=0.0.0.0` -> `0.0.0.0`; `/api/livez` 200 even when no model loaded; `/api/readyz` 503 when every model failed to load and 200 once one loaded; `/api/readyz` stays 200 when every gateway URL points at a closed port; `npm ls tsx --omit=dev` lists `tsx`. Commands and counts quoted in the PR body.
- Rollback: `git revert`; the default `HOST` keeps today's behaviour, so the host service needs no change.
- Sources: CURRENT.md section 1; `server/src/main.ts:7-17`, `server/src/app.ts:166`; `ecc:kubernetes-patterns` probes table (liveness = deadlock, readiness = traffic).

### S3: Image and CI build, pinned by digest
- DELTA: none
- Owner: fe  Size: M
- Prerequisites: S1, S2, the keyless L5 steps merged (a keyed pod is the opposite of the target: `docs/in-cluster-facts.md` blocker 9), L6
- Flags: spend (registry; see Spend), lead GO for the first registry push
- Does: `Dockerfile` (multi-stage: deps -> web build -> runtime). Runtime: `node:22-<minor>-slim` pinned by digest at build time, plus `python3` for `iroha3-intent.py` only; non-root numeric UID 10001; `NODE_ENV=production`; `HOST=0.0.0.0`; `CMD ["npx","tsx","server/src/main.ts"]` from `/app/frontend`; the state directory is created empty, mode 700, and is a mount point; no `HEALTHCHECK` line (Kubernetes probes own it). `.dockerignore` excludes `server/state`, `.env*`, `alibaba.yaml`, `.worktrees`, `node_modules`, `.git`. Not in the image: `kubectl`, `docker`, `opa`, the `iroha` CLI, `iroha3/bin`, any key. Workflow `.github/workflows/image.yml`: on push to `main` build and push `ghcr.io/radityaaa43/rd-lensa-frontend:sha-<commit>`, print the digest in the job summary; manifests take the digest (`IMAGE_DIGEST`), never a tag. `permissions: packages: write` on that job only. The `ghcr` package stays private.
- RED proof: `docker build` of the repo at the merge commit succeeds in CI (run id); image scan: `docker run --rm --entrypoint sh <image> -c 'ls /app/frontend/server/state; find / -name "*.key" -o -name "*.toml" -o -name ".env*" -o -name "alibaba.yaml" 2>/dev/null \| grep -v node_modules'` -> empty state dir and no file outside `node_modules`; `docker run --rm -e HOST=0.0.0.0 -p 18790:8790 <image>` then `curl /api/readyz` -> 200 and `/api/health` lists every model as not ready (no gateways) without a crash; `docker image inspect --format '{{.Config.User}}'` -> `10001`; `docker run ... which kubectl docker opa iroha` -> none found.
- Rollback: delete the workflow and the package tag; nothing runs it yet.
- Sources: CURRENT.md section 2; `ecc:docker-patterns` (hardening, `.dockerignore`); `ecc:deployment-patterns` (multi-stage Node, digest pin).

### S4: Namespace, policies, RBAC, volume (cluster 1)
- DELTA: none. AFTER row: "default-deny + per-namespace RBAC" pattern of zeto S1
- Owner: fe (manifests in `rd-lensa-frontend/deploy/k8s/` with `render.sh` and an offline test, the rd-besu pattern); apply by `lead` GO
- Prerequisites: S3 (digest known), L1; read-only capacity read (`kubectl describe nodes \| grep -A5 'Allocated resources'`; disk-attach slots per node) quoted in the CLUSTER-OP text
- Flags: CLUSTER-OP, user-only (credential issue for `lensa-admin` and `lensa-access`), spend (disk)
- Does: (S4a) namespace `rd-lensa` with the labels above; NetworkPolicies: `default-deny-all` (Ingress and Egress); `allow-dns-egress` to `kube-system` pods `k8s-app=kube-dns` UDP/TCP 53 [unverified label on this cluster]; `egress-party-gateways`: for the cluster-1 parties one `to` per `rd-<platform>-<party>` namespace (selector `kubernetes.io/metadata.name`) and gateway pods (`bank-gw-N` 8548 + 8545, `st-gw-N`, `fx-gw-N` 8443, Iroha `bank-gw` from iroha3 S14; ports as each platform step pins them [unverified until then]); for bank C one `ipBlock` /32 per public gateway LB address and port (addresses from the cluster-2 LB steps; no other egress); `allow-ingress-entry`: none for L1 option A; for option B/C the ingress-controller pods on 8790 plus `ipBlock 100.64.0.0/10` for the CLB check source (TEAM.md section 5). ServiceAccounts `lensa`, `lensa-admin`, `lensa-access` and Roles as in Names. (S4b) PVC `lensa-state` 5Gi (current need 1.2M + 880K, section 3 of CURRENT.md; sized for journals and policy audit growth, shrink if the minimum disk size allows [unverified]), node affinity excluding `member-16033-node` and `member-16034-node` as in zeto S8; Secrets `ghcr-pull`, `lensa-gw-mtls-{bi,a,b,c}`, created by the party operators and the user with `lensa-admin` (create-only; nothing is read back). Admin credential custody stays as zeto S1 says (README decision 25).
- RED proof: `kubectl get ns rd-lensa` before `NotFound`, after `Active`; `kubectl -n rd-lensa get netpol -o name \| wc -l` -> `3` under entry A (`4` with `allow-ingress-entry` only if L1 = B/C); `can-i` for `lensa-access`: `create pods --subresource=portforward` -> `yes` (the string form `pods/portforward` answers `no` for the same Role); `kubectl -n rd-lensa auth can-i get secrets --as=system:serviceaccount:rd-lensa:lensa-admin` -> `no`, `create secrets` -> `yes`; `auth can-i get pods -n rd-zeto-bank-a --as=system:serviceaccount:rd-lensa:lensa-admin` -> `no`; throwaway probe pod in `rd-lensa` (created and deleted inside the CLUSTER-OP): connect to a party gateway port succeeds, connect to a random in-cluster Service and to an external address is refused, DNS resolves; `kubectl -n rd-lensa get pvc lensa-state` -> `Bound` after the first pod mount (WaitForFirstConsumer), `pv` reclaim policy `Retain`.
- Rollback: `kubectl delete ns rd-lensa` (empty, or only the idle pod of S6). If the PV is Retain the disk stays and is released by hand.
- Sources: zeto PLAN S1 (pattern, custody); `rd-besu` #15 (`stealth-address/k8s/vault/templates/storage.yaml`, snapshot class); `rd-besu` #13 (hostname affinity, offline test); TEAM.md section 5 (LB rule); CURRENT.md section 3.

### S5: Let `rd-lensa` reach the party gateways (cross-plan)
- DELTA: none. AFTER row: "Gateway + NetworkPolicy: envoy+opa is the only ingress from Lensa" (stealth PLAN S17 DELTA 6, 7)
- Owner: besu (zeto, noto, stealth), iroha (iroha3), fabric (fabricx), one rendered file per platform from fe's `render.sh`; bank C part: owners of the cluster-2 gateway LBs  Size: S per platform
- Prerequisites: S4a, the platform's gateway step (zeto S16/S17, stealth S17, iroha3 S14, fabricx S16)
- Flags: CLUSTER-OP per platform; the bank C ACL change is its own CLUSTER-OP on cluster 2 (annotation on an existing project Service only)
- Does: (a) in each cluster-1 party namespace an additive NetworkPolicy `allow-from-lensa`: ingress to the gateway pods only, from namespace `rd-lensa` pods `app=lensa`, on that gateway's ports. Additive per pod, so it widens nothing else; mTLS and the party OPA stay the control, the policy only narrows who can open a connection. (b) For bank C: the gateway LB access-control list (whitelist first, TEAM.md section 5) gets the cluster-1 egress /32 that `rd-lensa` traffic leaves from; the host's address stays until S9. (c) The URLs go into `lensa-env`.
- RED proof: from the S4 probe pod labelled `app=lensa`: TLS handshake to each party gateway completes with the party's client cert and returns the gateway's deny for a request outside the party's bundle (positive control first, then the negative); the same from a pod in `default` is refused; bank C: connect from the cluster-1 egress /32 succeeds (positive control), a hosted-runner probe is refused; `kubectl get netpol allow-from-lensa -n rd-zeto-bank-a -o name` exists.
- Rollback: delete `allow-from-lensa` per namespace; remove the ACL entry for the cluster-1 egress /32.
- Sources: zeto PLAN S16-S17; TEAM.md section 5 (LB rule); CURRENT.md section 4.

### S6: Deploy `lensa` idle beside the host service (blue/green, shadow)
- DELTA: none
- Owner: fe  Size: M
- Prerequisites: S3, S4, S5; restore test of the snapshot class passed (see Backup)
- Flags: CLUSTER-OP, spend (disk, already in S4b)
- Does: Deployment `lensa` from digest, replicas 1, `Recreate`; pod security: `runAsNonRoot` UID 10001, `fsGroup` 10001, `seccompProfile: RuntimeDefault`, `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`, `readOnlyRootFilesystem: true` with `emptyDir` at `/tmp`; env from `lensa-env`; Secrets mounted at `$LENSA_GW_MTLS_DIR/<party>/`; PVC at `/app/frontend/server/state`; probes: `startupProbe` `/api/readyz` (30 x 5 s), `livenessProbe` `/api/livez` (period 30, failureThreshold 3), `readinessProbe` `/api/readyz` (period 10, failureThreshold 2); resources start at requests 250m / 512Mi, limits 1 / 1Gi [unverified: measured here, then fixed in the manifest]; Service `lensa` ClusterIP 8790. Seed: the operator copies the not-reconstructable files (CURRENT.md section 3) and the public state files from the host `server/state` into the PVC by name list (no key field may remain: stealth S21 and iroha3 S16 are prerequisites; the copy script refuses a file with a key field). The pod is the shadow: only read endpoints are called on it (health, history, balances, network). The host stays the live Lensa.
- RED proof: `kubectl -n rd-lensa rollout status deploy/lensa` -> `successfully rolled out`; `kubectl -n rd-lensa get pod -l app=lensa -o jsonpath='{.items[0].status.containerStatuses[0].ready}'` -> `true`; through the operator port-forward `GET /api/health` lists all five models `ready` with the four Paladin nodes and Besu up (positive control: the same call on the host service); `kubectl -n rd-lensa get pod -o jsonpath='{.items[0].spec.volumes[*].name}'` shows no token volume; `sha256sum` of `trades.jsonl`, `lensa-journal.json`, `policy/*/audit.jsonl` on the PVC equals the seeded copy after the smoke (no write happened); restart drill: `kubectl delete pod` of the idle pod (inside the CLUSTER-OP) and the PVC files still match.
- Rollback: `kubectl -n rd-lensa scale deploy/lensa --replicas=0`; the host service never stopped.
- Sources: `ecc:kubernetes-patterns` (Deployment template, probes); `ecc:deployment-patterns` (blue/green); CURRENT.md sections 1, 3.

### S7: Entry point
- DELTA: none
- Owner: fe (manifests), user (L1-L3 decisions)  Size: S (option A) / M (B, C)
- Prerequisites: S6, L1, L2, L3
- Flags: option A: CLUSTER-OP (ServiceAccount token issue is user-only). Option B: CLUSTER-OP, spend (CLB, EIP, bandwidth), user-only (the allowed /32 list and the domain)
- Does: Option A (default): no external object. The user gets the namespace-scoped `lensa-access` token and runs `kubectl -n rd-lensa port-forward svc/lensa 8790:8790` from their own machine: the same property as `ssh -L` today (loopback only, nothing public). Option B: Service `lensa-ext` type LoadBalancer (CLB) with the whitelist ACL annotations FIRST (`...-acl-status: "on"`, `...-acl-type: "white"`, `...-acl-id`) and verified on the listener, then `allow-ingress-entry` with `ipBlock 100.64.0.0/10`; TLS terminates per L3; auth per L2. Option C (VPN or private network) is the same as B with a private CLB address and the user's network; not planned further until the user names it.
- RED proof: option A: `kubectl auth can-i create pods --subresource=portforward -n rd-lensa --as=system:serviceaccount:rd-lensa:lensa-access` -> `yes`, `get secrets` -> `no`, `create pods` -> `no`; `kubectl get svc -n rd-lensa` shows only ClusterIP. Option B: ACL read-only CLI shows `AclStatus on`, `AclType white`, `AclId`; positive control (connect from an allowed address) before the negative (hosted-runner probe refused); no request without the L2 credential returns the UI.
- Rollback: delete `lensa-ext` (B) or the `lensa-access` token (A).
- Sources: TEAM.md section 5 (LB rule); CURRENT.md section 1 (access today).

### S8: Cutover window, host service to pod
- DELTA: none
- Owner: fe (steps), lead (window)  Size: M
- Prerequisites: S6, S7, L7 decided, restore test passed, a window named by the user (no live flows, one Lensa restart window per day, TEAM.md section 5)
- Flags: CLUSTER-OP (scale, copy, rollout restart), user-only (maintenance window), `lead` says "WINDOW OPEN" first
- Does: under `flock /tmp/lensa-paladin.lock`: (1) `VolumeSnapshot lensa-state-<date>` of the PVC and a host copy of `server/state` and `~/iroha3-pools` (named backup, mode 700). (2) Stop `lensa.service` on the host (stop only; the 17 forwards and all unit files stay). (3) Final copy host -> PVC of the not-reconstructable files, `sha256sum` equal on both sides. (4) `kubectl rollout restart deploy/lensa`, readiness 200. (5) Entry switches (S7). (6) Smoke through the pod: `/api/health` all models ready; `GET /api/history` for each model shows the pre-window tx ids; one smallest demo transaction per model under the lock, each visible in `/api/history` (the five tx ids quoted). (7) Rollback drill before the window closes (below), then leave the pod live. Both Lensa instances never write in the same window.
- RED proof: before the window `GET /api/history?model=<m>` on the pod equals the host's pre-copy count; after: pod history shows the old ids plus the five new ones; `sha256sum trades.jsonl` host (pre-stop) == pod (post-copy); `systemctl --user is-active lensa.service` -> `inactive` after step 2 and `/api/health` on the pod 200 after step 4; the stress dialog and the Publisher open without error in the browser through the entry.
- Rollback: before the first pod write: `kubectl -n rd-lensa scale deploy/lensa --replicas=0`, `systemctl --user start lensa.service` (Wants units are still running), entry back to the host; host state is untouched. After a pod write: copy the not-reconstructable files PVC -> host first (checksums), then start the host service; roll forward is preferred if the pod is healthy.
- Sources: `ecc:deployment-patterns` (blue/green, rollback checklist); TEAM.md section 5 (explicit "WINDOW OPEN" word from `lead`); CURRENT.md section 3.

### S9: Retire the host service and the 17 `lensa-pf@*` units (LAST)
- DELTA: none. AFTER row: "no kubeconfig of any org on the Lensa host" (zeto S20 completes it)
- Owner: fe (host steps), lead (GO)  Size: S
- Prerequisites: S8 done and a soak period with no incident named in the GO (default 3 days of normal use); qa PASS of every platform's cutover (README L6) so nothing depends on the old forwards; all platform decommission checks for forwards clean (LENSA.md section 6: `forwards.conf` 0 lines per namespace)
- Flags: user-only, CLUSTER-OP-class GO (own approval; host only, no cluster object), destructive
- Does: named backup first (`lensa-host-final-<date>`: `server/state`, `~/iroha3-pools`, `lensa.env` names list; no value copied into git). Then: `systemctl --user disable --now lensa.service`; stop and remove the 17 `lensa-pf@*` instances; remove the unit symlinks created by `deploy/install.sh`; remove `KUBECONFIG` / `FABRICX_KUBECONFIG` and every kubeconfig file from the host and from `lensa.env`; remove the host copies of `server/state` key material and `~/iroha3-keys` only as L7 allows; delete `deploy/forwards.conf`, `deploy/pf.sh`, `deploy/lensa-pf@.service`, `deploy/lensa.service`, `deploy/install.sh`, `deploy/update.sh`, `deploy/healthwait.sh` in a repo PR (their job is the image and the manifests now); README in English and updated (the Indonesian gateway bullet at `README.md:87` is translated in the same PR).
- RED proof: `systemctl --user list-units 'lensa*' --no-legend` -> empty; `ss -ltn \| grep -c ':8790'` -> `0` on the host; `ls ~/.config/lensa 2>&1` -> `No such file`; `find ~ -maxdepth 3 -name '*.yaml' \| xargs grep -l 'client-key' 2>/dev/null` -> no Lensa kubeconfig (names only reported); `kubectl -n rd-lensa get deploy lensa` still `1/1`; the pod answers `/api/health` after the host cleanup (nothing leaned on the host).
- Rollback: none for deleted secrets; unit files and state come back from the named backup `lensa-host-final-<date>` and the repo history; the pod is unaffected.
- Sources: `deploy/lensa.service`, `deploy/forwards.conf`, `deploy/install.sh` at `rd-lensa-frontend@28c8bdb`; LENSA.md sections 4.1, 6; zeto PLAN S20-S22.

## Network summary (S4/S5)
| Direction | Allowed | Everything else |
|---|---|---|
| Egress | DNS; cluster-1 party gateways (BI, A, B) by namespace + pod label + port; bank C public gateway endpoints by `ipBlock` /32 + port | denied (no registry, no kube API, no internet; image pull is done by the node) |
| Ingress | none (L1 A, port-forward); or the ingress/CLB source for L1 B/C | denied |

## Backup
- Not reconstructable (CURRENT.md section 3): `noto/trades.jsonl`, `policy/*/audit.jsonl`, `lensa-journal.json`. Everything else is public chain data and is also in CONTRACTS.md.
- A `VolumeSnapshot lensa-state-<date>` (class `rd-retain-snapshot`) before S8, after each release, and weekly by hand until a CronJob is asked for. Restore test (a gate for S6 and S8): create a scratch PVC from the snapshot in `rd-lensa`, mount it in a throwaway pod, `sha256sum` the three files equal to the live ones, delete the scratch objects.
- The PV is `Retain`: deleting the PVC does not delete the disk. Deleting `rd-lensa` is user-only, with a named backup first (same rule as README decision 23).

## Spend (per CLUSTER-OP, README decision 3 and 29)
| Step | Registry | Load balancer | Disk |
|---|---|---|---|
| S3 | `ghcr.io` private package; no new account, under the existing GitHub plan [unverified quota]; CI minutes | none | none |
| S4 | none | none | one PVC `lensa-state` 5Gi, one disk-attach slot (scarce, TEAM.md section 5): `lead` approves |
| S5 | none | none (annotation on existing bank C LBs) | none |
| S6 | none | none | snapshot storage (a few MB) |
| S7 A | none | none | none |
| S7 B | none | one CLB instance + bandwidth + (EIP if not shared) [price not read] | none |
| S8-S9 | none | none | snapshot storage |

## User decisions (this plan; row ids `L1`.. so they do not clash with README rows 1-30; L4 is withdrawn, its question moved to L7)
| # | Decision | Blocks | Options | Recommended / default if the user says nothing |
|---|---|---|---|---|
| L1 | Entry: how a person reaches Lensa | S4 (policy variant), S7 | A: ClusterIP only, operator `kubectl port-forward` with a namespace-scoped token (no new public surface, $0). B: public CLB with a whitelist ACL of named /32 addresses. C: VPN or private network the user supplies | A. B only if the user wants a link without a cluster credential on each viewer's machine |
| L2 | Auth in front of the API (none exists today, CURRENT.md section 1) | S7 B/C | none while L1 = A / HTTP basic auth at the entry (one shared Secret `lensa-basic-auth`) / per-user login in Lensa (new code, not planned) | none under A (the token is the control). Basic auth is mandatory before B or C |
| L3 | TLS certificate and domain | S7 B/C | none under A (loopback http) / a domain the user owns plus a certificate on the CLB listener or cert-manager [cert-manager on cluster 1 not read] | none under A. For B/C the user supplies the domain and says which certificate source |
| L5 | Sibling source for the build (replaces full-suite CI option A with the user) | S1, S3 | vendored copy in the repo (S1) / deploy key in CI checks out the private sibling repos | vendored copy: no CI credential, full suite runs in CI. Costs a re-copy script and a provenance check |
| L6 | Registry | S3 | `ghcr.io` private package (as the Iroha images; a `ghcr-pull` Secret already exists in `dfabi`) / Alibaba ACR (new product, spend) | `ghcr.io` private |
| L7 | Where `dvp-shared` runs once Lensa is a keyless pod (it needs all Iroha seeds and `docker run` in one process: iroha3 PLAN S16, README row 18). **DECIDED 2026-11-11 "iroha dvp 1"** (analyst classification, pins iroha@071e281e) | S8, S9 (both BLOCKED(L7)) | A: leave it on the host = ACCEPTED SHORTCUT (row-18 interim; the host service is never retired, S9 cannot finish). B: a separate Deployment in `rd-lensa` holding the Iroha seeds = DEVIATION (against ARCHITECTURE-iroha3.md AFTER :127-149: each org's seed only in its own namespace; Lensa shared, no keys): not planned. C: disable the two-leg Iroha DvP in the in-cluster Lensa (clear "not available" answer) = ALIGNED on keys, R3 GAP on Iroha. D-APS (per-bank private legs) = BLOCKED: no wire format to exchange legs (`client/private_settlement.rs:2527-2557`, `wallet.rs:139-148, 379-384`), adding one = custom code. D-native = per-bank `CanExecuteSettlement` grant (`permission.rs:785-799`) + counterparty-submitted `DvpIsi` with AllOrNothing (`isi/settlement.rs:561-576, :624`): keys ALIGNED, R3 ALIGNED, R1 GAP (the legs are public inside the dataspace). USER DECISION 2026-11-11 "iroha dvp 1": C now + D-native as the Iroha atomic DvP path (per-bank `CanExecuteSettlement` grant from each bank's own-namespace client with its own key; the counterparty's own client submits `DvpIsi` AllOrNothing bound to the intent hash; Lensa relays public terms only, no keys); R1 GAP accepted (legs public inside the dataspace); A and B not planned; host `dvp-shared` retires at S9. S8/S9 unblocked for C; D-native is iroha3 PLAN S17 work under the standing GO | iroha3 PLAN S17 |

## Open items for `lead` (not decisions)
- Client cert scope per platform gateway (see Names); `besu`, `iroha`, `fabric` to confirm what each gateway accepts.
- `iroha3.json` `torii.*` and `aps.auditor` point at gateway URLs only after iroha3 S16; the pod's seed copy must carry the new values (the copy script checks).
- Pool index `pools.json` (Iroha) is written by the driver, not by Lensa; where it lives after iroha3 S16 is [unverified]. Only `lensa-journal.json` is Lensa's own.
- README `Implementation schedule` needs a row L5b for S1-S9 and the status line `lensa: L5b S<id> waiting on <GO|PR|review|nothing>`; `lead` edits the README, this file does not.
- Memory and CPU of the pod are not measured (S6 measures); the first limits are starting values.

## Build notes 2026-11-11 (what the repo steps found; Lensa side of zeto S19/S20, S4b)
- **Paladin clients were not on the per-party path.** The Zeto adapter's Paladin clients came from the vendored `besu/zeto/src/common.ts` `nodeConnections` (loopback ports from `config.json`, one flat cert read when the module loads): `LENSA_GW_PALADIN_<P>` and the per-party certs never reached them, and a cert directory with only party subfolders (the state after S19) would have crashed the server at import. Fixed in rd-lensa-frontend #35: owned `zetoConnections()` (URL from `paladinUrl(party)`, that party's agent) and a second recorded patch to the vendored `common.ts` (the load-time cert read is removed; `server/vendor/PROVENANCE.md`, `scripts/vendor-siblings.sh`).
- **TLS servername rule (G1).** The gateway certificates carry no IP SAN. In per-party mode (a subfolder `<P>/` exists in `LENSA_GW_MTLS_DIR`) Lensa verifies the gateway as its service name: `bank-gw-<N>` for the Paladin and Besu doors, `fx-gw-<N>` for Fabric-X [name unverified until fabricx S16]; flat mode (one shared cert, IP SAN) is unchanged (`gateway.ts` `gwTarget`, `gwAgent`).
- **CSR flow (S4b item 3).** Lensa generates its own EC key and CSR per party (`deploy/mtls/csr.sh <BI|A|B|C>`), the party signs with `extendedKeyUsage=clientAuth` and returns `lensa.crt` + its gateway `ca.crt`; `deploy/mtls/install-signed.sh` accepts a cert only if it verifies against that CA, has clientAuth and matches our key. The Lensa key never leaves Lensa; no party private key reaches Lensa. The four Secrets `lensa-gw-mtls-{bi,a,b,c}` in `rd-lensa` were created from these files in one apply (S4b-D, 2026-11-11 15:42 UTC).
- **Host paths = accepted interim transport credentials.** `~/.opa-mtls-party/<P>/{ca.crt,lensa.crt,lensa.key}` and `~/.opa-sink-tokens/<P>` (dir 700, files 600, uppercase party ids `BI|A|B|C`; besu maps `bi/bank-a/bank-b/bank-c`) serve the host Lensa until the cutover; they are shredded at S9 with the rest of the host credentials. They are client identities and a bearer token for the party's own gateway, not keys of a party.
- **S20 (a) Publisher through the sinks** (rd-lensa-frontend #37, opt-in `LENSA_SINK_TOKENS_DIR`): unsigned own bundles to the owner's sink, BI's signed `bi` fetched from BI's sink (G4 `GET /sink/bundles/<name>/latest`) and relayed byte-identical to the bank sinks, `Content-Length` always sent, tokens read from 700/600 files and never put in a message. A failed publish cannot restore the previous bundles (the sink is append-only). The host switch is S8.
- **S20 (b) Besu network view** (rd-lensa-frontend #34): each validator is read through its own party's Besu door (`eth_blockNumber` decides up/down; `net_peerCount`, `eth_syncing` are extras the bundle may deny); no `kubectl`, no `FABRICX_KUBECONFIG`.
- **sdk D (zeto):** `createLock`, `prepareSpendLock`, `delegateLock`, `cancelLock`, `mint`, `transfer`, `balanceOf` and the pool deploy are Lensa-built plain `ptx` requests (#26 to #38); the private `IZetoFungible_V1` ABI is a PR #1189 artifact (see `server/vendor/PROVENANCE.md`). Still on the vendored SDK build: Atom calls, Pente group deploy, `PaladinClient`.

## DEVIATION REQUEST
None.
