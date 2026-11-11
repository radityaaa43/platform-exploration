# iroha3: plan CURRENT -> AFTER
Skills used (loaded by `lead` with the Skill tool before the review; the drafter applied them as checklists): superpowers:writing-plans, ecc:plan, ecc:architecture-decision-records, ecc:kubernetes-patterns, ecc:documentation-lookup (context7 has no Iroha 3 docs, see CURRENT.md header; upstream repo files at the pin used), superpowers:verification-before-completion (every RED proof is a command with quoted output). Not applied, one line each: solidity-auditor, ecc:evm-token-decimals, web3-testing (no EVM on this platform).
Target: agents/analyst/design/ARCHITECTURE-iroha3.md (AFTER, sections 2 and 2a) + objectives (decentralization per bank: validator, self-submit, third-party; R1, R2, R3). Start: final-design/iroha3/CURRENT.md @ 2026-11-11 16:17 CST (cluster 1, ns `iroha3`).
Namespaces: rd-iroha3-bi, rd-iroha3-bank-a, rd-iroha3-bank-b (cluster 1), rd-iroha3-bank-c (cluster 2, new namespace only; no existing cluster-2 namespace is read or used).
Pins: upstream `iroha@071e281e` (written `iroha@071e281e`); `iroha3-rd-dfabi@bc55e68` (CURRENT.md header); driver `iroha3-rd-node-build@ceccc4d`; frontend `rd-lensa-frontend@ed7b78b`. `docs.iroha.tech` not used.
Shape of the move: the AFTER needs a new chain id (DELTA 2: re-genesis). The new chain runs in the new namespaces beside the old one; nothing migrates on-chain. The old chain stays untouched until S19.

## Order and dependencies
Peer keys and addresses come before the nodes (genesis needs `pop_hex` and the peer addresses): S6 (load balancers) precedes S5 (genesis); S2 to S6 precede S7 and S8.
1. S1 S1a namespaces, S1b RBAC + deny-all (CLUSTER-OP, two GOs)
2. S2 split generate.sh (after S1 not required, repo only)
3. S3 genesis governance split (after S2)
4. S4 BI key custody: auditor keys into `rd-iroha3-bi`, rotation rule (user-only; after S1a)
5. S5 per-party keygen (peer, account, note keys) and public-only genesis (after S2, S3, S4, S6)
6. S6 peer addresses, external LBs for cross-cluster (after S1a)
7. S7 peers BI, A, B on cluster 1 (after S1, S5)
8. S8 peer bank C on cluster 2 (after S7)
9. S9 per-bank key custody Secrets (after S5, S8)
10. S10 per-bank client and sponsor in the driver (after S9)
11. S11 auditor 1 and policy from config (after S4, S8, S10)
12. S12 auditor orgs 2 and 3: BLOCKED (after S11)
13. S13 pools activate with the decided k-of-n (after S11, S12; BLOCKED with S12)
14. S14 gateways and OPA; closes `torii-bootstrap` (after S8, S13)
15. S15 pools index published by BI (after S13)
16. S16 Lensa per-bank pointers (after S10, S14, S15)
17. S17 leg exchange: BLOCKED (gate for full self-submit)
18. S18 qa cutover proof and drift re-run (after S16)
19. S19 Decommission iroha3 (after S18, user-only)

## Steps
### S1: Namespaces, deployer RBAC, deny-all ingress
- DELTA: 3 -> AFTER row: "Per-bank own namespace ... own deployer; remove cross-party secrets get/list"
- Owner: iroha  Size: S
- Prerequisites: a user GO per sub-step; S1b on cluster 2 also needs the user's kubeconfig that really points at cluster 2 (the supplied file points at cluster 1); read-only check before S1b (kube-system only, no workload namespace read): on each cluster `kubectl -n kube-system get ds -o name` lists a CNI daemonset and its policy switch is not off (cluster 1: `terway-eniip` 21/21 and `disable_network_policy` -> `false`, CURRENT.md section 5); expected on cluster 2: the same pair. Policies used are only `podSelector`, `namespaceSelector`, `ipBlock` (no `endPort`)
- Flags: CLUSTER-OP, two separate GOs
- Does: (S1a, GO 1) create Namespaces `rd-iroha3-bi`, `rd-iroha3-bank-a`, `rd-iroha3-bank-b` (cluster 1) and `rd-iroha3-bank-c` (cluster 2); cluster 2's first write is namespaces only. (S1b, GO 2) in each: ServiceAccount `deployer`, Role `deployer` = the verbs of `deploy/runner/rbac.yaml:12-14` (workloads, services, configmaps, pvc, networkpolicies, jobs, pods, pods/log) with `pods/exec` and `secrets get,list` removed (secrets: `create,update,patch` only), NetworkPolicy `default-deny-ingress` (empty podSelector). Cluster 1 only: PriorityClass `rd-iroha3-peer` value 10000 (same as `iroha3-peer`, CURRENT.md section 1). Cluster 2: NO PriorityClass (a priority above default could preempt foreign pods). No runner is created; applies are CLUSTER-OPs.
- RED proof: `kubectl auth can-i get secrets -n rd-iroha3-bank-a --as=system:serviceaccount:rd-iroha3-bank-a:deployer` -> `no` (before: `Error from server (NotFound): namespaces "rd-iroha3-bank-a" not found`); `kubectl get networkpolicy -n rd-iroha3-bi -o name` -> `networkpolicy.networking.k8s.io/default-deny-ingress`
- Rollback: `kubectl delete ns` of the four names (empty at this point, no PVC yet)
- Sources: `iroha3-rd-dfabi@bc55e68:deploy/runner/rbac.yaml:12-23`; CURRENT.md section 5 (cluster 1 CNI)

