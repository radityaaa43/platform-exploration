# CURRENT: iroha3 as it runs now (cluster 1, ns iroha3)

Skills loaded before the work (Skill tool): `superpowers:verification-before-completion` (every claim = command + quoted output or path:line), `ecc:kubernetes-patterns` (rows for probes, Secrets, PVC, NetworkPolicy), `ecc:documentation-lookup`.
Not run as skills, one line each: `ecc:code-explorer` and `caveman:cavecrew-investigator` are agent types, not Skill-tool skills; I ran `ecc:code-explorer` as ONE sonnet subagent for the repo path:line map and re-checked its key lines myself. context7 `resolve-library-id("Hyperledger Iroha")` returned only an unrelated Go framework (Touka), so Iroha setting names are checked in the pinned source `iroha@071e281e crates/iroha_config/src/parameters/user.rs` (nexus.atomic_private_settlement fields at :11285-11328, `local_budget_bytes` :9707, `trusted_peers`/`public_address` :845/:7836-7843 from my earlier study).

Observed 2026-11-11 16:17 CST, read-only. Cluster 1 kubeconfig (name withheld): `kubectl version` -> `Server Version: v1.33.3-aliyun.1`. Repo heads: iroha3-rd-dfabi `bc55e68`, iroha3-rd-node-build `ceccc4d`.
Tags: [L] = live command on cluster 1 or the host, output quoted; [R] = repo `path:line`; [H] = hash/equality check (no value printed); [U] = not verified, says why. Secret VALUES were never printed; only names, key names, and sha256 prefixes.

## 1. Peers (4 validators)
| Fact | Evidence |
|---|---|
| 4 StatefulSets `bi bank-a bank-b bank-c`, 1/1, age 40h, replicas 1 each, image `ghcr.io/radityaaa43/iroha3-rd-node:071e281e-stark` | [L] `kubectl -n iroha3 get sts,deploy -o wide`: `statefulset.apps/bank-a 1/1 40h iroha3d ...:071e281e-stark` (same for bank-b, bank-c, bi) |
| Same image in repo, init container too | [R] `deploy/k8s/base/statefulset.yaml:40,51` |
| Binary build = pin 071e281e, features incl. `zk-stark`, `external-software-signer-bin` | [L] GET `http://127.0.0.1:38080/status` (Norito) contains `2.0.0-rc.2.0)(071e281e778c5928cab4d6e007b7ddc9b050df27` and `...,external-software-signer-bin,gost,...,zk-stark` |
| Pods 1/1 Running, 0 restarts, age 23h; nodes `member-16029/16036/16035/16041-node` | [L] `kubectl -n iroha3 get pods -o wide` (bank-a-0 172.24.20.120, bank-b-0 .19.134, bank-c-0 .18.177, bi-0 .18.191) |
| args `--sora --config /config/peer.toml`, ports p2p 1337 + api 8080, env only `TELEMETRY_PROFILE` | [L] sts bi jq: `"args":["--sora","--config","/config/peer.toml"],"ports":["p2p:1337","api:8080"],"env":["TELEMETRY_PROFILE"]`; [R] `statefulset.yaml:55-64` |
| resources requests 250m / 1Gi, limits 2 CPU / 3Gi | [L] `"resources":{"limits":{"cpu":"2","memory":"3Gi"},"requests":{"cpu":"250m","memory":"1Gi"}}` (all four); [R] `statefulset.yaml:66-71` |
| Probes: startup `/livez` api period 5 s x60 (timeout 1), liveness `/livez` period 10 s x3 timeout 3, readiness `/readyz` period 5 s x3 timeout 3 | [L] sts bi jq `startup/liveness/readiness`; [R] `statefulset.yaml:75-93`. NOT `/health` (role file AGENT.md says `/health`) |
| updateStrategy `OnDelete`, podManagementPolicy `Parallel`, serviceName = party | [L] `"updateStrategy":"OnDelete","podMgmt":"Parallel","svc":"bi"`; [R] `statefulset.yaml:9-13` |
| priorityClass `iroha3-peer` value 10000 | [L] `kubectl get priorityclass iroha3-peer -o jsonpath='{.value}'` -> `10000`; [R] `statefulset.yaml:24` |
| Pod security: runAsNonRoot, uid/gid/fsGroup 1001, fsGroupChangePolicy OnRootMismatch, seccomp RuntimeDefault; container no privilege escalation, drop ALL; no readOnlyRootFilesystem on peers | [L] `"podsec":{"fsGroup":1001,...,"runAsUser":1001,"seccompProfile":{"type":"RuntimeDefault"}}`, `"sec":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]}}` |
| initContainer `storage-dir`: `mkdir -p /pvc/data && chmod 00700 /pvc/data` (SoraNet needs owner-only, non-setgid /storage) | [L] `"init":["storage-dir"]`; [R] `statefulset.yaml:36-48` |
| Mounts: `config -> /config/peer.toml` (Secret `peer-<party>`), `genesis -> /genesis/genesis.signed.nrt` + `genesis.expected_hash` (ConfigMap `genesis-a3d75eea`), `data -> /storage` | [L] `"mounts":[...]`, `"vols":[{"name":"config","src":"secret:peer-bi"},{"name":"genesis","src":"configMap:genesis-a3d75eea"}]`; bank-a/b/c: `"sec":["peer-bank-a","genesis-a3d75eea"]` etc. |
| PVC `data-<party>-0` 5Gi RWO `alicloud-essd-wffc`, Bound, age 40h | [L] `kubectl -n iroha3 get pvc` |
| Genesis label `iroha3-rd/genesis: a3d75eea` on all four, matches repo | [L] `"genesis":"a3d75eea"` (x4); [R] `deploy/k8s/kustomization.yaml:12-15` |
| 4 old genesis ConfigMaps still exist, unreferenced: `genesis-5eec7287 9a4a1989 d23c355a ea8b5dff` | [L] `kubectl -n iroha3 get cm` (5 `genesis-*`; only `a3d75eea` appears in any pod spec above) |
| Config pins (trusted_peers = 4 entries `pubkey@addr:<party>-0.<party>.iroha3.svc.cluster.local:1337#crc`; public_address same host; bind `addr:0.0.0.0:1337`; torii `0.0.0.0:8080`; chain `851464f5-af06-4311-8cb5-455cf74d0428`; telemetry urls `http://<party>-0.<party>.iroha3.svc.cluster.local:8080/`) | [H] Secret `peer-<party>` == generated `network/out/<party>/peer.toml`: `bi live=97d272a9b342 repo(network/out)=97d272a9b342 SAME`, same for bank-a `fcea199b6b14`, bank-b `de2cd162ea43`, bank-c `154b7385d2ce`; lines from the file: `trusted_peers = ["ea0130A5901ABF…@addr:bi-0.bi.iroha3.svc.cluster.local:1337#E61A", ...`, `public_address = "addr:bi-0.bi.iroha3.svc.cluster.local:1337#E61A"` (`network/out/bi/peer.toml:7,53`); generator `network/generate.sh:96-97,105-108,123-128` |
| Peer config also sets `lane_count = 3`, `local_budget_bytes = 3221225472` (3 GiB), `max_validators = 4`, `stake_elected` | [R] `network/out/bi/peer.toml:68,112` and `[nexus.staking]`; `network/nexus.toml:12-30,64-69,92` |
| NOT done: reading peer.toml VALUES from the Secret | [U] only the hash comparison above; `network/out/` (git-ignored, mode `drwx------`) holds all four peers' files incl. their private keys on the operator PC |

