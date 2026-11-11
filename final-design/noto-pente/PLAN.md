# noto-pente: plan CURRENT -> AFTER
Skills used (loaded by `lead`; the drafter applied them as checklists): superpowers:writing-plans, ecc:architecture-decision-records, ecc:kubernetes-patterns, superpowers:verification-before-completion (RED proofs), path:line map built by hand (ecc:code-explorer is an agent type, not a skill), ecc:deployment-patterns (Lensa cutover/rollback), web3-testing (RED proofs of contract/flow steps), ecc:evm-token-decimals + solidity-auditor (CONTRACTS.md inventory only). Not run: the 12-agent solidity audit (inventory only).
Target: agents/analyst/design/ARCHITECTURE-noto-pente.md (AFTER) + objectives (decentralization per bank: validator, self-submit, third-party; R1, R2, R3). Start: final-design/noto-pente/CURRENT.md @ 2026-11-11 (no time in the file).
Namespaces: this plan creates none. Noto + Pente run on the Zeto namespaces `rd-zeto-<party>` (`rd-zeto-bi`, `-bank-a`, `-bank-b` cluster 1; `-bank-c` cluster 2, new only; every existing cluster-2 namespace is foreign), or on `rd-noto-<party>` under README row 24 option B (user decision 24, default A). Every namespace below reads `rd-zeto-<party>` with that note.
Pins: `besu@9890701` (CURRENT pin; analyst lines were taken at 927f572, the lines cited here were re-read at 9890701), `besu@45122ae` (lines re-read by the besu engineer 2026-11-11; where it differs from 9890701 the platform.ts lines are one lower), `frontend@28c8bdb` (local HEAD; analyst pin aa6e09b), `paladin@v1.0.0` (6d4b913) as in ARCHITECTURE.
Shared with zeto and stealth (CURRENT.md section 11): validators (ns `besu`), Paladin nodes + gateways (ns `paladin`), `dfabi`. Those steps are owned by the zeto plan (`final-design/zeto/PLAN.md`) and NOT repeated here: **zeto S1+S2** namespaces + NetworkPolicies; **zeto S3-S5** validators and vote; **zeto S6** seeds and signing under party custody (seed Secret copy `node1..4.keys`); **zeto S8** Postgres per party + verified copy of the old DB; **zeto S9** Paladin node per party (rehearsal copy, scaled to 0 behind NetworkPolicy `rehearsal-no-9000-egress`); **zeto S10** cross-cluster transport endpoints; **zeto S11** registry ownership and endpoint republish (peers refuse the new cert until it runs); **zeto S16+S17** gateway + OPA bundles per party; **zeto S19+S20** Lensa forwards and Publisher; **zeto S21** cutover (live flip) and qa proof; **zeto S22** decommission. No Noto/Pente flow runs on a new node before zeto S21.
Assumption A1 (decision recorded, default A of README row 24, user-only): zeto and noto/pente share one Paladin node + namespace per bank (CURRENT sections 2-3: `pld.domains` selects noto+pente, zeto is static in the same CR; both are domains of one node, `paladin@v1.0.0` `spec.domains`). Splitting one bank's stack gives no decentralization gain and doubles nodes and keys; option B (one node + namespace per platform per bank) would make every namespace below `rd-noto-<party>` and need its own Postgres copy. Stealth has NO Paladin node (Besu door + keys in Lensa, stealth CURRENT section 5). The operator is namespace-scoped (`paladin@v1.0.0:operator/cmd/main.go:98` `getWatchNamespace()`, :108, :211-221; default ns `default` when WATCH_NAMESPACE is unset). Notary = BI is fixed by upstream (option A in ARCHITECTURE section 2, `paladin@v1.0.0:doc-site/docs/architecture/noto.md:50,569,580`; notary is fixed at deploy, `solidity/contracts/domains/noto/Noto.sol:56,126-134`), so no token is redeployed and no notary moves (options B-D are not planned: ARCHITECTURE says "not recommended", and they need a new token).
Assumption A2: the chain stays the same (validators join by vote, DELTA 2; the chain continues; party validators join by sync + vote (zeto S3-S5); the old `Retain` PVs are not a backup) and all Noto/Pente addresses in CURRENT section 4 survive ONLY with the Postgres: addresses come from DB key mappings, the seed alone is not enough (`paladin@v1.0.0:core/go/internal/keymanager/key_resolver.go:149-175` allocates `nextIndex` per key path from existing DB rows). Postgres PVs are `Delete` (CURRENT section 11). Cross-plan requirement: zeto S8 = verified copy of the old node's Postgres (`paladin-nodeN`), before zeto S9 (node move); zeto S8 must not be an empty DB. If zeto S3-S5/zeto S8+S9 choose a new chain, S1..S7 become a redeploy and lead must re-plan; this plan does not cover it.
Preserve (every step): privacy groups keep 100% endorsement (`paladin@v1.0.0:domains/pente/src/main/java/io/kaleido/paladin/pente/domain/PenteDomain.java:101-103`); no custom Paladin code (running fork digest unchanged); amounts are integer units, `PRICE_PER_UNIT = 1_000_000n` (`frontend@28c8bdb:server/src/domain.ts:14`).

