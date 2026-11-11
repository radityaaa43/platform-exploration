# zeto: plan CURRENT -> AFTER
Skills used (loaded by `lead` with the Skill tool before the review; the drafter applied them as checklists): superpowers:writing-plans, ecc:architecture-decision-records, ecc:kubernetes-patterns, superpowers:verification-before-completion (RED proofs), ecc:evm-token-decimals (S14, CONTRACTS), solidity-auditor (inventory only, no audit run), ecc:deployment-patterns (S19-S21 cutover and rollback), ecc:code-explorer (path:line reads, by hand). Not applied: web3-testing (no contract code is built). Drafter note: skills applied as checklists, not loaded as tool calls.
Target: agents/analyst/design/ARCHITECTURE-zeto.md (AFTER) + objectives (decentralization per bank: validator, self-submit, third-party; R1, R2, R3). Start: final-design/zeto/CURRENT.md @ 2026-11-11 (file carries no time).
Namespaces: rd-zeto-bi, rd-zeto-bank-a, rd-zeto-bank-b (cluster 1), rd-zeto-bank-c (cluster 2, new only). Old: `besu` (4 QBFT validators, PVs Retain), `paladin` (4 Paladin nodes, Postgres PVs Delete), `dfabi`; all three shared with noto-pente and stealth.
Pins: `besu@9890701` (CURRENT), `frontend@28c8bdb` (local HEAD; CURRENT cites aa6e09b, lines re-read), `paladin@v1.0.0` (6d4b913), `zeto@v0.5.1`, Besu image 26.8.1 (docs unversioned, so version match is not proven).
Preserve (every step): chain 1337 and every address in CONTRACTS.md (validators change by vote, no new genesis, no token redeploy unless ADR 0002 says so); Paladin node names node1..4 and their seeds (they ARE the Zeto owner keys); the running fork image digest (no new Paladin code); Zeto has no notary or auditor role, so no step for those.
Reused by noto-pente and stealth: S1-S5 (namespace pattern, validator per bank), S8-S11 (Paladin node, DB, transport, registry), S16-S17 (gateway, OPA). One Paladin node per party serves Zeto, Noto and Pente today (CURRENT sections 2-3), so it moves once, here, with the noto and pente domain selectors unchanged.

## Order and dependencies
1. S1 (none)  2. S2 after user cluster-2 credential  3. S3 after S1  4. S4 after S2,S3  5. S5 after S3,S4
6. S6 after S1,S2  7. S7 after ADR 0004  8. S8 after S1,S2 (spend decision)  9. S9 after S5,S6,S8  10. S10 after S9  11. S11 after S10 and ADR 0001
12. S12 after ADR 0002  13. S13 after ADR 0003  14. S14 (none)  15. S15 after S9  16. S16 after S1,S2,S9  17. S17 after S16
18. S18 after ADR 0005  19. S19 after S16,S17  20. S20 after S19  21. S21 after S5,S9,S11,S17,S20 (+ S12/S13/S18 if their ADR changes the flow)  22. S22 after S21 (LAST)

## Steps
### S1: Per-party namespaces on cluster 1
- DELTA: 2 -> AFTER row: "ingress to RPC 8548 only from this namespace's gateway pods" (2a NetworkPolicy)
- Owner: besu  Size: S
- Prerequisites: none; user issues one namespace-scoped credential per party
- Flags: CLUSTER-OP, user-only (credential issue)
- Does: create ns `rd-zeto-bi`, `rd-zeto-bank-a`, `rd-zeto-bank-b` (labels `part-of=rd-zeto`, `party=<bi|bank-a|bank-b>`); NetworkPolicy `default-deny-ingress`, `allow-dns-egress`, `allow-same-namespace`; ServiceAccount `party-admin` + Role/RoleBinding limited to the namespace. Egress stays open (ARCHITECTURE rows are ingress-only; Besu p2p and Paladin 9000 need egress). Reused by noto-pente, stealth.
- RED proof: `kubectl get ns rd-zeto-bank-a` before `NotFound`, after `Active`; `kubectl -n rd-zeto-bank-a auth can-i get pods -n rd-zeto-bank-b --as system:serviceaccount:rd-zeto-bank-a:party-admin` -> `no`; `kubectl -n rd-zeto-bank-a get netpol -o name | wc -l` -> `3`.
- Rollback: `kubectl delete ns rd-zeto-<x>` (empty at this point).
- Sources: https://kubernetes.io/docs/concepts/services-networking/network-policies/ (as in ARCHITECTURE 2a); CURRENT section 11 (current ns have no per-party RBAC).

