PLATFORM: IROHA3 @ iroha3@e2a1794 driver@be4dd89 frontend@ed7b78b   Upstream: hyperledger-iroha/iroha@071e281e (HEAD of PR #5627 "add permissioned lane-0 validators"); spec = specs/private_settlement.md at that commit.
Reviewer: analyst subagent (sonnet), read-only, live reads 2026-11-11.

DECENTRALIZATION: validator=GAP | self-submit=GAP | third-party=ACCEPTED (upstream rule) + GAP (our single instance)

component | runs today | per-bank or shared | upstream rec (source)
- peers bi-0, bank-a-0, bank-b-0, bank-c-0 | 4 STS, 1 replica, image iroha3-rd-node:071e281e-stark, each on its own k8s node, own PVC, Secret peer-<party> (peer.toml) | per bank in layout; one ns, one kubeconfig, one operator | each validator its own key; V1 requires f=1 four-validator geometry (spec :44-46)
- gha-runner-0 | STS, Role gha-deployer: pods/exec, secrets get/list, all workloads | shared, runs deploys | none
- bi-auditor | Deployment 1 replica Recreate, driver:be4dd898, PVC bi-audit-store, Secret bi-auditor-key (bi-auditor.seed, bi-auditor.hybrid) | shared; BI in name, same ns | `audit-online` one-shot CLI; up to 32 auditors per policy
- scenario Jobs rd-s1..s4, selftest | driver:23f7a444 / 06486202 (not be4dd898); mount Secret client-bi (client.toml, genesis.expected_hash) + Secret rd-dfabi-wallets (bank-a/b/c.seed, bi.seed) | one coordinator holds all 4 seeds + operator key | one wallet per party; sponsor = whoever signs the carrier
- Lensa driver | iroha3-aps.ts dockerRunner on the Lensa host, `docker run --network host` against port-forwards 127.0.0.1:38080..38083, :38090; mounts all of /home/ecs-user/iroha3-keys (bank-a/b/c.seed, bi.seed, 4 .note, bi.origin-*.note, bi-auditor.seed, bi-auditor.hybrid) | single host, shared | none
- pools | /home/ecs-user/iroha3-pools/pools.json on the Lensa host | shared | custom (pools.rs)
- Torii | each peer :8080 via port-forwards on one host | per-bank endpoint, one access path | n/a

FINDING: banks cannot self-submit; BI is the hard-wired sponsor and one process holds every party key   SEVERITY: major   KIND: deviation
  PROJECT:  driver/src/aps.rs:207, pools.rs:273,346 `cfg.sponsor("bi")`: every bundle signed with BI's client.toml. Scenario Job mounts client-bi + all four seeds. Lensa mounts the whole keys dir.
  UPSTREAM: sponsor = any manifest sponsor signing the carrier (private_settlement/carrier.rs:215 `transaction.authority() != &manifest.sponsor`; spec :457-496); reimbursement and fee per leg (:475-479).
  EVIDENCE: sponsor path; `kubectl get secret -n iroha3` key names; Role gha-deployer.
  FIX:      one driver per bank with its own client.toml, seed and note key; initiating bank sponsors; pool governance stays BI. UNVERIFIED: a two-leg DvP needs both payers' witnesses and upstream documents no multi-party witness exchange, so this may need new custom code (blocked by no-custom rule).   OWNER: iroha, lead
FINDING: lane author fixed per height; any single peer down stops user transactions   SEVERITY: major   KIND: accepted (R2 exemption, upstream limit)
  UPSTREAM: lane_consensus.rs:96-107 `deterministic_lane_author` = validator_set[(lane_height-1) % n], no view/liveness input; enforced :854-860 (ProducerNotDeterministicAuthor); autonomous payloads need lane_block_view == 0 (:984, :1048). Redrive scheduler sumeragi/lane_planner.rs:~418 is #[cfg(test)]. Torii admits only QueuePlanSynced txs (iroha_torii/src/lib.rs:25160-25165); v2_candidate.rs:833-842 defers to the lane.
  EVIDENCE: iroha3/reports/g1-network.md smoke step 3 failed twice with BI down ("height did not move", queue_size=1). Only BI down tested; code implies the same for each peer at its heights. V1 forbids > 4 validators (spec :44-46).
  FIX:      none on our side; upstream author failover.   OWNER: accepted
FINDING: one auditor instance, one key, threshold 1   SEVERITY: major   KIND: deviation (our side); upstream requirement ACCEPTED
  PROJECT:  aps.rs:879 `min_approvals: 1`; one auditor in the policy; pools.rs long-lived pools `retirement: None`.
  UPSTREAM: 1 <= min_approvals <= auditors.len() <= 32 (iroha_data_model/src/nexus/private_settlement.rs:2223-2226; MAX_AUDITORS_V1 = 32 at :61); defaults.rs:3301 DEFAULT_MIN_AUDITOR_APPROVALS = 1 is a floor (Torii private_settlement.rs:990-992); rotation RotatePrivateSettlementPoolPolicyV1 (spec :374-384); retired decryption keys kept (spec :354-360).
  FIX:      second auditor run by another org or regulator, k-of-n, rotation plan, PVC + key backups.   OWNER: iroha, lead
FINDING: one operator controls all four validators   SEVERITY: major   KIND: deviation
  PROJECT:  network/generate.sh:2-4 creates every peer key in network/out on one PC; all peers, runner, secrets in ns iroha3 under alibaba.yaml; Role gha-deployer can get/list secrets and pods/exec. reports/a-dataspace-restricted.md:62: one op-* operator key (CanReadAllLedgerData) same on all four nodes (not re-verified, needs key material).
  UPSTREAM: each validator holds its own key; BLS proof of possession verified per member (spec :44-46).
  FIX:      each bank generates its own keys and runs its own cluster or ns; share only peers.json and genesis.   OWNER: lead, user (scope)
FINDING: auditor key sits beside party keys on the Lensa host   SEVERITY: major   KIND: deviation (separation of duties)
  PROJECT:  ~/iroha3-keys has bi-auditor.seed, bi-auditor.hybrid beside bank-*.seed; dockerRunner (iroha3-aps.ts:~39) mounts the whole dir. Driver auditor_call uses HTTP and does not read the file, but it is readable.
  UPSTREAM: approver independent of payer and recipient (spec :55-56); audit-online keeps key files owner-only outside the signer's custody (spec :324-340).
  FIX:      mount only <party>.seed and <party>.note; auditor keys only in Secret bi-auditor-key.   OWNER: iroha
FINDING: driver drift; upload fails if any peer is down   SEVERITY: minor   KIND: drift / unverified
  EVIDENCE: Jobs ran 23f7a444 and 06486202; auditor + Lensa run be4dd898. aps.rs:374 uploads a leg to every committee endpoint, fails on first error; mirrors the upstream test (integration_tests/tests/nexus/atomic_private_settlement_localnet.rs:3207-3213). Upstream client has quorum logic for certify/prepare/commit (crates/iroha/src/client/private_settlement.rs valid_shares, canonical_*_quorum_v1); tolerance at upload unverified.
  FIX:      re-run scenario Jobs on be4dd898; probe with one peer down (lead go-ahead).   OWNER: iroha

R1: ALIGNED at protocol level, GAP at the Lensa layer. Validators receive proof + opaque fixed-shape delta, no audit plaintext (spec :53-56). Non-party peer sees bundle id, routes, participant count, heights, nullifiers, commitments, ciphertext slots, digests, committee QCs, sponsor, fee intent, reimbursement commitment, status (spec :59-68). Not hidden: timing, participant count, dataspace identity, stable-pool activity, asset inference when one CBDC per dataspace (spec :70-72; applies here, ds-rd = RD, ds-dfabi = DFABI): residual ACCEPTED. Live c-aps-all-flows.md:84 outsider column `sealed` for every flow. Plain DataspaceRestricted transfers are NOT R1: lane-1 data plaintext on all 4 validators, C's 403 is only an API gate (a-dataspace-restricted.md:62-71). Lensa gap: one host holds every .note and .seed; iroha3.ts lens() reads outsider views as the operator. Engine zk-stark, nexus.toml [zk.stark] enabled = true.
R2: ACCEPTED. Upstream requires an online auditor: min_approvals == 0 rejected InvalidAuditThreshold (private_settlement.rs:2223-2226); leg validation fails PrivateSettlementStateErrorV1::Approvals below policy minimum (private_settlement/state.rs:1118; count check private_settlement.rs:3958-3964 InsufficientAuditApprovals); sidecar re-checks (sidecar_store.rs:855, :1966); Torii rejects policy below floor (:990-992); spec :319-320 "insufficient approvals prevent Prepare"; audit_timeout_blocks 1200 then abort. bi-auditor is a separate Deployment from bi-0, so BI validator down does not stop approval, but it stops user txs (finding 2). Auditor client needs 3 of 4 validator responses (spec :297-320).
R3: ALIGNED. All legs apply in one state transaction or none (spec :56-57); global_state.rs:845 plan_private_settlement_receipt_v1, :986 plan_private_settlement_abort_v1 (abort releases staged locks unless a receipt exists, :1000-1020); test :3358 state_transaction_applies_all_legs_only_at_atomic_commit_boundaries. Live: Jobs rd-s1-dvp and rd-s2b-audit-reject Complete; rd-s2a-insufficient Error (refusal before proving, expected-ness unconfirmed). Residual: driver settle aborts only on prepare failure (parked M2 in NOTES); exits after prepare leave locks until expiry (drift, known).

ACCEPTED STATES (each with upstream citation and path to compliance)
- R2 exemption (user decision): upstream fixed lane author (lane_consensus.rs:96-107); compliance needs upstream author failover; > 4 validators forbidden in V1 (spec :44-46).
- Single online auditor is upstream design (private_settlement.rs:2223-2226); compliance = k-of-n auditors with a second org.
- driver/src/tree.rs custom (iroha3/NOTES.md): reimplements crate-private note-tree hashing (proof_managed_accumulator.rs, fns pub(crate), depth 32, SHA-256); upstream exposes only the fresh two-note path; compliance needs a public upstream API.
- APS "not production-qualified" (spec :27-29).
- Asset inference and sponsor visibility under R1 (spec :70-72).

SOURCES: iroha@071e281e specs/private_settlement.md, crates/iroha_core/src/{lane_consensus.rs,private_settlement/*.rs,sumeragi/*}, iroha_data_model/src/nexus/private_settlement.rs, iroha_torii/src/lib.rs, iroha_config/.../defaults.rs:3301, integration_tests/tests/nexus/atomic_private_settlement_localnet.rs; driver be4dd89 aps.rs, pools.rs; iroha3 network/, reports/{g1-network,a-dataspace-restricted,c-aps-all-flows}.md; frontend iroha3-aps.ts, iroha3.ts, state/iroha3.json (key names); live read-only kubectl ns iroha3; ~/iroha3-keys listing.
UNVERIFIED: docs.iroha.tech unusable (JS app), multi-auditor/rotation claims from the repo spec only; any single non-BI peer down stalls lanes (code reading only); op-* key identical on all nodes; upload tolerance of a missing endpoint; bank-only sponsor flow without multi-party witness handoff.
