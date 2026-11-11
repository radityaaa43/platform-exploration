# noto-pente: plan CURRENT -> AFTER
Skills used (loaded by `lead`; the drafter applied them as checklists): superpowers:writing-plans, ecc:architecture-decision-records, ecc:kubernetes-patterns, superpowers:verification-before-completion (RED proofs), path:line map built by hand (ecc:code-explorer is an agent type, not a skill), ecc:deployment-patterns (Lensa cutover/rollback), web3-testing (RED proofs of contract/flow steps), ecc:evm-token-decimals + solidity-auditor (CONTRACTS.md inventory only). Not run: the 12-agent solidity audit (inventory only).
Target: agents/analyst/design/ARCHITECTURE-noto-pente.md (AFTER) + objectives (decentralization per bank: validator, self-submit, third-party; R1, R2, R3). Start: final-design/noto-pente/CURRENT.md @ 2026-11-11 (no time in the file).
Namespaces: rd-noto-bi, rd-noto-bank-a, rd-noto-bank-b (cluster 1), rd-noto-bank-c (cluster 2, new only; every existing cluster-2 namespace is foreign).
Pins: `besu@9890701` (CURRENT pin; analyst lines were taken at 927f572, the lines cited here were re-read at 9890701), `frontend@28c8bdb` (local HEAD; analyst pin aa6e09b), `paladin@v1.0.0` (6d4b913) as in ARCHITECTURE.
Shared with zeto and stealth (CURRENT.md section 11): validators (ns `besu`), Paladin nodes + gateways (ns `paladin`), `dfabi`. Those steps are owned by the zeto plan and NOT repeated here. They appear below as external ids: **zeto S1+S2** = zeto PLAN.md step (namespace/validator/Paladin node; id filled by lead) for per-bank namespaces + NetworkPolicies; **zeto S3-S5** = same, validators and vote; **zeto S8+S9** = same, Paladin node CR, Postgres, seed Secret copy, signer config; **zeto S10** = zeto PLAN.md step (transport; id filled by lead), certs, `externalHostname`, PaladinRegistration; **zeto S16+S17** = zeto PLAN.md step (gateway; id filled by lead) [assumption: zeto owns gateways because the gateway serves every domain]; **zeto S19+S20** = zeto PLAN.md step (Lensa forwards.conf + kubeconfig per org; id filled by lead).
Assumption A1: Noto/Pente run inside the same Paladin node as Zeto and Stealth (CURRENT section 2), and the operator watches only its own namespace (`paladin@v1.0.0:operator/cmd/main.go:98,108,211-221`). So the Noto CRs of a party (S6) live in the namespace where zeto S1+S2 puts that party's node; if that prefix is not `rd-noto-*`, lead substitutes it. Notary = BI is fixed by upstream (option A in ARCHITECTURE section 2, `paladin@v1.0.0:doc-site/docs/architecture/noto.md:50,569,580`; notary is fixed at deploy, `solidity/contracts/domains/noto/Noto.sol:56,126-134`), so no token is redeployed and no notary moves (options B-D are not planned: ARCHITECTURE says "not recommended", and they need a new token).
Assumption A2: the chain stays the same (validators join by vote, DELTA 2) and each node's Postgres is carried over by zeto S8+S9, so all Noto/Pente addresses in CURRENT section 4 survive. If zeto S3-S5/zeto S8+S9 choose a new chain, S1..S7 become a redeploy and lead must re-plan; this plan does not cover it.
Preserve (every step): privacy groups keep 100% endorsement (`paladin@v1.0.0:domains/pente/src/main/java/io/kaleido/paladin/pente/domain/PenteDomain.java:101-103`); no custom Paladin code (running fork digest unchanged); amounts are integer units, `PRICE_PER_UNIT = 1_000_000n` (`frontend@28c8bdb:server/src/domain.ts:14`).