## Order and dependencies
1. S1 initial (none, read-only, before zeto S8/S9)  2. zeto S1+S2  3. zeto S3-S5  4. zeto S6  5. zeto S8 (verified Postgres copy of `paladin-nodeN`, not an empty DB), then zeto S9, both after S1  6. S2 after S1,zeto S6,zeto S8,zeto S9  7. S4 (not planned, decision record after S3)  8. S5 (BLOCKED user; owned by zeto S11(b) + ADR 0001)
9. zeto S10, zeto S11 (republish; ownership part blocked by ADR 0001)  10. S6 after zeto S9 (check only)  11. S8 after S1 (code incl. fe sub-step, before S13)  12. S10 after zeto S16+S17  13. S11 (code only, before S12)  14. S9 after S7
15. S1 re-baseline at the zeto S21 freeze (Lensa idle, lock held)  16. S3 (sign probe + flows) after zeto S6,zeto S8+S9,S2,zeto S11,zeto S21  17. S7 after S2,S6,zeto S10,zeto S11,zeto S21  18. S12 after S8,S10,S11,zeto S19+S20,zeto S11,zeto S21  19. S13 after S1 re-baseline,S7,S8,S12,zeto S21  20. S14 after S8,S13 (BLOCKED user)  21. S15 LAST after S13, the zeto and stealth cutovers and zeto S22

DELTA coverage: 1 -> S2,S3,S4,S11 (+zeto S8+S9); 2 -> zeto S3-S5; 3 -> S6 (+zeto S8+S9); 4 -> S5 (+zeto S11); 5 -> S1,S2,S6; 6 -> S7,S9; 7 -> S8,S14; 8 -> S10,S11,S12 (+zeto S16+S17); 9 -> zeto S1+S2 (kubeconfig per org); 10 -> S5; 11 -> zeto S1+S2,zeto S3-S5,zeto S10+S11 (cluster 2).

## Steps
### S1: Noto/Pente continuity baseline (read-only)
- DELTA: 5 -> AFTER row: "Move BI's notary identities ... no token change"
- Owner: qa (script by besu)  Size: S
- Prerequisites: none for the initial baseline; must finish before zeto S8 and zeto S9 touch `paladin-node1..4`. Cross-plan requirement: zeto S8 = verified copy of the old node's Postgres. Runs TWICE: initial (now) and a re-baseline at the zeto S21 freeze (Lensa idle, lock held), because a live trade between the two would invalidate the first; S13 compares against the re-baseline.
- Flags: none. Resolving the KNOWN names on the OLD node is read-equivalent: `getVerifiers` = `ptx_resolveVerifier` creates a key only when no mapping exists (paladin@v1.0.0:core/go/internal/identityresolver/identityresolver.go:140-148, `paladin@v1.0.0:core/go/internal/keymanager/key_resolver.go:233`); never resolve an unknown name.
- Does: new read-only script `noto+pente/bond/src/tests/noto-baseline.ts` (or an extension of `data-persistence.ts`, the script behind `npm run verify`) writes the CURRENT section 3-5 values as machine-checkable lines: verifier address for `cashIssuer@node1`, `bondIssuer@node1`, `bondCustodian@node1` and the investor names read from the data file (known names only); `owner()` and impl slot of the 12 addresses in CURRENT section 4 (`0x8da5cb5b`, slot `0x3608...2bbc`); group ids and members of cash group `0xece3d19e...f522f`, issuer-custodian group `0x2a195eda...a8bf` and the 3 investor groups; BI custodian cash and bond balance and each bank balance (data file `custodianFinalBalances` was 3000/997000 on 2026-10-19, so re-read now); `PaladinDomain` `noto` + `pente` `registryAddress`; SCD count 43. `verify-deployed.ts` is not the base: it is legacy, not an npm script, its `ContractData` (:8-24) lacks `restrictedAtomFactoryAddress` and per-investor ids, its resume (:139-143) gets undefined, and it asserts no owner or impl slot.
- RED proof: `ls noto+pente/bond/src/tests/noto-baseline.ts` and file `noto-baseline-<date>.txt` in the qa report do not exist before; after: the file contains 12 owner/impl rows, 6 identity rows, 3+ group rows; `grep -c 'owner=' noto-baseline-*.txt` -> `12`.
- Rollback: none needed (read-only).
- Sources: CURRENT.md sections 3-5, 9; `besu@45122ae:noto+pente/bond/src/verify-deployed.ts:8-24,139-143`; `besu@45122ae:noto+pente/bond/package.json` (`verify` -> data-persistence.ts).