## 2. bi-auditor
| Fact | Evidence |
|---|---|
| Deployment `bi-auditor` 1/1, image `ghcr.io/radityaaa43/iroha3-rd-driver:be4dd898`, strategy Recreate, pod `bi-auditor-55d997fff8-vvrrw` restarts 0 | [L] `get deploy -o wide`; `"strategy":"Recreate"`; pod imageID `ghcr.io/radityaaa43/iroha3-rd-driver@sha256:ab6e8154c919e4a25dd5817158756c6a4921e814212c5cd42b89e2c882a337f7` |
| args `auditor /config/rd-dfabi.toml`, port `http:8090`, readiness tcpSocket http period 10 s (no liveness/startup) | [L] jq `"args":["auditor","/config/rd-dfabi.toml"]`, `"readiness":{...,"tcpSocket":{"port":"http"},"periodSeconds":10}`; [R] `deploy/k8s-apps/bi-auditor.yaml:53-60`. The log line `request failed: Broken pipe` every 10 s = this probe (benign) |
| resources 50m/64Mi requests, 500m/256Mi limits; readOnlyRootFilesystem, drop ALL, uid/gid/fsGroup 1001, automount token false | [L] jq `"resources":{...}`, `"automount":false`, `"sec":{...,"readOnlyRootFilesystem":true}` |
| Mounts: `config`(ConfigMap `rd-dfabi-config`) `/config`, `peers`(`rd-dfabi-peers`) `/peers`, `genesis`(`genesis-a3d75eea`) `/genesis`, `key`(Secret `bi-auditor-key`) `/keys`, `store`(PVC `bi-audit-store`) `/audit-store` | [L] `"vols":[{"name":"config","src":"rd-dfabi-config"},...,{"name":"key","src":"bi-auditor-key"},{"name":"store","src":"bi-audit-store"}]` |
| Secret `bi-auditor-key`: keys `bi-auditor.hybrid`, `bi-auditor.seed` (Opaque) | [L] `bi-auditor-key type=Opaque keys=bi-auditor.hybrid,bi-auditor.seed` |
| PVC `bi-audit-store` 1Gi RWO `alicloud-essd-wffc` Bound, age 47h; 147 records via the auditor | [L] `get pvc`; GET `127.0.0.1:38090/records` -> `auditor total records: 147` |
| Service `bi-auditor` ClusterIP 10.200.6.183 :8090 -> `http` | [L] `get svc -o wide`; `{"type":"ClusterIP","ports":[{"name":"http","port":8090,...}]}` |
| Audit policy: ONE auditor, `min_approvals: 1`, `auditor_id` = the auditor key | [R] `driver/src/aps.rs:917,919` (node-build main) |
| Auditor rules: `max_rd = 10000000000`, `max_dfabi = 10000`, 4 allowed parties, `store_dir = /audit-store`, `listen 0.0.0.0:8090` | [R] `deploy/k8s-apps/rd-dfabi.toml:29-39` |
| `GET /records` serializes 7 fields only | [L] `/records/3a004906...` keys -> `['amount','asset','bundle_id','leg','payer','recipient','verdict']` |

