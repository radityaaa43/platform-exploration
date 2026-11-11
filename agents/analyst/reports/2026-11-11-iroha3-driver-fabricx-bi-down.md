REVIEW: iroha3-driver + fabricx-bi-down @ iroha3@e2a1794 frontend@ed7b78b fabric-x@3f7caeb driver iroha3-rd-node-build@be4dd89   VERDICT: GAPS (no blocker)
Reviewer: analyst subagent (sonnet), read-only. Driver read at iroha3-rd-node-build@be4dd89 (origin/main, PR #8); local iroha3/build checkout is stale at f6f9968. Upstream iroha@071e281e778c5928cab4d6e007b7ddc9b050df27. No cargo build or test run.

FINDING: BI report redelivery has no automatic trigger   SEVERITY: major   KIND: deviation
  PROJECT:  frontend@ed7b78b:server/src/adapters/fabricx.ts:255 tells the BI lens "laporan dikirim ulang nanti". `git grep "op: 'report'"` finds no Lensa caller. Redelivery = `driver report` (fabric-x/panurus-itest/rdbi/cmd/driver/main.go:158,180) or gateway op serve.go:246 (`deliver`, :278). Both operator-run. rdbi-driver Deployment at 0 (DESIGN.md:141).
  UPSTREAM: fabric-x/opa/DESIGN.md:146 "redelivered once BI is back (`op: report`)" is our own doc. No FSC redelivery feature opened.
  EVIDENCE: `kubectl get pods -n fabricx` -> no rdbi-driver pod. Due state is derived, not queued: `Report` with empty TxID covers every confirmed tx in the node store (rdbi/report/report.go:36-48; main.go:177-181), so it survives Lensa or node restarts. Nothing runs it.
  FIX:      Scheduled `op: report` with empty TxID per bank (gateway or CronJob), or change the Lensa text to "perlu dikirim ulang operator".   OWNER: fabric (job), fe (text)

FINDING: Deadline expiry or Envoy 504 shows an error, not pending, for a tx that commits   SEVERITY: major   KIND: unverified
  PROJECT:  fabricx.ts:26-27 GW_CALL_MS 305 s, TX_DEADLINE_MS 340 s. app.ts:273 wraps run + 4 lens reads in `withDeadline`; app.ts:276 emits `error` "Transaksi tidak selesai dalam 340 detik". Envoy 504 -> "Gateway X gagal (HTTP 504)" (fabricx.ts:107). No pending outcome in either path.
  UPSTREAM: Envoy route timeout 300 s (fabric-x/panurus-itest/scripts/k8s.py:299). Envoy docs not opened; `stream_idle_timeout` default 5 min from recollection, unsourced; k8s.py sets neither it nor `request_timeout`.
  EVIDENCE: Chain 300 < 305 < 340 consistent (fabricx.test.ts:523 asserts it). Measured BI-down 260868 ms -> margin to Envoy ~39 s. api.go:76-100 `final` waits up to 90 s per participant, serial. Extra slowness > 39 s hits 504 and Lensa shows error for a committed tx (DESIGN.md:147 symptom). fabricx-deadline.test.ts fakes the gateway at 262 s only; 300 s cut and 504 text untested; header still says 310_000 and CALL_MS (stale).
  FIX:      Map 504/DeadlineError to "pending, check history", or add a test with the gateway at 301 s.   OWNER: fe

FINDING: 340 s deadline includes lock wait; `busy` clears at deadline while the run continues   SEVERITY: minor   KIND: deviation
  PROJECT:  app.ts:273 plain `withDeadline`. fabricx.ts:64-76 `exclusive` waits on per-sender tails and `slot` (MAX_TX=3) inside it. `run` continues after deadline (deadline.ts:7-12); app.ts finally sets `busy = null`.
  UPSTREAM: frontend's own deadline.ts `afterLock` ("lock-queue wait is not charged"), used by zeto.ts:563, not by fabricx.
  EVIDENCE: Not run. A retry after a timed-out BI-down tx queues behind the held sender lock (~260 s) and is charged for it.
  FIX:      Use `afterLock` in the fabricx adapter, or keep `busy` until the run settles.   OWNER: fe

FINDING: The "~2m10s" waits trace to a hardcoded 2-minute endorsement timeout, not a SYN drop   SEVERITY: minor   KIND: unverified
  PROJECT:  Submit 130973 ms ≈ 120 s + 11 s. First attempt `CollectEndorsements(ctx, tx, 2*time.Minute, ...)` at panurus@5f3c49e2 token/services/network/fabric/endorsement/fsc/initiator.go:99, setup_initiator.go:107; then the failover patch re-selects without BI (service.go:143-171, kept by decision).
  UPSTREAM: 2-minute literal in Panurus v0.24.0, no config knob seen. FSC fsc.grpc.connectionTimeout not opened (module cache absent). Report leg 128897 ms vs rdbi/report/report.go:44 `timeout = 3 * time.Minute` (our code): actual cut-off untraced.
  EVIDENCE: `kubectl get svc -n fabricx` -> endorser-1 normal ClusterIP (10.200.13.130). DESIGN.md:147 "Service with no endpoints drops the SYN" unverified vs kubernetes.io; 128.9 s fits a Linux 127 s SYN-retry window (guess).
  FIX:      Trace the report leg (FSC logs or pod capture). Fail-fast needs a Panurus/FSC patch: out of scope under no-new-custom.   OWNER: fabric

FINDING: M2b consistent with upstream; per-node `Pending` is view lag only   SEVERITY: minor   KIND: accepted
  PROJECT:  aps.rs:474-532 (`abort_bundle`, `receipt_error`, `abort_on_error`, `FinalizedSeen`); `wait_receipt` aps.rs:588 requires all four nodes terminal.
  UPSTREAM: iroha@071e281e crates/iroha_core/src/private_settlement/global_state.rs:1002-1003 `plan_private_settlement_abort_v1` returns `Terminal` when a receipt exists; finalization refused when an abort exists (:883, :1198); `plan_prepare` :768. crates/iroha_torii_shared/src/private_settlement_api.rs:1242-1243: `Pending` = "this node has no public finalized receipt or abort marker". Finalized on A + pending on B possible (lag); finalized + aborted impossible under consensus. Abort after finalize rejected on-chain, so not aborting is right.
  EVIDENCE: cited files read. Nit: rejected late abort surfaces as "abort failed (pools stay reserved until expiry)" (aps.rs:527), misleading when finalized. Expired locks released by consensus (iroha_core/src/state.rs:63774). Down node -> `wait_receipt` times out 300 s on a finalized bundle; Iroha 3 exempt from R2.
  FIX:      none.   OWNER: iroha

FINDING: Every ISI, query and client call exists at 071e281e; "1 RD sponsor reimbursement" is a driver value   SEVERITY: minor   KIND: accepted
  PROJECT:  aps.rs:105 `SPONSOR_REIMBURSEMENT = 1` on leg 0 (aps.rs:193,1011,1185); `FEE_SIGNED_MAXIMUM = 1` (:102); `FeePaymentIntent::authority` (:577).
  UPSTREAM: crates/iroha_data_model/src/isi/private_settlement.rs:106,139; crates/iroha/src/client/private_settlement.rs certify :1333, prepare :1817, recover_or_commit :2138, register_prepare_and_wait :2260, build_abort :2293, build_finalization :2380, upload :2469, submit :3119, receipt :3181; client.rs :22478, :17823, :15937; blocking.rs :239, :276. `sponsor_reimbursement_amount` is a leg-0 output note (private_settlement.rs:1468, checks :1856-1857); amount free (localnet test uses 5: integration_tests/tests/nexus/atomic_private_settlement_localnet.rs:1282,1471).
  EVIDENCE: reimbursement = private note in RD; fee = XOR 0.001/instruction, 2 fee-bearing carriers per success (private_settlement.rs:110). Unrelated. Activation txs and abort carriers unreimbursed. "1 RD" = driver convention. M4 formula beyond pools.rs:354-356 not opened.
  FIX:      Document as convention, not a fee match.   OWNER: iroha

FINDING: pools.json lock (M1) and receipt-cache temp name (L1): no upstream equivalent, small gaps   SEVERITY: minor   KIND: unverified
  PROJECT:  pools.rs:111-126 `PoolFile::update` flock on `pools.json.lock`, then load/change/save. `save()` fixed `pools.json.tmp`, no fsync before rename; unlocked `save` at pools.rs:308 shares the temp name. L1 `store_cached` (pools.rs:197-202) random u64 temp name.
  UPSTREAM: `grep pools.json` over crates and docs: nothing. wallet.rs:745-760 only plans a bootstrap for a fresh two-note pool.
  EVIDENCE: flock is mutual exclusion only if all Job pods share one filesystem (volume type not checked). Crash between write and rename leaves a stale `.tmp` (benign).
  FIX:      Confirm PVC/RWX type; random temp name in `save`.   OWNER: iroha

FINDING: Config gates and probes match upstream and live   SEVERITY: minor   KIND: accepted
  PROJECT:  iroha3/network/nexus.toml:98-105, live Secret `peer-bi` peer.toml (nexus section + public keys only), ConfigMap rd-dfabi-peers.
  UPSTREAM: crates/iroha_config/src/parameters/defaults.rs:3247 ENABLED=false, :3249 notice 7200, :3259 max_expiry 7200, :3290 retention 1_000_000, :3301 DEFAULT_MIN_AUDITOR_APPROVALS=1. Probes crates/iroha_torii/src/lib.rs:14308 `handler_livez`, :14249 `handler_readyz`, routes :44048-44049.
  EVIDENCE: live `enabled = true`, `activation_height = 11`, `minimum_activation_notice_blocks = 10` (PoC cut from 7200), `max_expiry_blocks = 7200`; min approvals default 1, driver aps.rs:879 `min_approvals: 1`; `EXPIRY_BLOCKS` 1000 < 7200. peers.json byte-identical live/repo; BLS keys match. Live STS /livez + /readyz timeout 3.
  FIX:      none.   OWNER: lead

FINDING: M2, M2b, M4 CI-tested only; no scenario Job ran with them   SEVERITY: minor   KIND: unverified
  PROJECT:  live bi-auditor runs ghcr.io/radityaaa43/iroha3-rd-driver:be4dd898 (= main HEAD, PR #8). Completed scenario Jobs rd-s1..s4 ran :23f7a444 (older than PRs #5-#8).
  UPSTREAM: n/a.
  EVIDENCE: `kubectl get pods -n iroha3 -o jsonpath=...image`. PR #9 CI recompiles and runs unit tests only.
  FIX:      Re-run S1 (dvp) and S2b (audit-reject) on :be4dd898 before closing.   OWNER: iroha

FINDING: Slow OPA decision (> 3 s) shows as "policy denied" in Lensa   SEVERITY: minor   KIND: unverified
  PROJECT:  k8s.py:290-294 ext_authz `failure_mode_allow=False`, grpc timeout 3s. Lensa maps any 403 to "Ditolak kebijakan di gateway" (fabricx.ts:106).
  UPSTREAM: Envoy ext_authz default `status_on_error` 403 from memory; docs not opened.
  EVIDENCE: not run. Margin over the daily-limit `http.send` is 1 s.
  FIX:      Raise the ext_authz timeout, or distinguish policy deny from authz error.   OWNER: fabric

SOURCES:
- hyperledger-iroha/iroha@071e281e778c5928cab4d6e007b7ddc9b050df27 (files cited); repo docs/ not read
- radityaaa43/iroha3-rd-node-build@be4dd89 driver/src/{aps.rs,pools.rs}
- radityaaa43/iroha3-rd-dfabi@e2a1794 network/nexus.toml, deploy/k8s/base/statefulset.yaml
- rd-lensa-frontend@ed7b78b server/src/adapters/fabricx.ts, app.ts, deadline.ts, gateway.ts, test/fabricx-deadline.test.ts, test/fabricx.test.ts:523
- rd-fabric-x@3f7caeb opa/DESIGN.md:138-158, panurus-itest/scripts/k8s.py:290-299, rdbi/cmd/driver/{api.go,serve.go,main.go}, rdbi/report/report.go
- panurus-itest/.work/panurus (v0.24.0 + patches) token/services/network/fabric/endorsement/fsc/{initiator.go,setup_initiator.go,service.go}
- live read-only: kubectl get cm, sts, svc, pods -n iroha3, -n fabricx

UNVERIFIED:
- docs.iroha.tech not consulted.
- FSC v0.24.0 dial/endorsement timeout knobs.
- kubernetes.io behaviour of a Service with no endpoints.
- Envoy stream_idle_timeout default, ext_authz status_on_error.
- What cuts the report leg at ~129 s vs report.go:44 3 min.
- Volume type behind pools.json.
- qa commit b87e798 not located; equivalent tests read on origin/main.
- M4 wallet-item fee formula vs proof.
