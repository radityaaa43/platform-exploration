# CURRENT: Fabric-X as it runs now (read-only study, 2026-11-11 08:20 UTC)

Author `fabric`. Skills used: `superpowers:verification-before-completion` (every live claim = command + quoted line), `ecc:code-explorer` (path:line map of the repo, one sonnet subagent), `ecc:kubernetes-patterns` (namespace, NetworkPolicy, Secret, PVC rows), `ecc:documentation-lookup` (Context7: only Panurus is indexed, and only `main`, not v0.24.0; FSC, committer and orderer are not in Context7, so setting names come from the pinned sources, marked below).
Rules kept: cluster 1 read-only (`kubectl get/describe/logs`, no exec); Secrets by NAME only, ConfigMaps by name; cluster 2: node-level facts only (none needed here); foreign namespaces not read. Live-fact commands use `KUBECONFIG=<cluster-1 kubeconfig>` (never printed). Raw outputs of the commands below: the author's scratchpad `cur/*.json`.
Pins (repo `fabric-x/NOTES.md:5-12`): Panurus v0.24.0 5f3c49e2, FSC v0.24.0 86539af4, committer v1.0.4 08a469d2, orderer v1.0.4 dd296e3f, Ansible collection 0.8.26 315a91ce. Repo HEAD read: `rd-fabric-x main 7bef424` (+ PR #7 open, env only).

## 1. Namespaces
- `fabricx` (ours, cluster 1, ap-southeast-5): everything below.
- `<foreign-ns>`, `<foreign-ns>`, `<foreign-ns>`, `<foreign-ns>`: exist, foreign to the final design, not read inside. Command: `kubectl get ns --no-headers | awk '{print $1}' | grep -i fabricx` -> `fabricx <foreign-ns> <foreign-ns> <foreign-ns> <foreign-ns>`.
- `paladin` (cluster 1) hosts `bundle-server`, which the fx-gw gateways pull bundles from and post decision logs to (section 10).
- One namespace, one cluster for every Fabric-X institution: `panurus-itest/README.md:178` "All institutions run in one cluster namespace"; `k8s.py:30` `NS = "fabricx"`.

## 2. Workloads (44), `kubectl -n fabricx get deploy,sts -o json`
Quoted counts (script over the JSON): `('STS',1,'RollingUpdate'): 24, ('Deploy',1,'RollingUpdate'): 14, ('Deploy',1,'Recreate'): 4, ('Deploy',0,'RollingUpdate'): 1, ('Deploy',0,'Recreate'): 1`. All pods Running: `kubectl -n fabricx get pods --no-headers | awk ...` -> `pods 42 not-running 0`; restart counts: no pod with restarts > 0 printed.
| Group | Workloads (replicas 1 unless noted) | Strategy |
|---|---|---|
| Orderer (Arma), 4 parties x 4 roles | StatefulSets `orderer-{router,batcher,consenter,assembler}-{1..4}` (16), PVC `data-*-0` 2Gi each | RollingUpdate |
| Orderer CAs | Deployments `fca-orderer-org{1..4}`, `fca-org1` + StatefulSets `*-db` (5+5) | RollingUpdate |
| BI committer | Deployments `committer-{coordinator,validator,verifier,query-service}`, StatefulSets `committer-sidecar`, `committer-db` | RollingUpdate |
| Token nodes | Deployments `rdbi-bi` (issuer, endorser-1), `rdbi-bank2/3/4` (bank + endorser + 5 committer containers + db) | **Recreate** |
| Gateways | Deployments `fx-gw-1..4` (envoy, opa, fxapi; init `unpack`) | RollingUpdate maxSurge 0 / maxUnavailable 1 (`k8s.py:369`) |
| Other | `block-explorer` (+`-db`), `orderer-loadgen` (0/0), `rdbi-driver` (0/0, Recreate) | |
- Recreate quote: `Deployment rdbi-bank2 | repl 1 | Recreate | containers bank2,endorser-2,committer-verifier,committer-vc,committer-coordinator,committer-sidecar,committer-query,db`. A bank's node, endorser and committer restart together (AGENT rule).
- Repo: pods and containers `k8s.py:35-36` (`PODS = {"rdbi-bi": ["issuer", "endorser-1"], "rdbi-bank2": ["bank2", "endorser-2"], ...}`); bank committer containers `k8s.py:200-207`; BI has no committer container of its own, it reads `committer-sidecar.fabricx.svc.cluster.local:5130` / `committer-query-service...:5140` (`k8s.py:41`).
- Party map: BI = party 1 / Org1MSP, bank2 = A / OrdererOrg2MSP, bank3 = B / OrdererOrg3MSP, bank4 = C / OrdererOrg4MSP (`k8s.py:38-40`, `cfgupdate/main.go:53-54`).

## 3. Images with digests, from `kubectl -n fabricx get pods -o json` (`.status.containerStatuses[].imageID`)
| Component | Image (tag) @ digest (12 hex) | Quoted line |
|---|---|---|
| committer (all 5 roles, BI and banks) | `docker.io/hyperledger/fabric-x-committer:1.0.4` @ b5bc4c6c010f | `committer-sidecar: sidecar=docker.io/hyperledger/fabric-x-committer:1.0.4@b5bc4c6c010f` |
| orderer (all 16 pods) | `docker.io/hyperledger/fabric-x-orderer:1.0.4` @ 052ae8e16571 | `orderer-router-1: router=docker.io/hyperledger/fabric-x-orderer:1.0.4@052ae8e16571` |
| Postgres | `docker.io/library/postgres:17.10` @ 7958605b474b | `committer-db: postgres=...postgres:17.10@7958605b474b` |
| fabric-ca | `ghcr.io/hyperledger/fabric-ca:1.5.22` @ 87c36f0b6558 | |
| block-explorer | `ghcr.io/lf-decentralized-trust-labs/fabric-x-block-explorer:0.1.0` @ a8f4e56ee6c1 | |
| FSC node (bank2/3/4, issuer) | `ghcr.io/radityaaa43/rdbi-node` pinned `@sha256:71e3b6782215...` (award image, NOTES.md) | `rdbi-bank2: bank2=...@71e3b6782215` |
| endorser-1..4 | `ghcr.io/radityaaa43/rdbi-node:ebbb28f1d552` (older build, tag not digest) | `endorser-2=ghcr.io/radityaaa43/rdbi-node:ebbb28f1d552@61b473e881b1` |
| `rdbi-driver` (0 replicas) | same digest as the node: `@sha256:71e3b6782215...` | `rdbi-driver [('driver', 'sha256:71e3b6782215')]` |
| gateway fxapi | `ghcr.io/radityaaa43/rdbi-node@sha256:2d2cc69f81d9...` (`rdbi-driver serve`) | `fx-gw-2: ... fxapi=...@2d2cc69f81d9` |
| gateway envoy / opa | `envoyproxy/envoy:v1.38.9` @ b1f389c3a614 / `openpolicyagent/opa:1.21.1-envoy-1-static` @ c1f40d815a15 | `k8s.py:281-282` |
- Three different `rdbi-node` builds run at once (node 71e3b678, endorser ebbb28f1d552, gateway 2d2cc69f). Tag `1.0.4` of committer/orderer is identical on ghcr.io and docker.io (`b5bc4c6c`, `052ae8e1`, checked with the registry manifest HEAD, anonymous token); it is [unverified] that the image was built from git tag v1.0.4 (`NOTES.md:14`).
- Repo constants: `k8s.py:32-33` `COMMITTER_IMAGE`, `PG_IMAGE` (`postgres:17.10`; `multiorg/committer/compose.yaml:14` uses `17.10-alpine`).

## 4. Services and ports, `kubectl -n fabricx get svc -o json` (60 services, 47 ClusterIP)
- NodePort (13): orderer routers `orderer-router-N-nodeport 7050->30050, 7150->30150, 7250->30250, 7350->30350`; `committer-sidecar-nodeport 5130->30560`, `committer-query-service-nodeport 5140->30580`; `fca-orderer-org{1..4}-nodeport 9019/9029/9039/9049->30919/30929/30939/30949`, `fca-org1-nodeport 9069->30969`, `block-explorer-nodeport 18000->30690`, `orderer-loadgen-nodeport 12010->30600`. Assembler NodePorts 30052/30152/30252/30352 (our file `multiorg/committer/assembler-nodeports.yaml`) are NOT live: `grep assembler services.txt` -> `orderer-assembler-1 ClusterIP 7052,7062; ... orderer-assembler-4 ClusterIP 7352,7362`, no `-nodeport` service. The file serves the host-side committer (`compose.yaml:38-41`), not the in-cluster bank committers, which reach the assemblers by their in-cluster names.
- ClusterIP per FSC node, named as its TLS cert: `issuer 5100,5101,5102`, `bank2 5103-5105`, `bank3 5106-5108`, `bank4 5109-5111`, `endorser-1 5112-5114`, `endorser-2 5115-5117`, `endorser-3 5118-5120`, `endorser-4 5121-5123` (grpc, p2p, web; web disabled, `opa/networkpolicy.yaml:7-10`). Committer: `committer-coordinator 5120,5220`, `committer-sidecar 5130,5230`, `committer-query-service 5140,5240`, `committer-validator 5100,5200`, `committer-verifier 5110,5210`, `committer-db 5150`. Gateways `fx-gw-N 8443`. Orderer per role `orderer-router-N 7050,7060`, `orderer-assembler-N 7052,7062`.
- Bank committers are pod-local: `localhost:6130/6140` (`k8s.py:42`, port shift `k8s.py:117`); their Postgres has no TLS (`README.md:140`, `committer/config/vc.yaml:19`).

## 5. NetworkPolicies, `kubectl -n fabricx get networkpolicy -o json`
Four, all Ingress-only (`opa/networkpolicy.yaml:23,39,55,71`):
- `rdbi-bi-ingress sel={'app.kubernetes.io/name': 'rdbi-bi'} ingress=[from part-of=rdbi ports [5101, 5113]; from name=fx-gw-1 ports [5100]; from name=rdbi-driver ports []]`; same shape for `rdbi-bank2/3/4-ingress` with ports `[5104,5116]/[5107,5119]/[5110,5122]` and `fx-gw-N` on `5103/5106/5109`.
- Not selected by any policy: committer, orderer, CAs, explorer, fx-gw pods (`opa/networkpolicy.yaml:17`). Egress is open. No default-deny in `fabricx`.
- CNI enforces policy: Terway v1.15.0, `"network_policy_provider": "ebpf"`, `disable_network_policy: false` (kube-system `eni-config`; `kubectl -n kube-system get ds terway-eniip` -> `21/21`).
- bundle-server NetworkPolicy (rd-besu #9) is NOT applied yet (`kubectl -n paladin get networkpolicy` is for the batch).

## 6. PVCs, `kubectl -n fabricx get pvc -o json` + `kubectl get pv -o json`
28 PVCs, all `2Gi alicloud-essd-wffc Bound zone=[['ap-southeast-5b']]`: 16 `data-orderer-*-0`, `data-committer-db-0`, `data-committer-sidecar-0`, 5 `data-fca-*-db-0`, `data-block-explorer-db-0`, `rdbi-{bi,bank2,bank3,bank4}-state` (node stores, sidecar ledger, Postgres via subPaths: `k8s.py:190-210`). Repo: `k8s.py:216` `"storageClassName": "alicloud-essd-wffc" ... "storage": "2Gi"`, `k8s.py:45` zone pin `ap-southeast-5b`.
- Disk-attach on the node of `rdbi-bi` (member-16041-node): `allocatable=5 attached=5 free=0`; PVs are bound to zone 5b; 92 free slots cluster-wide (checked earlier today).

## 7. Secrets (names only) and ConfigMaps (names only)
- Secrets (51), `kubectl -n fabricx get secret --no-headers`: `rdbi-{bi,bank2,bank3,bank4}-files`, `rdbi-driver-files`, `fx-gw-{1..4}-files`, `fx-gw-{1..4}-mtls`, `orderer-{router,batcher,consenter,assembler}-{1..4}-secret`, `committer-{coordinator,validator,verifier,query-service,sidecar}-secret`, `committer-db-secret`, `fca-orderer-org{1..4}`, `fca-org1`, `*-db-secret`, `block-explorer`, `block-explorer-db-secret`, `orderer-loadgen-secret`, `ghcr-pull`, `acr-credential-<hash>` x2. NOT yet present: `bundle-sink-token` (`kubectl -n fabricx get secret bundle-sink-token` -> `NotFound`).
- ConfigMaps (41): `orderer-{router,batcher,consenter,assembler}-N-config` (16), `committer-*-config` (6), `fca-*` (10), `fx-gw-{1..4}-envoy`, `fx-gw-opa`, `block-explorer*`, `orderer-loadgen-config`, `kube-root-ca.crt`.
- Who holds which keys (by name and mount, never values), from the Deployments' `volumes`/`volumeMounts` and `k8s.py`:
  - `rdbi-<pod>-files` (Secret, mode 0400, key `rdbi.tgz`; bank pods also `db-password`) -> unpacked by init `unpack` into the `rdbi` emptyDir at `/home/rdbi/.fabricx-token`: that pod's FSC node and endorser keys, MSP, TLS, `client-config.yaml` (`k8s.py:214-219`). One pod = one institution's keys.
  - `rdbi-driver-files` (Secret, replicas 0): the view-client keys of EVERY node (`opa/DESIGN.md:148-150`, open decision: delete or keep).
  - `fx-gw-N-files`: only party N's view-client key (`rdbi.tgz`); `fx-gw-N-mtls` (`tls.crt`, `tls.key`, `ca.crt`, mode 0444, mounted `/mtls` in envoy and fxapi, `k8s.py:374`).
  - `orderer-*-N-secret` / `fca-*`: the Ansible deployment's keys per orderer party and CA.
  - Shared identity: all nodes submit with one Org1MSP key `ids/anon` (`README.md:118-121`, deviation 2).

## 8. Channel, consensus, endorsement
- Channel `arma`: `cfgupdate/main.go:50` `const channelID = "arma"`. Reset on 2026-11-01 with a new genesis that has capabilities `V3_0 / Orderer V2_0 / Application V2_5` (`main.go:132`, `README.md:103-111`), data on `/data/v2`. Reason: the Ansible 0.8.26 genesis had no capabilities, so MSPv1_0 and no admin could sign a config update (`main.go:10-15`).
- Genesis block (host copy, public): `sha256sum ~/.fabricx-token/multiorg/genesis-multiorg.block` -> `b9c342d7ca7f5cef1ae939eccdf468c547340787071d86c0fc1e39c0e02769ab`. [unverified] that the cluster's sidecars hold byte-identical file (they would refuse block 0 otherwise: committer `utils/deliverorderer/verify.go:240`; the file is inside Secrets, not read).
- Offline check of that block, `go run . check-genesis -block ... -msp ~/.fabricx-token/admin/msp` (multiorg/cfgupdate): `PASS ValidateNewConfig LifecycleEndorsement`, `MSP 4`, `PASS`.
- Consenter set: 4 parties, one consenter each, live `statefulset.apps/orderer-consenter-{1..4} 1/1`; SmartBFT, N = 4 (F = 1).
- Application orgs: Org1MSP (BI) + OrdererOrg2..4MSP (banks reuse the orderer orgs as application orgs): `cfgupdate/main.go:53-54,111-129`. LifecycleEndorsement 4-of-4 (`main.go:123` `SignedByNOutOfGivenRole(int32(len(allMSPIDs)), MEMBER, allMSPIDs)`); `/Channel/Application/Admins` needs 3 of 4 (`main.go:204-209`).
- Token namespace policy `rd_dfabi_v2`: `OutOf(3, Org1MSP, OrdererOrg2MSP, OrdererOrg3MSP, OrdererOrg4MSP)` (`README.md:19`); `topology.go:84` writes the same with generic names `OutOf(3, 'Org1MSP.member', 'Org2MSP.member', ...)` and `topology.go:80` `tms.SetNamespace("token_chaincode")`; the live name and MSPs differ from the topology file (comment `topology.go:35-36`). [not re-read from the ledger: needs a committer query-service client; recorded as a gap].
- Orderer/committer config comes from the config block: endpoints, CAs, TLS roots (`committer utils/ordererdial/dialinfo.go:45-69`, orderer `config/party_shared_config.go:257-297`).

## 9. FSC and Panurus (pins 86539af4 / 5f3c49e2)
- FSC p2p: static resolvers only, mutual TLS 1.3, no advertised address; Panurus endorsers are a name list plus the on-chain namespace policy. Live core.yaml is inside the `rdbi-*-files` Secrets (not readable); generated by `k8s.py:73-75` (`r["addresses"]["P2P"] = f"{r['name']}:{port(...)}"`), i.e. `issuer:5101`, `bank2:5104`, `endorser-1:5113`, ...
- Panurus: 3-of-4 `namespace` endorsement type (`topology.go:82-84`), Idemix enabled (`:46`), websocket p2p (`:51`), libp2p bootstrap node (`:89-90`); public parameters 64-bit amounts via `rdbi/cmd/ppgen`, auditor list empty (`ppgen/main.go:45`, `README.md:20-22`); no auditor, so BI reports (`topology.go:4-6`).
- Context7 for names (docs of `main`, not the v0.24.0 pin: [unverified against the pin]): `services.network.fabric.fsc_endorsement.{endorser, id, endorsers, policy.type}` with `policy.type` in `1outn | all | namespace`; `namespace` on FabricX uses the query service. FSC `fsc.p2p`, `fsc.endpoint.resolvers`, committer and orderer keys: not in Context7, taken from the pinned sources (`fsc .../websocket/config.go`, committer `utils/ordererdial/config.go`).
- Local patches on the pins (kept, user decision 2026-11-10): FSC full-certificate; Panurus endorser-failover, sequential-remote-signatures, issuer-keeps-audit-tokens, auditor-limits (`README.md:113-141`, `NOTES.md` table).
- Node limits live: bank4 `RDBI_PAYMENT_LIMIT = 18446744073709551615` (= uint64 max, no real limit), same for `CUMULATIVE` and `HOLDING` (kubectl get deploy -o json, env values), `RDBI_ROLE = bank`; issuer same values.

## 10. rdbi driver and gateways
- `fx-gw-N` (party N): containers `envoy`, `opa`, `fxapi`. `fxapi`: `command ['rdbi-driver', 'serve', node, '127.0.0.1:8080']` (`k8s.py:354-355`), env names `HOME`, `FXGW_TLS` (+ `RDBI_REDELIVER_INTERVAL` after PR #7 rolls out), mounts `/home/rdbi/.fabricx-token`, `/mtls`; resources cpu 10m, mem 32Mi / limit 256Mi. Envoy: `0.0.0.0:8443`, client certificate required, ext_authz `failure_mode_allow=False`, timeout 3s, route timeout 300s (`k8s.py:287-320`). OPA args quoted from the live Deployment: `--server --addr=localhost:8181 --diagnostic-addr=0.0.0.0:8282 --authorization=basic --config-file=/config/opa.yaml --set=labels.gateway=fx-gw-2 --set=services.bundle-server.url=http://bundle-server.paladin.svc --set=services.sink.url=http://bundle-server.paladin.svc:8081`, then `bundles.bi.resource=N/bi.tar.gz`, `bundles.bank.resource=N/bank.tar.gz`. (The sink token arg is in the repo at `k8s.py:343-346`, not in the live pod yet.)
- Ops of the gateway: `issue, award (gw-1 only), transfer, swap, redeem, balance, history, records, finality, report, usage`; anything else denied (`opa/DESIGN.md:43-45`).
- Driver `rdbi-driver` Deployment: 0/0 since 2026-11-06 (`opa/DESIGN.md:148-150`).
- OPA bundles in use, `kubectl get --raw /api/v1/namespaces/paladin/services/bundle-server:sink/proxy/status` (quoted): `fx-gw-2 {'bank': 'bank-a-zeto.9-noto.5-fabricx.6-iroha3.1', 'bi': 'bi-zeto.41-noto.11-fabricx.13-iroha3.1'}`; `fx-gw-1 bank-bi-zeto.1-noto.1-fabricx.1-iroha3.1`, `fx-gw-3 bank-b-zeto.7-noto.1-fabricx.3-iroha3.1`, `fx-gw-4 bank-c-zeto.1-noto.1-fabricx.1-iroha3.1`; all 8 gateways (bank-gw-1..4, fx-gw-1..4) report both bundles, no error code. Signing keys `bi, bank-a, bank-b, bank-c` (`k8s.py:280`), custody on the Lensa host (rd-besu README "Not done" 3).

## 11. R1 view per party, as observed (mTLS to the gateways, lensa cert, `{"op":"records","txid":"141e2a02af08..."}`)
Tx `141e2a02...4150` = bank2 to bank3, RD 5 (BI-down proof, 2026-11-11). Quoted:
- BI (fx-gw-1): `{"records":[{"action":"transfer","sender":"bank2","recipient":"bank3","type":"RD","amount":"5","status":"confirmed"},{"action":"transfer","sender":"bank2","recipient":"bank2","type":"RD","amount":"995","status":"confirmed"}]}` (both rows).
- sender bank2 / A (fx-gw-2): the same two rows.
- receiver bank3 / B (fx-gw-3): `{"records":[{"action":"transfer","sender":"bank2","recipient":"bank3","type":"RD","amount":"5","status":"confirmed"}]}` (only its row).
- outsider bank4 / C (fx-gw-4): `{"records":[]}`.
R1 holds: BI, sender, receiver see the tx; the outsider sees nothing. Balances now (op balance RD): `fx-gw-1 5000000`, `fx-gw-2 56098776704466`, `fx-gw-3 953902221304375`, `fx-gw-4 7007005`.
R2 (settlement with BI offline) shown 2026-11-11: `NOTES.md` "BI-down proof"; R3 (atomic DvP) shown in earlier runs (`README.md` test results ~143-165), not repeated here.

## 12. BEFORE vs found (analyst `agents/analyst/design/ARCHITECTURE-fabricx.md`, on origin/master; line numbers of the copy read)
| BEFORE (line: claim) | Found | Source |
|---|---|---|
| :3 pins fabric-x@3f7caeb | main is 7bef424 (PRs #5 #6 merged, #7 open) | `git log` |
| :63 BI-down text at `opa/DESIGN.md:145-150`; :66 `rdbi-driver` text at :141-143 | the texts are at `DESIGN.md:152-156` and `:148-150` | file read |
| :146 BI-down latency ~260 s | ~267 s (131+1+131 s), second transfer ~380 s | `DESIGN.md:154`, `NOTES.md` |
| :257 "fabricx 42 pods ... most containers have no requests" | 42 pods confirmed; every container made by `k8s.py` has requests | `pods 42`, `k8s.py:148-149` |
| :257 "party C is about 13 pods" | 8 workloads of party 4: `rdbi-bank4`, `fx-gw-4`, 4 `orderer-*-4`, `fca-orderer-org4` (+db) | workloads list |
| :53 "3/3 pods fx-gw-1..4" | four `fx-gw-N` Deployments, 1/1 each | `kubectl get deploy` |
| :69 pods on `member-16045-node` | `rdbi-bank2/3/4` on `member-16045-node`, `rdbi-bi` on `member-16041-node` | `kubectl get pods -o wide` |
| :70 `rdbi-bi` 0/0 at 07:19Z, 1/1 at 07:22Z | window 2: scale 0 at 07:15:43Z, scale 1 at 07:21:04Z, Ready 07:21:17Z | `win2.out` |
| :125 Idemix route unverified live | still not exercised; deployment uses one shared Org1MSP key | `README.md:118-121` |
| :134 gateway text `DESIGN.md:105-109` as client-CA trust | 105-109 is the sink token / label note | file read |
Stale repo line (not fixed, docs PR cancelled by user order): `opa/DESIGN.md:18` "ns `fabricx` has NO NetworkPolicy today"; live `kubectl -n fabricx get networkpolicy --no-headers` -> `rdbi-bank2-ingress`, `rdbi-bank3-ingress`, `rdbi-bank4-ingress`, `rdbi-bi-ingress` (4).

## 13. Not verified / gaps
1. Live on-chain namespace policy `rd_dfabi_v2` and token ids: needs a committer query-service client (not run).
2. Cluster copies of the genesis block and of every `core.yaml` (inside Secrets).
3. FSC, committer, orderer setting names at the pins are from source, not Context7 (not indexed).
4. Image build provenance (`1.0.4` image vs git tag).
5. Free capacity per node on cluster 1 (pod requests of other namespaces not summed here); cluster 2 not touched.
6. `bundle-sink-token` Secret and the `bundle-server-ingress` NetworkPolicy do not exist yet (batch pending).

## 14. Decommission inventory (ns `fabricx`, cluster 1; read-only, 2026-11-11 08:22 UTC)
Planning input for the last PLAN.md step "Decommission fabricx": destructive, user-only, its own CLUSTER-OP approval at that time; cluster 1 only, nothing on cluster 2 is ever deleted. Nothing below was changed.
- Object counts, `for r in deployments statefulsets ...; do kubectl -n fabricx get $r --no-headers | wc -l; done`: `deployments=20 statefulsets=24 daemonsets=0 jobs=0 cronjobs=0 pods=42 services=60 endpoints=60 ingresses=0 networkpolicies=4 persistentvolumeclaims=28 configmaps=41 secrets=51 serviceaccounts=1 roles=0 rolebindings=0 horizontalpodautoscalers=0 poddisruptionbudgets=0 resourcequotas=0 limitranges=0`.
- Deployments (20): `fx-gw-1..4`, `rdbi-bi`, `rdbi-bank2/3/4`, `rdbi-driver` (0/0), `committer-{coordinator,query-service,validator,verifier}`, `fca-orderer-org{1..4}`, `fca-org1`, `block-explorer`, `orderer-loadgen` (0/0). StatefulSets (24): `orderer-{router,batcher,consenter,assembler}-{1..4}`, `committer-sidecar`, `committer-db`, `fca-orderer-org{1..4}-db`, `fca-org1-db`, `block-explorer-db`.
- PVCs (28): all `2Gi` = 56Gi (list in section 6). StorageClass quote, `kubectl get sc alicloud-essd-wffc -o jsonpath=...` -> `alicloud-essd-wffc reclaim=Delete binding=WaitForFirstConsumer`; PVs of this namespace: `PV reclaim policy for fabricx PVCs: {'Delete': 28}`. **Deleting the PVCs or the namespace deletes the cloud disks and the chain data with them.**
- Secrets (51) by name: section 7 (no `bundle-sink-token` yet). ConfigMaps (41): section 7. NetworkPolicies (4), `kubectl -n fabricx get networkpolicy --no-headers`: `rdbi-bank2-ingress`, `rdbi-bank3-ingress`, `rdbi-bank4-ingress`, `rdbi-bi-ingress` (selectors `app.kubernetes.io/name=rdbi-*`). ServiceAccount: 1 (`default`).
- Services (60): 0 LoadBalancer, 0 Ingress, 13 NodePort: routers `30050,30150,30250,30350`; `committer-sidecar-nodeport 30560`, `committer-query-service-nodeport 30580`; `fca-orderer-org{1..4}-nodeport 30919,30929,30939,30949`, `fca-org1-nodeport 30969`; `block-explorer-nodeport 30690`; `orderer-loadgen-nodeport 30600`. These ports are open on the cluster-1 node IPs (host-side tools use `CLUSTER_HOST`, below).
- Chain data that must survive (or be exported) before any delete:
  - Orderer ledgers and consensus state: the 16 `data-orderer-{router,batcher,consenter,assembler}-{1..4}-0`.
  - BI committer: `data-committer-sidecar-0` (ledger) and `data-committer-db-0` (state Postgres).
  - Banks: `rdbi-bank2-state`, `rdbi-bank3-state`, `rdbi-bank4-state` = node stores + that bank's sidecar ledger + Postgres (subPaths, `k8s.py:190-210`); BI: `rdbi-bi-state` = issuer and endorser-1 stores including BI's audit store (the R1 records BI holds).
  - Identities: the 5 `data-fca-*-db-0` (CA enrolment state). `data-block-explorer-db-0` is derived data [unverified that it can be rebuilt].
  - Host side: `~/.fabricx-token` (201M: live configs, crypto, `multiorg/genesis-multiorg.block`, `public-params-64bit.bin`) and its backups `ls ~/.fabricx-token/backup` -> `2026-11-01-pre-multiorg`, `2026-11-01-report-migration`, `2026-11-01-report-migration-2`, `2026-11-02-pre-k8s`. The Secrets in the namespace were built from this directory (`k8s.py:11-14`).
- What outside the namespace points at it (path:line; `grep -n fabricx`):
  - Lensa: `frontend/deploy/forwards.conf:20-23` (`fabricx-gw-1 fabricx fx-gw-1 39441:8443` ... `fabricx-gw-4 ... 39444:8443`), `frontend/deploy/lensa.service:3-4` (Wants/After the 4 units); live, `systemctl --user list-units 'lensa-pf@fabricx*'` -> `lensa-pf@fabricx-gw-1.service active` ... `-4 active`. Adapter: `frontend/server/src/adapters/fabricx.ts:88` (`kubectl --kubeconfig ... -n s.namespace`), `:399` (pod status of the namespace), `:486` `FABRICX_KUBECONFIG`; state file `frontend/server/state/fabricx.json` -> `{'kubeconfig': '<redacted>', 'namespace': 'fabricx', 'funded': True}`; `frontend/deploy/lensa.env.example:7,18` (`FABRICX_KUBECONFIG`, `LENSA_FABRICX_GW`).
  - Host-side committer and tools: `multiorg/committer/compose.yaml:38-41` (`orderer-assembler-1..4.fabricx.svc.cluster.local` -> `host-gateway`); `multiorg/committer/assembler-nodeports.yaml` (NodePorts 30052/30152/30252/30352: NOT live, section 4); `panurus-itest/scripts/assemble.py:10-21` (`CLUSTER_HOST` default 172.24.11.197, sidecar/query `30560/30580`, routers `30050,30150,30250,30350`, `NAMESPACE rd_dfabi_v2`); `panurus-itest/scripts/reconcile.py:15,22` (`kubectl -n fabricx exec/get`); `panurus-itest/scripts/k8s.py:30,41` (`NS = "fabricx"`, `committer-sidecar.fabricx.svc.cluster.local:5130`) and the whole manifest generator; `opa/networkpolicy.yaml` (ns fabricx); `panurus-itest/rdbi/cmd/node/netshim.go:15-16` (`orderer-{router,assembler}-N.fabricx.svc.cluster.local`).
  - rd-besu (PR #9 merged, `d5331cf`): the NetworkPolicy `bundle-server-ingress` admits fx-gw pods by `namespaceSelector kubernetes.io/metadata.name: fabricx` + label `app.kubernetes.io/part-of: rdbi-gw`; the bundle-server sink status lists `fx-gw-1..4` (section 10) and the Publisher waits for the union of `<name>-gw-<node>` gateways (`besu/opa/README.md:77`). A removed namespace leaves those gateways missing in the Publisher's wait.
  - Team files: `agents/ops/post-reboot-check.sh:8` (`NAMESPACES=${NAMESPACES:-paladin iroha3 fabricx}`), `agents/fabric/AGENT.md:12` (on origin/master).
  - CI: `fabric-x/.github/workflows/ci.yml` and `rdbi.yml`: no reference to the namespace (`grep -n fabricx` -> no hit); they never touch a cluster.
  - Dependency in the other direction: `ghcr-pull` is copied from ns `dfabi` (`k8s.py:248`); `fx-gw-N` pull bundles from ns `paladin` (`k8s.py:343-344`).
- Other namespaces this project created for Fabric-X: none. The only namespace constant in the repo is `NS = "fabricx"` (`k8s.py:30`). `<foreign-ns>`, `<foreign-ns>`, `<foreign-ns>`, `<foreign-ns>` exist on cluster 1: foreign to the final design, not read, not to be touched by that step [their creation history is unverified].