## 3. Genesis, assets, accounts, topology
| Fact | Evidence |
|---|---|
| chain id `851464f5-af06-4311-8cb5-455cf74d0428` | [R] `network/public/chain_id:1`, `deploy/k8s-apps/rd-dfabi.toml:4`; also in generated peer.toml `chain =` (above) |
| Genesis hash `hash:A3D75EEA3228F8C6C8AD05DD409FAB3CE861C25C0D5162044E7EA384856CE37B#AAF1`, ConfigMap = repo | [L] `kubectl -n iroha3 get cm genesis-a3d75eea -o jsonpath='{.data.genesis\.expected_hash}'` and `cat network/public/genesis.expected_hash` print the same string; ConfigMap keys `genesis.expected_hash,genesis.public_key` |
| Assets: RD `7onbjg2gRXveoAAUFsohCZyGW98t`, DFABI `4mBWK1JCwQdHLDPpuVKc56eLsXka`, scale 0, `balance_scope_policy: DataspaceRestricted`, mintable Infinitely; aliases `rd#<domain>`, `dfabi#<domain>`; domain `wonderland.universal` | [R] `deploy/k8s-apps/rd-dfabi.toml:4-11,20-21`; `network/genesis-rd-dfabi.jq:8,32-34` |
| Accounts at genesis: bi, bank-a, bank-b, bank-c, each minted 1000 of fee asset `6TEAJqbb8oEPmLncoNiMRbLEK6tw`; BI gets CanMintAssetWithDefinition; reader role (CanReadRestrictedDataspace per dataspace) to bi, bank-a, bank-b, NOT bank-c | [R] `genesis-rd-dfabi.jq:10,11,16,17,25-28` |
| Topology in OUR genesis transactions: `topology: []` in both extra transactions. Signing still needs an exact 3f+1 topology over all transactions | [R] `genesis-rd-dfabi.jq:29,36`; upstream `crates/iroha_genesis/src/lib.rs:3841-3860` (analyst point, confirmed earlier). Peer-SET change = re-signed genesis = reset |
| Lanes: 3 (universal id 0 public; ds-rd id 1 restricted; ds-dfabi id 2 restricted), each dataspace fault_tolerance 1, all 4 validators in all lanes (committee 3f+1 = 4) | [R] `network/nexus.toml:8-9,12-30,35-53`; assets map to lanes rd=1, dfabi=2 `rd-dfabi.toml:25-26` |
| Pool state now: epoch 52, 155 leaves per pool, 52 bundles per pool | [L] driver `pool-history`: `pool_history asset=rd epoch=52 leaves=155 root=d7d28191...`, `asset=dfabi epoch=52 leaves=155 root=4b08b46e...`; `pools.json: ... rd bundles=52 dfabi bundles=52` |
| Pool ids: RD `c85bab68a437...aa6c3a4`, DFABI `e56e5b6b96a1...8db5`; 1 RD bundle listed at height 0 (the 15:47 aborted one `52289681...`, receipt `aborted` on all 4 Torii) | [L] `jq` on `/home/ecs-user/iroha3-pools/pools.json`; GET `/v1/nexus/private-settlements/bundles/52289681.../receipt` -> `{"status":"aborted",...}` on 38080-38083 |
| Live chain epoch exposure: default `epoch_length_blocks` 3600; the epoch end needs the Pasta mint-finality authority that stock `iroha3d` cannot load (`iroha_core/src/sumeragi/v2_worker_io_execution.rs:262-270`, loader only in `iroha3d_taira`), so the live chain is expected to stall at height 3600 [inferred]; height ~657 on 2026-11-11, grows only with transactions | [R] user decision "iroha iii" 2026-11-11; monitoring line: keep height < 3000 or plan the new chain (S5) before it; no change to the live chain |
| Live asset/account definitions on chain | [U] Torii query endpoints need signed requests (`GET /v1/privacy/capabilities` -> HTTP 401 unauthenticated); chain facts above are from the genesis source + wallet reads, not an on-chain query |

