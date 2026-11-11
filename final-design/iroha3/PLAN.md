# iroha3: plan CURRENT -> AFTER
Skills used (loaded by `lead` with the Skill tool before the review; the drafter applied them as checklists): superpowers:writing-plans, ecc:plan, ecc:architecture-decision-records, ecc:kubernetes-patterns, ecc:documentation-lookup (context7 has no Iroha 3 docs, see CURRENT.md header; upstream repo files at the pin used), superpowers:verification-before-completion (every RED proof is a command with quoted output). Not applied, one line each: solidity-auditor, ecc:evm-token-decimals, web3-testing (no EVM on this platform).
Target: agents/analyst/design/ARCHITECTURE-iroha3.md (AFTER, sections 2 and 2a) + objectives (decentralization per bank: validator, self-submit, third-party; R1, R2, R3). Start: final-design/iroha3/CURRENT.md @ 2026-11-11 16:17 CST (cluster 1, ns `iroha3`).
Namespaces: rd-iroha3-bi, rd-iroha3-bank-a, rd-iroha3-bank-b (cluster 1), rd-iroha3-bank-c (cluster 2, new namespace only; no existing cluster-2 namespace is read or used).
Pins: upstream `iroha@071e281e` (written `iroha@071e281e`); `iroha3-rd-dfabi@bc55e68` (CURRENT.md header); driver `iroha3-rd-node-build@ceccc4d`; frontend `rd-lensa-frontend@ed7b78b`. `docs.iroha.tech` not used.
Shape of the move: the AFTER needs a new chain id (DELTA 2: re-genesis). The new chain runs in the new namespaces beside the old one; nothing migrates on-chain. The old chain stays untouched until S19.

## Order and dependencies
Peer keys come before the nodes (genesis needs `pop_hex`), so S2 to S5 precede S6 to S8.
1. S1 namespaces, RBAC, deny-all (CLUSTER-OP)
2. S2 split generate.sh (after S1 not required, repo only)
3. S3 genesis governance split (after S2)
4. S4 BI key custody and rotation (user-only; before S5)
5. S5 per-party keygen and public-only genesis (after S2, S3, S4)
6. S6 external peer addresses (after S1)
7. S7 peers BI, A, B on cluster 1 (after S1, S5, S6)
8. S8 peer bank C on cluster 2 (after S7, S6)
9. S9 per-bank key custody Secrets (after S5, S8)
10. S10 per-bank client and sponsor in the driver (after S9)
11. S11 auditor 1 and policy from config (after S8, S10)
12. S12 auditor orgs 2 and 3: BLOCKED (after S11)
13. S13 pools activate (after S11; S12 only if decided)
14. S14 gateways and OPA (after S8, S13)
15. S15 pools index published by BI (after S13)
16. S16 Lensa per-bank pointers (after S10, S14, S15)
17. S17 leg exchange: BLOCKED (gate for full self-submit)
18. S18 qa cutover proof and drift re-run (after S16)
19. S19 Decommission iroha3 (after S18, user-only)

## Steps
### S1: Namespaces, deployer RBAC, deny-all ingress
- DELTA: 3 -> AFTER row: "Per-bank own namespace ... own deployer; remove cross-party secrets get/list"
- Owner: iroha  Size: S
- Prerequisites: user go for a CLUSTER-OP (cluster 1); cluster 2 is a second, separate CLUSTER-OP that creates only `rd-iroha3-bank-c`
- Flags: CLUSTER-OP
- Does: create Namespaces `rd-iroha3-bi`, `rd-iroha3-bank-a`, `rd-iroha3-bank-b` (cluster 1) and `rd-iroha3-bank-c` (cluster 2); in each: ServiceAccount `deployer`, Role `deployer` = the verbs of `deploy/runner/rbac.yaml:12-14` (workloads, services, configmaps, pvc, networkpolicies, jobs, pods, pods/log) with `pods/exec` and `secrets get,list` removed (secrets: `create,update,patch` only), NetworkPolicy `default-deny-ingress` (empty podSelector). Cluster 1 only: PriorityClass `rd-iroha3-peer` value 10000 (same as `iroha3-peer`, CURRENT.md section 1). Cluster 2: NO PriorityClass (a priority above default could preempt foreign pods). No runner is created; applies are CLUSTER-OPs.
- RED proof: `kubectl auth can-i get secrets -n rd-iroha3-bank-a --as=system:serviceaccount:rd-iroha3-bank-a:deployer` -> `no` (before: `Error from server (NotFound): namespaces "rd-iroha3-bank-a" not found`); `kubectl get networkpolicy -n rd-iroha3-bi -o name` -> `networkpolicy.networking.k8s.io/default-deny-ingress`
- Rollback: `kubectl delete ns` of the four names (empty at this point, no PVC yet)
- Sources: `iroha3-rd-dfabi@bc55e68:deploy/runner/rbac.yaml:12-23`; CNI enforces policies on cluster 1 (CURRENT.md section 5); cluster 2 enforcement [unverified]