### S2: Split generate.sh into per-party keygen and public-only assembly
- DELTA: 2 -> AFTER row: "Genesis from public data only: `kagami genesis ... --peer-pop PK=POP` per peer"
- Owner: iroha  Size: M
- Prerequisites: none (repo only, no cluster)
- Flags: none
- Does: in `iroha3-rd-dfabi` split `network/generate.sh` (key generation `:65-68`, peer.toml rewrite `:105-134`, Committee keys `:330-397`, genesis signing `:403-430`) into `network/keygen-party.sh <party>` (writes only that party's `peer.toml` seed material, prints no key) and `network/assemble.sh` (reads `network/public/peers.json` + `network/public/peers.addr.json` from S6, writes genesis and `expected_hash`). `assemble.sh` also reads `network/public/accounts.json` (public account ids of the four parties and `bi-gov`, from S5). `trusted_peers` / `public_address` come from `peers.addr.json` and in-cluster DNS for same-cluster peers (S6), not `dns(p)` alone (`generate.sh:96-97,105-108`). Genesis signing also needs the KAGEMUSHA mint-finality public parameters (`kagami ... --kagemusha-mint-finality-parameters`): Pasta proof keys are provisioned per peer and a topology change means replacing that authority before signing (`iroha_genesis/src/lib.rs:3829-3835`); `generate.sh:330-397` builds these committee keys today, so `keygen-party.sh` also emits each party's public parameters and `assemble.sh` passes them.
- RED proof: on a clean checkout with only `network/public/peers.json`, `peers.addr.json` and a signer key: `bash network/assemble.sh && ls network/out 2>&1` -> `ls: cannot access 'network/out': No such file or directory`, and `assemble.sh` runs `kagami genesis sign --topology ... --peer-pop PK=POP --private-key-file ... --expected-public-key ... --out-file ... --expected-hash-out ...` (README:248-262) and `test -s network/public/genesis.expected_hash && echo ok` -> `ok`; with one org's mint-finality public parameters missing it exits non-zero [message unverified]; before the split `assemble.sh` does not exist (`No such file or directory`)
- Rollback: `git revert` of the PR; old `generate.sh` still works for the old chain
- Sources: `iroha@071e281e:crates/iroha_kagami/README.md:77-87,223-273` (keys `:226-229`, sign `:248-262`, `--kagemusha-mint-finality-parameters` ~`:244`); `crates/iroha_genesis/src/lib.rs:3829-3835`; `iroha3-rd-dfabi@bc55e68:network/generate.sh:65-68,96-134,330-430` (`:429-430` moves `genesis.private_key` + `genesis.json` into `$OUT/genesis/`; verified: `:65-68,105-108,330,392,403-406`)

### S3: Genesis governance split (CanEnactGovernance, CanReadAllLedgerData only at BI)
- DELTA: 8 -> AFTER row: "Holder of `CanReadAllLedgerData`: BI only"
- Owner: iroha  Size: M
- Prerequisites: S2
- Flags: none
- Does: edit `network/genesis-rd-dfabi.jq` (grants `:10,11,16,17,25-28`) and `generate.sh:392` so `CanEnactGovernance` goes to a dedicated BI governance account `bi-gov`, not to the account behind `client-bi`; `CanReadAllLedgerData` / `CanReadRestrictedDataspace` only at BI; bank accounts keep `CanReadRestrictedDataspace` for their dataspace only (today bank-c has none, CURRENT.md section 3: keep that gap and flag it to analyst, do not fix). Whether `client-bi` holds CanEnactGovernance stays [unverified]: `generate.sh:392` grants it to `GEN_ACCOUNT` (`:275`) and `config.rs:21` calls the operator client the sponsor, but the account ids were not compared. Both permissions are genesis-only, so this edit only takes effect with S5.
- RED proof: `jq -r '.transactions[].instructions[]|select(.Grant)|.Grant.Permission.destination' <(jq -f network/genesis-rd-dfabi.jq ...) | sort | uniq -c` shows `CanEnactGovernance` granted to `bi-gov` only (`1 bi-gov`); before: granted to the `bi` operator account
- Rollback: `git revert`; no cluster effect
- Sources: `iroha@071e281e:crates/iroha_core/src/executor.rs:8225-8236`; `crates/iroha_core/src/smartcontracts/isi/private_settlement.rs:23-29,49-55`; `iroha3-rd-dfabi@bc55e68:network/genesis-rd-dfabi.jq`

### S4: BI key custody: auditor keys into rd-iroha3-bi, rotation rule
- DELTA: 1 (1a) + 1c (analyst addendum 2026-11-11) -> AFTER row: "BI org: own BLS key, own PVC; auditor 1: own signing + hybrid key"
- Owner: iroha (lead holds the rotation question)  Size: S
- Prerequisites: S1a; user decision on rotation of the BI `[streaming] identity_private_key` printed to a terminal on 2026-11-11 (CURRENT.md section 11)
- Flags: user-only, CLUSTER-OP (one Secret write in `rd-iroha3-bi`)
- Does: (1a) in BI custody generate fresh auditor keys with the driver (`keys new <dir> bi-auditor`, `keys new-hybrid <dir> bi-auditor`, `main.rs:44,52`) and create Secret `bi-auditor-key` (keys `bi-auditor.seed`, `bi-auditor.hybrid`) in `rd-iroha3-bi` only; the old `bi-auditor.*` stay in `~/iroha3-keys` and ns `iroha3` for the old chain until the S19 backup, they are not copied. S11 consumes this Secret. (1c) The user decides whether the exposed old BI identity is rotated on the OLD chain (no old peer restart until the user answers, per CURRENT.md). For the NEW chain the BI peer identity and `[streaming]` identity are generated fresh in S5 and never reuse old values; S7 checks this before `rd-iroha3-bi` serves. No value is quoted.
- RED proof: `kubectl get secret bi-auditor-key -n rd-iroha3-bi -o jsonpath='{.data}' | jq 'keys'` -> `["bi-auditor.hybrid","bi-auditor.seed"]` and `kubectl get secret bi-auditor-key -n rd-iroha3-bank-a` -> NotFound; after S7 (qa, read-only): `peer-bi` in `rd-iroha3-bi` is newer than S5 and the sha256 prefix of its `peer.toml` differs from the old Secret's (`97d272a9b342`, CURRENT.md section 1) -> `differs`
- Rollback: delete Secret `bi-auditor-key` in `rd-iroha3-bi` (fresh keys, nothing else used them yet); rotation of the old chain: none needed (no change)
- Sources: CURRENT.md sections 1, 8, 11; `iroha3-rd-node-build@ceccc4d:driver/src/main.rs:44,52`; `iroha@071e281e:crates/iroha_kagami/README.md:223-235` (private key never printed)

### S5: Per-party keygen and public-only genesis (new chain id)
- DELTA: 2 -> AFTER row: "one signer builds genesis from `peers.json` only; destroy genesis private key"
- Owner: iroha  Size: M
- Prerequisites: S2, S3, S4, S6 (`peers.addr.json` must exist: allocate the load balancers first, then genesis); each org's KAGEMUSHA mint-finality public parameters from S2; user go for the new chain id: a new genesis is a new `network_id` (`NetworkId::from_genesis_hash`, `iroha_data_model/src/id.rs:36`), manifests and audit plaintext/AAD carry `network_id` (`aps.rs:1202,1371`; `private_settlement.rs:329,382,460`), so ledger and pools start fresh, balances do not carry, and the 147 records in `bi-audit-store` stay readable but bound to the old `network_id`
- Flags: user-only (new chain id)
- Does: each org (BI, A, B, C) runs `kagami keys --algorithm bls_normal --pop` in its own custody, publishes only `public_key` + `pop_hex` into `network/public/peers.json`; each org also generates its own account seed and note key (`keys new`, `keys new-note`, `main.rs:44,63`; BI also `bi-gov`, S3) and publishes only the public account id (`keys show`, `main.rs:~74`) into `network/public/accounts.json` beside `peers.json`, because genesis registers the four party accounts and ids are key-derived (`genesis-rd-dfabi.jq` `acct(...)`); private seeds and note keys never leave the org (S9 only turns them into Secrets); one signer runs `assemble.sh` -> `genesis.signed.nrt`, `genesis.public_key`, `genesis.expected_hash` (`--expected-hash-out`); the genesis private key is destroyed after signing. CURRENT.md contradicts the analyst BEFORE: `generate.sh:429-430` moves `genesis.private_key` + `genesis.json` to `$OUT/genesis/`, but no `genesis/` dir exists in `network/out` now, so the current location stays [unverified]; the step records where the signer key lived and proves its deletion. Each org verifies `kagami genesis validate` and the hash. Committee-role key per peer is built from peer key + PoP (`generate.sh:365-397`).
- RED proof: `ls network/out/*/` on the assembling machine -> no other org's `peer.toml`; `jq 'keys' network/public/accounts.json` -> the four party names + `bi-gov`, values are public ids only (no file named `*.seed` or `*.note` in `network/public`); `cat network/public/genesis.expected_hash` -> `hash:<8 hex>...` different from `hash:A3D75EEA...` (CURRENT.md section 3); `find / -name '*genesis*key*' 2>/dev/null` (assembler host) -> empty after destruction
- Rollback: none after the signer key is destroyed; to redo, repeat S5 with a new signer key (new chain id again). Old chain unaffected.
- Sources: `iroha@071e281e:crates/iroha_kagami/README.md:77-87,223-273`; `crates/iroha_genesis/src/lib.rs:3829-3860` (key-set change = new signed genesis)

### S6: Peer addresses (cluster DNS inside cluster 1, external LoadBalancer for cross-cluster)
- DELTA: 3 -> AFTER row: "Cross-org P2P :1337 ... `trusted_peers` addresses"
- Owner: iroha  Size: M
- Prerequisites: S1a (the four namespaces; the Service needs no S1b objects)
- Flags: CLUSTER-OP, spend (4 load balancers)
- Does: configured addresses win over gossip (`iroha_core/src/peers_gossiper.rs:944-958`: `selected_peer_addresses` starts from `initial_peers` and skips ids already in `peers`; test `configured_address_cannot_be_replaced_by_gossip_quorum` `:1379`; doc `:308-318`), and `trusted_peers` / `public_address` are per node (`user.rs:845,7843`). So cluster-1 peers keep cluster DNS for each other and add only bank C's external address; bank C's `trusted_peers` lists external addresses for BI, A, B. Minimum shape: Service `p2p` type LoadBalancer :1337 (selector `iroha3-rd/party=<party>`) for each cluster-1 peer, reachable from cluster 2, plus one for bank C = 4 LBs, addresses recorded in `network/public/peers.addr.json`. Upstream alternative: `relay_mode` hub/spoke with `relay_hub_addresses` (`user.rs:7844-7852`), one LB; not chosen. The 4-LB shape does not depend on one-way reachability. Read-only prerequisite check for any reduction below 4 LBs (iroha, repo read): read `crates/iroha_p2p` connection handling and write in the PR whether a connection dialled by one side carries both directions; expected output: one sentence with path:line; not proven means keep 4 LBs. NodePort not chosen (needs node IPs reachable from the other cluster) [lead may overrule].
- RED proof: `kubectl get svc p2p -n rd-iroha3-bank-c -o jsonpath='{.status.loadBalancer.ingress[0].ip}'` -> a non-empty IP (before: `Error from server (NotFound)`); `jq length network/public/peers.addr.json` -> `4`
- Rollback: `kubectl delete svc p2p` in each namespace (releases the load balancers)
- Sources: `iroha@071e281e:crates/iroha_config/src/parameters/user.rs:844-857,7840-7852`; `crates/iroha_core/src/peers_gossiper.rs:308-318,944-958,1379`; analyst file section 2a ("bank-C address must be reachable from cluster 1 (LB or NodePort: our choice)")

### S7: Peers BI, A, B on cluster 1
- DELTA: 3 -> AFTER row: "own STS, PVC, Secret `peer-<party>`"
- Owner: iroha  Size: L
- Prerequisites: S1, S4, S5
- Flags: CLUSTER-OP
- Does: in each of the three namespaces apply StatefulSet `<party>` (base `deploy/k8s/base/statefulset.yaml`, image `ghcr.io/radityaaa43/iroha3-rd-node:071e281e-stark`, `priorityClassName: rd-iroha3-peer`, args `--sora --config /config/peer.toml`, probes `/livez` and `/readyz` as in CURRENT.md section 1, requests 250m/1Gi limits 2/3Gi), PVC `data-<party>-0` 5Gi `alicloud-essd-wffc`, Secret `peer-<party>` (that org's own `peer.toml` only), immutable ConfigMap `genesis-<hash8>`; `trusted_peers` = cluster DNS for the other cluster-1 peers + bank C's external address (S6); NetworkPolicy `peers-p2p` (1337 from the other two cluster-1 namespaces by `namespaceSelector` and from bank C's LB by `ipBlock`; LB/NAT source IP behaviour must be tested, analyst caveat) `peers-torii` (8080 only from pods labelled `rd-iroha3/role=gateway` in the same namespace) and a TEMPORARY `torii-bootstrap` (8080 from any pod in the own namespace; the operator's `kubectl port-forward` goes through the API server and needs no rule, CURRENT.md section 5), so S8, S11 and S13 reach Torii before the gateways exist; S14 deletes it. Chain cannot commit user txs until S8 (4 validators, fixed lane author).
- RED proof: `kubectl get pod bi-0 -n rd-iroha3-bi -o jsonpath='{.status.phase} {.status.containerStatuses[0].restartCount}'` -> `Running 0` (before: `NotFound`); `kubectl get secret -n rd-iroha3-bank-a -o name` lists no `peer-bi`
- Rollback: delete the three StatefulSets and PVCs (new chain, nothing worth keeping yet; before S8 only; deleting PVCs destroys disks: user-only)
- Sources: `iroha3-rd-dfabi@bc55e68:deploy/k8s/base/statefulset.yaml:36-93,118-133`; `deploy/k8s/networkpolicy.yaml:12-22`; `iroha@071e281e:crates/iroha_core/src/lane_consensus.rs:96-107,854-860`; kubernetes.io network-policies ("ipBlock", "Cluster ingress and egress mechanisms")

### S8: Peer bank C on cluster 2
- DELTA: 12 -> AFTER row: "Cluster 2 for bank C: peer `public_address`, NetworkPolicy `ipBlock`s, PVC class overlay"
- Owner: iroha  Size: M
- Prerequisites: S7, S6; user item: a kubeconfig that really points at cluster 2 (the file supplied earlier points at cluster 1); sequence after Besu and Paladin and gateways on cluster 2 (analyst 2a)
- Flags: CLUSTER-OP, user-only (cluster 2 first write is its own approval)
- Does: in `rd-iroha3-bank-c` only: StatefulSet `bank-c` (no PriorityClass; set requests 250m/1Gi, limits 2/3Gi; schedule on a member node with free memory), PVC `data-bank-c-0` 5Gi with a cluster-2 StorageClass overlay (`alicloud-essd-wffc` is not in cluster 2's class list: `alicloud-essd` or `fabricx-essd`; choose `alicloud-essd` [unverified binding mode]), Secret `peer-bank-c`, ConfigMap `genesis-<hash8>`, NetworkPolicy `peers-p2p` with `ipBlock`s of the three cluster-1 LBs. DELTA 12's "rolling restart of BI, A, B" does not apply: in the fresh chain every cluster-1 `peer.toml` already lists bank C's external address (S6). Cross-region RTT 15 ms measured, no tunable changes (analyst 2a).
- RED proof: qa, read-only, two GETs of `/status` 10 s apart on each of the four peers (CURRENT.md section 1 used a Norito `/status` read; decode the binary body) -> status field `blocks` (height) strictly increases and `peers` is 3 on all four (`iroha_torii_shared/src/status/common.rs:278-296`)
- Rollback: scale `bank-c` to 0 (chain halts: fixed lane author); full undo = delete the namespace objects created here; cluster 2 other namespaces never touched
- Sources: analyst file section 2a "Capacity on cluster 2", "Cross-cluster limits"; `statefulset.yaml:66-71,130`

### S9: Per-bank key custody Secrets (seed, note key)
- DELTA: 1 (1b) -> AFTER row: "Bank A org: client.toml, seed, note key, own sponsor"
- Owner: iroha  Size: M
- Prerequisites: S5, S8
- Flags: CLUSTER-OP (Secrets in four namespaces on two clusters)
- Does: no new keys (the accounts are fixed in genesis, S5): each org takes the `<party>.seed` and `<party>.note` it generated in S5 and creates Secret `client-<party>` (`client.toml`, `genesis.expected_hash`) plus Secret `wallet-<party>` (seed, note key) in its own namespace; split `deploy/secrets.sh:48-52` and Secret `rd-dfabi-wallets` (today `bank-a.seed bank-b.seed bank-c.seed bi.seed` together) into per-namespace creation; remove the sample `[basic_auth]` table from `client.toml`. 1b is only complete after S17 (one driver process still needs payer, recipient and sponsor keys, `aps.rs:1175-1211`; view-key signing loop `for (index, signer) in [recipient, payer, sponsor_key]` at `aps.rs:1345`).
- RED proof: `kubectl get secret -n rd-iroha3-bank-b -o name` -> `secret/client-bank-b` and `secret/wallet-bank-b`, and `kubectl get secret -n rd-iroha3-bank-b wallet-bank-a` -> `Error from server (NotFound)`
- Rollback: delete the Secrets; the material stays in each org's custody (S5)
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
- Prerequisites: S4, S8, S10
- Flags: CLUSTER-OP
- Does: code: make `min_approvals` and the `auditors` list config keys in `rd-dfabi.toml` (hardcoded at `aps.rs:917,919`, CURRENT.md section 2) and make the driver wait for k approvals instead of one `/approve` (the `/approve` loop at `aps.rs:386-396`; `:384` is `println!("legs uploaded")`). Cluster: in `rd-iroha3-bi` Deployment `bi-auditor` (readOnlyRootFilesystem, as CURRENT.md section 2), Secret `bi-auditor-key` (created by S4 in this namespace, not recreated here), PVC `bi-audit-store` 1Gi, ConfigMaps `rd-dfabi-config`, `rd-dfabi-peers`, NetworkPolicy `bi-auditor` (8090 from the three bank namespaces; bank C via gateway, S14). The auditor starts with the policy file S12 decides; no pool is activated before S12 (S13). The auditor HTTP caller is unauthenticated today [unverified, LENSA.md section 5].
- RED proof: `cargo test -p driver policy_from_config` (k=2, n=3 config parses; k=0 and k>n rejected) -> `test result: ok. 3 passed`; live: `kubectl get deploy bi-auditor -n rd-iroha3-bi -o jsonpath='{.status.readyReplicas}'` -> `1`
- Rollback: delete the Deployment and PVC in `rd-iroha3-bi` (new empty store; deleting the PVC is user-only); driver image pin as in S10
- Sources: `iroha@071e281e:crates/iroha_data_model/src/nexus/private_settlement.rs:2127-2129,2222-2227`; `crates/iroha_core/src/private_settlement/state.rs:1118`; `iroha3-rd-dfabi@bc55e68:deploy/k8s-apps/bi-auditor.yaml:8-10,21-28,89,110`

### S12: Auditor orgs 2 and 3 (k-of-n)
- DELTA: 5 -> AFTER row: "Default proposed: 2-of-3 (BI, org 2, org 3) ... 2-of-2 is the minimum"
- Owner: lead  Size: M
- Prerequisites: S11; user decision ADR 0002
- Flags: BLOCKED(Iroha auditor orgs 2 and 3), CLUSTER-OP
- Does: nothing until the user picks. After the pick: official `iroha nexus private-settlement audit-online` run by each extra org with its own signing + hybrid key and business policy allowlisting all four sponsors; the namespace naming rule has no slot for these orgs, `lead` names them with the decision. The decided k and n go into S13's pool activation. ADR 0002 option "keep 1-of-1" stays the user's choice, not a deviation from the AFTER.
- RED proof: `jq '.auditors|length, .min_approvals' <policy>` -> the chosen n and k (e.g. `3` and `2`); a settlement with one auditor stopped -> still `finalized` for k-of-n with k < n
- Rollback: stop the extra auditors (no pool exists yet; S13 not started)
- Sources: `iroha@071e281e:crates/iroha_cli/README.md:194-256`; `specs/private_settlement.md:296-340,353-392`

### S13: Activate the RD and DFABI pools with the decided k-of-n policy
- DELTA: 6 -> AFTER row: "Alternative: new pools at re-genesis with the k-of-n policy from the start"
- Owner: iroha  Size: M
- Prerequisites: S11, S12 (decided)
- Flags: CLUSTER-OP, BLOCKED(Iroha auditor orgs 2 and 3) inherited from S12
- Does: with the BI governance account (S3) run driver `pool-init` for `rd` and `dfabi` (`ActivatePrivateSettlementPoolV1`; `activation_height = 11`, `minimum_activation_notice_blocks = 10` from `nexus.toml:98-105`) with the `min_approvals` and `auditors` S12 decided; the chain is new, so DELTA 6's alternative applies (new pools carry k-of-n from the start, no later rotation, old pools on the old chain are not rotated). Then BI mints test balances to the four accounts (`CanMintAssetWithDefinition`).
- RED proof: driver `pool-history --asset rd` -> line `pool_history asset=rd epoch=<n> leaves=<m> root=<hex>` for both assets (CURRENT.md section 3 shows the format; initial values [unverified]); before: `pools.json` absent
- Rollback: none after activation (pools are on-chain); the whole new chain is dropped by deleting S7/S8 objects (StatefulSets and PVCs: user-only) before S16
- Sources: `iroha@071e281e:crates/iroha_core/src/smartcontracts/isi/private_settlement.rs:23-29,49-55`; `specs/private_settlement.md:353-360,375-392`; `iroha3-rd-dfabi@bc55e68:network/nexus.toml:94-105`

### S14: Gateways (Envoy + OPA) per namespace
- DELTA: 13 (analyst addendum 2026-11-11) -> AFTER row: "gateway envoy+opa ... peer 8080 only from the own gateway pod"
- Owner: iroha  Size: L
- Prerequisites: S8, S13; read-only check (iroha, repo read): list every Torii path the clients use with `git grep -nE '/v1/|/status' ceccc4d -- driver/src` in node-build and the `iroha` client methods in `crates/iroha/src/client/private_settlement.rs`; expected output: `gateway/paths.txt`, one `path  file:line` per row, from which the OPA allowlist is generated (nothing outside it)
- Flags: CLUSTER-OP, spend (one external listener per namespace so a client on the other cluster can reach all four Torii)
- Does: Deployment `gateway` + Service in each of the four namespaces, labelled `rd-iroha3/role=gateway`, forwarding to the own peer Torii `:8080`, mTLS client cert, OPA allowing only the Torii paths a client and the auditor use. Pattern: the Fabric-X fx-gw gateways (`fabric-x/opa/DESIGN.md:18-30`, LENSA.md section 6). No Iroha-specific gateway config exists in the repos. Also delete NetworkPolicy `torii-bootstrap` (S7) in each namespace. Every client must reach all four Torii (exactly four, canonical order).
- RED proof: from a pod in `rd-iroha3-bank-a` without client cert: `curl -sS https://gateway.rd-iroha3-bank-b.svc:8443/status` -> `curl: (56)` / TLS alert; direct `curl --max-time 3 http://bank-b-0.bank-b.rd-iroha3-bank-b.svc:8080/status` -> `curl: (28) Connection timed out`; with the cert -> `HTTP/2 200`; `kubectl get networkpolicy torii-bootstrap -n rd-iroha3-bi` -> NotFound, and `curl --max-time 3 http://bi-0.bi.rd-iroha3-bi.svc:8080/status` from a non-gateway pod in that namespace -> `curl: (28) Connection timed out`
- Rollback: delete the Deployment and Service and re-apply `torii-bootstrap`; peers keep working
- Sources: `iroha@071e281e:specs/private_settlement.md:296-310,545-559`; `crates/iroha/src/client/private_settlement.rs:379-470`

### S15: Pools index published by BI
- DELTA: 9 -> AFTER row: "`pools.json` published by BI (public data), single writer"
- Owner: iroha  Size: M
- Prerequisites: S13, S14
- Flags: CLUSTER-OP (PVC `pools-index`, gateway route)
- Does: today `pools.json` is a flock'd local file under `~/iroha3-pools` (CURRENT.md section 6). Target: BI driver is the single writer (PVC `pools-index` 1Gi in `rd-iroha3-bi`), content public only (origin commitments, bundle ids); banks read it through the BI gateway and scan their own notes from receipts. Code: `pools.rs:105` (`impl PoolFile`: load/save/update) reads from a URL instead of the flock'd file; Lensa `iroha3.ts` stops reading the file. Serving path on the gateway is [unverified] (needs a static route; may need analyst input).
- RED proof: `curl --cert <bank-a cert> https://gateway.rd-iroha3-bi.svc:8443/pools/pools.json | jq '.rd.bundles|length'` -> a number equal to the bundle count; `ls ~/iroha3-pools/pools.json` is not used by the new driver (strace-free check: driver run with the dir unmounted passes)
- Rollback: re-mount `~/iroha3-pools`; image pin as in S10
- Sources: `iroha3-rd-dfabi@bc55e68:NOTES.md` sections "Rollout record" and "Limits" (`NOTES.md:22` is stale: M1 merged in 972b272); `iroha3-rd-node-build@ceccc4d:driver/src/pools.rs:105`

### S16: Lensa per-bank pointers, no keys on the Lensa host
- DELTA: 10 + 10a (analyst answer 2026-11-11, PR #32) -> AFTER row: "Lensa: relay + UI, only shared part, NO keys"
- Owner: fe (Lensa) + iroha (driver server mode)  Size: L
- Prerequisites: S10, S14, S15; LENSA.md "Namespace references" for `iroha3`
- Flags: CLUSTER-OP; dvp-shared part BLOCKED(Iroha leg exchange, ADR 0001)
- Conditions (DELTA 10a, all five required): (1) the driver server mode runs only in that bank's namespace `rd-iroha3-<party>`; (2) it mounts only `<party>.seed` + `<party>.note` (DELTA 1b), never the auditor key (1a); (3) it exposes only the existing `pay`, `dvp-shared`, `wallet` commands, no new chain logic (`driver/src/auditor.rs:1-6` is the existing HTTP mode it extends); (4) reachable only through that bank's gateway envoy+opa with mTLS (S14, AFTER 2a NetworkPolicy row); (5) Lensa holds no key and no kubeconfig. Limit unchanged: two-leg DvP still needs the BI sponsor path until the user decides ADR 0001.
- Does (cluster): in each of the four namespaces Deployment `iroha3-driver-<party>` (image `ghcr.io/radityaaa43/iroha3-rd-driver:<tag from S10>`, args `serve`, label `rd-iroha3/role=driver`, mounts only `wallet-<party>`), Service `iroha3-driver`, NetworkPolicy `driver-ingress` (ingress only from `rd-iroha3/role=gateway` pods). In `rd-iroha3-bi` the same Deployment holds BI's seed only and is the sponsor path. Routing: `pay` and `wallet` run on the acting bank's own service (single-leg, keyless Lensa achieved). `dvp-shared` builds every leg in ONE process (`driver/src/aps.rs:1345`, signers recipient + payer + sponsor), so it cannot be split across the bank services without the leg exchange of ADR 0001: until the user decides ADR 0001, `dvp-shared` keeps today's path (Lensa host with all seeds mounted, `iroha3-aps.ts:37-41`) as a recorded interim gap against conditions (2) and (5), and S18's two-leg proof runs on that path. Flags for the dvp part: BLOCKED(Iroha leg exchange). Interim conditions (analyst 2026-11-11): the auditor key never sits on that host (DELTA 1a still applies); CONTRACTS.md marks `dvp-shared` as the one op outside the keyless-relay contract until README row 18 is decided. No upstream route avoids the gap: only the sponsor submits bundle carriers (spec :545-559, `carrier.rs:215-219`), the client crate's prepared-leg type is single-process (`crates/iroha/src/client/private_settlement.rs`), no protocol passes prepared legs between clients (ARCHITECTURE-iroha3.md §2, DELTA 7).
- Does (Lensa): `frontend/deploy/forwards.conf:13-18` (`iroha-bi/bank-a/bank-b/bank-c`, `iroha-auditor`) and `lensa.service:3-4` `Wants=/After=` stop naming `iroha3`; `server/state/iroha3.json` `torii.{BI,A,B,C}` and `aps.auditor` point at the four gateways (S14), `aps.mounts.keys` removed, driver image pin updated (`iroha3.json:21`); `iroha3-aps.ts:9-10,34-41` no longer mounts `~/iroha3-keys`; `state/iroha3/{admin,op-*,<party>}.toml` removed from the Lensa host; `cli/bootstrap-iroha3.ts:19,47` and `README.md:22` comments updated. Chain, asset ids and the `rd-dfabi.toml` torii map change with the new chain (`iroha3.json` assets, `accounts`).
- RED proof: `grep -nE "^\S+\s+iroha3\s" frontend/deploy/forwards.conf` -> 0 lines; `ls /home/ecs-user/iroha3-keys 2>&1` is no longer mounted: `grep -n 'keys' frontend/server/src/adapters/iroha3-aps.ts` -> 0 matches for the mount; `systemctl --user list-units 'lensa-pf@iroha-*' --no-legend` -> empty
- Rollback: `git revert` of the frontend PR, restore `forwards.conf` and `state/iroha3.json` from the pre-change copy; old namespace still alive until S19
- Sources: `rd-lensa-frontend@ed7b78b:server/src/adapters/iroha3-aps.ts:9-10,34-41`; LENSA.md sections 1.2, 4.2, 6

### S17: Leg exchange for per-bank proving
- DELTA: 7 -> AFTER row: "leg exchange: NOT in upstream"
- Owner: lead  Size: L
- Prerequisites: user decision ADR 0001
- Flags: BLOCKED(Iroha leg exchange)
- Does: nothing is built. Without it S9 (1b) and S10 stay partial and `pay` keeps its BI companion leg. Upstream has no protocol to pass prepared legs or authorizations between clients (analyst file section 2, "Multi-party leg question"); any transport is new custom code.
- RED proof: after a decision and a build: two banks each prove only their own leg and the bundle finalizes with neither process holding the other's seed (`ps`/mount check in each namespace); today: `aps.rs:1345` (`for (index, signer) in [recipient, payer, sponsor_key]`) signs all legs in one process
- Rollback: not applicable (nothing started)
- Sources: `iroha@071e281e:crates/iroha/src/client/private_settlement.rs:2527-2557`; `crates/iroha_core/src/privacy_engines/atomic_private_settlement/wallet.rs:139-148,222-228,365-384`; `specs/private_settlement.md:444-447`

### S18: qa cutover proof and drift re-run
- DELTA: 11 -> AFTER row: "re-run S1 and S2b on `be4dd898`; probe upload with one peer down"
- Owner: qa  Size: M
- Prerequisites: S16
- Flags: CLUSTER-OP (scenario Jobs; scaling one peer to 0 needs its own GO)
- Does: on the NEW namespaces run the project scenarios S1 (dvp) and S2b (audit reject) plus `pay` and `dvp-shared` through Lensa; one wallet read per party like CURRENT.md section 9 (sender sees out + fee, receiver sees in, outsider has no item, BI sees both legs in the auditor store); BI-balance proof (BI RD/DFABI balances equal the issued amounts less transfers); leg upload with one peer scaled to 0 (`aps.rs:374-379` fails on first error) records the result; R2 stays ACCEPTED (a peer down stops user txs).
- RED proof: scenario Jobs -> `Complete` for S1 and S2b; `wallet --party bank-c` `bundle_items: []` for the A->B bundle; BI auditor `/records/<bundle>` -> both legs `approved`. Before the cutover: the same commands against `rd-iroha3-*` -> `NotFound`
- Rollback: Lensa pins back to the old namespace (S16 rollback); no data change on the old chain
- Sources: CURRENT.md section 9; `agents/analyst/reports/2026-11-11-iroha3-driver-fabricx-bi-down.md`

### S19: Decommission iroha3
- DELTA: 12a (analyst addendum 2026-11-11) -> AFTER row: "Cluster 1 (Jakarta) = ns-bi, ns-bank-a, ns-bank-b"
- Owner: lead  Size: M
- Prerequisites: (1) cutover proven: S18 qa PASS on the new namespaces for every flow + BI-balance proof; (2) nothing in Lensa, `lensa-pf@iroha-*` units, the OPA bundle server or CI points at `iroha3` (LENSA.md "Namespace references", row `iroha3`: 5 units, `iroha3.json`, `bootstrap-iroha3.ts:19,47`; CI `ci.yml` names no namespace; the self-hosted runner `iroha3-incluster` registered in `radityaaa43/iroha3-rd-dfabi` is deregistered); (3) chain data that must survive is migrated or snapshotted with a NAMED backup: `data-bi-0`, `data-bank-a-0`, `data-bank-b-0`, `data-bank-c-0` (5Gi each, about 364 MB used) and `bi-audit-store` (1Gi, 147 records, needs `bi-auditor.hybrid` to decrypt), backup name `iroha3-final-2026-11-11` (volume snapshot or `tar` copy of `/storage` plus the Secrets `peer-*`, `client-*`, `bi-auditor-key`, `rd-dfabi-wallets`); (4) all 6 PVs have reclaimPolicy Delete (CURRENT.md section 12), so an explicit step comes first: patch the 5 data PVs to `Retain` (or verify the copy), before any `kubectl delete`.
- Flags: user-only, CLUSTER-OP (own approval at that time), destructive
- Does: inventory = CURRENT.md section 12 "Decommission inventory": 1 Deployment (`bi-auditor`) + 7 ReplicaSets, 5 StatefulSets (4 peers + `gha-runner`), 6 Jobs, 6 PVCs (4 x 5Gi + 1Gi + 1Gi = 22Gi total including `runner-state-gha-runner-0`; 21Gi without it), 13 Secrets, 8 ConfigMaps (4 stale `genesis-*`), 2 NetworkPolicies, 5 Services, Role + RoleBinding `gha-deployer`, ServiceAccounts `default` and `gha-runner`, cluster-scoped PriorityClass `iroha3-peer`. Order: retain PVs -> verify backup restore on a scratch volume -> delete namespace `iroha3` -> delete PriorityClass `iroha3-peer` -> remove `lensa-pf@iroha-*` units, host dirs `~/iroha3-keys` and `~/iroha3-pools` only after the user confirms. GHCR packages stay. Scope cluster 1 only; cluster 2: nothing is ever deleted. Nothing executes now.
- RED proof: `kubectl get ns iroha3` -> `Error from server (NotFound): namespaces "iroha3" not found` and `kubectl get pv | grep iroha3` -> the 5 retained PVs `Released` (not gone) until the backup is verified; `kubectl get priorityclass iroha3-peer` -> NotFound
- Rollback: none after delete; restore the named backup `iroha3-final-2026-11-11` into a new namespace (retained PVs rebind by claimRef edit)
- Sources: CURRENT.md section 12; LENSA.md section 6; Kubernetes docs "Persistent Volumes" (reclaim policy Retain) [version not pinned: unverified]

## DEVIATION REQUEST
None. The S16 question (per-bank driver HTTP mode) was answered by `analyst` on 2026-11-11: inside the AFTER as project client code, recorded as DELTA 10a (platform-exploration PR #32).