## Order and dependencies
1. S1 (none, read-only, before any Z-* step)  2. zeto S1+S2  3. zeto S3-S5  4. zeto S8+S9 after S1  5. S2 after S1,zeto S8+S9  6. S3 after zeto S8+S9  7. S4 (BLOCKED upstream)  8. S5 (BLOCKED user)
9. zeto S10 (blocked in zeto plan by the same ADR)  10. S6 after zeto S8+S9  11. S7 after S2,S6,zeto S10  12. S8 after S1 (code only, any time before S13)  13. S9 after S7
14. S10 after zeto S16+S17  15. S11 (code only, any time before S12)  16. S12 after S10,S11,zeto S19+S20  17. S13 after S7,S8,S12  18. S14 after S8,S13 (BLOCKED user)  19. S15 LAST after S13 and the zeto and stealth cutovers

DELTA coverage: 1 -> S2,S3,S4,S11 (+zeto S8+S9); 2 -> zeto S3-S5; 3 -> S6 (+zeto S8+S9); 4 -> S5 (+zeto S10); 5 -> S1,S2,S6; 6 -> S7,S9; 7 -> S8,S14; 8 -> S10,S11,S12 (+zeto S16+S17); 9 -> zeto S1+S2 (kubeconfig per org); 10 -> S5; 11 -> zeto S1+S2,zeto S3-S5,zeto S10 (cluster 2).

## Steps
### S1: Noto/Pente continuity baseline (read-only)
- DELTA: 5 -> AFTER row: "Move BI's notary identities ... no token change"
- Owner: qa  Size: S
- Prerequisites: none (must finish before zeto S8+S9 touches `paladin-node1..4`)
- Flags: none
- Does: record into the qa report the CURRENT section 3-5 values as machine-checkable lines: for `cashIssuer@node1`, `bondIssuer@node1`, `bondCustodian@node1`, `investor1..3@node2..4` the verifier address; `owner()` and impl slot of the 12 addresses in CURRENT section 4 (`0x8da5cb5b`, slot `0x3608...2bbc`); group ids and members of cash group `0xece3d19e...f522f`, issuer-custodian group `0x2a195eda...a8bf`; BI custodian cash and bond balance and each bank balance (data file `custodianFinalBalances` was 3000/997000 on 2026-10-19, so re-read now); `PaladinDomain` `noto` + `pente` `registryAddress`; SCD count 43. Start from `besu@9890701:noto+pente/bond/src/verify-deployed.ts` (what it asserts: [unverified]).
- RED proof: file `noto-baseline-<date>.txt` in the qa report does not exist before; after: contains the 12 owner/impl rows, 6 identity rows, 3 group rows; `grep -c 'owner=' noto-baseline-*.txt` -> `12`.
- Rollback: none needed (read-only).
- Sources: CURRENT.md sections 3-5, 9; `besu@9890701:noto+pente/bond/src/verify-deployed.ts:1-30`.