### S2: Split generate.sh into per-party keygen and public-only assembly
- DELTA: 2 -> AFTER row: "Genesis from public data only: `kagami genesis ... --peer-pop PK=POP` per peer"
- Owner: iroha  Size: M
- Prerequisites: none (repo only, no cluster)
- Flags: none
- Does: in `iroha3-rd-dfabi` split `network/generate.sh` (key generation `:65-68`, peer.toml rewrite `:105-134`, Committee keys `:330-397`, genesis signing `:403-430`) into `network/keygen-party.sh <party>` (writes only that party's `peer.toml` seed material, prints no key) and `network/assemble.sh` (reads `network/public/peers.json` + `network/public/peers.addr.json` from S6, writes genesis and `expected_hash`). `trusted_peers` / `public_address` come from `peers.addr.json`, not `dns(p)` (`generate.sh:96-97,105-108`).
- RED proof: on a clean checkout with only `network/public/peers.json`, `peers.addr.json` and a signer key: `bash network/assemble.sh && ls network/out 2>&1` -> `ls: cannot access 'network/out': No such file or directory` and `kagami genesis validate` exit 0 [validate flags unverified beyond README]; before the split `assemble.sh` does not exist (`No such file or directory`)
- Rollback: `git revert` of the PR; old `generate.sh` still works for the old chain
- Sources: `iroha@071e281e:crates/iroha_kagami/README.md:77-87,223-273`; `iroha3-rd-dfabi@bc55e68:network/generate.sh:65-68,96-134,330-430` (cites from the analyst file; line numbers at bc55e68 not re-read)

### S3: Genesis governance split (CanEnactGovernance, CanReadAllLedgerData only at BI)
- DELTA: 8 -> AFTER row: "Holder of `CanReadAllLedgerData`: BI only"
- Owner: iroha  Size: M
- Prerequisites: S2
- Flags: none
- Does: edit `network/genesis-rd-dfabi.jq` (grants `:10,11,16,17,25-28`) and `generate.sh:392` so `CanEnactGovernance` goes to a dedicated BI governance account `bi-gov`, not to the account behind `client-bi`; `CanReadAllLedgerData` / `CanReadRestrictedDataspace` only at BI; bank accounts keep `CanReadRestrictedDataspace` for their dataspace only (today bank-c has none, CURRENT.md section 3: keep that gap and flag it to analyst, do not fix). CURRENT.md section 11 says whether `client-bi` holds CanEnactGovernance is inferred, not read [unverified]. Both permissions are genesis-only, so this edit only takes effect with S5.
- RED proof: `jq -r '.transactions[].instructions[]|select(.Grant)|.Grant.Permission.destination' <(jq -f network/genesis-rd-dfabi.jq ...) | sort | uniq -c` shows `CanEnactGovernance` granted to `bi-gov` only (`1 bi-gov`); before: granted to the `bi` operator account
- Rollback: `git revert`; no cluster effect
- Sources: `iroha@071e281e:crates/iroha_core/src/executor.rs:8225-8236`; `crates/iroha_core/src/smartcontracts/isi/private_settlement.rs:23-29,49-55`; `iroha3-rd-dfabi@bc55e68:network/genesis-rd-dfabi.jq`

### S4: BI key custody and rotation (prerequisite of the BI namespace cutover)
- DELTA: 1 (1a) -> AFTER row: "BI org: own BLS key, own PVC; auditor 1: own signing + hybrid key"
- Owner: lead  Size: S
- Prerequisites: user decision on rotation of the BI `[streaming] identity_private_key` printed to a terminal on 2026-11-11 (CURRENT.md section 11)
- Flags: user-only
- Does: the user decides whether the exposed old BI identity is rotated on the OLD chain (no old peer restart until the user answers, per CURRENT.md). For the NEW chain: the BI peer identity, `[streaming]` identity and auditor keys are generated fresh in S5/S11 inside BI custody and never reuse the old values; this is the rule S7 checks before `rd-iroha3-bi` starts serving. Nothing is rotated by this step; no value is quoted.
- RED proof: qa (read-only) on `rd-iroha3-bi` after S7: `kubectl get secret peer-bi -n rd-iroha3-bi -o jsonpath='{.metadata.creationTimestamp}'` is later than S5 and the sha256 prefix of its `peer.toml` differs from the old Secret's (`97d272a9b342`, CURRENT.md section 1) -> `differs`
- Rollback: none needed (no change)
- Sources: CURRENT.md sections 1, 8, 11; `iroha@071e281e:crates/iroha_kagami/README.md:223-235` (private key never printed)

### S5: Per-party keygen and public-only genesis (new chain id)
- DELTA: 2 -> AFTER row: "one signer builds genesis from `peers.json` only; destroy genesis private key"
- Owner: iroha  Size: M
- Prerequisites: S2, S3, S4; user go for the new chain id (old balances and the 147 audit records in `bi-audit-store` do not carry over)
- Flags: user-only (new chain id)
- Does: each org (BI, A, B, C) runs `kagami keys --algorithm bls_normal --pop` in its own custody, publishes only `public_key` + `pop_hex` into `network/public/peers.json`; one signer runs `assemble.sh` -> `genesis.signed.nrt`, `genesis.public_key`, `genesis.expected_hash` (`--expected-hash-out`); the genesis private key is destroyed after signing. CURRENT.md contradicts the analyst BEFORE: no genesis key file is found in `network/out` now, its location is [unverified]; the step records where the signer key lived and proves its deletion. Each org verifies `kagami genesis validate` and the hash. Committee-role key per peer is built from peer key + PoP (`generate.sh:365-397`).
- RED proof: `ls network/out/*/` on the assembling machine -> no other org's `peer.toml`; `cat network/public/genesis.expected_hash` -> `hash:<8 hex>...` different from `hash:A3D75EEA...` (CURRENT.md section 3); `find / -name '*genesis*key*' 2>/dev/null` (assembler host) -> empty after destruction
- Rollback: none after the signer key is destroyed; to redo, repeat S5 with a new signer key (new chain id again). Old chain unaffected.
- Sources: `iroha@071e281e:crates/iroha_kagami/README.md:77-87,223-273`; `crates/iroha_genesis/src/lib.rs:3829-3860` (key-set change = new signed genesis)

### S6: External peer addresses (LoadBalancer for p2p 1337)
- DELTA: 3 -> AFTER row: "Cross-org P2P :1337 ... `trusted_peers` addresses"
- Owner: iroha  Size: M
- Prerequisites: S1 (cluster 1 and cluster 2 namespaces)
- Flags: CLUSTER-OP, spend (4 load balancers)
- Does: Service `p2p` type LoadBalancer port 1337 in each of the four namespaces (selector `iroha3-rd/party=<party>`); the four addresses are written to `network/public/peers.addr.json` and used for both `public_address` and every `trusted_peers` entry (one external address per peer, also for peers in the same cluster, so the list is the same on every peer). In-cluster DNS names cannot resolve on cluster 2. Alternative NodePort not chosen (needs node IPs reachable from the other cluster) [lead may overrule]. Whether a peer behind its own LB can dial that LB (hairpin) is [unverified].
- RED proof: `kubectl get svc p2p -n rd-iroha3-bank-c -o jsonpath='{.status.loadBalancer.ingress[0].ip}'` -> a non-empty IP (before: `Error from server (NotFound)`); `jq length network/public/peers.addr.json` -> `4`
- Rollback: `kubectl delete svc p2p` in each namespace (releases the load balancers)
- Sources: `iroha@071e281e:crates/iroha_config/src/parameters/user.rs:844-857,7840-7843`; analyst file section 2a ("bank-C address must be reachable from cluster 1 (LB or NodePort: our choice)")

### S7: Peers BI, A, B on cluster 1
- DELTA: 3 -> AFTER row: "own STS, PVC, Secret `peer-<party>`"
- Owner: iroha  Size: L
- Prerequisites: S1, S4, S5, S6
- Flags: CLUSTER-OP
- Does: in each of the three namespaces apply StatefulSet `<party>` (base `deploy/k8s/base/statefulset.yaml`, image `ghcr.io/radityaaa43/iroha3-rd-node:071e281e-stark`, `priorityClassName: rd-iroha3-peer`, args `--sora --config /config/peer.toml`, probes `/livez` and `/readyz` as in CURRENT.md section 1, requests 250m/1Gi limits 2/3Gi), PVC `data-<party>-0` 5Gi `alicloud-essd-wffc`, Secret `peer-<party>` (that org's own `peer.toml` only), immutable ConfigMap `genesis-<hash8>`; NetworkPolicy `peers-p2p` (1337 from the other three peers by `ipBlock`; LB/NAT source IP behaviour must be tested, analyst caveat) and `peers-torii` (8080 only from pods labelled `rd-iroha3/role=gateway` in the same namespace). Chain cannot commit user txs until S8 (4 validators, fixed lane author).
- RED proof: `kubectl get pod bi-0 -n rd-iroha3-bi -o jsonpath='{.status.phase} {.status.containerStatuses[0].restartCount}'` -> `Running 0` (before: `NotFound`); `kubectl get secret -n rd-iroha3-bank-a -o name` lists no `peer-bi`
- Rollback: delete the three StatefulSets and PVCs (new chain, nothing worth keeping yet; before S8 only)
- Sources: `iroha3-rd-dfabi@bc55e68:deploy/k8s/base/statefulset.yaml:36-93,118-133`; `deploy/k8s/networkpolicy.yaml:12-22`; `iroha@071e281e:crates/iroha_core/src/lane_consensus.rs:96-107,854-860`; kubernetes.io network-policies ("ipBlock", "Cluster ingress and egress mechanisms")

### S8: Peer bank C on cluster 2
- DELTA: 12 -> AFTER row: "Cluster 2 for bank C: peer `public_address`, NetworkPolicy `ipBlock`s, PVC class overlay"
- Owner: iroha  Size: M
- Prerequisites: S7, S6; user item: a kubeconfig that really points at cluster 2 (the file supplied earlier points at cluster 1); sequence after Besu and Paladin and gateways on cluster 2 (analyst 2a)
- Flags: CLUSTER-OP, user-only (cluster 2 first write is its own approval)
- Does: in `rd-iroha3-bank-c` only: StatefulSet `bank-c` (no PriorityClass; set requests 250m/1Gi, limits 2/3Gi; schedule on a member node with free memory), PVC `data-bank-c-0` 5Gi with a cluster-2 StorageClass overlay (`alicloud-essd-wffc` is not in cluster 2's class list: `alicloud-essd` or `fabricx-essd`; choose `alicloud-essd` [unverified binding mode]), Secret `peer-bank-c`, ConfigMap `genesis-<hash8>`, NetworkPolicy `peers-p2p` with `ipBlock`s of the three cluster-1 LBs. DELTA 12's "rolling restart of BI, A, B" does not apply: in the fresh chain every `peer.toml` already lists bank C's address (S6). Cross-region RTT 15 ms measured, no tunable changes (analyst 2a).
- RED proof: qa, read-only, two GETs of `/status` 10 s apart on each of the four peers (CURRENT.md section 1 used a Norito `/status` read) -> committed height strictly increases on all four [field name unverified]
- Rollback: scale `bank-c` to 0 (chain halts: fixed lane author); full undo = delete the namespace objects created here; cluster 2 other namespaces never touched
- Sources: analyst file section 2a "Capacity on cluster 2", "Cross-cluster limits"; `statefulset.yaml:66-71,130`

### S9: Per-bank key custody Secrets (seed, note key)
- DELTA: 1 (1b) -> AFTER row: "Bank A org: client.toml, seed, note key, own sponsor"
- Owner: iroha  Size: M
- Prerequisites: S5, S8
- Flags: none
- Does: new keys per bank (new chain, new accounts): each org generates `<party>.seed` and `<party>.note` and creates Secret `client-<party>` (`client.toml`, `genesis.expected_hash`) plus Secret `wallet-<party>` (seed, note key) in its own namespace; split `deploy/secrets.sh:48-52` and Secret `rd-dfabi-wallets` (today `bank-a.seed bank-b.seed bank-c.seed bi.seed` together) into per-namespace creation; remove the sample `[basic_auth]` table from `client.toml`. 1b is only complete after S17 (one driver process still needs payer, recipient and sponsor keys, `aps.rs:1175-1211,1283-1289`).
- RED proof: `kubectl get secret -n rd-iroha3-bank-b -o name` -> `secret/client-bank-b` and `secret/wallet-bank-b`, and `kubectl get secret -n rd-iroha3-bank-b wallet-bank-a` -> `Error from server (NotFound)`
- Rollback: delete the Secrets (new keys only; nothing else used them)
- Sources: `iroha3-rd-dfabi@bc55e68:deploy/secrets.sh:48-52`; `iroha3-rd-node-build@ceccc4d:driver/src/config.rs:105-132` (analyst lines)

### S10: Own client and sponsor per bank in the driver
- DELTA: 4 -> AFTER row: "Bank client: own `client.toml` ... same shape as driver `client_with_key`"
- Owner: iroha  Size: M
- Prerequisites: S9
- Flags: none
- Does: in `iroha3-rd-node-build` parameterize `cfg.sponsor("bi")` -> `cfg.sponsor(<party>)` at `driver/src/aps.rs:208` and `driver/src/pools.rs:274,347,492,507`; BI sponsorship becomes an option; `config.rs:96-102` reads `client.toml` of the acting party. `pay` still needs the BI companion leg (`NOTES.md:44`; `pools.rs:301`), so self-submit by a bank stays partial until S17. New image tag recorded in the PR; rollback line of the driver image is kept below.
- RED proof: new unit test `cargo test -p driver sponsor_is_acting_party` -> before: `error[E0599]` / test missing; after: `test result: ok. 1 passed`
- Rollback: pin the previous driver image: `docker pull ghcr.io/radityaaa43/iroha3-rd-driver:c1afa678`, then `gh workflow run scenario -R radityaaa43/iroha3-rd-dfabi -f target=auditor -f tag=c1afa678`, pin `frontend/server/state/iroha3.json:21` back to `:c1afa678`, restart `lensa.service`; each step needs its own approval then. CURRENT.md closing block.
- Sources: `iroha@071e281e:crates/iroha_core/src/private_settlement/carrier.rs:215-219` (carrier authority = `manifest.sponsor`); CURRENT.md section 4 (line cites moved)

### S11: Auditor 1 in the BI namespace, policy from config
- DELTA: 5 -> AFTER row: "Policy `min_approvals` and `auditors` from config, not hardcoded 1"
- Owner: iroha  Size: M
- Prerequisites: S8, S10
- Flags: CLUSTER-OP
- Does: code: make `min_approvals` and the `auditors` list config keys in `rd-dfabi.toml` (hardcoded at `aps.rs:917,919`, CURRENT.md section 2) and make the driver wait for k approvals instead of one `/approve` (`aps.rs:384-393`). Cluster: in `rd-iroha3-bi` Deployment `bi-auditor` (readOnlyRootFilesystem, as CURRENT.md section 2), Secret `bi-auditor-key` (fresh `bi-auditor.seed`, `.hybrid` from S4), PVC `bi-audit-store` 1Gi, ConfigMaps `rd-dfabi-config`, `rd-dfabi-peers`, NetworkPolicy `bi-auditor` (8090 from the three bank namespaces; bank C via gateway, S14). Config value for now: `min_approvals = 1`, one auditor (same as today); S12 changes the numbers. The auditor HTTP caller is unauthenticated today [unverified, LENSA.md section 5].
- RED proof: `cargo test -p driver policy_from_config` (k=2, n=3 config parses; k=0 and k>n rejected) -> `test result: ok. 3 passed`; live: `kubectl get deploy bi-auditor -n rd-iroha3-bi -o jsonpath='{.status.readyReplicas}'` -> `1`
- Rollback: delete the Deployment and PVC in `rd-iroha3-bi` (new store, empty); driver image pin as in S10
- Sources: `iroha@071e281e:crates/iroha_data_model/src/nexus/private_settlement.rs:2127-2129,2222-2227`; `crates/iroha_core/src/private_settlement/state.rs:1118`; `iroha3-rd-dfabi@bc55e68:deploy/k8s-apps/bi-auditor.yaml:8-10,21-28,89,110`

### S12: Auditor orgs 2 and 3 (k-of-n)
- DELTA: 5 -> AFTER row: "Default proposed: 2-of-3 (BI, org 2, org 3) ... 2-of-2 is the minimum"
- Owner: lead  Size: M
- Prerequisites: S11; user decision ADR 0002
- Flags: BLOCKED(Iroha auditor orgs 2 and 3), CLUSTER-OP
- Does: nothing until the user picks. After the pick: official `iroha nexus private-settlement audit-online` run by each extra org with its own signing + hybrid key and business policy allowlisting all four sponsors; the namespace naming rule has no slot for these orgs, `lead` names them with the decision. Pool policy then needs S13 or `RotatePrivateSettlementPoolPolicyV1`.
- RED proof: `jq '.auditors|length, .min_approvals' <policy>` -> the chosen n and k (e.g. `3` and `2`); a settlement with one auditor stopped -> still `finalized` for k-of-n with k < n
- Rollback: stop the extra auditors; rotate the pool policy back (spec `:375-392`)
- Sources: `iroha@071e281e:crates/iroha_cli/README.md:194-256`; `specs/private_settlement.md:296-340,353-392`

### S13: Activate the RD and DFABI pools with the policy from config
- DELTA: 6 -> AFTER row: "Alternative: new pools at re-genesis with the k-of-n policy from the start"
- Owner: iroha  Size: M
- Prerequisites: S11 (S12 if decided)
- Flags: CLUSTER-OP
- Does: with the BI governance account (S3) run driver `pool-init` for `rd` and `dfabi` (`ActivatePrivateSettlementPoolV1`; `activation_height = 11`, `minimum_activation_notice_blocks = 10` from `nexus.toml:98-105`); because the chain is new, DELTA 6's rotation of old pools is replaced by its listed alternative. If S12 is undecided, activate with the S11 policy and later rotate (`RotatePrivateSettlementPoolPolicyV1`, key_epoch +1, no pending bundle across the boundary, keep the retired hybrid key). Old pools on the old chain are not rotated. Then BI mints test balances to the four accounts (`CanMintAssetWithDefinition`).
- RED proof: driver `pool-history --asset rd` -> line `pool_history asset=rd epoch=<n> leaves=<m> root=<hex>` for both assets (CURRENT.md section 3 shows the format; initial values [unverified]); before: `pools.json` absent
- Rollback: none after activation (pools are on-chain); the whole new chain is dropped by deleting S7/S8 objects before S16
- Sources: `iroha@071e281e:crates/iroha_core/src/smartcontracts/isi/private_settlement.rs:23-29,49-55`; `specs/private_settlement.md:353-360,375-392`; `iroha3-rd-dfabi@bc55e68:network/nexus.toml:94-105`

### S14: Gateways (Envoy + OPA) per namespace
- DELTA: 3 -> AFTER row: "gateway envoy+opa ... peer 8080 only from the own gateway pod"
- Owner: iroha  Size: L
- Prerequisites: S8, S13; analyst DELTA addendum (the DELTA list has no gateway line; section 2a diagram and the NetworkPolicy row do)
- Flags: CLUSTER-OP, spend (one external listener per namespace so a client on the other cluster can reach all four Torii)
- Does: Deployment `gateway` + Service in each of the four namespaces, labelled `rd-iroha3/role=gateway`, forwarding to the own peer Torii `:8080`, mTLS client cert, OPA allowing only the Torii paths a client and the auditor use. Pattern: the Fabric-X fx-gw gateways (`fabric-x/opa/DESIGN.md:18-30`, LENSA.md section 6). No Iroha-specific gateway config exists in the repos and the full Torii path list is [unverified]; the first deliverable lists the paths used by `aps.rs` and `iroha` CLI reads. Every client must reach all four Torii (exactly four, canonical order).
- RED proof: from a pod in `rd-iroha3-bank-a` without client cert: `curl -sS https://gateway.rd-iroha3-bank-b.svc:8443/status` -> `curl: (56)` / TLS alert; direct `curl --max-time 3 http://bank-b-0.bank-b.rd-iroha3-bank-b.svc:8080/status` -> `curl: (28) Connection timed out`; with the cert -> `HTTP/2 200`
- Rollback: delete the Deployment and Service; peers keep working (`peers-torii` policy stays closed)
- Sources: `iroha@071e281e:specs/private_settlement.md:296-310,545-559`; `crates/iroha/src/client/private_settlement.rs:379-470`

### S15: Pools index published by BI
- DELTA: 9 -> AFTER row: "`pools.json` published by BI (public data), single writer"
- Owner: iroha  Size: M
- Prerequisites: S13, S14
- Flags: none
- Does: today `pools.json` is a flock'd local file under `~/iroha3-pools` (CURRENT.md section 6). Target: BI driver is the single writer (PVC `pools-index` 1Gi in `rd-iroha3-bi`), content public only (origin commitments, bundle ids); banks read it through the BI gateway and scan their own notes from receipts. Code: `pools.rs:4-8,105-111,351` read from a URL; Lensa `iroha3.ts` stops reading the file. Serving path on the gateway is [unverified] (needs a static route; may need analyst input).
- RED proof: `curl --cert <bank-a cert> https://gateway.rd-iroha3-bi.svc:8443/pools/pools.json | jq '.rd.bundles|length'` -> a number equal to the bundle count; `ls ~/iroha3-pools/pools.json` is not used by the new driver (strace-free check: driver run with the dir unmounted passes)
- Rollback: re-mount `~/iroha3-pools`; image pin as in S10
- Sources: `iroha3-rd-dfabi@bc55e68:NOTES.md:22` (M1 race); `iroha3-rd-node-build@ceccc4d:driver/src/pools.rs:4-8,105-111`

### S16: Lensa per-bank pointers, no keys on the Lensa host
- DELTA: 10 -> AFTER row: "Lensa: relay + UI, only shared part, NO keys"
- Owner: fe  Size: M
- Prerequisites: S10, S14, S15; LENSA.md "Namespace references" for `iroha3`
- Flags: none (transport question in DEVIATION REQUEST)
- Does: `frontend/deploy/forwards.conf:13-18` (`iroha-bi/bank-a/bank-b/bank-c`, `iroha-auditor`) and `lensa.service:3-4` `Wants=/After=` stop naming `iroha3`; `server/state/iroha3.json` `torii.{BI,A,B,C}` and `aps.auditor` point at the four gateways (S14), `aps.mounts.keys` removed, driver image pin updated (`iroha3.json:21`); `iroha3-aps.ts:9-10,34-41` no longer mounts `~/iroha3-keys`; `state/iroha3/{admin,op-*,<party>}.toml` removed from the Lensa host; `cli/bootstrap-iroha3.ts:19,47` and `README.md:22` comments updated. Chain, asset ids and the `rd-dfabi.toml` torii map change with the new chain (`iroha3.json` assets, `accounts`).
- RED proof: `grep -nE "^\S+\s+iroha3\s" frontend/deploy/forwards.conf` -> 0 lines; `ls /home/ecs-user/iroha3-keys 2>&1` is no longer mounted: `grep -n 'keys' frontend/server/src/adapters/iroha3-aps.ts` -> 0 matches for the mount; `systemctl --user list-units 'lensa-pf@iroha-*' --no-legend` -> empty
- Rollback: `git revert` of the frontend PR, restore `forwards.conf` and `state/iroha3.json` from the pre-change copy; old namespace still alive until S19
- Sources: `rd-lensa-frontend@ed7b78b:server/src/adapters/iroha3-aps.ts:9-10,34-41`; LENSA.md sections 1.2, 4.2, 6

### S17: Leg exchange for per-bank proving
- DELTA: 7 -> AFTER row: "leg exchange: NOT in upstream"
- Owner: lead  Size: L
- Prerequisites: user decision ADR 0001
- Flags: BLOCKED(Iroha leg exchange)
- Does: nothing is built. Without it S9 (1b) and S10 stay partial and `pay` keeps its BI companion leg. Upstream has no protocol to pass prepared legs or authorizations between clients (analyst file section 2, "Multi-party leg question"); any transport is new custom code.
- RED proof: after a decision and a build: two banks each prove only their own leg and the bundle finalizes with neither process holding the other's seed (`ps`/mount check in each namespace); today: `aps.rs:1283-1289` builds all legs in one process
- Rollback: not applicable (nothing started)
- Sources: `iroha@071e281e:crates/iroha/src/client/private_settlement.rs:2527-2557`; `crates/iroha_core/src/privacy_engines/atomic_private_settlement/wallet.rs:139-148,222-228,365-384`; `specs/private_settlement.md:444-447`

### S18: qa cutover proof and drift re-run
- DELTA: 11 -> AFTER row: "re-run S1 and S2b on `be4dd898`; probe upload with one peer down"
- Owner: qa  Size: M
- Prerequisites: S16
- Flags: none (reads and the existing scenario Jobs, each run needs its own approval)
- Does: on the NEW namespaces run the project scenarios S1 (dvp) and S2b (audit reject) plus `pay` and `dvp-shared` through Lensa; one wallet read per party like CURRENT.md section 9 (sender sees out + fee, receiver sees in, outsider has no item, BI sees both legs in the auditor store); BI-balance proof (BI RD/DFABI balances equal the issued amounts less transfers); leg upload with one peer scaled to 0 (`aps.rs:374-379` fails on first error) records the result; R2 stays ACCEPTED (a peer down stops user txs).
- RED proof: scenario Jobs -> `Complete` for S1 and S2b; `wallet --party bank-c` `bundle_items: []` for the A->B bundle; BI auditor `/records/<bundle>` -> both legs `approved`. Before the cutover: the same commands against `rd-iroha3-*` -> `NotFound`
- Rollback: Lensa pins back to the old namespace (S16 rollback); no data change on the old chain
- Sources: CURRENT.md section 9; `agents/analyst/reports/2026-11-11-iroha3-driver-fabricx-bi-down.md`

### S19: Decommission iroha3
- DELTA: 3 (retire the one-operator namespace) -> AFTER row: "Cluster 1 (Jakarta) = ns-bi, ns-bank-a, ns-bank-b"
- Owner: lead  Size: M
- Prerequisites: (1) cutover proven: S18 qa PASS on the new namespaces for every flow + BI-balance proof; (2) nothing in Lensa, `lensa-pf@iroha-*` units, the OPA bundle server or CI points at `iroha3` (LENSA.md "Namespace references", row `iroha3`: 5 units, `iroha3.json`, `bootstrap-iroha3.ts:19,47`; CI `ci.yml` names no namespace; the self-hosted runner `iroha3-incluster` registered in `radityaaa43/iroha3-rd-dfabi` is deregistered); (3) chain data that must survive is migrated or snapshotted with a NAMED backup: `data-bi-0`, `data-bank-a-0`, `data-bank-b-0`, `data-bank-c-0` (5Gi each, about 364 MB used) and `bi-audit-store` (1Gi, 147 records, needs `bi-auditor.hybrid` to decrypt), backup name `iroha3-final-2026-11-11` (volume snapshot or `tar` copy of `/storage` plus the Secrets `peer-*`, `client-*`, `bi-auditor-key`, `rd-dfabi-wallets`); (4) all 6 PVs have reclaimPolicy Delete (CURRENT.md section 12), so an explicit step comes first: patch the 5 data PVs to `Retain` (or verify the copy), before any `kubectl delete`.
- Flags: user-only, CLUSTER-OP (own approval at that time), destructive
- Does: inventory = CURRENT.md section 12 "Decommission inventory": 1 Deployment (`bi-auditor`) + 7 ReplicaSets, 5 StatefulSets (4 peers + `gha-runner`), 6 Jobs, 6 PVCs (4 x 5Gi + 1Gi + 1Gi = 22Gi total including `runner-state-gha-runner-0`; 21Gi without it), 13 Secrets, 8 ConfigMaps (4 stale `genesis-*`), 2 NetworkPolicies, 5 Services, Role + RoleBinding `gha-deployer`, ServiceAccounts `default` and `gha-runner`, cluster-scoped PriorityClass `iroha3-peer`. Order: retain PVs -> verify backup restore on a scratch volume -> delete namespace `iroha3` -> delete PriorityClass `iroha3-peer` -> remove `lensa-pf@iroha-*` units, host dirs `~/iroha3-keys` and `~/iroha3-pools` only after the user confirms. GHCR packages stay. Scope cluster 1 only; cluster 2: nothing is ever deleted. Nothing executes now.
- RED proof: `kubectl get ns iroha3` -> `Error from server (NotFound): namespaces "iroha3" not found` and `kubectl get pv | grep iroha3` -> the 5 retained PVs `Released` (not gone) until the backup is verified; `kubectl get priorityclass iroha3-peer` -> NotFound
- Rollback: none after delete; restore the named backup `iroha3-final-2026-11-11` into a new namespace (retained PVs rebind by claimRef edit)
- Sources: CURRENT.md section 12; LENSA.md section 6; Kubernetes docs "Persistent Volumes" (reclaim policy Retain) [version not pinned: unverified]

## DEVIATION REQUEST (sent to `analyst`, copy `orchestrator`, 2026-11-11 by `lead`; S16 stays as written until answered)
Lead's position: a driver HTTP mode per bank is project code in `iroha3-rd-node-build` (the same repo as the existing `auditor` mode), not chain or Paladin code, so it falls under "settings and project client code" and does not need a target change; if `analyst` disagrees, the user decides. AFTER row: section 2a diagram "Lensa host: relay + UI, NO keys" with "bank-a client ... -> signed requests" and DELTA 10 "per-bank clients". The driver has only CLI commands (`pay`, `dvp-shared`, `wallet`, run by Lensa as `docker run`, `iroha3-aps.ts:37-41`) and one HTTP mode (`auditor`, `auditor.rs:1-6`). A per-bank in-namespace service that Lensa can call, so the seeds stay in the bank namespace, needs a new HTTP wrapper around the existing commands, which is new project code, not an upstream setting, and the AFTER does not say how Lensa reaches a bank's driver. The Paladin no-custom rule does not cover it, but the analyst header says "No custom code beyond what exists". Request: analyst confirms whether a thin driver server mode is inside the AFTER, or whether S16 keeps bank keys off the Lensa host by another route. S16 cannot finish its RED proof until this is answered.