## 4. APS parameters and fee rule
| Fact | Evidence |
|---|---|
| Gate `[nexus.atomic_private_settlement]`: `enabled = true`, `activation_height = 11`, `minimum_activation_notice_blocks = 10` (shipped default 7200), `max_expiry_blocks = 7200`, `audit_timeout_blocks = 1200`, `prepare_timeout_blocks = 1200`, `commit_timeout_blocks = 1200` | [R] `network/nexus.toml:98-105,94-97`; [L] same section in the live-identical file `network/out/bi/peer.toml:136-143` |
| `[zk.stark] enabled = true`; `--sora` required for the 3-lane config | [R] `nexus.toml:71-72`; `statefulset.yaml:53-56` |
| Driver constants: bundle `EXPIRY_BLOCKS = 1_000`, `SIDECAR_RETENTION_BLOCKS = 1_000_000`, `FEE_SIGNED_MAXIMUM = 1`, `SPONSOR_REIMBURSEMENT = 1`, finality timeout 300 s, poll 500 ms | [R] node-build `driver/src/aps.rs:95,101,103,106,109,110` |
| Public fee: `fee_asset_id 6TEAJqbb8oEPmLncoNiMRbLEK6tw`, `per_instruction_fee = 0.001`, base/per_byte/per_gas 0 | [R] `nexus.toml:79-83`; `deploy/k8s-apps/rd-dfabi.toml:4-11` |
| Private fee rule: the leg-0 (RD leg) payer also pays 1 RD to a note nobody can scan; BI companion leg BI->BI 1 when there is no RD payer. BI RD: rd-issue -1001, dfabi-issue / dfabi-transfer -1 | [R] `aps.rs:106`, `pools.rs` pay(); [L] V4 of the rollout: bank-a RD `4995694 -> 4995692` for a 1-unit transfer; wallet item `"amount":"1","direction":"out","fee":"1"` |
| Sponsor of every bundle, and of pool activation, is BI (operator client) | [R] `aps.rs:208`, `pools.rs:274,347,492,507` (`cfg.sponsor("bi")`) |
| Shared pools (RD, DFABI): every Lensa flow is a 2-leg bundle [RD, DFABI]; `pay` adds a companion leg; `dvp-shared` is the DvP | [R] `iroha3-aps.ts:75,103,125,131`; `pools.rs` pay/dvp |

## 5. Network: Services, ports, NetworkPolicy, Torii forwards
| Fact | Evidence |
|---|---|
| Services `bi bank-a bank-b bank-c`: headless (ClusterIP None), ports 1337/TCP, 8080/TCP, selector `part-of=iroha3-rd, iroha3-rd/party=<party>`; `bi-auditor` ClusterIP :8090 | [L] `kubectl -n iroha3 get svc -o wide`; [R] `deploy/k8s/base/service.yaml:7-16` (base name `peer`, renamed per party by the overlays) |
| No Ingress in the namespace | [L] `kubectl -n iroha3 get ingress` -> `No resources found in iroha3 namespace.` |
| NetworkPolicy `iroha3-rd-peers` (peers): Ingress only; p2p 1337 from pods labelled `part-of=iroha3-rd`; Torii 8080 from ANY pod in the namespace | [L] `{"n":"iroha3-rd-peers","podSel":{"app.kubernetes.io/part-of":"iroha3-rd"},"types":["Ingress"],"ingress":[{"from":[{"app.kubernetes.io/part-of":"iroha3-rd"}],"ports":["TCP:1337"]},{"from":[null],"ports":["TCP:8080"]}]` (`null` = empty podSelector `{}`); [R] `deploy/k8s/networkpolicy.yaml:12-22` |
| NetworkPolicy `bi-auditor`: Ingress only, from pods labelled `rd-dfabi/role=coordinator`, TCP 8090 | [L] `{"n":"bi-auditor",...,"ingress":[{"from":[{"rd-dfabi/role":"coordinator"}],"ports":["TCP:8090"]}]`; [R] `bi-auditor.yaml:112-126`; the scenario Job pods carry that label `scenario.yaml:23` |
| No egress policy on either | [L] `"egress":null` (both) |
| CNI enforces policies (cluster 1) | [L] `kubectl -n kube-system get ds terway-eniip` -> `21/21`; `eni-config disable_network_policy` -> `false` |
| Torii forwards on the Lensa host, all active, 127.0.0.1 only: `38080 svc/bi:8080`, `38081 svc/bank-a`, `38082 svc/bank-b`, `38083 svc/bank-c`, `38090 svc/bi-auditor:8090` | [L] `systemctl --user status lensa-pf@iroha-*` -> `kubectl port-forward -n iroha3 svc/bi 38080:8080 --address 127.0.0.1` (and the other four); `ss -ltn` shows the five listeners. Host access goes through the API server, so it is not subject to the pod NetworkPolicy |
| Runner: StatefulSet `gha-runner` (actions-runner 2.338.1), ServiceAccount `gha-runner`, Role `gha-deployer`: `get/list/watch/create/update/patch/delete` on statefulsets, services, configmaps, pvc, networkpolicies, jobs, deployments, pods, pods/log; `pods/exec` create; `secrets` get,list | [L] `kubectl -n iroha3 get role -o json`: `{"n":"gha-deployer","rules":[{"r":[...],"v":[...]},{"r":["pods/exec"],"v":["create"]},{"r":["secrets"],"v":["get","list"]}]}` |
| Jobs: `rd-s1-dvp` (image be4dd898, Complete 2m57s, re-run 15:26), `rd-s2a/s2b/s3/s4` (image `23f7a444`), `rd-selftest` (`06486202`) | [L] `kubectl -n iroha3 get job -o wide` |