### S2: Namespace on cluster 2 (first write there)
- DELTA: 11, 2 -> AFTER row: "ns-bank-c ... own operator, bank-gw, keys Secret C" (2a diagram)
- Owner: besu  Size: S
- Prerequisites: user supplies the real cluster-2 credential (the one supplied so far may resolve to cluster 1: [unverified], the RED proof checks it)
- Flags: CLUSTER-OP, user-only, spend (none yet)
- Does: create ONLY ns `rd-zeto-bank-c` and in it the same three NetworkPolicies and `party-admin` objects as S1. No read of any existing cluster-2 namespace, no cluster-scoped object here (CRDs wait for S9's own approval).
- RED proof: `kubectl get nodes -L topology.kubernetes.io/region` (node level) -> `ap-southeast-1` rows, before any write; then `kubectl get ns rd-zeto-bank-c` -> `Active`; `kubectl get ns` shows no other change (qa compares ns count before and after).
- Rollback: `kubectl delete ns rd-zeto-bank-c` (empty). Cluster 2: nothing else is ever deleted.
- Sources: ARCHITECTURE 2a "Capacity on cluster 2" (user rule: new namespaces only).

### S3: Besu node per party on cluster 1, joined to chain 1337
- DELTA: 3 -> AFTER row: "Besu QBFT validator (bank nodekey)" and 2a "Besu validator | 1, own nodekey"
- Owner: besu  Size: L
- Prerequisites: S1
- Flags: CLUSTER-OP, spend (LoadBalancer Services)
- Does: in each of rd-zeto-bi/-bank-a/-bank-b: Secret `besu-nodekey` (generated inside the ns, never leaves it); ConfigMap `besu-genesis` byte-identical to live `besu-genesis` (chainId 1337, qbft 2 s / 4 s); StatefulSet `besu-validator` image `hyperledger/besu:26.8.1`, PVC 40Gi, config.toml copied from live `besu-node-validator-1-besu-config` with `p2p-host` = this ns's p2p Service address and `static-nodes-file` listing the 4 old validators (enode host = the Service address; DNS in enode [unverified]). Starts as NON-validator. Service `besu-p2p` LoadBalancer TCP+UDP 30303 (mixed-protocol LB on this CNI/cloud: [unverified]). NetworkPolicy: 8545 only from this ns's gateway and Paladin pods, 30303 from the other validators. In ns `besu` add ONE ingress rule per `besu-node-validator-N-ingress` for 30303 from `rd-zeto-*`. Permissioning stays off (CURRENT section 1: no `permissions-*` keys). Reused by noto-pente (baseLedgerEndpoint) and stealth (chain door).
- RED proof: before `kubectl -n rd-zeto-bank-a get sts besu-validator` -> `NotFound`; after, via port-forward to the pod: `eth_chainId` -> `0x539`, `net_peerCount` >= `0x3`, `eth_blockNumber` within 2 blocks of `besu-node-validator-1`.
- Rollback: delete sts, pvc, Services in `rd-zeto-<x>`; remove the added rule in `besu`.
- Sources: Besu docs (context7 `/websites/besu-eth`) bootnodes, static-nodes-file, p2p-host options, as listed in ARCHITECTURE sources; CURRENT section 1.

### S4: Besu node for bank C on cluster 2
- DELTA: 11, 3 -> AFTER row: "Besu reader node ... enode reachable through an L4 LB for TCP 30303 and UDP discovery"
- Owner: besu  Size: M
- Prerequisites: S2, S3 (cluster-1 `besu-p2p` addresses reachable from cluster 2: network path [unverified], RED proof decides)
- Flags: CLUSTER-OP, spend
- Does: in `rd-zeto-bank-c` the same objects as S3 (nodekey generated there, same genesis ConfigMap, `static-nodes-file` = the S3 `besu-p2p` addresses); Service `besu-p2p` LoadBalancer TCP+UDP 30303; requests set on every container (cluster 2 memory is tight, ARCHITECTURE 2a). Ingress/egress IPs of the LB are what the cluster-1 NetworkPolicy ipBlock uses if permissioning is later switched on.
- RED proof: node C `net_peerCount` >= `0x3` with enodes of cluster 1, `eth_blockNumber` within 2 blocks of cluster 1, `eth_chainId` -> `0x539`; before: no pod in `rd-zeto-bank-c`.
- Rollback: delete sts, pvc, Services in `rd-zeto-bank-c`.
- Sources: ARCHITECTURE 2a (cross-cluster limits, latency 15-30 ms vs 2 s / 4 s: no tunable changes); Besu quickstart-with-privacy "Add non-validator node" as cited there.

### S5: Validator swap: vote in the 4 party nodes, vote out the 4 old ones
- DELTA: 3 -> AFTER row: "4 validators, one per party; any 1 down = 3 of 4"
- Owner: besu  Size: L
- Prerequisites: S3, S4 (new nodes synced); each party's operator casts its own vote
- Flags: CLUSTER-OP
- Does: one change at a time, never below 3 of 4 up: `qbft_proposeValidatorVote(<new>, true)` on a majority of the current validators, wait until the new address is in `qbft_getValidatorsByBlockNumber`, then `qbft_proposeValidatorVote(<old>, false)` the same way; repeat for BI, A, B, C. Old validator pods keep running as peers until S22 (they serve the old Paladin nodes until S21). Admin RPC is denied through the OPA door (CURRENT section 1), so calls go by port-forward to the pod.
- RED proof: before `qbft_getValidatorsByBlockNumber latest` = the 4 old addresses (`0xe89105d4…25d0`, `0x712f8366…69fd`, `0x95197d60…a715`, `0xd27cb197…38d9f3`); after: 4 addresses, none of them old, each address mined at least 1 of the last 20 blocks, block number rises 3 times in 10 s (blockperiod 2 s).
- Rollback: vote the old address back in with the same procedure while the old pod is still up (valid until S22).
- Sources: Besu docs `private-networks/how-to/configure/consensus/qbft` (Add and remove validators), `private-networks/concepts/poa` (liveness) via ARCHITECTURE section 4 sources.

### S6: Seeds and signing under party custody
- DELTA: 1 -> AFTER row: "Wallet, embedded ... `keyManager.disableSignRPC: true`"
- Owner: besu  Size: M
- Prerequisites: S1, S2
- Flags: CLUSTER-OP, user-only (the seed copy is a trust reset: a seed that sat in a shared Secret cannot be proven private)
- Does: each party's operator creates Secret `node<N>.keys` in its own ns from the live Secret of the same name (sealed channel chosen by that party; no value in chat, git, logs); the CR in S9 uses `secretBackedSigners` {name `signer-1`, type `autoHDWallet`} which reuses an existing Secret (`paladin_controller.go:1137-1139` upserts only if missing). `disableSignRPC: true` goes into the S9 config (Zeto flows never call `keymgr_sign`, CURRENT section 7). BI's Secret carries `registry.operator` and the factory and token owner keys (CURRENT section 11).
- RED proof: with the new node (S9 rehearsal) resolve `bi@node1` through the same call Lensa uses (`ptx_resolveVerifier`, zeto.ts) -> equals `owners.BI` of `state/zeto.json`; eth address -> `0xc77e80b8878c2509552b16336d5fc9bb0dc415a9`; `kubectl -n rd-zeto-bi get secret node1.keys` -> exists; `keymgr_sign` on the new node -> RPC error (disabled).
- Rollback: delete the new Secret (the old one stays until S22).
- Sources: paladin@v1.0.0:operator/internal/controller/paladin_controller.go:1118-1145; config/pkg/pldconf/keymanager.go:29; doc-site/docs/administration/configuration.md:344; ARCHITECTURE section 2 Settings.

### S7: Seed rotation (Zeto owner identities)
- DELTA: 1 (open question) -> AFTER row: "Keys stay with their owner"
- Owner: besu  Size: L
- Prerequisites: ADR 0004 decided
- Flags: BLOCKED(Zeto seed rotation), user-only
- Does: only if the user chooses rotation: new seeds per party, each holder moves its UTXOs to the new BabyJubJub key by ordinary Zeto transfers, BI re-assigns token owner and factory owner to the new BI keys, old Secrets destroyed. Not planned further until the ADR is decided.
- RED proof: `owners.{BI,A,B,C}` in `state/zeto.json` differ from today's, `owner()` of RD and DFABI -> new BI address, balances per party unchanged (qa, VERIFY.md).
- Rollback: none after the old Secrets are destroyed; before that, return to the old seeds.
- Sources: ARCHITECTURE section 3 DELTA 1; CURRENT sections 4-6.

### S8: Postgres per party
- DELTA: 6 -> AFTER row: "`database.mode: preConfigured` (external HA PostgreSQL, DSN with passwordSecret)"
- Owner: besu  Size: M
- Prerequisites: S1, S2; user chooses the Postgres product (managed or in-cluster operator: ARCHITECTURE did not open HA operators)
- Flags: CLUSTER-OP, spend, user-only (product choice)
- Does: one PostgreSQL per party in its ns (Service `paladin-pg`, Secret `paladin-pg-credentials`, storage >= 20Gi `alicloud-essd` as today's `paladin-nodeN-pgdata`; used size not read: [unverified]); NetworkPolicy lets only the Paladin pod reach it; backup schedule named by the product choice.
- RED proof: from the Paladin pod (S9) `psql "$DSN" -c 'select 1'` -> `1`; from another ns the same connection times out; a restore of last night's backup into a scratch DB succeeds (qa).
- Rollback: delete the instance (empty before S9).
- Sources: paladin@v1.0.0:operator/api/v1alpha1/paladin_types.go:170-185; doc-site/docs/concepts/cloud_native.md:5,21.

### S9: Paladin node per party (rehearsal copy, scaled to 0)
- DELTA: 1, 3, 6, 11 -> AFTER row: "Paladin node | 1 CR `paladin` + own operator"
- Owner: besu  Size: L
- Prerequisites: S5, S6, S8; on cluster 2 the CRD chart is a cluster-scoped write needing its own user approval
- Flags: CLUSTER-OP, user-only (cluster-2 CRDs)
- Does: Helm `paladin-operator` v1.0.0 per ns (`WATCH_NAMESPACE` = ns, `installCRDs=false`; CRD chart `paladin-operator-crd` installed once on cluster 2: that cluster has no Paladin CRDs [unverified]); CR `paladin node<N>` with the live fork digest `ghcr.io/radityaaa43/paladin@sha256:6f113f38…`, `baseLedgerEndpoint` = own Besu (S3/S4) http :8545 / ws :8546, `database.mode preConfigured`, `secretBackedSigners` per S6, `keyManager.disableSignRPC: true`, domain selectors `noto` and `pente` plus `config.domains.zeto` copied verbatim (registryAddress `0x753a64ea…cf91`, `allowSigning`, `defaultGasLimit 30000000`), PaladinDomain CRs and PaladinRegistry `evm-registry` on `0x99f3326e…7874`. NO `PaladinRegistration` here (S11). Rehearsal: freeze Lensa writes, pg_dump the old `paladin-node<N>-0` DB, restore into S8, start, prove, scale to 0.
- RED proof: with Lensa frozen: tx id list from the new node (`ptx_queryTransactionsFull`, limit 60, port-forward) equals the old node's saved list; `bi@node1` check of S6; before: no `paladin` CR in `rd-zeto-<x>`. Method names [unverified].
- Rollback: delete the CR and PVC copy in `rd-zeto-<x>`; the old node was never touched.
- Sources: paladin@v1.0.0:operator/charts/paladin-operator/values.yaml:204-206, operator/cmd/main.go:98,108,211-221; CURRENT sections 2-3 (live CR, domains); `besu@9890701:zeto/ops/backup-pld-node1-1792061433.yaml:6` (CR shape).

### S10: Cross-cluster Paladin transport endpoints
- DELTA: 4 -> AFTER row: "gRPC mTLS across clusters, directCertVerification"
- Owner: besu  Size: M
- Prerequisites: S9
- Flags: CLUSTER-OP, spend (LoadBalancer)
- Does: per party Service `paladin-transport` LoadBalancer 9000/TCP (port 9000, not 8549); transport config `externalHostname` = the LB address, `tls.clientAuth true`, `directCertVerification` default true (no shared CA); cert-manager Certificate `paladin-node<N>-mtls` (issuer `selfsigned-issuer`, kind [unverified]) with CN = node name and the LB address in SAN; NetworkPolicy 9000 only from the other parties' egress IPs (`ipBlock`, source IP may be LB or node IP).
- RED proof: from `rd-zeto-bank-a`, `nc -zv <rd-zeto-bank-c LB> 9000` -> `succeeded`, before: timeout; `openssl s_client` without client cert is refused by the handshake (clientAuth).
- Rollback: delete the Services and the Certificate; the CR keeps the in-cluster default hostname.
- Sources: paladin@v1.0.0:transports/grpc/internal/grpctransport/config.go:23-47, grpc_transport.go:105,337; doc-site/docs/administration/certificate_management.md:3-25; doc-site/docs/getting-started/installation-manual.md:433-461.

### S11: Registry ownership and endpoint republish
- DELTA: 5 -> AFTER row: "Child identity `owner` is chosen at registration"
- Owner: besu  Size: M (a) / L (b)
- Prerequisites: S10, ADR 0001 decided
- Flags: BLOCKED(registry rootless), user-only
- Does: the 4 node identities already exist, so `registerIdentity` reverts "Name already taken" and the operator `PaladinRegistration` (which registers first, then publishes) cannot be re-applied for them (`IdentityRegistry.sol:67-72`; `paladinregistration_controller.go:101-120`). Option (a) keeps the registry: each node owner republishes `transport.grpc` with `setIdentityProperty` using its own node key (`IdentityRegistry.sol:105-107`); how to trigger that without custom code: [unverified]. Option (b): a rootless registry, four new registrations in each party's own ns, new address in every `PaladinRegistry` CR.
- RED proof: `reg_queryEntriesWithProps` for node2 from node1 -> property `transport.grpc` names `dns:///<LB>:9000`; before: `dns:///paladin-node2.paladin.svc.cluster.local:9000`. Method name [unverified].
- Rollback: republish the old endpoint with the same mechanism (any time).
- Sources: paladin@v1.0.0:solidity/contracts/registry/IdentityRegistry.sol:45-47,67-72,105-108; operator/internal/controller/paladinregistration_controller.go:101-175,283-340; ARCHITECTURE section 2a cross-cluster limits.

### S12: Proving-key ceremony
- DELTA: 10 -> AFTER row: "proving keys from a ceremony" (SHARED box)
- Owner: besu  Size: L
- Prerequisites: ADR 0002 decided
- Flags: BLOCKED(proving-key ceremony), user-only
- Does: only if the user chooses a ceremony: generate keys, rebuild the zkp directory in the Paladin image (image rebuild is a conflict with "no new custom code": [unverified], goes to analyst), redeploy `zeto-v1-g16-*` verifiers and the RD and DFABI tokens. Otherwise the test keys stay as accepted PoC limit (CONTRACTS row).
- RED proof: verifier addresses in `state/zeto.json` differ and a transfer proves and verifies; before: test keys (`zeto-test-proving-keys.tar.gz`).
- Rollback: none after tokens are redeployed (balances not carried); before: keep the old addresses.
- Sources: zeto@v0.5.1:README.md:28; paladin fork `domains/zeto/build.gradle:64-67` (as in CURRENT section 3).

### S13: Atom.cancel mitigation
- DELTA: 9 -> AFTER row: "create, delegateLock, execute in one step"
- Owner: besu  Size: S (client step) / M (RestrictedAtom)
- Prerequisites: ADR 0003 decided; S18 raises the race window if bank-side
- Flags: BLOCKED(Atom.cancel mitigation), user-only
- Does: keep `swap` as one create + delegateLock + execute client step (`besu@9890701:zeto/src/flows.ts:118-131`) and add a test that no failure path leaves an Atom created and not executed; `RestrictedAtom` (`besu@9890701:noto+pente/contracts/src/RestrictedAtom.sol:219-224`) only if the user picks it.
- RED proof: node test (`besu@9890701:zeto/package.json:8` runner `node --test`) in besu/zeto: inject a failure after Atom create -> test asserts the swap fails closed and no `cancel()` call is made by the client; before: no such test.
- Rollback: `git revert` of the PR (client change only).
- Sources: paladin@v1.0.0:solidity/contracts/shared/Atom.sol:102-107; doc-site/docs/architecture/atomic_interop.md:105-110.

### S14: Decimals mismatch recorded and the comment corrected
- DELTA: none (correctness fix; analyst records the addendum) -> AFTER row preserved: "Zeto factory + verifier contracts" (units untouched)
- Owner: besu  Size: S
- Prerequisites: none
- Flags: none
- Does: `instrument.ts:146-147` says "Zeto has no decimals of its own"; the chain says `decimals()` = 4 (CURRENT section 3). Change the comment only (unit stays integer, `PRICE_PER_UNIT = 1_000_000n`, `domain.ts:14`); whether any record field or wallet shows the 4: [unverified]. No redesign.
- RED proof: `grep -n "no decimals" besu/zeto/src/instrument.ts` before 1 hit, after 0; `eth_call decimals()` on RD and DFABI -> `0x0000000000000000000000000000000000000000000000000000000000000004`.
- Rollback: `git revert`.
- Sources: zeto@v0.5.1:solidity/contracts/lib/zeto_common.sol:93-94; `besu@9890701:zeto/src/instrument.ts:146-149`.

### S15: Report groups: record live config, no new groups
- DELTA: 8 -> AFTER row: "`{bank, bi@node1}` per bank; BI in every group"
- Owner: besu  Size: S
- Prerequisites: S9
- Flags: none
- Does: new groups already use `externalCallsEnabled: false` (`flows.ts:100`); the three live groups were created with `true` and it is fixed at deploy (CURRENT section 6). Read the live config of groups A, B, C and the BI reachability behaviour, write both into `besu@9890701:zeto/docs/r1-limitation.md`; no replacement groups unless the user asks (BI history would move).
- RED proof: `pgroup_getGroupById` for each group id of `state/zeto.json` -> `externalCallsEnabled` value quoted in the doc; doc has an SLO line "BI down = reports lost" with the 2026-11-10 test date.
- Rollback: `git revert` the docs commit.
- Sources: paladin@v1.0.0:domains/pente/src/main/java/io/kaleido/paladin/pente/domain/PenteDomain.java:100-108,697; core/go/internal/groupmgr/manager.go:155-172.

### S16: Gateway per party with its own mTLS CA
- DELTA: 2 -> AFTER row: "own gateway: envoy + opa; only path to RPC 8548"
- Owner: besu  Size: M
- Prerequisites: S1, S2, S9
- Flags: CLUSTER-OP
- Does: Deployment and Service `bank-gw-<N>` (N: 1 BI, 2 A, 3 B, 4 C, keeps the names `kube.ts:22` and `platforms.ts:25` accept) in each `rd-zeto-<party>` from `besu@9890701:opa/k8s/bank-gw-1.yaml` (namespace lines :8,:65 become the ns), envoy 8548 (Paladin) + 8545 (Besu) with Secret `bank-gw-N-mtls` from a CA that party holds (`opa/mtls/gen-certs.sh` issues all from one CA today); only the Lensa client cert of THAT party is trusted. NetworkPolicy: RPC 8548 only from the gateway pods. No Ingress object is created in new namespaces (the user decision of 2026-11-06 keeps the old ingress until S22: user confirms).
- RED proof: with party B's client cert `curl --cert ... https://127.0.0.1:<fwd to bank-gw-2> -d '{"method":"transport_nodeName"}'` -> TLS handshake failure; with party A's cert -> `"node2"` (this read call must be allowed by the bank bundle: [unverified]); before: one shared Lensa cert opens all four.
- Rollback: delete the Deployment, Service, Secret in `rd-zeto-<x>`.
- Sources: `besu@9890701:opa/k8s/bank-gw-1.yaml:8,65`, `opa/mtls/gen-certs.sh:1-7`; CURRENT section 7 (OPA gateways); LENSA.md section 1.1.

### S17: OPA bundles per party, sink hardening, RPC credentials
- DELTA: 2 -> AFTER row: "Own RPC credentials | `rpcAuthorizers` + `rpcServer.authorizers`, one credential set per bank"
- Owner: besu  Size: M
- Prerequisites: S16
- Flags: CLUSTER-OP
- Does: Deployment `bundle-server` in each ns (`opa/k8s/bundle-server.yaml:9,64`) with the rd-besu #9 hardening (sink token, NetworkPolicy; merged, not rolled out: CURRENT section 8); each owner signs its own bundle with a key in its own custody (`opa/README.md:329`); BI bundle served from `rd-zeto-bi`, pulled by every gateway (cluster 2 over a BI Service: path [unverified]); rego unchanged (same revisions as CURRENT section 8). Paladin `rpcAuthorizers` + `rpcServer.authorizers` credential per bank replace `paladin-basic-auth`.
- RED proof: `kubectl -n rd-zeto-bank-a get secret paladin-basic-auth` -> `NotFound`; a sink POST without token -> `401` [code unverified]; bundle status shows `bank-a-zeto.<rev>` active on `bank-gw-2` with the same rego revision as today.
- Rollback: delete the Deployment, ConfigMaps; gateways in S16 fall back to deny (enforcing, `failure_mode_allow: false`).
- Sources: `besu@9890701:opa/README.md:130,218,325-329`; paladin@v1.0.0:doc-site/docs/administration/auth.md:88-134.

### S18: Bank-side client and cross-bank DvP flow
- DELTA: 7 -> AFTER row: "own Lensa / client, only this bank's node"
- Owner: besu  Size: L
- Prerequisites: ADR 0005 decided
- Flags: BLOCKED(bank-side DvP flow), user-only
- Does: today one process drives both legs (`flows.ts:118-131`, `zeto.ts:34,280`). Planned only after the decision: per-bank client talking to its own node, lockId, calldata and Atom address exchanged between banks.
- RED proof: a swap where seller and buyer run as two processes each holding only its own node URL completes; before: `createZetoAdapter` builds `party()` for all four nodes (`zeto.ts:280-281`).
- Rollback: keep the single coordinator (current behaviour).
- Sources: paladin@v1.0.0:doc-site/docs/architecture/atomic_interop.md:46-117; ARCHITECTURE section 3 DELTA 7.

### S19: Lensa forwards and gateway client per party (fe)
- DELTA: 2, 1 -> AFTER row: "one client per bank: URL + token; Lensa holds no key"
- Owner: fe  Size: M
- Prerequisites: S16, S17
- Flags: none (host unit change is part of S21's cutover window)
- Does: `frontend@28c8bdb:deploy/forwards.conf:3-6,8,10-12` lines become `paladin-node1 rd-zeto-bi bank-gw-1 31548:8548` ... `besu-bank-c rd-zeto-bank-c bank-gw-4 38548:8545`; `deploy/pf.sh:14` gets a kubeconfig column (cluster 2 needs its own); `server/src/gateway.ts:8-17` `gwAgent` returns one client cert per party instead of one for all (LENSA.md section 1.1); unit names unchanged so `lensa.service` Wants stay valid. `LENSA_GW_MTLS_DIR` holds per-party subfolders. dfabi bank backends are NOT repointed here (S22 prerequisite).
- RED proof: server test `gwAgent('A')` uses A's cert only (fails before); `grep -nE "^(paladin|besu)\S*\s+(paladin|besu)\s" frontend/deploy/forwards.conf` -> 0 lines after.
- Rollback: `git revert` and restore the previous `forwards.conf`; units restart.
- Sources: LENSA.md sections 1.1, 4.2, 6 (rows `paladin`, `besu`); `frontend@28c8bdb:server/src/gateway.ts:21-24`.

### S20: Lensa Publisher and Besu network view namespaces (fe)
- DELTA: 2 -> AFTER row: "bundle served from this org's own bundle source"
- Owner: fe  Size: S
- Prerequisites: S19
- Flags: none
- Does: `server/src/policy/kube.ts:3` `NS='paladin'` becomes a per-gateway namespace (`bank-gw-N` -> `rd-zeto-<party>`; `kube.ts:22,65` guards and the `bundle-server:sink` read follow); `server/src/adapters/besu-network.ts:20` namespace `besu` -> the four `rd-zeto-<party>` pods `besu-validator-0`. Each uses that party's namespace-scoped credential (S1), not one admin kubeconfig.
- RED proof: `grep -n "NS = 'paladin'\|namespace: 'besu'" frontend/server/src` -> 0 hits after (2 before); existing in-memory `Kube` tests pass.
- Rollback: `git revert`.
- Sources: LENSA.md section 6 (rows `paladin`, `besu`, decommission check lines 116-121).

### S21: Cutover party by party and qa proof
- DELTA: 1, 3, 6 -> AFTER row: "Each bank runs its Paladin node in its own namespace"
- Owner: qa (steps by besu, fe)  Size: L
- Prerequisites: S5, S9, S11, S17, S20
- Flags: CLUSTER-OP, user-only (maintenance window)
- Does: order bank-a, bank-b, bank-c, bi (BI last, it receives the reports). Per party: freeze Lensa writes; scale old `paladin-node<N>` StatefulSet to 0 (not deleted); fresh pg_dump and restore into S8; scale new node up; endpoint published (S11); flip that party's forward (S19, S20); unfreeze. After all four: qa runs `zeto/VERIFY.md` for issue, transfer, DvP RD vs DFABI, outsider C sealed, and the BI-balance proof (BI ledger verified outputs vs chain commitments, same `tx 0x664c1faf2f09…` view per party as CURRENT section 9); transactions made after the last restart (TEAM.md section 10 rule 3).
- RED proof: per party: `GET /api/history?model=zeto&party=<P>` shows the old tx ids and a NEW tx made after cutover; R1 views = BI `reported`, A `clear`, B `clear`, C `sealed`.
- Rollback: before the first new tx: scale old node up, republish old endpoint, flip forward back; after it: new data exists only in the new DB, so roll forward.
- Sources: CURRENT sections 9, 11; LENSA.md section 4.1 (release flow); ecc:deployment-patterns.

### S22: Decommission `besu`, `paladin`, `dfabi`
- DELTA: 2, 3 -> AFTER row: "Bank-owned namespace ... kubeconfig and credentials" (old shared ns removed)
- Owner: lead  Size: M
- Prerequisites: shared with noto-pente and stealth plans; executes once, after all three cutovers. Cutover proven (qa PASS on the new namespaces for every flow + BI-balance proof). Nothing points at the old ns: LENSA.md "Namespace references" rows `paladin`, `besu`, `dfabi` all clean (forwards.conf 0 lines, `lensa-pf@*` none, `kube.ts` and `besu-network.ts` updated, OPA bundle server and CI: ci.yml names no ns); dfabi bank backends repointed or dfabi retired (user decides). Surviving data copied BEFORE any delete: Postgres dump per node of `paladin-node1..4-pgdata` (PV reclaim = Delete, 4 x 20Gi) as backup `zeto-decom-pgdump-<date>`; Besu `data-besu-node-validator-1..4-0` 4 x 40Gi (Retain, kept as is, not a backup); Secrets `node1..4.keys`, `paladin-nodeN-mtls`, `besu-node-validator-N-keys`, CM `besu-genesis`; Lensa state files; `~/.opa-keys`, `~/.opa-mtls`; `dfabi` PVs `data-postgres-0`, `runner-state` (Delete, 2 x 5Gi).
- Flags: user-only, CLUSTER-OP (own approval at that time), destructive
- Does: inventory = CURRENT.md section 11 "Decommission inventory": `besu` 4 STS, 4 PVC 40Gi; `paladin` 6 Deployments incl. `bank-gw-1..4`, 4 STS, 4 PVC 20Gi, 43 `smartcontractdeployment`, 3 `paladindomain`, 4 `paladinregistration`, 1 `paladinregistry`; `dfabi` 9 Deployments, 2 PVC. PVC total this plan touches: 160 Gi Besu + 80 Gi Paladin (+10 Gi dfabi). First re-set the 4 `paladin` PVs to Retain (`kubectl patch pv ... persistentVolumeReclaimPolicy=Retain`) or copy, verify the dump restores, then delete workloads, then namespaces. Cluster-scoped CRDs stay. Cluster 2: nothing is ever deleted.
- RED proof: `kubectl get ns besu paladin` -> `NotFound`; qa re-runs S21 read-only checks on the new namespaces (PASS); the dump restores into a scratch DB (row counts equal) before the delete.
- Rollback: none after delete; restore `zeto-decom-pgdump-<date>` into S8 and the retained Besu PVs / seeds from the named secret backup.
- Sources: CURRENT.md section 11; LENSA.md section 6.

## DEVIATION REQUEST (draft for lead)
None for the AFTER rows. One open conflict goes to `analyst` with S12: replacing the proving keys in the Paladin image is a rebuild of the fork image, which the user's "no new custom code" rule may exclude; the AFTER row "proving keys from a ceremony" is unchanged, the route is undecided.