### S2: Notary and bank identities keep their addresses on the moved nodes
- DELTA: 5, 1 -> AFTER row: "notary identities: cashIssuer, bondCustodian, assetIssuer" in BI's own node
- Owner: besu  Size: S
- Prerequisites: S1, zeto S8+S9 (node CRs and seed Secret copies `node1..4.keys` into each party's namespace, embedded `static` keystore; names only)
- Flags: CLUSTER-OP (read only through the door, but the node move itself is zeto S8+S9's CLUSTER-OP)
- Does: after zeto S8+S9, resolve every identity of S1 on its new node (`PaladinClient.getVerifiers(lookup)`, as in `besu@9890701:noto+pente/bond/src/lib/platform.ts:55-69`) and compare with S1. `assetIssuer@node1` (swap-noto notary, `besu@927f572:noto+pente/swap-noto/src/index.ts:95-96`) is not in CURRENT: [unverified], S1 re-reads it from the swap-noto data file if present. Notary stays `*@node1` in the BI namespace (upstream requirement).
- RED proof: before (old ns) and after each lookup returns the same address: `diff <(S1 identity rows) <(post-move identity rows)` -> empty. A changed address = STOP, tokens bound to the old address (UTXOs and group members, ARCHITECTURE DELTA 1).
- Rollback: zeto S8+S9 rollback (restore old namespace nodes, which stay until S15).
- Sources: `paladin@v1.0.0:doc-site/docs/architecture/key_management.md:76-140` [not opened by analyst; derived vs direct mapping unverified]; `besu@9890701:noto+pente/bond/src/index.ts:134,205` (notary identities).

### S3: Prove Noto and Pente flows with `keyManager.disableSignRPC: true`
- DELTA: 1 -> AFTER row: "`keyManager.disableSignRPC = true` after Lensa stops signing for banks"
- Owner: besu  Size: S
- Prerequisites: zeto S8+S9 (sets the flag in each node CR; not duplicated here), S2
- Flags: none
- Does: run one Noto transfer, one Pente private call in a bank group and one `executeOutright` against nodes that have the flag set. Analyst: "effect on domains that call keymgr sign: not tested".
- RED proof: old nodes (flag false, CURRENT section 2 Signer config) answer the sign RPC; new nodes reject it and `npm test` in `noto+pente/bond` plus `npm run test:live-atom` still end PASS. Expected: sign RPC error text [unverified], flows `SETTLED`.
- Rollback: set the flag back in the node CR (zeto S8+S9 rollback).
- Sources: `paladin@v1.0.0:doc-site/docs/administration/configuration.md:344`; `besu@9890701:noto+pente/bond/package.json:12,14`.

### S4: Per-bank signing module (remote / HSM): not planned, inside the AFTER as an option
- DELTA: 1 -> AFTER row "Key custody: `keyManager.disableSignRPC: true`; `signingModules` (plugin) or `secretBackedSigners`; one signer per node via `secretBackedSigners`" (ARCHITECTURE-noto-pente.md:197)
- Owner: lead  Size: S (decision record only)
- Prerequisites: S3
- Flags: none
- Does: nothing is built. The AFTER names two custody shapes; S3 delivers the `secretBackedSigners` shape (embedded signer, `disableSignRPC: true`, the bank's own seed Secret in `rd-noto-<party>`), which already satisfies DELTA 1 (keys stay with their owner). A remote/HSM signing module is Paladin plugin code (`paladin@v1.0.0:doc-site/docs/architecture/key_management.md:41-70`, section "4. Signing Modules" :224); upstream ships the interface, no ready-made module [unverified]; under "no custom Paladin code" it stays an option for later, not a plan step. Same reading for the zeto plan.
- RED proof: `grep -c 'secretBackedSigners' final-design/noto-pente/CONTRACTS.md` >= 1 after S3's row is filled; no live check.
- Rollback: none.
- Sources: ARCHITECTURE-noto-pente.md:121,197; `paladin@v1.0.0:doc-site/docs/administration/configuration.md:344` as cited there.

### S5: Registry root owner: rootless or BI-signed
- DELTA: 10, 4 -> AFTER row: "Registry root owner: `rootless` registry lets any sender register a root child"
- Owner: besu  Size: M
- Prerequisites: user decision (ADR 0001, shared with the zeto plan, same number and slug)
- Flags: BLOCKED(registry rootless), user-only, CLUSTER-OP
- Does: CURRENT already read the owner: root identity owner `0xf404...A11b` = `registry.operator` on node1, so DELTA 10's "eth_call owner()" is done and CURRENT wins over the analyst's "not read". Per the chosen option: (A) deploy a rootless `IdentityRegistry`, point each node's `PaladinRegistry` CR at it, re-register 4 nodes; or (B) keep `evm-registry` `0x99f3326e...7874` and let BI's key sign each bank registration (zeto S10). Factories `0x1419f612...daf3` / `0x19980494...3254` have their own owners (`<name>_factory_proxy.operator` on node1) and do not depend on this choice.
- RED proof: after: a registration of `node2` signed by bank A's own key succeeds without BI's key (A; call name [unverified]), or the registration CR in the bank namespace reaches `Available` with BI's key supplied through the agreed path (B). Before: bank-side CR cannot sign (`paladinregistration_controller.go:107,137,238,256`).
- Rollback: re-point the `PaladinRegistry` CR to `0x99f3326e...7874` (A); none (B).
- Sources: `paladin@v1.0.0:solidity/contracts/registry/IdentityRegistry.sol:45-47,67-72`; adr/0001-registry-rootless.md.

### S6: PaladinDomain `noto` and `pente` on each per-bank node
- DELTA: 3, 5 -> AFTER row: "node CR per namespace ... own operator per namespace"
- Owner: besu  Size: M
- Prerequisites: zeto S8+S9
- Flags: CLUSTER-OP
- Does: per party namespace create `PaladinDomain` `noto` (plugin `/app/domains/libnoto.so`, `registryAddress 0x1419f612c603466f254ca71e78a324c0d922daf3`, configJSON `factoryVersion`) and `pente` (jar `io.kaleido.paladin.pente.domain.PenteDomainFactory`, `registryAddress 0x199804944e574c6f726f5aa13b343c6cd2c73254`, configJSON empty), labelled `paladin.io/domain-name: noto|pente`, and list both in the node CR `spec.domains` selector. No new factory deploy, no SCD for the factories (existing proxies). Whether a `PaladinDomain` with a pre-set `registryAddress` skips the deploy: [unverified, CURRENT shows the field only].
- RED proof: `kubectl -n rd-noto-bank-a get paladindomain -o custom-columns=N:.metadata.name,A:.spec.registryAddress` before: `No resources found`; after: `noto 0x1419f612...` and `pente 0x19980494...`; node CR `spec.domains` contains both; `kubectl -n rd-noto-bank-a get scd --no-headers | wc -l` unchanged (no factory redeploy).
- Rollback: `kubectl -n <ns> delete paladindomain noto pente`; node CR `domains` back to previous.
- Sources: CURRENT.md sections 2-3; `paladin@v1.0.0:operator/api/v1alpha1/paladin_types.go:51-52` (as cited by ARCHITECTURE 2a).

### S7: Pente groups resume across nodes; tracker ownership unchanged
- DELTA: 6, 5 -> AFTER row: "Pente group per bank pair {bank, BI} per token; BI stays in each group"
- Owner: qa  Size: M
- Prerequisites: S2, S6, zeto S10 (and S5 decided, since cross-cluster delivery needs the registry)
- Flags: none
- Does: on the new nodes, `PenteFactory.resumePrivacyGroup({id})` for the cash group (members {cashIssuer}), the issuer-custodian group `0x2a195eda...` ({bondIssuer, bondCustodian}) and the 3 per-investor groups ({investor, bondCustodian}; their addresses were not read: [unverified], read in S1). One private call per group completes with 100% endorsement, incl. bank C on cluster 2 with BI on cluster 1. Ownership: `bondTrackerPublic` `0xb6adb924...` `owner()` = `0x2a195eda...` (owned by the issuer-custodian group contract), `cashTracker` `0xc6bb619f...` has 0 bytes of public code (private inside the cash group).
- RED proof: before zeto S10 a call in the group {investor3@node4, bondCustodian@node1} cannot reach node 4's new endpoint (timeout, error text [unverified]); after: `resumePrivacyGroup` returns the S1 address, `eth_call owner()` on `0xb6adb924...` -> `0x2a195eda9c56444a1247c4e827d94ffe73e9a8bf`, `eth_getCode 0xc6bb619f...` -> `0x`.
- Rollback: none needed (no state change beyond a test call; point Lensa back, S12).
- Sources: `besu@9890701:noto+pente/bond/src/index.ts:114-117,158-160,258-260`; `besu@9890701:noto+pente/bond/src/lib/platform.ts:61-65`; PenteDomain.java:101-103.

### S8: RestrictedAtom executor per trade
- DELTA: 7 -> AFTER row: "pass the selling bank as `executor` for secondary trades"
- Owner: besu  Size: S
- Prerequisites: S1 (no cluster needed for the code part)
- Flags: none
- Does: `executeOutright` (`besu@9890701:noto+pente/bond/src/lib/outright.ts:125`) takes an optional `executor` identity; today the executor is hard-wired to the custodian: `atomFactory.create(..., await bondCustodian.address())` (:247-254), `atom.execute(bondCustodian)` (:270), rollback atom (:360-364). Default stays the custodian (BI) for primary sales. Contract unchanged (`RestrictedAtomFactory.create` already takes `executor`, `contracts/src/RestrictedAtomFactory.sol:33-40`; execute is executor-only, cancel is executor or party: `RestrictedAtom.sol:150-155,219-224`). Execute still needs locks prepared and delegated through the notary, so R2 stays exempt (`paladin@v1.0.0:doc-site/docs/architecture/noto.md:597`).
- RED proof: new case in `noto+pente/bond/src/tests/restricted-atom.ts` ("executeOutright with executor=seller: atom.executor == seller, execute by BI reverts NotExecutor") fails before (no parameter); after `npm test` in `noto+pente/bond` passes. Forge: `forge test --match-contract RestrictedAtom` stays green (contract untouched).
- Rollback: `git revert` of the rd-besu PR.
- Sources: files above; `paladin@v1.0.0:solidity/contracts/shared/Atom.sol:60-70`.

### S9: Record the blast radius of Pente groups
- DELTA: 6 -> AFTER row: "a bank outage stops only its own group; BI outage stops all"
- Owner: besu  Size: S
- Prerequisites: S7
- Flags: none
- Does: add one section to `besu@9890701:noto+pente/docs/architecture-brief.md` (next to section 8.4): per group the member nodes, and the rule "100% endorsement, so an offline member stops that group's transactions; BI is a member of every group, so BI offline stops every group". No test with a node down (that is S14).
- RED proof: `grep -c 'Blast radius' noto+pente/docs/architecture-brief.md` before `0`, after `1`; the section lists 5 groups (cash, issuer-custodian, 3 investor) with their members.
- Rollback: `git revert`.
- Sources: PenteDomain.java:101-103; ARCHITECTURE-noto-pente.md DELTA 6.

### S10: Noto policy packages in each org's own bundle
- DELTA: 8 -> AFTER row: "bundle served from this org's own bundle source"
- Owner: besu  Size: M
- Prerequisites: zeto S16+S17
- Flags: CLUSTER-OP (Publisher writes `bank-gw-N-bundles` ConfigMaps)
- Does: bi bundle keeps `bi.noto`, `bi.noto.balance`, `bi.notosetup`, `bi.atom` (CURRENT OPA table); bank bundles carry no Noto package, so bank gateways keep denying Noto-only paths. Per-org gateway only receives its own org's signed bundle (signing keys per owner already exist; where they live after the move is a zeto/lead item, CURRENT section "Signing keys"). Revision shape to reach: `bi-zeto.N-noto.N-...` loaded on all four new gateways.
- RED proof: `opa check --strict bundles/bi bundles/bank test` and `opa test --coverage bundles/bi bundles/bank test` (`besu@9890701:opa/README.md:114-115`) pass; read-only `bundle-server:sink/proxy/status` shows `noto.<n>` in the `bi` revision for each new gateway (before: new gateways absent).
- Rollback: Publisher re-applies the previous bundle revision (ConfigMap kept).
- Sources: CURRENT.md section "OPA gateways"; `besu@9890701:opa/README.md:114-115`.

### S11: Per-bank client credentials in the Noto SDK config
- DELTA: 1, 8 -> AFTER row: "Lensa gets one client per bank holding only that bank's URL and token"
- Owner: besu  Size: M
- Prerequisites: none (code only)
- Flags: none
- Does: `nodeConnections` in `besu@9890701:noto+pente/common/src/config.ts:62-70` builds all four clients with one shared mTLS dir (`LENSA_GW_MTLS_DIR`) and an optional `bearer` (:23,53-56). Change: per-node credential source (mTLS dir or bearer per node), defaulting to today's behaviour. `platform.ts:55` keeps one client per node (`executeOutright` needs seller and buyer in one call, LENSA.md section 2); credentials differ per node, keys stay in the nodes.
- RED proof: new unit test: node 2 config with a different credential dir produces `clientOptions` whose TLS material differs from node 1; fails before (one dir for all).
- Rollback: `git revert`.
- Sources: files above; final-design/LENSA.md sections 1.1-1.2.

### S12: Lensa Noto pointers
- DELTA: 8 -> AFTER row: "Lensa reaches nodes by per-bank URL, not port-forward with one kubeconfig"
- Owner: fe  Size: M
- Prerequisites: S10, S11, zeto S19+S20 (forwards per org; the 4 Paladin forwards are shared with Zeto, not duplicated)
- Flags: CLUSTER-OP (host service restart; own approval)
- Does: no code in `frontend@28c8bdb:server/src/adapters/noto.ts` changes if S11 is consumed through env; set per-bank credential env/paths in `~/.config/lensa/lensa.env` (values not copied here), keep `server/state/noto.json` `dataDir` and `state/noto/contract-data-*.json` (addresses unchanged by A2) and `trades.jsonl`. Lensa still holds no Noto keys (`state/noto.json` = `{dataDir}`). Namespace references to clear: LENSA.md section 6 row `paladin` (units `paladin-node1..4`, `besu*`, Publisher `kube.ts:3` `NS='paladin'`) is the zeto S19+S20 owner; this step only checks the Noto side.
- RED proof: `grep -n 'paladin-node' frontend/deploy/forwards.conf` before shows ns `paladin`, after `rd-*`; qa reads, with no direct node call, `GET /api/history?model=noto&party=P&limit=60` for BI, A, B, C and gets verdicts `notarised, clear, clear, sealed` with amount `1000`, `1000`, `1000`, `null` (CURRENT section 9).
- Rollback: restore the previous `lensa.env` and forwards.conf (kept as backup), restart `lensa.service`.
- Sources: LENSA.md sections 1.1, 2, 6; CURRENT.md sections 7, 9.

### S13: qa cutover proof for Noto + Pente
- DELTA: 5, 6, 7 -> AFTER row: "Pente group per bank pair {bank, BI} per token"; "BI keeps R1"
- Owner: qa  Size: M
- Prerequisites: S7, S8, S12
- Flags: none
- Does: through Lensa on the new namespaces: (1) cash transfer A to B; (2) bond transfer; (3) one `executeOutright` DvP, bank C on cluster 2 as seller once; (4) per-party R1 view of each tx; (5) BI balance proof: BI custodian cash and bond equal the S1 baseline adjusted by the test amounts. Notary is BI for all (R2 exempt, CURRENT section 3).
- RED proof: before, flows run against old namespaces only; after, each `trades.jsonl` line `status` = `SETTLED` and `GET /api/history?model=noto&party=C` shows `sealed`, amount `null`; BI sees `notarised` with amount; `BI balance == S1 baseline +/- test amounts` printed.
- Rollback: S12 rollback (point Lensa to the old namespaces, which stay until S15).
- Sources: CURRENT.md sections 7, 9; `besu@9890701:noto+pente/bond/src/lib/outright.ts:125`.

### S14: Atom.cancel with BI's node down
- DELTA: 7 -> AFTER row: "Live test of `cancel()` with node1 down is open"
- Owner: besu  Size: M
- Prerequisites: S8, S13, user decision (ADR 0002)
- Flags: BLOCKED(Atom.cancel BI-down test), user-only, CLUSTER-OP
- Does: per the chosen option: create a throwaway RestrictedAtom with two delegated legs, take BI's Paladin node out of service for a bounded window, call `cancel()` as a party; measure whether legs are released. BI's node is also the notary, so Noto flows stop during the window (R2 exempt).
- RED proof: `atom.status` before test `Pending`; after `Cancelled` and both legs unlocked, or the exact revert recorded. Before this step the outcome is "not tested" (ARCHITECTURE section 1).
- Rollback: scale BI node back; recover the throwaway atom with `cancel` after BI returns.
- Sources: `besu@9890701:noto+pente/contracts/src/RestrictedAtom.sol:219-224`; `paladin@v1.0.0:doc-site/docs/architecture/noto.md:597`; adr/0002-atom-cancel-bi-down-test.md.

### S15: Decommission `besu`, `paladin`, `dfabi` (old namespaces)
- DELTA: none (cleanup after AFTER is reached; maps to the objective "per-bank namespace")
- Owner: lead  Size: L
- Prerequisites: shared with zeto and stealth plans; executes once after all three cutovers. (1) Inventory: CURRENT.md section 11 (`besu`: 4 STS, 4 PVC x 40Gi, 4 NetworkPolicies, 5 ConfigMap kinds; `paladin`: 6 Deployments incl. `bank-gw-1..4`, `bundle-server`, `paladin-operator`, 4 STS, 4 PVC x 20Gi, 43 SCD, 3 PaladinDomain, 4 PaladinRegistration, 1 PaladinRegistry, 5 NetworkPolicies; `dfabi`: 9 Deployments, 2 PVC x 5Gi; PVC total 160 Gi + 80 Gi + 10 Gi = 250 Gi). (2) qa PASS on the new namespaces for every flow (S13 + zeto + stealth) and BI-balance proof; nothing in Lensa, `lensa-pf@*` (8 units for `paladin`), Publisher `kube.ts:3`, the `fx-gw-1..4` bundle pull from `bundle-server.paladin`, or the `dfabi` NetworkPolicy rule still points at the old namespaces (LENSA.md section 6, rows `paladin`, `besu`; CI names no namespace); NAMED backups made first: Postgres dump or disk snapshot of `paladin-node1..4-pgdata` (PV reclaim is `Delete`, so deleting the PVC or namespace destroys them; Besu PVs are `Retain`, which is not a backup), Secrets `node1..4.keys` and `paladin-nodeN-mtls`, `besu-node-validator-N-keys`, CM `besu-genesis`, Lensa state files `state/noto/*`.
- Flags: user-only, CLUSTER-OP (own approval at that time), destructive
- Does: cluster 1 only; delete order `dfabi` stack, `paladin`, then `besu` (after the retained Besu disks are copied or released on purpose). Cluster-scoped CRDs `*.core.paladin.io` are not deleted by a namespace delete and stay. Cluster 2: nothing is ever deleted. Nothing executes now.
- RED proof: before: `kubectl get ns besu paladin dfabi` -> 3 rows; after: `NotFound` x3 AND the named backups restore-tested (a dump restores into a scratch Postgres, `select count(*) from states` > 0 [table name unverified]).
- Rollback: none after delete. Restore from the named backup set above (Postgres dumps/snapshots, Secrets export, Besu retained disks) into recreated namespaces.
- Sources: CURRENT.md section 11 (counts, PV reclaim table, StorageClasses); LENSA.md section 6.

## DEVIATION REQUEST
None. The drafter raised the remote signing module (S4); `lead` resolved it inside the AFTER Key custody row (ARCHITECTURE-noto-pente.md:197, `secretBackedSigners` per node), see S4.