## 6. Driver and pools on the host
| Fact | Evidence |
|---|---|
| Lensa pins the driver image `ghcr.io/radityaaa43/iroha3-rd-driver:be4dd898` (git-ignored runtime file); local image id `sha256:ab6e8154c919e4a25dd5817...` = pod digest above | [R] `frontend/server/state/iroha3.json:21`; [L] `docker image inspect ... --format '{{.Id}}'` |
| `docker run --rm --network host --memory 2g --memory-swap 2g --cpus 2 --user uid:gid -v state:/state:ro -v keys:/keys:ro -v public:/public:ro -v pools:/pools` | [R] `frontend/server/src/adapters/iroha3-aps.ts:37-41` |
| Mount sources: state `frontend/server/state/iroha3`, keys `/home/ecs-user/iroha3-keys` (mode `drwx------`), public `iroha3/network/public`, pools `/home/ecs-user/iroha3-pools` | [R] `iroha3.json:24-27`; [L] `stat -c '%A %U'` -> `drwx------ ecs-user` |
| pools dir holds `pools.json`, `pools.json.lock`, `lensa-journal.json`, `receipts/`; flock on a local ext4 (`/dev/vda3`) | [L] `ls /home/ecs-user/iroha3-pools`; `stat -f` -> `ext2/ext3` |
| Driver commands Lensa runs: `dvp` (old per-trade path), `pay`, `dvp-shared`, `wallet`; `pool-init` and `pool-history` are operator commands | [R] `iroha3-aps.ts:75,103,125,131,140` |
| Config `/state/rd-dfabi.toml`: `key_dir = "/keys"`, `client_toml = "/state/admin.toml"` (sponsor = operator account key), torii map to `127.0.0.1:3808x`, `auditor` `http://127.0.0.1:38090/` | [L] `grep -nE 'key_dir|client_toml' frontend/server/state/iroha3/rd-dfabi.toml` -> `4:client_toml = "/state/admin.toml"`, `6:key_dir = "/keys"`; [R] `frontend/server/state/iroha3.json:4-7,28` |

## 7. Lensa's role (iroha3)
| Fact | Evidence |
|---|---|
| Lensa is `lensa.service` (user unit, port 8790) with the five iroha forwards in `Wants=` | [L] `systemctl --user show lensa.service -p Wants` -> 5 iroha units; env var NAMES only: `LENSA_ROOT PATH PORT NODE_ENV KUBECONFIG FABRICX_KUBECONFIG OPA_BIN OPA_KEYS_DIR LENSA_BESU_RPC LENSA_GW_MTLS_DIR LENSA_FABRICX_GW LENSA_BESU_RPC_BANKS` |
| Flows (`/api/tx`): every iroha3 flow runs as a driver container (`pay` / `dvp-shared`); reads: wallet per party via `wallet`, BI history via the auditor `/records` | [R] `iroha3.ts:223-239`, `iroha3-aps.ts:89,149`; [L] V4 `rd-transfer` A->B 1 unit finalized, block 554 |
| Non-APS reads use the `iroha` CLI with node-operator accounts `op-<party>` (CanReadAllLedgerData) from the state dir: files `admin.toml bi.toml bank-a.toml bank-b.toml bank-c.toml op-bi.toml op-bank-a.toml op-bank-b.toml op-bank-c.toml bin keys genesis.expected_hash rd-dfabi.toml` | [R] `iroha3.ts:145`; [L] `ls frontend/server/state/iroha3` (names only); `admin.toml` mode `-rw-------` |
| Lensa keeps a journal of what each flow was in `/home/ecs-user/iroha3-pools/lensa-journal.json` | [R] `iroha3.ts:129`; [L] file present |

