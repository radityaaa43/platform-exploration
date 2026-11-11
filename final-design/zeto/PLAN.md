# zeto: plan CURRENT -> AFTER
Skills used (loaded by `lead` with the Skill tool before the review; the drafter applied them as checklists): superpowers:writing-plans, ecc:architecture-decision-records, ecc:kubernetes-patterns, superpowers:verification-before-completion (RED proofs), ecc:evm-token-decimals (S14, CONTRACTS), solidity-auditor (inventory only, no audit run), ecc:deployment-patterns (S19-S21 cutover and rollback), ecc:code-explorer (path:line reads, by hand). Not applied: web3-testing (no contract code is built). Drafter note: skills applied as checklists, not loaded as tool calls.
Target: agents/analyst/design/ARCHITECTURE-zeto.md (AFTER; DELTA list incl. addenda 3a and 8a, analyst PR #54, merged) + objectives (decentralization per bank: validator, self-submit, third-party; R1, R2, R3). Start: final-design/zeto/CURRENT.md @ 2026-11-11 (file carries no time).
Namespaces: rd-zeto-bi, rd-zeto-bank-a, rd-zeto-bank-b (cluster 1), rd-zeto-bank-c (cluster 2, new only). Old: `besu` (4 QBFT validators, PVs Retain), `paladin` (4 Paladin nodes, Postgres PVs Delete), `dfabi`; all three shared with noto-pente and stealth.
Pins: `besu@9890701` (CURRENT; `opa/` cites re-read at `besu@45122ae`), `frontend@28c8bdb` (local HEAD; CURRENT cites aa6e09b, lines re-read), `paladin@v1.0.0` (6d4b913), `zeto@v0.5.1`, Besu image 26.8.1 (docs unversioned, so version match is not proven).
Preserve (every step): chain 1337 and every address in CONTRACTS.md (validators change by vote, no new genesis, no token redeploy unless ADR 0002 says so); Paladin node names node1..4 and their seeds (they ARE the Zeto owner keys); the running fork image digest (no new Paladin code); Zeto has no notary or auditor role, so no step for those.
Reused by noto-pente and stealth: S1-S5 (namespace pattern, validator per bank), S8-S11 (Paladin node, DB, transport, registry), S16-S17 (gateway, OPA). One Paladin node per party serves Zeto, Noto and Pente today (CURRENT sections 2-3), so it moves once, here, with the noto and pente domain selectors unchanged. S8 = verified copy of each old node's Postgres (row counts equal), before S9; noto-pente S1/S2 depend on it.

## Order and dependencies
1. S1 (none)  2. S2 after user cluster-2 credential  3. S3 after S1  4. S4 after S2,S3  5. S5a after S3,S4; S5b after S21 (just before S22)
6. S6 after S1,S2  7. S7 after ADR 0004  8. S8 after S1,S2 (spend decision)  9. S9 after S5a,S6,S8  10. S10 after S9  11. S11 after S10 (ownership part: ADR 0001)
12. S12 after ADR 0002  13. S13 after ADR 0003  14. S14 (none)  15. S15 after S9  16. S16 after S1,S2,S9  17. S17 after S16
18. S18 after ADR 0005  19. S19 after S16,S17  20. S20 after S19  21. S21 after S5a,S9,S11,S17,S20 (+ S12/S13/S18 if their ADR changes the flow)  22. S22 after S21,S5b (LAST)

## Steps
### S1: Per-party namespaces on cluster 1
- DELTA: 2 -> AFTER row: "ingress to RPC 8548 only from this namespace's gateway pods" (2a NetworkPolicy)
- Owner: besu  Size: S
- Prerequisites: none; user issues one namespace-scoped credential per party; read-only capacity read (`kubectl describe nodes | grep -A5 'Allocated resources'`, disk-attach slots per node as in fabricx PLAN S11; the old stack stays until S22) quoted in CURRENT.md
- Flags: CLUSTER-OP, user-only (credential issue)
- Does: create ns `rd-zeto-bi`, `rd-zeto-bank-a`, `rd-zeto-bank-b` (labels `part-of=rd-zeto`, `party=<bi|bank-a|bank-b>`); NetworkPolicy `default-deny-ingress`, `allow-dns-egress`, `allow-same-namespace`, `rehearsal-no-9000-egress` (pods `app=paladin`: egress to everything except TCP 9000, via `endPort` ranges 1-8999 and 9001-65535 [unverified on this CNI]; the S9 rehearsal node must not reach other parties; lifted in S21); ServiceAccount `party-admin` (Role on workloads, services, configmaps, pvc, networkpolicies, pods, pods/log; `secrets` only `create,update,patch`, never get/list/watch), `lensa-publisher` (INTERIM exception for S20 only: `get services/proxy` on `bundle-server` in `rd-zeto-bi`, nothing else, no `secrets`; removed inside S20). Reused by noto-pente, stealth.
- Admin credential custody (README decision 25): the cluster-1 cluster-admin kubeconfig stays with the platform operator (the user) only, mode 600, never on the Lensa host (Lensa host: the admin-style kubeconfig listed in LENSA.md 1.1 is removed at S20; until then it is an inventory fact, not a plan input); per-party kubeconfigs = the ServiceAccount tokens above; the cluster operator stays a trusted party for Secrets at rest (Kubernetes limit); Secrets encryption at rest on cluster 1 = optional cluster-config step, user-only; cluster 2 is not ours to configure. The party operator (`party-admin`) can read its own namespace's Secrets through a pod mount: that is the owner reading its own keys; the limit is cross-namespace (none is granted).
- RED proof: `kubectl get ns rd-zeto-bank-a` before `NotFound`, after `Active`; `kubectl -n rd-zeto-bank-a auth can-i get pods -n rd-zeto-bank-b --as system:serviceaccount:rd-zeto-bank-a:party-admin` -> `no`; `auth can-i get secrets -n rd-zeto-bank-a --as=system:serviceaccount:rd-zeto-bank-a:party-admin` -> `no`, same for `lensa-publisher`; `get netpol -o name | wc -l` -> `4`; egress proof: a throwaway probe pod labelled `app=paladin` (created and deleted inside this CLUSTER-OP, with throwaway listeners on 9000 in another party's ns and on 8549 of its own ns): TCP connect to the other party's 9000 fails, to 8549 of its own ns succeeds. S9 requires this proof.
- Rollback: `kubectl delete ns rd-zeto-<x>` (empty at this point).
- Sources: https://kubernetes.io/docs/concepts/services-networking/network-policies/; CURRENT section 11; iroha3 PLAN S1 (secrets create-only Role).

### S2: Namespace on cluster 2 (first write there)
- DELTA: 11, 2 -> AFTER row: "ns-bank-c ... own operator, bank-gw, keys Secret C" (2a diagram)
- Owner: besu  Size: S
- Prerequisites: user supplies the real cluster-2 credential (the one supplied so far may resolve to cluster 1: [unverified], the RED proof checks it)
- Flags: CLUSTER-OP, two separate GOs, user-only, spend (none yet)
- Does: (S2a, GO 1) create ONLY ns `rd-zeto-bank-c`; no read of any existing cluster-2 namespace, no cluster-scoped object (CRDs wait for S9's own approval). (S2b, GO 2) in it the ServiceAccounts, Roles and four NetworkPolicies of S1 (same custody rule: cluster 2 admin credential stays with the user).
- RED proof: S2a: `kubectl get nodes -L topology.kubernetes.io/region` (node level) -> `ap-southeast-1` rows before any write; then `kubectl get ns rd-zeto-bank-c` -> `Active` and `kubectl auth can-i create pods -n rd-zeto-bank-c` -> `yes`; never a full `kubectl get ns` on cluster 2. S2b: `auth can-i get secrets -n rd-zeto-bank-c --as=system:serviceaccount:rd-zeto-bank-c:party-admin` -> `no`; `get netpol -o name | wc -l` -> `4`.
- Rollback: `kubectl delete ns rd-zeto-bank-c` (empty). Cluster 2: nothing else is ever deleted.
- Sources: ARCHITECTURE 2a "Capacity on cluster 2" (user rule: new namespaces only).

### S3: Besu node per party on cluster 1, joined to chain 1337
- DELTA: 3 -> AFTER row: "Besu QBFT validator (bank nodekey)" and 2a "Besu validator | 1, own nodekey"
- Owner: besu  Size: L
- Prerequisites: S1
- Flags: CLUSTER-OP, spend, user-only (3 LoadBalancer Services, 3 x 40Gi PVCs)
- Does: in each of rd-zeto-bi/-bank-a/-bank-b: Secret `besu-nodekey` (generated inside the ns, never leaves it); ConfigMap `besu-genesis` byte-identical to live `besu-genesis` (chainId 1337, qbft 2 s / 4 s); StatefulSet `besu-validator` image `hyperledger/besu:26.8.1`, PVC 40Gi, config.toml copied from live `besu-node-validator-1-besu-config` with `--p2p-host` = this party's `besu-p2p` LoadBalancer IP (its enode uses that IP; analyst DELTA 3a), bootnodes empty, `discovery-enabled=false`, and `static-nodes-file` listing IPs, never DNS names (Xdns is early access): the other 2 new cluster-1 `besu-p2p` IPs (C added after S4, before S22) and the 4 old validators by pod IP enode (accepted interim, lead ruling: an in-cluster pod IP is an IP not a DNS name; it lasts only while the pod lives, so the static-nodes file is re-rendered after any old-pod restart: owner besu; trigger = after an old-pod restart, `net_peerCount` on a new node falls below the expected count (7 = 4 old + 3 other new once S4 is up, 6 before) or its `admin_peers` lacks an old enode; check = re-run the S3 RED; needed only until S5b removes the old validators). Starts as NON-validator. Service `besu-p2p` LoadBalancer TCP 30303 only (peers dial by TCP; no UDP). NetworkPolicy: 8545 only from this ns's gateway and Paladin pods, 30303 from the other validators. In ns `besu` add ONE ingress rule per `besu-node-validator-N-ingress` for 30303 from `rd-zeto-*`. Permissioning stays off (CURRENT section 1: no `permissions-*` keys). Reused by noto-pente (baseLedgerEndpoint) and stealth (chain door).
- RED proof: before `kubectl -n rd-zeto-bank-a get sts besu-validator` -> `NotFound`; after, via port-forward to the pod: `eth_chainId` -> `0x539`, `net_peerCount` >= `0x6` (4 old + the 2 other new cluster-1 nodes; `0x7` once S4 adds bank C), `admin_peers` lists the 4 old and the 2 other new cluster-1 enodes, `eth_blockNumber` within 2 blocks of `besu-node-validator-1`.
- Rollback: delete sts, pvc, Services in `rd-zeto-<x>`; remove the added rule in `besu`.
- Sources: Besu docs (context7 `/websites/besu-eth`, unversioned) bootnodes, static-nodes-file, p2p-host options and private-networks node keys "Domain name support" (DNS in an enode is early access; an enode carries one IP); analyst DELTA 3a; CURRENT section 1.
- Cross-plan: the stealth plan (stealth S4) adds a non-validator JWT RPC node per party that dials this validator; the S1 NetworkPolicy must allow TCP 30303 from `rd-stealth-<party>` as well (stealth PLAN.md S4).

### S4: Besu node for bank C on cluster 2
- DELTA: 11, 3 -> AFTER row: "Besu reader node ... enode reachable through an L4 LB for TCP 30303 and UDP discovery" (UDP dropped: analyst DELTA 3a, static-nodes peers dial by TCP)
- Owner: besu  Size: M
- Prerequisites: S2, S3 (cluster-1 `besu-p2p` addresses reachable from cluster 2: network path [unverified], RED proof decides)
- Flags: CLUSTER-OP, spend
- Does: in `rd-zeto-bank-c` the same objects as S3 (nodekey generated there, same genesis ConfigMap, `static-nodes-file` = the S3 `besu-p2p` LB IPs of all 3 cluster-1 nodes, never a DNS name; `--p2p-host` = bank C's own LB IP, bootnodes empty, `discovery-enabled=false`); Service `besu-p2p` LoadBalancer TCP 30303; requests set on every container (cluster 2 memory is tight, ARCHITECTURE 2a). Ingress/egress IPs of the LB are what the cluster-1 NetworkPolicy ipBlock uses if permissioning is later switched on.
- RED proof: node C `net_peerCount` >= `0x3` with enodes of cluster 1, `admin_peers` on each of the 4 new nodes lists the 3 other new enodes, `eth_blockNumber` within 2 blocks of cluster 1, `eth_chainId` -> `0x539`; before: no pod in `rd-zeto-bank-c`.
- Rollback: delete sts, pvc, Services in `rd-zeto-bank-c`.
- Sources: ARCHITECTURE 2a (cross-cluster limits, latency 15-30 ms vs 2 s / 4 s: no tunable changes); Besu quickstart-with-privacy "Add non-validator node" as cited there.

### S5: Validator swap in two parts: S5a vote in the 4 party nodes, S5b vote out the 4 old ones
- DELTA: 3 -> AFTER row: "4 validators, one per party; any 1 down = 3 of 4"
- Owner: besu  Size: L
- Prerequisites: S5a: S3, S4 (new nodes synced as non-validators). S5b: S21 cutover proven by VERIFY (qa PASS on every flow + BI-balance proof); runs just before S22
- Flags: S5a CLUSTER-OP. S5b user-only, destructive, CLUSTER-OP (own approval at that time)
- Does (S5a): add one, confirm, discard, then the next. More than 50% of the CURRENT set each call `qbft_proposeValidatorVote(<new>, true)` on their own node; the vote lands when that validator proposes; wait until the address is in `qbft_getValidatorsByBlockNumber`, then each calls `qbft_discardValidatorVote(<new>)`; repeat for BI, A, B, C. Transitional set n=8: quorum ceil(2n/3)=6 [derived, Besu source not read]; never below 6 of 8 up (n=5,6,7 on the way need 4,4,5). Votes on the OLD pods are cast by the cluster-1 operator (cluster-admin) through the `besu` namespace admin RPC by port-forward (the OPA door denies admin RPC, CURRENT section 1), not by party credentials.
- Does (S5b): the same procedure with `(<old>, false)`, one old validator at a time; the 4-validator floor (3 of 4) returns after the last removal. Old pods stay as non-validator peers until S22.
- RED proof: S5a: before `qbft_getValidatorsByBlockNumber latest` = the 4 old addresses (`0xe89105d4…25d0`, `0x712f8366…69fd`, `0x95197d60…a715`, `0xd27cb197…38d9f3`); after: 8 addresses (4 old + 4 new), block number rises 3 times in 10 s (blockperiod 2 s). S5b: 4 addresses, none old, each mined at least 1 of the last 20 blocks, blocks rising.
- Rollback: S5a: vote the new address out the same way. S5b: vote an old address back in while its pod is up (valid until S22).
- Sources: Besu docs `private-networks/how-to/configure/consensus/qbft` (Add and remove validators; docs unversioned, live image 26.8.1), `private-networks/concepts/poa` (liveness) via ARCHITECTURE section 4 sources.

### S6: Seeds and signing under party custody
- DELTA: 1 -> AFTER row: "Wallet, embedded ... `keyManager.disableSignRPC: true`"
- Owner: besu  Size: M
- Prerequisites: S1, S2
- Flags: CLUSTER-OP, user-only (the seed copy is a trust reset: a seed that sat in a shared Secret cannot be proven private)
- Does: each party's operator creates Secret `node<N>.keys` in its own ns from the live Secret of the same name (sealed channel chosen by that party; no value in chat, git, logs); the CR in S9 uses `secretBackedSigners` {name `signer-1`, type `autoHDWallet`} which reuses an existing Secret (`paladin_controller.go:1137-1139` upserts only if missing). `disableSignRPC: true` goes into the S9 config (Zeto flows never call `keymgr_sign`, CURRENT section 7). BI's Secret carries `registry.operator` and the factory and token owner keys (CURRENT section 11).
- RED proof: `kubectl -n rd-zeto-bi get secret node1.keys -o name` -> `secret/node1.keys` (names only; before: `NotFound`). The `bi@node1` address check moved to S9, after the DB restore: `ptx_resolveVerifier` is not a pure read (it can allocate a new key index on a node without the restored DB).
- Rollback: delete the new Secret (the old one stays until S22).
- Sources: paladin@v1.0.0:operator/internal/controller/paladin_controller.go:1118-1145; config/pkg/pldconf/keymanager.go:29; doc-site/docs/administration/configuration.md:344; paladin@v1.0.0:core/go/internal/identityresolver/identityresolver.go:140-148; ARCHITECTURE section 2 Settings.

### S7: Seed rotation (Zeto owner identities)
- DELTA: 1 (open question) -> AFTER row: "Keys stay with their owner"
- Owner: besu  Size: L
- Prerequisites: ADR 0004 decided
- Flags: BLOCKED(Zeto seed rotation), user-only
- Does: only if the user chooses rotation: new seeds per party, each holder moves its UTXOs to the new BabyJubJub key by ordinary Zeto transfers, BI re-assigns token owner and factory owner to the new BI keys, old Secrets destroyed. Rotation needs NEW node names: registry entries are owned by the old `registry.nodeN` key and there is no owner transfer (`IdentityRegistry.sol:108` strict equality), so "node1..4 preserved" breaks (ADR 0004). Not planned further until the ADR is decided.
- RED proof: `owners.{BI,A,B,C}` in `state/zeto.json` differ from today's, `owner()` of RD and DFABI -> new BI address, balances per party unchanged (qa, VERIFY.md).
- Rollback: none after the old Secrets are destroyed; before that, return to the old seeds.
- Sources: ARCHITECTURE section 3 DELTA 1; CURRENT sections 4-6; paladin@v1.0.0:solidity/contracts/registry/IdentityRegistry.sol:103-108.

### S8: Postgres per party and verified copy of the old node's DB
- DELTA: 6 -> AFTER row: "`database.mode: preConfigured` (external HA PostgreSQL, DSN with passwordSecret)"
- Owner: besu  Size: M
- Prerequisites: S1, S2; precondition: `ptx_queryPendingTransactions` -> `[]` on the old node of that party (quoted in the RED); user chooses the Postgres product (managed or in-cluster operator: ARCHITECTURE did not open HA operators)
- Flags: CLUSTER-OP, spend, user-only (product choice)
- Does: one PostgreSQL per party in its ns (Service `paladin-pg`, Secret `paladin-pg-credentials`, storage >= 20Gi `alicloud-essd` as today's `paladin-nodeN-pgdata`; used size not read: [unverified]); NetworkPolicy lets only the Paladin pod reach it; backup schedule named by the product choice. Copy: Lensa idle and lock held, pending list empty, `pg_dump` the old `paladin-node<N>-0` sidecar DB with the node up (scaling the StatefulSet to 0 would stop its Postgres), restore into the new instance, verify row counts per table equal; fallback = throwaway `postgres:17` pod on the old PVC. HA per AFTER: one replica on a PVC that survives pod restart; restore test: a dump restored into a scratch Postgres, row counts equal.
- RED proof: `ptx_queryPendingTransactions` on the old node -> `[]`; per-table `select count(*)` old = new (listed side by side); `psql "$DSN" -c 'select 1'` -> `1` from the Paladin pod, times out from another ns; restart test: delete the Postgres pod, it returns Ready on the same PVC with unchanged counts; scratch restore counts equal; before: empty DB. Table list [unverified].
- Rollback: delete the instance and the copy (the old DB is only read).
- Sources: paladin@v1.0.0:operator/api/v1alpha1/paladin_types.go:170-185; doc-site/docs/concepts/cloud_native.md:5,21.

### S9: Paladin node per party (rehearsal copy, scaled to 0)
- DELTA: 1, 3, 6, 11 -> AFTER row: "Paladin node | 1 CR `paladin` + own operator"
- Owner: besu  Size: L
- Prerequisites: S5a, S6, S8, S1 egress proof (probe to another party's 9000 fails); precondition: `ptx_queryPendingTransactions` -> `[]` on all 4 old nodes (a restored Prepared tx would be re-dispatched with the same signer keys: nonce clash); CRD facts (named cluster-scoped reads 2026-11-11, rd-besu #28 + orchestrator): the 8 `core.paladin.io` v1alpha1 CRDs already exist on BOTH clusters, cluster 1 owned by Helm release `paladin-crds` in ns `default` (our old stack), cluster 2 owned by release `paladin-crds` in ns `privacydev` (foreign project, chart `paladin-operator-crd-1.0.0`, created 2026-07-29); no CRD install anywhere, those CRDs are never touched; HOLD (orchestrator 2026-11-11 ~22:00 CST): S9 apply on both clusters waits for the user's decision on coupling to the foreign cluster-2 release and for the answers (a) ownership transfer before any uninstall of the cluster-1 release (L7), (b) operator watch scopes, (c) live CRD schema vs chart 1.0.0, (d) upstream position on running a node without the operator
- Flags: CLUSTER-OP, user-only (cluster-2 CRD ownership decision; no CRD write)
- Party credential (user decision via orchestrator 2026-11-11, aligned to the design: own account per institution, cluster-admin operator only, Lensa holds no kubeconfig): until this step the party operator gets short `kubectl create token party-admin` tokens re-issued per window (API-server cap 12 h); inside THIS step's CLUSTER-OP one bound token Secret `party-admin-token` (type `kubernetes.io/service-account-token`, annotation `kubernetes.io/service-account.name: party-admin`) is created per party namespace, delivered to that party's operator only (never the Lensa host, never chat), revocable by deleting the Secret. RED: `kubectl -n <ns> get secret party-admin-token -o name` NotFound before, present after; `auth can-i get secrets --as=system:serviceaccount:<ns>:party-admin` stays `no`.
- Does: Helm `paladin-operator` v1.0.0 per ns (`WATCH_NAMESPACE` = ns, `installCRDs=false`; no CRD chart anywhere: both clusters already carry the Paladin CRDs, see Prerequisites); CR `paladin node<N>` with the live fork digest `ghcr.io/radityaaa43/paladin@sha256:6f113f38…`, `baseLedgerEndpoint` = own Besu (S3/S4) http :8545 / ws :8546, `database.mode preConfigured`, `secretBackedSigners` per S6, `keyManager.disableSignRPC: true`, domains `noto`, `pente`, `zeto` and registry `evm-registry` as static CR `config` carrying the live addresses (noto `0x1419…daf3`, pente `0x1998…3254`, zeto registryAddress `0x753a64ea…cf91` with `allowSigning`, `defaultGasLimit 30000000`; registry `0x99f3326e…7874`); NO `PaladinDomain`, `PaladinRegistry` or `SmartContractDeployment` CR in any party namespace: those CRs take their address from a `SmartContractDeployment` status and would deploy new factory/registry contracts (paladin-operator `paladindomain_controller.go:98-103`, `paladin_controller.go:1247`); lead decision 2026-11-11, contracts unchanged (CONTRACTS.md rows hold). NO `PaladinRegistration` here (S11). Rehearsal: start the node on the S8 copy (live write risk: hence the precondition and the S1 egress policy; its new self-signed cert is refused by peers until S11 republishes, grpc_transport.go:126-137), prove, scale to 0.
- RED proof: with Lensa frozen: tx id list from the new node (`ptx_queryTransactionsFull`, limit 60, port-forward) equals the old node's saved list; after the restore, `bi@node1` resolved (known names only) equals `owners.BI` of `state/zeto.json` and the eth address `0xc77e80b8878c2509552b16336d5fc9bb0dc415a9`; `keymgr_sign` -> RPC error (disabled); a connect to another party's 9000 from the pod fails; `ptx_queryPendingTransactions` `[]` on all 4 old nodes quoted; before: no `paladin` CR in `rd-zeto-<x>`. Method names [unverified].
- Rollback: delete the CR and PVC copy in `rd-zeto-<x>`; the old node was never touched.
- Sources: paladin@v1.0.0:operator/charts/paladin-operator/values.yaml:204-206, operator/cmd/main.go:98,108,211-221; CURRENT sections 2-3 (live CR, domains); `besu@9890701:zeto/ops/backup-pld-node1-1792061433.yaml:6` (CR shape).

### S10: Cross-cluster Paladin transport endpoints
- DELTA: 4 -> AFTER row: "gRPC mTLS across clusters, directCertVerification"
- Owner: besu  Size: M
- Prerequisites: S9
- Flags: CLUSTER-OP, spend (LoadBalancer)
- Does: per party Service `paladin-transport` LoadBalancer 9000/TCP (port 9000, not 8549); transport config `externalHostname` = the LB address, `tls.clientAuth true`, `directCertVerification` default true (no shared CA); no cert-manager: the project script `besu@45122ae:opa/mtls/gen-certs.sh` (as S16) makes each party's own self-signed CA + node cert (CN = node name, LB address in SAN) into Secret `paladin-node<N>-mtls` (tls.crt, tls.key, ca.crt) in that party's namespace; CR `transports[0].tls` sets `secretName` only (no `certName`, no `issuer`), so the operator creates no Certificate (`paladin_controller.go:1345-1371`); this step creates no Issuer or ClusterIssuer on either cluster; whether gen-certs.sh already issues a Paladin node cert: [unverified] (it lists gw-N, lensa, fx-gw-N certs, `gen-certs.sh:1-7`), else a script change in rd-besu; NetworkPolicy 9000 only from the other parties' egress IPs (`ipBlock`, source IP may be LB or node IP).
- RED proof: from `rd-zeto-bank-a`, `nc -zv <rd-zeto-bank-c LB> 9000` -> `succeeded`, before: timeout; `openssl s_client` without client cert is refused by the handshake (clientAuth); `kubectl -n rd-zeto-bank-a get secret paladin-node2-mtls -o name` -> exists, and `openssl x509 -noout -subject` on the generated `tls.crt` file (before apply) shows CN `node2`.
- Rollback: delete the Services and the Secret; the CR keeps the in-cluster default hostname.
- Sources: paladin@v1.0.0:transports/grpc/internal/grpctransport/config.go:23-47, grpc_transport.go:105,337; operator/internal/controller/paladin_controller.go:1345-1371; doc-site/docs/getting-started/installation-manual.md:433-461.

### S11: Registry ownership and endpoint republish
- DELTA: 5, 4 (endpoint republish = analyst DELTA 4a, addendum, PR number to follow) -> AFTER row: "Child identity `owner` is chosen at registration"
- Owner: besu  Size: M (a) / L (b)
- Prerequisites: S10; ADR 0001 only for the ownership part (b)
- Flags: BLOCKED(registry rootless) for the ownership part only; the republish runbook below needs no decision; user-only
- Does: the `PaladinRegistration` CR cannot republish: its first tx `registerIdentity` reverts "Name already taken" for existing names (`IdentityRegistry.sol:77-78`) and a failed tx returns before the publish loop (`paladinregistration_controller.go:110-120`, loop :128-155); editing CR status to skip it is a hack: not used. Runbook (a), no custom code, per node owner: (1) read the node's local transport details `{endpoint, issuers}` (JSON-RPC `transport_localTransportDetails`, Go client `LocalTransportDetails`; `grpc_transport.go:337-345`); (2) `identityHash` = entry named after the node, parentId null, from `reg_queryEntries` (`paladinregistration_controller.go:317-322`); (3) send `setIdentityProperty(identityHash, "transport.grpc", <details>)` from the node key as a public tx with upstream `ptx_sendTransaction` (the same tx the operator builds, `paladinregistration_controller.go:334-343`; owner check `IdentityRegistry.sol:103-108`). Option (b): a rootless registry, four new registrations in each party's own ns, new address in every `PaladinRegistry` CR.
- RED proof: `reg_queryEntriesWithProps` for node2 from node1 -> property `transport.grpc` names `dns:///<LB>:9000`; before: `dns:///paladin-node2.paladin.svc.cluster.local:9000`. Method name [unverified].
- Rollback: republish the old endpoint with the same mechanism (any time).
- Sources: paladin@v1.0.0:solidity/contracts/registry/IdentityRegistry.sol:45-47,77-78,103-108; operator/internal/controller/paladinregistration_controller.go:110-155,317-343; transports/grpc/internal/grpctransport/grpc_transport.go:320-345; ARCHITECTURE section 2a cross-cluster limits.

### S12: Proving-key ceremony
- DELTA: 10 -> AFTER row: "proving keys from a ceremony" (SHARED box)
- Owner: besu  Size: L
- Prerequisites: ADR 0002 decided
- Flags: BLOCKED(proving-key ceremony), user-only
- Does: only if the user chooses a ceremony: generate keys, rebuild the fork image with the new key artifacts (fork `domains/zeto/build.gradle:67` provingKeysFile, no source change: not NEW custom code per analyst, but a new fork build), redeploy `zeto-v1-g16-*` verifiers and the RD and DFABI tokens (DELTA 10, zeto@v0.5.1 README.md:28). This step IS the ceremony decision (README row 5): user-only, stays BLOCKED on the user. Otherwise the test keys stay as accepted PoC limit (CONTRACTS row).
- RED proof: verifier addresses in `state/zeto.json` differ and a transfer proves and verifies; before: test keys (`zeto-test-proving-keys.tar.gz`).
- Rollback: none after tokens are redeployed (balances not carried); before: keep the old addresses.
- Sources: zeto@v0.5.1:README.md:28; paladin fork `domains/zeto/build.gradle:64-67` (as in CURRENT section 3).

### S13: Atom.cancel mitigation
- DELTA: 9 -> AFTER row: "create, delegateLock, execute in one step"
- Owner: besu  Size: S (client step) / M (RestrictedAtom)
- Prerequisites: ADR 0003 decided; S18 raises the race window if bank-side
- Flags: BLOCKED(Atom.cancel mitigation), user-only
- Does: keep `swap` as one create + delegateLock + execute client step (`besu@9890701:zeto/src/flows.ts:118-131`) and add a test that no failure path leaves an Atom created and not executed; the `test` script `besu@9890701:zeto/package.json:8` runs one explicit file (`test/flows-group.test.ts`), so it is edited to add the new file; `RestrictedAtom` (`besu@9890701:noto+pente/contracts/src/RestrictedAtom.sol:219-224`) only if the user picks it.
- RED proof: node test (`besu@9890701:zeto/package.json:8` runner `node --test`) in besu/zeto: inject a failure after Atom create -> test asserts the swap fails closed and no `cancel()` call is made by the client; before: no such test and the script lists one file.
- Rollback: `git revert` of the PR (client change only).
- Sources: paladin@v1.0.0:solidity/contracts/shared/Atom.sol:102-107; doc-site/docs/architecture/atomic_interop.md:105-110.

### S14: Decimals mismatch recorded and the comment corrected
- DELTA: none; correctness record (on-chain `decimals()` = 4 vs the `instrument.ts:146` comment) -> AFTER row preserved: token units row of ARCHITECTURE-zeto.md section 2 (RD/DFABI as Zeto fungible tokens); analyst DELTA 10a, PR #61, merged
- Owner: besu  Size: S
- Prerequisites: none
- Flags: none
- Does: `instrument.ts:146-147` says "Zeto has no decimals of its own"; the chain says `decimals()` = 4 (CURRENT section 3). Change the comment only (unit stays integer; the frontend constant `PRICE_PER_UNIT = 1_000_000n` is `frontend@28c8bdb:server/src/domain.ts:14`, not in rd-besu/zeto); whether any record field or wallet shows the 4: [unverified]. No redesign.
- RED proof: `grep -n "no decimals" besu/zeto/src/instrument.ts` before 1 hit, after 0; `eth_call decimals()` on RD and DFABI -> `0x0000000000000000000000000000000000000000000000000000000000000004`.
- Rollback: `git revert`.
- Sources: zeto@v0.5.1:solidity/contracts/lib/zeto_common.sol:93-94; `besu@9890701:zeto/src/instrument.ts:146-149`.

### S15: Report groups: record live config, no new groups
- DELTA: 8 -> AFTER row: "`{bank, bi@node1}` per bank; BI in every group"
- Owner: besu  Size: S
- Prerequisites: S9
- Flags: none
- Does: new groups already use `externalCallsEnabled: false` (`flows.ts:100`); the three live groups were created with `true` and it is fixed at deploy (CURRENT section 6). ACCEPTED LIMIT (analyst DELTA 8a): group config is fixed at creation, so `externalCallsEnabled` is only recorded; the three groups are recreated for the new namespaces at S21 (new groups get `false`). Read the live config of groups A, B, C and the BI reachability behaviour, write both into `besu@9890701:zeto/docs/r1-limitation.md`.
- RED proof: `pgroup_getGroupById` for each group id of `state/zeto.json` -> `externalCallsEnabled` value quoted in the doc ([unverified] that the RPC result carries it: the flag is in the Pente config ABI, `PenteConfiguration.java:246-277`, not proven in the RPC result); doc has an SLO line "BI down = reports lost" with the 2026-11-10 test date.
- Rollback: `git revert` the docs commit.
- Sources: paladin@v1.0.0:domains/pente/src/main/java/io/kaleido/paladin/pente/domain/PenteDomain.java:100-108,697; core/go/internal/groupmgr/manager.go:155-172.

### S16: Gateway per party with its own mTLS CA
- DELTA: 2 -> AFTER row: "own gateway: envoy + opa; only path to RPC 8548"
- Owner: besu  Size: M
- Prerequisites: S1, S2, S9
- Flags: CLUSTER-OP, spend (cluster-2 LoadBalancer)
- Does: Deployment and Service `bank-gw-<N>` (N: 1 BI, 2 A, 3 B, 4 C, keeps the names `kube.ts:22` and `platforms.ts:25` accept) in each `rd-zeto-<party>` from `besu@9890701:opa/k8s/bank-gw-1.yaml` (namespace lines :8,:67 become the ns), envoy 8548 (Paladin) + 8545 (Besu) with Secret `bank-gw-N-mtls` from a CA that party holds (`opa/mtls/gen-certs.sh` issues all from one CA today); only the Lensa client cert of THAT party is trusted. NetworkPolicy: RPC 8548 only from the gateway pods. Each gateway is also exposed by Service `bank-gw-<N>-ext` of type NodePort (cluster 1, node reachability from the Lensa host: [unverified: fabricx CURRENT.md:44 is a config fact, not a connect test; VERIFY S16 check (1) decides]) or LoadBalancer (cluster 2) behind mTLS, for S19. No Ingress object is created in new namespaces (the user decision of 2026-11-06 keeps the old ingress until S22: user confirms).
- RED proof: with party B's client cert `curl --cert ... https://127.0.0.1:<fwd to bank-gw-2> -d '{"method":"transport_nodeName"}'` -> TLS handshake failure; with party A's cert -> `"node2"` (this read call must be allowed by the bank bundle: [unverified]); before: one shared Lensa cert opens all four.
- Rollback: delete the Deployment, Service, Secret in `rd-zeto-<x>`.
- Sources: `besu@45122ae:opa/k8s/bank-gw-1.yaml:8,67`, `opa/mtls/gen-certs.sh:1-7`; CURRENT section 7 (OPA gateways); LENSA.md section 1.1.

### S17: OPA bundles per party, sink hardening, RPC credentials
- DELTA: 2 -> AFTER row: "Own RPC credentials | `rpcAuthorizers` + `rpcServer.authorizers`, one credential set per bank"
- Owner: besu  Size: L (project code in `sink.py`, envoy routes, `gw.rego`, per-party signing Secrets)
- Prerequisites: S16
- Flags: CLUSTER-OP, spend (PVC `bundle-store` per party, README decision 29)
- Does (per-party bundle source and upload): Deployment `bundle-server` in each ns (`opa/k8s/bundle-server.yaml:9,68`) with the rd-besu #9 hardening (sink token, NetworkPolicy; merged, not rolled out: CURRENT section 8). One bundle-server per party namespace, no cross-namespace pull: each gateway pulls from its own namespace's bundle-server (`opa.yaml:10-14`), bank C included, so no bundle-server Service is exposed outside its namespace. A PVC `bundle-store` per bundle-server replaces the ConfigMap bundle mounts (`bundle-server.yaml:34-37,59-62`); `sink.py` gains `POST /bundles/<name>` (project code; today `sink.py:49-70` takes only `POST /logs` and `POST /status` and serves only `GET /status`, and nginx reads the bundles read-only from the ConfigMap mounts). It accepts the UNSIGNED rego source (taken from the main checkout, user rule), builds the bundle, signs it with that party's key from Secret `opa-bundle-signing-<party>` in the party namespace (moved there from `~/.opa-keys`: copy now, destroy at S22) and writes `<name>/<revision>.tar.gz` + `<name>/<revision>.signatures.json` to `bundle-store` (append-only: revision = content sha256 + timestamp, never overwritten); nginx serves that directory. The PVC survives a pod restart, so that party's OPA pulls and verifies the same revisions again (`persist` stays off, `opa.yaml:32`). Owners sign in their own custody, the Publisher only uploads source.
- Does (gateway routes, upload matrix): target `sink` on every party gateway: a route in the envoy config (ConfigMap `bank-gw-<N>-envoy`) tagged `context_extensions` target `sink`, and in `gw.rego` (`opa/bundles/bi/gw/gw.rego:30-34`, third rule: both packages must allow) new packages `data.bi.platform.sink` and `data.bank.platform.sink` that allow only the Lensa publisher cert subject on `GET /sink/status` and `POST /sink/bundles`; the POST also needs the bearer token and forwards to `POST /bundles/<name>`; no per-route ext_authz disable. Upload matrix (one POST per party gateway per bundle; a party's `bank` bundle goes only to that party's gateway): `bi` bundle -> bank-gw-1, -2, -3, -4; `bank` bundle of BI -> bank-gw-1, of A -> bank-gw-2, of B -> bank-gw-3, of C -> bank-gw-4. Lead ruling on the `bi` bundle (`bundles.bi.signing.keyid: bi`, `opa.yaml:22-26`): the `bi` bundle is signed ONLY in BI's namespace (BI's bundle-server, Secret `opa-bundle-signing-bi`); the Publisher POSTs the unsigned `bi` source to BI's gateway only; BI's bundle-server then distributes the signed artifact (`bi/<revision>.tar.gz` + `.signatures.json`) to bank-gw-2..4 by `POST /bundles/bi` on each bank gateway with BI's publisher-role cert, and a bank bundle-server stores a bundle whose name is not its own party's AS-IS (no re-signing; `sink.py` store-only branch for foreign bundle names); each bank's OPA verifies `bi` under the BI key as today. BI's key never leaves `rd-zeto-bi`; a bank's key signs only its own `bank` bundle. The sink policy allows BI's cert subject on `POST /bundles/bi` at bank gateways in addition to the Lensa publisher subject.
- Does (rego and credentials): the `bi` bundle's `besu` method list (`opa/bundles/bi/bi/config/data.json:57-61`; the Besu door is gated only by `data.bi.besu`, `gw.rego:25-28`) gets `net_peerCount` and `eth_syncing` as a new `bi` bundle revision (`eth_blockNumber` is already listed), for the S20 Besu network view. Paladin `rpcAuthorizers` + `rpcServer.authorizers` credential per bank replace `paladin-basic-auth`.
- RED proof: `kubectl -n rd-zeto-bank-a get secret paladin-basic-auth` -> `NotFound`; `net_peerCount` and `eth_syncing` through a bank gateway's Besu listener: denied before the new `bi` revision, `200` after; on a party gateway `GET /sink/status` and `POST /sink/bundles`: a bank client cert -> `403`, the Lensa publisher cert -> `200` (POST with the bearer token), the POST without the token -> `401` [code unverified], no client cert -> TLS handshake failure; the status body shows `bank-a-zeto.<rev>` active on `bank-gw-2`.
- Rollback: delete the Deployment, ConfigMaps and PVC `bundle-store`; gateways in S16 fall back to deny (enforcing, `failure_mode_allow: false`).
- Sources: `besu@45122ae:opa/README.md:22-26,130,218`; `besu@45122ae:opa/bundle-server/sink.py:49-70`, `opa/k8s/bundle-server.yaml:34-37,59-62`, `opa/opa.yaml:10-33`, `opa/bundles/bi/bi/config/data.json:57-61`, `opa/bundles/bi/gw/gw.rego:25-34`; paladin@v1.0.0:doc-site/docs/administration/auth.md:88-134.

### S18: Bank-side client and cross-bank DvP flow
- DELTA: 7 -> AFTER row: "own Lensa / client, only this bank's node"
- Owner: besu  Size: L
- Prerequisites: ADR 0005 decided
- Flags: BLOCKED(bank-side DvP flow), user-only
- Does: today one process drives both legs (`flows.ts:118-131`, `zeto.ts:34,280`). Planned only after the decision: per-bank client talking to its own node, lockId, calldata and Atom address exchanged between banks.
- RED proof: a swap where seller and buyer run as two processes each holding only its own node URL completes; before: `createZetoAdapter` builds `party()` for all four nodes (`zeto.ts:280-281`).
- Rollback: keep the single coordinator (current behaviour).
- Sources: paladin@v1.0.0:doc-site/docs/architecture/atomic_interop.md:46-117; ARCHITECTURE section 3 DELTA 7.

### S19: Lensa reaches the gateways directly, no port-forward for zeto (fe)
- DELTA: 1, 9 -> AFTER row: "Lensa relay: no kubeconfig of any org" (2a)
- Owner: fe  Size: M
- Prerequisites: S16, S17
- Flags: none (host unit change is part of S21's cutover window)
- Does: each party's `bank-gw-N` is reached at `https://<ip>:<port>` (S16 `-ext` Service: NodePort cluster 1, LoadBalancer cluster 2, mTLS) with that party's own client cert; `server/src/gateway.ts:8-17` `gwAgent` returns one cert per party, `gateway.ts:23-24` `paladinUrl`/`BESU_RPC` take the URLs from `lensa.env` instead of 127.0.0.1 ports (`besu/zeto/config.json` URLs likewise); `frontend@28c8bdb:deploy/forwards.conf:3-6,8,10-12` lines, units `lensa-pf@paladin-node*` and `lensa-pf@besu*`, and their `lensa.service` Wants/After entries are removed; `state/zeto.json` and the env lose any kubeconfig path; no `kubectl port-forward` for zeto anywhere. `LENSA_GW_MTLS_DIR` holds per-party subfolders. dfabi bank backends are NOT repointed here (S22 prerequisite). Reused by noto-pente S12 and stealth S19.
- RED proof: server test `gwAgent('A')` uses A's cert only (fails before); `systemctl --user list-units 'lensa-pf@paladin-*' 'lensa-pf@besu*' --no-legend` -> empty; `grep -rc kubeconfig frontend/server/state/zeto.json` -> `0`; `/api/health` ok through the gateway addresses.
- Rollback: `git revert` and restore the previous `forwards.conf` and units; the S16 `-ext` Services stay.
- Sources: LENSA.md sections 1.1, 4.2, 6 (rows `paladin`, `besu`); `frontend@28c8bdb:server/src/gateway.ts:21-24`.

### S20: Lensa Publisher and Besu network view without kube credentials (fe)
- DELTA: 1 -> AFTER row: "Lensa relay: no kubeconfig of any org" (2a)
- Owner: fe  Size: S
- Prerequisites: S19
- Flags: none
- Does (a): the Publisher status read (`server/src/policy/kube.ts:65`) goes through the S17 route `GET /sink/status` on each party gateway (mTLS). Interim exception only if the route is not ready at S20: SA `lensa-publisher`, `get services/proxy` on `bundle-server` in `rd-zeto-bi`, no secrets, no other namespace; it is removed inside S20 and a line is added to LENSA.md. Applying the bundle ConfigMaps (`kube.ts:60`) is replaced by an HTTP upload: the Publisher POSTs the UNSIGNED rego source (from the main checkout, user rule) to every party gateway that needs it, per the S17 upload matrix (route `POST /sink/bundles`, bearer token + Lensa publisher mTLS cert); each party's bundle-server signs it with that party's own key (Secret `opa-bundle-signing-<party>`) and stores the revision (S17), and each party's OPA pulls from its own bundle source as today. The Publisher holds no signing key and makes no kubectl apply; fe sub-step replaces `kube.ts:60`. Analyst DELTA 9a (PR #57, merged) with three conditions: the sink route sits under the gateway's own OPA policy (S17 target `sink`); OPA signature verification stays unchanged at each party's pull (`opa.yaml` `bundles.<name>.signing` + `.signatures.json`); the `lensa-publisher` SA is removed inside S20.
- Does (b): fe sub-step: the Besu network view (`server/src/adapters/besu-network.ts:20,57` pod listing) is replaced by JSON-RPC through each bank gateway: `net_peerCount`, `eth_syncing`, `eth_blockNumber` (ETH/NET/WEB3 stay in the AFTER; `net_peerCount` and `eth_syncing` are added to the `bi` bundle's `besu` method list in S17; `admin_peers` is not used). Lensa holds no kube credential after S20 and loses its admin kubeconfig here (README decision 25).
- RED proof: `grep -n "NS = 'paladin'\|namespace: 'besu'" frontend/server/src` -> 0 hits after (2 before); a test feeds the three RPC replies and the network view renders without `kubectl`; the Lensa service env and `state/` reference no kubeconfig file for the zeto path (names only); `kubectl -n rd-zeto-bi get sa lensa-publisher` -> `NotFound` after S20 (it exists before: the interim exception); `auth can-i` not applicable. Upload path: (1) a POST of the unsigned source to a party gateway is accepted, the bundle-server lists the new revision and that party's OPA shows the bundle active (`opa.yaml` `bundles.<name>` status via `GET /sink/status`); (2) a bundle with a bad signature (the test places a tampered `.signatures.json` on the PVC) is rejected at that party's OPA pull and the previous revision stays active (`opa.yaml:22-33`, signature verification unchanged); (3) the bundle-server pod is restarted and the same revision is still served and pulled.
- Rollback: `git revert`.
- Sources: LENSA.md section 6 (rows `paladin`, `besu`, decommission check lines 116-121); analyst ruling 2026-11-11.

### S21: Cutover party by party and qa proof
- DELTA: 1, 3, 6 -> AFTER row: "Each bank runs its Paladin node in its own namespace"
- Owner: qa (steps by besu, fe)  Size: L
- Prerequisites: S5a, S9, S11, S17, S20
- Flags: CLUSTER-OP, user-only (maintenance window)
- Does: order bank-a, bank-b, bank-c, bi (BI last, it receives the reports). Per party: freeze Lensa writes and hold the lock; quiesce: `ptx_queryPendingTransactions` -> `[]` on all 4 old nodes (quoted); fresh `pg_dump` with the old node UP (its Postgres is the sidecar), restore, row counts equal (S8 method; fallback throwaway `postgres:17` pod on the old PVC); then scale the old `paladin-node<N>` StatefulSet to 0 (not deleted); delete `rehearsal-no-9000-egress` in that namespace; scale new node up; endpoint published (S11); BI side recreates the report group {bank, BI} (`newGroup`, `besu@9890701:zeto/src/flows.ts:101-104`, `externalCallsEnabled: false`) and writes the new id to `state/zeto.json`; switch that party's gateway URL (S19); unfreeze. After all four: qa runs `zeto/VERIFY.md` for issue, transfer, DvP RD vs DFABI, outsider C sealed, and the BI-balance proof (BI ledger verified outputs vs chain commitments, same `tx 0x664c1faf2f09…` view per party as CURRENT section 9); transactions made after the last restart (TEAM.md section 10 rule 3).
- RED proof: per party: `GET /api/history?model=zeto&party=<P>` shows the old tx ids and a NEW tx made after cutover; R1 views = BI `reported`, A `clear`, B `clear`, C `sealed`; `groups.A|B|C` in `state/zeto.json` differ from the old ids.
- Rollback: before the first new tx: scale old node up, republish old endpoint, flip forward back; after it: new data exists only in the new DB, so roll forward.
- Sources: CURRENT sections 9, 11; LENSA.md section 4.1 (release flow); ecc:deployment-patterns.

### S22: Decommission `besu`, `paladin`, `dfabi`
- DELTA: 2, 3 -> AFTER row: "Bank-owned namespace ... kubeconfig and credentials" (old shared ns removed)
- Owner: lead  Size: M
- Prerequisites: shared with noto-pente and stealth plans; executes once, after all three cutovers. Cutover proven (qa PASS on the new namespaces for every flow + BI-balance proof). Nothing points at the old ns: LENSA.md "Namespace references" rows `paladin`, `besu`, `dfabi` all clean (forwards.conf 0 lines, `lensa-pf@*` none, `kube.ts` and `besu-network.ts` updated, OPA bundle server and CI: ci.yml names no ns); dfabi bank backends repointed or dfabi retired (user decides). S5b done. Surviving data copied BEFORE any delete into the named backup `zeto-decom-<date>` (manifests incl. CM `besu-genesis`, Lensa state files, Postgres dump per node of `paladin-node1..4-pgdata` (PV reclaim = Delete, 4 x 20Gi), PV snapshots; NO seed or CA key); Besu `data-besu-node-validator-1..4-0` 4 x 40Gi (Retain, kept as is, not a backup); no seed or CA-key backup in any shared place: each party keeps its own copy from S6 (OPA signing keys from S17) in its namespace; `dfabi` PVs `data-postgres-0`, `runner-state` (Delete, 2 x 5Gi).
- Flags: user-only, CLUSTER-OP (own approval at that time), destructive
- Does: inventory = CURRENT.md section 11 "Decommission inventory": `besu` 4 STS, 4 PVC 40Gi; `paladin` 6 Deployments incl. `bank-gw-1..4`, 4 STS, 4 PVC 20Gi, 43 `smartcontractdeployment`, 3 `paladindomain`, 4 `paladinregistration`, 1 `paladinregistry`; `dfabi` 9 Deployments, 2 PVC. PVC total this plan touches: 160 Gi Besu + 80 Gi Paladin (+10 Gi dfabi). First re-set the 4 `paladin` PVs to Retain (`kubectl patch pv ... persistentVolumeReclaimPolicy=Retain`) or copy, verify the dump restores, then delete workloads, then namespaces. Then destroy the shared copies (old Secrets `node1..4.keys`, `paladin-nodeN-mtls`, `besu-node-validator-N-keys`; host dirs `~/.opa-keys`, `~/.opa-mtls`; `~/.opa-keys` only after S17 has confirmed each party's Secret `opa-bundle-signing-<party>` by name) and record it in `zeto-decom-destroyed-<date>` (names and date, no values). Cluster-scoped CRDs stay: the Helm release `paladin-crds` in ns `default` OWNS them; it is never uninstalled or upgraded before ownership is transferred (mechanism per besu's cited answer, own user GO), otherwise every Paladin CR on cluster 1 is deleted with the CRDs. Cluster 2: nothing is ever deleted.
- RED proof: `kubectl get ns besu paladin` -> `NotFound`; qa re-runs S21 read-only checks on the new namespaces (PASS); the dump restores into a scratch DB (row counts equal) before the delete; each `opa-bundle-signing-<party>` Secret listed by name (`kubectl -n rd-zeto-<party> get secret opa-bundle-signing-<party> -o name`) before `~/.opa-keys` is destroyed; `ls ~/.opa-keys ~/.opa-mtls` -> `No such file`; the destruction record exists.
- Rollback: none after delete; restore the named backup `zeto-decom-<date>` (manifests, dumps, PV snapshots) into S8 and the retained Besu PVs; seeds and CA keys come from each party's own copy (S6, S17), never from a shared backup.
- Sources: CURRENT.md section 11; LENSA.md section 6.

## DEVIATION REQUEST
None open. Three items answered by `analyst` 2026-11-11:
1. S3/S4 TCP-only LoadBalancer + `discovery-enabled=false` + `static-nodes-file` is INSIDE the AFTER (DELTA 3a, PR #54). Conditions (written into S3/S4): every party's enode uses its LB address, `--p2p-host` = the LB address, bootnodes empty, IPs not DNS names (Xdns is early access, so no DNS in any enode).
2. `externalCallsEnabled` on the three live report groups = ACCEPTED LIMIT (DELTA 8a): group config is fixed at creation, new groups get `false` from `flows.ts`, and the report groups are recreated for the new namespaces at S21 (S15, S21).
3. S12 proving keys: rebuilding the fork image with new key artifacts (fork `build.gradle:67` provingKeysFile) and no source change is not NEW custom code, but it is a new fork build and forces verifier + token redeploy (DELTA 10, zeto@v0.5.1 README.md:28): it is the ceremony decision itself, README row 5, user-only; S12 stays BLOCKED on the user.
