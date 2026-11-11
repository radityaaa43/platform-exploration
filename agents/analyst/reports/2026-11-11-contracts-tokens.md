REVIEW: contracts-tokens @ besu@927f572 fabric-x@3f7caeb iroha3@e2a1794 frontend@aa6e09b   VERDICT: GAPS
Reviewer: analyst subagent (sonnet), read-only; forge tests run in a scratchpad copy only.

FINDING: Zeto proving keys are the test-ceremony artifact   SEVERITY: major   KIND: deviation
  PROJECT:  fork /home/ecs-user/eksplorasi-paladin/build-v1/paladin/domains/zeto/build.gradle:67 ships `zeto-test-proving-keys-v0.5.1-lfdt.tar.gz` (single-party setup). Tarball not opened. Project docs mention test keys only for v0.2.2 (besu/zeto/docs/architecture-brief.md:483,747); no ceremony warning.
  UPSTREAM: LFDT-Paladin/zeto@v0.5.1:README.md:28 "the proving keys must be generated either in a well-documented, decentralized ceremony, or by one trusted, central party" for deployment.
  EVIDENCE: `grep -n provingKeysFile build.gradle` -> `67: provingKeysFile : 'zeto-test-proving-keys-v0.5.1-lfdt.tar.gz'`
  FIX:      Record the test-key risk as an explicit accepted PoC limit in besu/zeto/README.md; beyond PoC: ceremony + verifier redeploy.   OWNER: lead

FINDING: Fabric-X "official alternative" for the FSC full-certificate patch is stale   SEVERITY: major   KIND: drift
  PROJECT:  fabric-x/NOTES.md:25 says the `known_certs` route is "impossible on a channel without Capabilities". fabric-x/panurus-itest/README.md:99-105 and multiorg/cfgupdate/main.go:10-17: channel reset 2026-11-01 with Channel V3_0 / Application V2_5; `cfgupdate build/verify` is the update path "for channels that have capabilities". `patches/fsc-full-certificate.patch` still applied.
  UPSTREAM: fabric-smart-client@86539af4 platform/fabricx/core/transaction/transaction.go:770-800 (per NOTES.md; not opened) sends certificate-ID; committer accepts IDs for certs in `known_certs` (fabric-x-common@v0.2.8 msp/mspimplsetup.go:190, per NOTES.md; not opened).
  EVIDENCE: `sed -n 1,22p multiorg/cfgupdate/main.go` -> "build/verify are the config-update path for channels that have capabilities."
  FIX:      Rewrite the NOTES.md row: the official route is now possible. Lead decides on dropping the patch via a `known_certs` config update; same for the Idemix MSP option (README deviation 2).   OWNER: fabric