### S2: Notary and bank identities keep their addresses on the moved nodes
- DELTA: 5, 1 -> AFTER row: "notary identities: cashIssuer, bondCustodian, assetIssuer" (`assetIssuer` is not a live identity, dropped here)
- Owner: besu  Size: S
- Prerequisites: S1; zeto S6 (seed Secret copy `node1..4.keys`, names only), zeto S8 (verified Postgres copy of `paladin-nodeN`) and zeto S9 (node CRs into each party's namespace, embedded `static` keystore)
- Flags: CLUSTER-OP (reads through the door, but the node move itself is zeto S8+S9's CLUSTER-OP)
- Does: only after the Postgres copy, resolve only the known names (`cashIssuer`, `bondIssuer`, `bondCustodian`, the investor names from the data file) on their new nodes (`PaladinClient.getVerifiers(lookup)`, `besu@45122ae:noto+pente/bond/src/lib/platform.ts:54-55` clients and node1, `:60-65` investors loop) and compare with S1. This is not a pure read: before the Postgres copy a resolve on a moved node allocates a NEW key index and returns a different address, and an unknown name writes a mapping (`key_resolver.go:149-175,233`). `assetIssuer` exists only in the swap-noto example (`index.ts:47-53,95`; live data file participants = cashIssuer, bondIssuer, bondCustodian). Notary stays `*@node1` in the BI namespace (upstream requirement).
- RED proof: before (old ns) and after each lookup returns the same address: `diff <(S1 identity rows) <(post-move identity rows)` -> empty (valid because the Postgres copy came first). A changed address = STOP, tokens bound to the old address (UTXOs and group members, ARCHITECTURE DELTA 1).
- Rollback: zeto S8+S9 rollback (restore old namespace nodes, which stay until S15).
- Sources: `paladin@v1.0.0:core/go/internal/keymanager/key_resolver.go:149-175,233`; `paladin@v1.0.0:doc-site/docs/architecture/key_management.md:76-140` [not opened by analyst]; `besu@45122ae:noto+pente/bond/src/index.ts:134,205` (notary identities).

### S3: Prove Noto and Pente flows with `keyManager.disableSignRPC: true`
- DELTA: 1 -> AFTER row: "`keyManager.disableSignRPC = true` after Lensa stops signing for banks"
- Owner: besu  Size: S
- Prerequisites: zeto S6 (seed Secret copy), zeto S8+S9 (sets the flag in each node CR; not duplicated here), S2; the flows part (2) also zeto S11 and zeto S21 (the rehearsal node is scaled to 0 until the live flip)
- Flags: CLUSTER-OP (live writes under the cluster flock, besu GO: locks, atoms, trades)
- Does: (1) sign probe: call `keymgr_sign` with a throwaway key identifier `probe/disable-sign-check`, never a party key, on one old node and on each new node; (2) on the new nodes run one Noto transfer, one Pente private call in a bank group and one `executeOutright` (`npm run test:live-atom`, `bond/package.json:14` -> `live-restricted-atom.ts`). `npm test` (:12) is offline, never calls the sign RPC and proves nothing here. With the flag true `keymgr_sign` is not registered (`paladin@v1.0.0:core/go/internal/keymanager/keymanager_rpc.go:41-43`), so the node answers like for any unknown JSON-RPC method.
- RED proof: `keymgr_sign` with the throwaway id succeeds on the old node (flag false, CURRENT section 2 Signer config) and returns a method-not-found class error on the new node (code -32601 expected [unverified]; exact text from firefly-common rpcserver [unverified]); then the three flows end `SETTLED`.
- Rollback: set the flag back in the node CR (zeto S8+S9 rollback).
- Sources: `paladin@v1.0.0:doc-site/docs/administration/configuration.md:344`; `paladin@v1.0.0:core/go/internal/keymanager/keymanager_rpc.go:41-43`; `besu@45122ae:noto+pente/bond/package.json:12,14`.

### S4: Per-bank signing module (remote / HSM): not planned, inside the AFTER as an option
- DELTA: 1 -> AFTER row "Key custody: `keyManager.disableSignRPC: true`; `signingModules` (plugin) or `secretBackedSigners`; one signer per node via `secretBackedSigners`" (ARCHITECTURE-noto-pente.md:197)
- Owner: lead  Size: S (decision record only)
- Prerequisites: S3
- Flags: none
- Does: nothing is built. The AFTER names two custody shapes; S3 delivers the `secretBackedSigners` shape (embedded signer, `disableSignRPC: true`, the bank's own seed Secret in `rd-zeto-<party>`, or `rd-noto-<party>` under README row 24 option B), which already satisfies DELTA 1 (keys stay with their owner). A remote/HSM signing module is Paladin plugin code (`paladin@v1.0.0:doc-site/docs/architecture/key_management.md:41-70`, section "4. Signing Modules" :224); upstream ships the interface, no ready-made module [unverified]; under "no custom Paladin code" it stays an option for later, not a plan step. Same reading for the zeto plan. Accepted reading of ARCHITECTURE :197: `secretBackedSigners` is an unencrypted mnemonic in a Secret (static keystore hardcoded by the operator, `paladin_controller.go:1147` [cite from analyst gaps file, not re-read]), weaker than rows :121/:225 (HSM/signing module = plugin code, not planned); analyst addendum follows (shared with zeto S6).
- RED proof: `grep -c 'secretBackedSigners' final-design/noto-pente/CONTRACTS.md` >= 1 after S3's row is filled; no live check.
- Rollback: none.
- Sources: ARCHITECTURE-noto-pente.md:121,197; `paladin@v1.0.0:doc-site/docs/administration/configuration.md:344` as cited there.

### S5: Registry root owner: rootless or BI-signed
- DELTA: 10, 4 -> AFTER row: "Registry root owner: `rootless` registry lets any sender register a root child"
- Owner: besu  Size: S
- Prerequisites: user decision (ADR 0001, shared with the zeto plan, same number and slug)
- Flags: BLOCKED(registry rootless), user-only, CLUSTER-OP
- Does: owned by zeto S11(b) and ADR 0001 (shared); this plan adds no second decision and no second deploy. Noto/Pente side only: CURRENT already read the owner (root identity owner `0xf404...A11b` = `registry.operator` on node1), so DELTA 10's "eth_call owner()" is done and CURRENT wins over the analyst's "not read". The factories `0x1419f612...daf3` / `0x19980494...3254` have their own owners (`<name>_factory_proxy.operator` on node1) and do not depend on the choice; `evm-registry` `0x99f3326e...7874` stays in CONTRACTS.md until zeto S11(b) says otherwise.
- RED proof: the same as zeto S11's RED (bank-side registration without BI's key under A, or via the agreed path under B); no extra check here. Before: bank-side CR cannot sign (`paladinregistration_controller.go:107,137,238,256` [cite from analyst file, not re-read]).
- Rollback: zeto S11 rollback.
- Sources: `paladin@v1.0.0:solidity/contracts/registry/IdentityRegistry.sol:45-47,67-72`; adr/0001-registry-rootless.md.

### S6: Check `noto` and `pente` domains selected on each new node (check only)
- DELTA: 3, 5 -> AFTER row: "node CR per namespace ... own operator per namespace"
- Owner: besu  Size: S
- Prerequisites: zeto S9
- Flags: none (read-only `get`; no write)
- Does: zeto S9 creates the node CR with `PaladinDomain` `noto` (plugin `/app/domains/libnoto.so`, `registryAddress 0x1419f612c603466f254ca71e78a324c0d922daf3`) and `pente` (jar `io.kaleido.paladin.pente.domain.PenteDomainFactory`, `registryAddress 0x199804944e574c6f726f5aa13b343c6cd2c73254`) and the `spec.domains` selector `paladin.io/domain-name: noto|pente`; this step only verifies them on each new node and that no factory was redeployed. The controller copies `Spec.RegistryAddress` to status, so a pre-set address is not redeployed (`paladin@v1.0.0:operator/internal/controller/paladindomain_controller.go:64-65` [cite from analyst gaps file, not re-read]).
- RED proof: `kubectl -n rd-zeto-bank-a get paladindomain -o custom-columns=N:.metadata.name,A:.spec.registryAddress` (or `rd-noto-bank-a` under option B) before zeto S9: `No resources found`; after: `noto 0x1419f612...` and `pente 0x19980494...`; node CR `spec.domains` contains both; `kubectl -n rd-zeto-bank-a get scd --no-headers | wc -l` equals the S1 count (43 on the old `paladin` namespace; per-namespace count `[unverified]`), i.e. no factory redeploy.
- Rollback: none (read-only); a wrong result is fixed in zeto S9.
- Sources: CURRENT.md sections 2-3; `paladin@v1.0.0:operator/api/v1alpha1/paladin_types.go:60-61` (`spec.domains`; :51-52 is BaseLedgerEndpoint) [cite from analyst gaps file, not re-read]; `paladin@v1.0.0:operator/internal/controller/paladindomain_controller.go:64-65`.

### S7: Pente groups resume across nodes; tracker ownership unchanged
- DELTA: 6, 5 -> AFTER row: "Pente group per bank pair {bank, BI} per token; BI stays in each group"
- Owner: qa  Size: M
- Prerequisites: S2, S6, zeto S10, zeto S11 (peers refuse the new cert until the republish; S5 decided, since cross-cluster delivery needs the registry), zeto S21 (the private test call is a live write on the live node)
- Flags: CLUSTER-OP (the private test call is a live write; the other checks are reads: `resumePrivacyGroup`, `eth_call`, `eth_getCode`)
- Does: on the new nodes, `PenteFactory.resumePrivacyGroup({id})` for the cash group (members {cashIssuer}), the issuer-custodian group `0x2a195eda...` ({bondIssuer, bondCustodian}) and the 3 per-investor groups ({investor, bondCustodian}; their addresses were not read: [unverified], read in S1). One private call per group completes with 100% endorsement, incl. bank C on cluster 2 with BI on cluster 1. Ownership: `bondTrackerPublic` `0xb6adb924...` `owner()` = `0x2a195eda...` (owned by the issuer-custodian group contract), `cashTracker` `0xc6bb619f...` has 0 bytes of public code (private inside the cash group).
- RED proof: before zeto S11 a call in the group {investor3@node4, bondCustodian@node1} cannot reach node 4's new endpoint (timeout, error text [unverified]); after: `resumePrivacyGroup` returns the S1 address, `eth_call owner()` on `0xb6adb924...` -> `0x2a195eda9c56444a1247c4e827d94ffe73e9a8bf`, `eth_getCode 0xc6bb619f...` -> `0x`.
- Rollback: none needed (no state change beyond a test call; point Lensa back, S12).
- Sources: `besu@9890701:noto+pente/bond/src/index.ts:114-117,158-160,258-260`; `besu@45122ae:noto+pente/bond/src/lib/platform.ts:54-65`; PenteDomain.java:101-103.

### S8: RestrictedAtom executor per trade
- DELTA: 7 -> AFTER row: "pass the selling bank as `executor` for secondary trades"
- Owner: besu (library + forge), fe (adapter sub-step)  Size: S
- Prerequisites: S1 (no cluster needed for the code part)
- Flags: none
- Does: only the address stored as `executor` at create can call `execute` (`besu@45122ae:noto+pente/contracts/src/RestrictedAtom.sol:149-157` `msg.sender != executor -> NotExecutor`; `RestrictedAtomFactory.sol:33-40`). Today it is `bondCustodian.address()` (`bond/src/lib/outright.ts:246-254`, key on node1) and `atom.execute(bondCustodian)` (:270) goes through the node1-bound atom. `Atom.execute(from: PaladinVerifier)` (`bond/src/helpers/atom.ts:109`) uses the client the Atom is bound to (`Atom.using(paladin)` :105), so swapping only the identity fails. Change: `executeOutright` (:125) takes an optional executor Participant (client + verifier), passes `executor.verifier.address()` to `create`, and calls `atom.using(executor.client).execute(executor.verifier)`. Default stays the custodian (BI) for primary sales. Rollback atom (:359-373) may stay custodian (cancel = executor or party, `RestrictedAtom.sol:223`). Sub-step (fe): `frontend@28c8bdb:server/src/adapters/noto.ts:293-294` calls `executeOutright(p, { seller, buyer, units, price, tradeId }, log)` with the default custodian (the findings cite :305, which is the `emit(3, ...)` line; there is no `recordedTrade` in the file); pass the executor Participant of the trade's seller through that call, otherwise "selling bank as executor" never goes live. R2 stays exempt: preparing and delegating the locks need BI, execute and cancel after delegation do not (`paladin@v1.0.0:doc-site/docs/architecture/noto.md:597`: a delegated contract acts "without involvement of the notary").
- RED proof: (1) new unit test for the Participant plumbing in `outright.ts` (create receives the seller address, execute is called through the seller's client) fails before (no parameter), passes after; (2) forge test in the RestrictedAtom suite (`contracts/test/RestrictedAtom.t.sol`; case added if missing, existing coverage [unverified]) asserts `NotExecutor` for a non-executor caller and success for the stored executor: `forge test --match-contract RestrictedAtom`. (3) fe unit test on the adapter asserting the executor argument passed to `executeOutright` is the seller's Participant. `src/tests/restricted-atom.ts` is an offline helper check and is not used as proof.
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
- Prerequisites: S8 (adapter sub-step), S10, S11, zeto S19+S20 (forwards per org; the 4 Paladin forwards are shared with Zeto, not duplicated), zeto S11, zeto S21 (the live flip)
- Flags: CLUSTER-OP (host service restart; own approval)
- Does: the `noto.ts` code change is S8's fe sub-step; here only the S11 credentials are consumed through env; set per-bank credential env/paths in `~/.config/lensa/lensa.env` (values not copied here), keep `server/state/noto.json` `dataDir` and `state/noto/contract-data-*.json` (addresses unchanged by A2) and `trades.jsonl`. Lensa still holds no Noto keys (`state/noto.json` = `{dataDir}`). Namespace references to clear: LENSA.md section 6 row `paladin` (units `paladin-node1..4`, `besu*`, Publisher `kube.ts:3` `NS='paladin'`) is the zeto S19+S20 owner; this step only checks the Noto side.
- RED proof: `grep -n 'paladin-node' frontend/deploy/forwards.conf` before shows ns `paladin`, after `rd-*`; qa reads, with no direct node call, `GET /api/history?model=noto&party=P&limit=60` for BI, A, B, C and gets verdicts `notarised, clear, clear, sealed` with amount `1000`, `1000`, `1000`, `null` (CURRENT section 9).
- Rollback: restore the previous `lensa.env` and forwards.conf (kept as backup), restart `lensa.service`.
- Sources: LENSA.md sections 1.1, 2, 6; CURRENT.md sections 7, 9.

### S13: qa cutover proof for Noto + Pente
- DELTA: 5, 6, 7 -> AFTER row: "Pente group per bank pair {bank, BI} per token"; "BI keeps R1"
- Owner: qa  Size: M
- Prerequisites: S7, S8, S12, S1 re-baseline, zeto S11, zeto S21
- Flags: CLUSTER-OP (live Lensa flows cash, bond, DvP: flock + cap + lead GO, as VERIFY.md:13 says)
- Does: through Lensa on the new namespaces: (1) cash transfer A to B; (2) bond transfer; (3) one `executeOutright` DvP, bank C on cluster 2 as seller once; (4) per-party R1 view of each tx; (5) BI balance proof: BI custodian cash and bond equal the S1 re-baseline (zeto S21 freeze) adjusted by the test amounts. Notary is BI for all (R2 exempt, CURRENT section 3).
- RED proof: before, flows run against old namespaces only; after, each `trades.jsonl` line `status` = `SETTLED` and `GET /api/history?model=noto&party=C` shows `sealed`, amount `null`; BI sees `notarised` with amount; `BI balance == S1 re-baseline +/- test amounts` printed.
- Rollback: S12 rollback (point Lensa to the old namespaces, which stay until S15).
- Sources: CURRENT.md sections 7, 9; `besu@9890701:noto+pente/bond/src/lib/outright.ts:125`.

### S14: Atom.cancel with BI's node down
- DELTA: 7 -> AFTER row: "Live test of `cancel()` with node1 down is open"
- Owner: besu  Size: M
- Prerequisites: S8, S13, user decision (ADR 0002)
- Flags: BLOCKED(Atom.cancel BI-down test), user-only, CLUSTER-OP
- Does: per the chosen option: create a throwaway RestrictedAtom with two delegated legs, take BI's Paladin node out of service for a bounded window, call `cancel()` as a party; measure whether legs are released. BI's node is also the notary, so Noto flows stop during the window (R2 exempt). Expected result: a delegated contract acts "without involvement of the notary" (`noto.md:597`), so `cancel()` by a party should succeed with BI down; a revert would mean the R2 exemption reaches beyond prepare and delegate.
- RED proof: `atom.status` before test `Pending`; after `Cancelled` and both legs unlocked, or the exact revert recorded. Before this step the outcome is "not tested" (ARCHITECTURE section 1).
- Rollback: scale BI node back; recover the throwaway atom with `cancel` after BI returns.
- Sources: `besu@9890701:noto+pente/contracts/src/RestrictedAtom.sol:219-224`; `paladin@v1.0.0:doc-site/docs/architecture/noto.md:597` ("without involvement of the notary"); adr/0002-atom-cancel-bi-down-test.md.

### S15: Decommission `besu`, `paladin`, `dfabi` (old namespaces)
- DELTA: none (cleanup after AFTER is reached; maps to the objective "per-bank namespace")
- Owner: lead  Size: L
- Prerequisites: pointer to zeto S22 (shared with zeto and stealth; executes once, after all three cutovers). (1) Inventory: CURRENT.md section 11 (`besu`: 4 STS, 4 PVC x 40Gi, 4 NetworkPolicies, 5 ConfigMap kinds; `paladin`: 6 Deployments incl. `bank-gw-1..4`, `bundle-server`, `paladin-operator`, 4 STS, 4 PVC x 20Gi, 43 SCD, 3 PaladinDomain, 4 PaladinRegistration, 1 PaladinRegistry, 5 NetworkPolicies; `dfabi`: 9 Deployments, 2 PVC x 5Gi; PVC total 160 Gi + 80 Gi + 10 Gi = 250 Gi). (2) qa PASS on the new namespaces for every flow (S13 + zeto + stealth) and BI-balance proof; nothing in Lensa, `lensa-pf@*` (8 units for `paladin`), Publisher `kube.ts:3`, the `fx-gw-1..4` bundle pull from `bundle-server.paladin`, or the `dfabi` NetworkPolicy rule still points at the old namespaces (LENSA.md section 6, rows `paladin`, `besu`; CI names no namespace). (3) PV prerequisite named: `paladin-nodeN-pgdata` and `dfabi` PVs (`data-postgres-0`, `runner-state`) are reclaim `Delete`, so deleting the PVC or namespace destroys them, and the Besu `data-besu-node-validator-N-0` PVs are `Retain`, which is a leftover disk and not a backup; NAMED backups first (Postgres dump or disk snapshot of `paladin-node1..4-pgdata`, Secrets `node1..4.keys` and `paladin-nodeN-mtls`, `besu-node-validator-N-keys`, CM `besu-genesis`, Lensa state files `state/noto/*`) or the verified copy of zeto S8.
- Flags: user-only, CLUSTER-OP (own approval at that time), destructive
- Does: executed as zeto S22; cluster 1 only; delete order `dfabi` stack, `paladin`, then `besu` (after the retained Besu disks are copied or released on purpose). Cluster-scoped CRDs `*.core.paladin.io` are not deleted by a namespace delete and stay. Cluster 2: nothing is ever deleted. Nothing executes now.
- RED proof: before: `kubectl get ns besu paladin dfabi` -> 3 rows; after: `NotFound` x3 AND the named backups restore-tested (a dump restores into a scratch Postgres, `select count(*) from states` > 0 [table name unverified]).
- Rollback: none after delete. Restore from the named backup set above into recreated namespaces.
- Sources: CURRENT.md section 11 (counts, PV reclaim table, StorageClasses); LENSA.md section 6.

## DEVIATION REQUEST
None. The drafter raised the remote signing module (S4); `lead` resolved it inside the AFTER Key custody row (ARCHITECTURE-noto-pente.md:197, `secretBackedSigners` per node), see S4.