## 8. Who holds which keys (names, never values)
| Holder | Names |
|---|---|
| Operator host dir `/home/ecs-user/iroha3-keys` (mode 0700), mounted whole into every Lensa driver run | `bank-a bank-b bank-c bi` x `.seed` and `.note`, `bi.origin-rd.note`, `bi.origin-dfabi.note`, `bi-auditor.seed`, `bi-auditor.hybrid` [L] `ls` stems: `bank-a bank-b bank-c bi bi-auditor` |
| Host state dir `frontend/server/state/iroha3/` | sponsor/operator `admin.toml`, party `bi/bank-a/bank-b/bank-c.toml`, node-operator `op-*.toml`, `keys/`, CLI `bin/` |
| Secret `rd-dfabi-wallets` (Jobs) | `bank-a.seed bank-b.seed bank-c.seed bi.seed` |
| Secret `bi-auditor-key` (auditor pod only) | `bi-auditor.seed bi-auditor.hybrid` |
| Secrets `peer-bi/bank-a/bank-b/bank-c` (one per node) | `peer.toml` (holds the node's keys; `[streaming] identity_private_key` is also in it) |
| Secrets `client-bi/bank-a/bank-b/bank-c` | `client.toml`, `genesis.expected_hash`; `client-bi` = the sponsor/operator account used by the Jobs |
| Operator PC `iroha3/network/out/<party>/` (git-ignored, 0700) | `peer.toml`, `client.toml` per party: hash-identical to the live Secrets (section 1) |
| Runner | Secret `gha-runner-registration` (`RUNNER_TOKEN`); Role can `get/list` all Secrets in the namespace |
| Secrets also present | `acr-credential-*` x2 (`.dockerconfigjson`) [L] `kubectl -n iroha3 get secret -o json | jq` (key names only) |

## 9. R1 as observed (one wallet read per party, read-only)
Command: the driver `wallet --party <p>` via the same `docker run` as Lensa (image be4dd898), then `jq` on the V4 bundle `3a004906e8a3...` (rd-transfer bank-a -> bank-b, 1 unit). Output quoted:
```
{"party":"bank-a","balances":{"dfabi":"19","rd":"5992689"},"items":31,"bundle_items":[{"asset":"rd","direction":"out","amount":"1","fee":"1"}]}
{"party":"bank-b","balances":{"dfabi":"16","rd":"3008194"},"items":31,"bundle_items":[{"asset":"rd","direction":"in","amount":"1","fee":"0"}]}
{"party":"bank-c","balances":{"dfabi":"20","rd":"3008095"},"items":27,"bundle_items":[]}
{"party":"bi","balances":{"dfabi":"999945","rd":"999999987990972"},"items":33,"bundle_items":[]}
auditor /records/<bundle>: [(0,'approved','7onbjg2g','1'),(1,'approved','4mBWK1JCwQdHLDPpuVKc56eLsXka'...,'1')] 
```
- Sender (bank-a) sees its own RD out + fee; receiver (bank-b) sees RD in; outsider bank-c has no item for that bundle (bundle_items is empty; that its other 27 items are all bundles it took part in is [U], not checked per bundle); the BI wallet has no item for it (inferred from the fee rule: BI's part is the DFABI companion leg BI->BI 1, which leaves no wallet row), BI's view of the bundle is the auditor store: both legs `approved`, amounts 1.
- R1 holds at wallet level for this bundle. Not proved here [U]: what a bank's NODE stores. Every validator is in every lane, so all four nodes keep the (sealed) pool data; `reports/a-dataspace-restricted.md:59-73` says plain DataspaceRestricted transfers are NOT sealed, only APS bundles are. Lensa reads outsider views with the operator account, so those views show nothing about outsiders (`NOTES.md` Limits section).

## 10. BEFORE (analyst, `agents/analyst/design/ARCHITECTURE-iroha3.md` section 1) vs found
| BEFORE claim | Found now |
|---|---|
| 4 peers, 1 replica, own 5Gi PVC, Secret `peer-<party>`, `--sora --config` | SAME ([L] sts/pvc/jq above). Line cites moved: statefulset args at `:55-56`, volumes `:118-124`, PVC `:125-133` |
| Torii headless `:8080`, any pod in ns may call, no ingress | SAME ([L] netpol rule, `get ingress` empty) |
| Runner Role `gha-deployer` (pods/exec, secrets get/list) | SAME, exact rules quoted in section 5 (+ create/delete on workloads) |
| Auditor one key, `min_approvals: 1`, one `auditors` entry, Secret `bi-auditor-key`, PVC `bi-audit-store`, own NetworkPolicy | SAME. Line cites moved: `aps.rs:917,919` (analyst `aps.rs:879-884`) after L1..M5 |
| Sponsor always BI | SAME; lines now `aps.rs:208`, `pools.rs:274,347,492,507` (analyst `aps.rs:207`, `pools.rs:273,346`) |
| Live: Jobs `rd-s1..s4` + selftest | Jobs differ in image: s1 `be4dd898` (re-run 15:26 CST), s2a/s2b/s3/s4 `23f7a444`, selftest `06486202` |
| "4 PVC" | 6 PVC in the ns: 4 x `data-*` 5Gi, `bi-audit-store` 1Gi, `runner-state-gha-runner-0` 1Gi |
| (not in BEFORE) | Probes are `/livez` + `/readyz`, not `/health`. WRONG LINE: `agents/iroha/AGENT.md:100` still says `Probes hit /health` (fix PR cancelled by lead; noted here instead) |
| (not in BEFORE) | 4 stale `genesis-*` ConfigMaps unreferenced; auditor and Lensa pin = `be4dd898` after rollout A (14:56-15:03) |
| (not in BEFORE) | `network/out/<party>/peer.toml` on the operator PC is hash-identical to the live Secrets, so one PC holds all four node keys + the `[streaming]` identity keys |
| "genesis private key in network/out" | NOT FOUND now: `ls network/out/bi` -> `client.toml peer.toml`; `network/out/` holds only the four party dirs (no genesis key file there) [U] where the genesis signing key lives now |
| `topology: []` as a peer-set argument (my earlier study) | WITHDRAWN: analyst is right, signing needs an exact 3f+1 topology (`iroha_genesis/src/lib.rs:3841-3860`); our `[]` is only in the two extra transactions |

## 11. Gaps and notes
- [U] peer.toml values beyond the hash match; on-chain asset/account/permission queries (401 without signing); genesis signing key location; node logs (`bi-0` logs warnings only; 15 `monitor.rs:780` telemetry errors per 10 min, cause not examined).
- Key exposure: BI [streaming] identity_private_key printed to the iroha agent terminal on 2026-11-11, rotation pending user decision (no peer restart until the user answers).
- Cluster 2 not touched in this file.

## 12. Decommission inventory, ns `iroha3` (cluster 1 only; planning, nothing deleted)
The final PLAN step "Decommission iroha3" is destructive, user-only, with its own CLUSTER-OP approval at that time. Cluster 2: nothing is ever deleted. Read-only `kubectl get` at 2026-11-11 16:22 CST, `KUBECONFIG=<cluster-1 kubeconfig>`:
| Kind | Quoted inventory |
|---|---|
| Namespaces for Iroha | `kubectl get ns \| grep -iE 'iroha\|sora'` -> `iroha3` only; created `2026-10-19T06:39:59Z`, labels only `{"kubernetes.io/metadata.name":"iroha3"}` |
| Cluster-scoped, created for it | `kubectl get priorityclass iroha3-peer` -> `iroha3-peer 10000` (used by the peers, `statefulset.yaml:24`); no ClusterRole/ClusterRoleBinding matching `iroha\|gha` |
| Deployments | `deployment.apps/bi-auditor 1/1`, plus 7 ReplicaSets (`bi-auditor-55d997fff8` 1 live, 6 old revisions at 0) |
| StatefulSets | `bank-a bank-b bank-c bi` 1/1 age 41h; `gha-runner` 1/1 age 19d |
| Jobs (+ pods) | `rd-s1-dvp Complete`, `rd-s2a-insufficient Failed`, `rd-s2b-audit-reject Complete`, `rd-s3-replay Complete`, `rd-s4-redeem Complete`, `rd-selftest Complete`; 6 pods Completed/Error; `ttlSecondsAfterFinished: 604800` (`scenario.yaml:18`) |
| PVCs (all `alicloud-essd-wffc`, RWO, Bound) | `data-bi-0 5Gi`, `data-bank-a-0 5Gi`, `data-bank-b-0 5Gi`, `data-bank-c-0 5Gi`, `bi-audit-store 1Gi`, `runner-state-gha-runner-0 1Gi` |
| PV reclaim policy | `kubectl get pv -o json \| jq` for claims in iroha3: every row `\| Delete \|` (6 of 6); `kubectl get storageclass alicloud-essd-wffc -o json` -> `{"reclaimPolicy":"Delete","volumeBindingMode":"WaitForFirstConsumer","allowVolumeExpansion":true}`. Deleting a PVC or the namespace DESTROYS the disks |
| Secrets (names only, 13) | `acr-credential-a427d73e...`, `acr-credential-f4cddafa...`, `bi-auditor-key`, `client-bank-a`, `client-bank-b`, `client-bank-c`, `client-bi`, `gha-runner-registration`, `peer-bank-a`, `peer-bank-b`, `peer-bank-c`, `peer-bi`, `rd-dfabi-wallets` |
| ConfigMaps (8) | in use: `genesis-a3d75eea`, `rd-dfabi-config`, `rd-dfabi-peers`; system `kube-root-ca.crt`; STALE, unreferenced by any pod: `genesis-5eec7287`, `genesis-9a4a1989`, `genesis-d23c355a`, `genesis-ea8b5dff` |
| NetworkPolicies | `bi-auditor`, `iroha3-rd-peers` |
| Services / LB / Ingress | `bi bank-a bank-b bank-c` ClusterIP None (1337, 8080), `bi-auditor` ClusterIP :8090; no LoadBalancer, no Ingress |
| RBAC | ServiceAccounts `default`, `gha-runner`; Role + RoleBinding `gha-deployer` |
Must survive (decision for the plan, not an action): the 4 `data-*` PVCs (chain state under `/storage`, each about 364 MB used of 5Gi, [L] `364 MB`/`7%` earlier today) and `bi-audit-store` (147 decrypted audit records; stored capsules cannot be re-decrypted without `bi-auditor.hybrid`). Because the reclaim policy is Delete, keeping them needs an explicit step BEFORE any deletion (retain policy on the 5 PVs, or a copy); not done here. Identities that define the chain also survive outside the namespace: Secrets `peer-*`, `client-*`, `bi-auditor-key`, `rd-dfabi-wallets` (sources `network/out/<party>/`, `~/iroha3-keys`, hash-identical per section 1). Not data: the 6 Jobs and pods, 6 old ReplicaSets, the 4 stale genesis ConfigMaps, the runner and its PVC (re-registrable).
What outside the namespace points at it:
| Pointer | Evidence |
|---|---|
| 5 systemd forwards `lensa-pf@iroha-bi/bank-a/bank-b/bank-c/auditor` (`kubectl port-forward -n iroha3 svc/...`, ports 38080-83, 38090) | [R] `frontend/deploy/forwards.conf:13-18` (`iroha-bi iroha3 bi 38080:8080` ... `iroha-auditor iroha3 bi-auditor 38090:8090`); [L] units `active` (section 5) |
| `lensa.service` `Wants=`/`After=` the 5 iroha units | [R] `frontend/deploy/lensa.service:3-4`; [L] `Wants` shows 5 iroha units |
| Lensa state `frontend/server/state/iroha3.json` (Torii `127.0.0.1:38080-38083`, auditor `:38090`, driver image pin, mounts) and `frontend/server/state/iroha3/` (`admin.toml`, `op-*.toml`, `<party>.toml` with Torii URLs/keys) | [R] `iroha3.json:4-7,21-29`; [L] `ls frontend/server/state/iroha3` |
| GitHub self-hosted runner `iroha3-incluster` registered in `radityaaa43/iroha3-rd-dfabi` | [L] `gh api repos/radityaaa43/iroha3-rd-dfabi/actions/runners` -> `iroha3-incluster online labels=self-hosted,Linux,X64,iroha3`; it runs `deploy.yml:10`, `runner-check.yml:5`, `scenario.yml:24`, `smoke.yml:6` (`runs-on: [self-hosted, iroha3]`); `ci.yml:8` is hosted (`ubuntu-24.04`) and does not depend on the namespace |
| Namespace name baked into configs: peer.toml (`trusted_peers`, `public_address`, `peer_telemetry_urls` = `<p>-0.<p>.iroha3.svc.cluster.local`), `rd-dfabi.toml` torii map, kustomize `namespace: iroha3` | [R] `network/generate.sh:96-97,105-108,123-124`; `deploy/k8s-apps/rd-dfabi.toml:14-17`; `deploy/k8s/kustomization.yaml:3` |
| Host dirs `~/iroha3-keys` (0700), `~/iroha3-pools` (`pools.json`, `lensa-journal.json`, `receipts/`), `iroha3/network/out/` (0700) | [L] `stat`/`ls` (sections 6, 8) |
| Host image: only `ghcr.io/radityaaa43/iroha3-rd-driver:be4dd898` is left locally; older tags are in ghcr | [L] `docker images \| grep -i iroha3` -> `...:be4dd898 2 hours ago` (one line); ghcr tags: `ceccc4d0 011b0082 be4dd898 6136f697 a5e809d8 5015ac3f 972b272d f6f9968b d928b6ee c1afa678`. Rollback to `c1afa678` therefore needs a `docker pull` first. Cause (lead): the older tags went with the lead's tiered disk cleanup earlier today under the user's one-time exception, root fs was 99% |
| GHCR packages `iroha3-rd-driver`, `iroha3-rd-node` (outside the cluster, keep) | [L] `gh api users/radityaaa43/packages/container/iroha3-rd-driver --jq .name` -> `iroha3-rd-driver` (same for `iroha3-rd-node`) |

### Rollback line for the driver image (the rollout text, section 6 and 12)
Rollback to the previous driver image: first `docker pull ghcr.io/radityaaa43/iroha3-rd-driver:c1afa678` (the tag is no longer on the host), then `gh workflow run scenario -R radityaaa43/iroha3-rd-dfabi -f target=auditor -f tag=c1afa678`, pin `frontend/server/state/iroha3.json:21` back to `:c1afa678`, restart `lensa.service`. Each step needs its own approval at that time (cluster write, restart); nothing here is run now.