FINDING: Zeto V1 / v0.5.1 is not in Paladin v1.0.0; running code = unmerged PR in the fork   SEVERITY: major   KIND: accepted
  PROJECT:  besu/zeto/docs/fork-commits.md (group A: 50 commits + 13 merges from LFDT-Paladin/paladin#1189, OPEN). Live CR domain config: Zeto_Anon_V1 and Zeto_AnonNullifier (`forZetoVariant: 1`, circuits `anon_nullifier_transfer` / `withdraw_nullifier`, `usesNullifiers: true`, `transferLocked: anon`). Token name exactly `Zeto_AnonNullifier` (besu/zeto/src/zeto-v1.ts:19). Event ABIs (abis/ZetoV1Events.json) match v0.5.1 IZetoLockableCapability.sol.
  UPSTREAM: paladin@v1.0.0:domains/zeto/build.gradle:36 `zetoVersion = "v0.2.2"`; zeto@v0.5.1:solidity/contracts/zeto_anon_nullifier.sol:35 `contract Zeto_AnonNullifier`.
  EVIDENCE: `kubectl -n paladin get paladin node1 -o json` (spec.config) -> `forZetoVariant: 1 / name: Zeto_AnonNullifier / usesNullifiers: true`. No custom circuit: both circuits are upstream names.
  FIX:      None (running fork accepted). Rebase when #1189 merges. Note: `forZetoVariant` is a fork key, which answers the network review's drift finding.   OWNER: besu

FINDING: Zeto README contradicts the live token name and RD address   SEVERITY: minor   KIND: drift
  PROJECT:  besu/zeto/README.md:10,13 say `tokenName: "Zeto_Anon_V1"`; README:12 RD `0x08106229...` (the SMT-broken token). frontend/server/state/zeto.json:2 RD `0x0b91f511...`. besu/zeto/bootstrap-zeto.ts:3 header says `Zeto_Anon`, line 34 uses ZETO_V1.tokenName.
  UPSTREAM: fork `IsNullifiersToken()` matches the exact string `Zeto_AnonNullifier` (handler_transfer.go:156, fork build-v1). A `_V1` name silently drops nullifiers.
  EVIDENCE: `cat frontend/server/state/zeto.json` -> `"rd": "0x0b91f511a3c9ca8144a5422734a2db42bb86e8f6"`
  FIX:      Update README:10-13 and the bootstrap header.   OWNER: besu

FINDING: Pente report groups enable external calls   SEVERITY: minor   KIND: deviation
  PROJECT:  besu/zeto/src/flows.ts:99 (also spike-*.ts): {bank, BI} groups with `externalCallsEnabled: true`, used only for `pgroup_sendMessage` reports. Noto hook groups (noto+pente/bond/src/index.ts:111) do need it.
  UPSTREAM: paladin@v1.0.0:domains/pente/src/main/java/io/kaleido/paladin/pente/domain/PenteDomain.java:697 `putConfiguration("externalCallsEnabled", "false")` (default false).
  EVIDENCE: `grep -rn externalCallsEnabled besu/zeto/src/flows.ts` -> `99`. Live group config not read.
  FIX:      Drop the flag for report-only groups; run the report test.   OWNER: besu

FINDING: Stealth memo uses a home-made key schedule   SEVERITY: minor   KIND: unverified
  PROJECT:  besu/stealth-address/ts/memo.ts:8-9,41-51 AES-256-GCM, key = keccak256("RD-memo-v1" || compressed ECDH point), nonce = first 12 bytes of keccak256("RD-memo-nonce" || ephemeralPubKey); appended after the 57-byte metadata (RupiahDigital.sol `_announce`, MAX_MEMO 256).
  UPSTREAM: EIP-5564: metadata byte 1 view tag, 2-5 selector, 6-25 token, 26-57 amount; rest "used by senders however like". No memo encryption standardized. Contract layout matches. Derivation as the ScopeLift SDK. Registry matches EIP-6538.
  EVIDENCE: `forge test` in scratchpad copy -> `84 tests passed, 0 failed, 0 skipped`
  FIX:      Document as app-level extension. If kept: HKDF with domain label or audited ECIES. Deterministic nonce safe only while the ephemeral key is never reused.   OWNER: besu

FINDING: Iroha 3: hand-rolled intent hash and Norito decoder; APS overrides   SEVERITY: minor   KIND: accepted
  PROJECT:  frontend/server/src/adapters/iroha3-intent.py:13-24 parses Norito bytes at offset 23/40, Blake2b-256 over the Dvp body. iroha3-norito.ts decodes Mint/Transfer/Dvp by hand. iroha3/network/nexus.toml:99-101 APS `enabled = true`, `minimum_activation_notice_blocks = 10`. genesis-rd-dfabi.jq:8 assets DataspaceRestricted, mintable Infinitely, scale 0.
  UPSTREAM: iroha@071e281e crates/iroha_data_model/src/isi/settlement.rs:603 `INTENT_HASH_DOMAIN = b"iroha:settlement:dvp-intent:v1\0"`, :624 `intent_hash()`; CanExecuteSettlement fields match permission.rs:792-799; iroha_config defaults.rs:3247 `ENABLED = false`, :3249 notice 7_200, :3301 `DEFAULT_MIN_AUDITOR_APPROVALS = 1`; driver aps.rs:336 min_approvals 1.
  EVIDENCE: domain tag and intent_hash body match upstream source. Norito offsets not compared to norito core.rs.
  FIX:      Replace the script with an upstream client call when one exists; keep test vectors.   OWNER: fe

FINDING: RD and DFABI identity and decimals inconsistent across tracks   SEVERITY: minor   KIND: drift
  PROJECT:  Besu: BDT field ids + ISIN (besu/docs/instrument-data/profiles/DFABI.profile.json, InstrumentRegistry.sol:26). Fabric-X: free string type `DFABI-2027A`. Iroha: one asset "DFABI", description only (genesis-rd-dfabi.jq:31). Zeto backing SampleERC20 decimals 18 (besu/zeto/src/instrument.ts:146-148) vs record "0". Stealth RD 0 (RupiahDigital.sol:24). Fabric-X 64-bit integer. Iroha scale 0.
  UPSTREAM: ICMA BDT v1.2 not opened (licensed). Panurus@5f3c49e2 setup.go:321 BitLength up to 64. Auditor-less public params legitimate: common/validator_auditing.go:50-56.
  EVIDENCE: `grep -rliE "isin|bdt|InstrumentRegistry" fabric-x/panurus-itest/rdbi iroha3/network` -> iroha3 network scripts only (BDT description).
  FIX:      Lead sets a minimal cross-track DFABI key (primaryId + series), one mapping doc.   OWNER: lead

SOURCES:
- zeto@v0.5.1 (1b895de): README.md:28; solidity/contracts/zeto_anon_nullifier.sol:35; lib/interfaces/IZetoLockableCapability.sol:122-173
- paladin@v1.0.0 (6d4b9134): domains/zeto/build.gradle:36; domains/pente/.../PenteDomain.java:697,102; domains/noto/pkg/types/config.go:62-111
- paladin fork build-v1 worktree 0da5af7b6 (what runs): domains/zeto/build.gradle:55-67; integration-test/zeto/config-for-deploy-fungible-v1.yaml
- EIP-5564, EIP-6538 (raw ERC text)
- iroha@071e281e: isi/settlement.rs:603-627; executor_data_model/permission.rs:792; iroha_config defaults.rs:3245-3301
- panurus@5f3c49e2 local checkout: setup.go:303-337; validator_auditing.go:45-56
- live: `kubectl -n paladin get paladin node1 -o json`, `get paladindomain`

UNVERIFIED:
- Fork image to commit link; test proving-key tarball checksum vs zeto v0.5.1 release.
- Zeto SMT divergence under concurrent cross-node transfers (zeto.ts:538, RD redeployed 2026-11-09): no upstream issue cited; load serialized in app.
- Noto BondTracker.sol (603 vs 168 upstream lines) uses the official hooks extension; hook behavior vs paladin@v1.0.0 domains/noto not read line by line.
- Panurus patches: official alternatives per NOTES.md not re-checked here.
- DvPEscrow: settle atomic, cancel expiry-gated; over-funded bond stays stuck after cancel (DvP.t.sol:354-362, controller-recoverable); no external audit.
- ICMA BDT v1.2 field names vs licensed doc.
- Iroha APS live config read from repo, not from live peers.
