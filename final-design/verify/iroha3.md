# VERIFY-L6: Iroha 3 (model `iroha3`), cutover proof

Owner: `qa`. Status: DRAFT 2026-11-12, not run. Rules, verdict line, API calls and templates: `L6-COMMON.md`. Per-step proofs: `final-design/iroha3/VERIFY.md` (S18 cites this file).
Parties: `rd-iroha3-bi`, `-bank-a`, `-bank-b` (cluster 1), `-bank-c` (cluster 2): four peers, p2p LoadBalancer Service `p2p` on 1337 with ACL-first, BI as auditor (`bi-auditor-key`), APS bundles in shared pools.

## 0. Preconditions
- Idle chain: Iroha makes no block without a transaction. Before the first Lensa or qa tx the chain stays at height 1 (`iroha3-idle-no-blocks`). Liveness before W1 is proven by 4 of 4 peers connected, not by height; the first tx of W1 is what makes block 2.
- The data path of the p2p Services is unproven until S7 (peers running): checks on it are `NOT-RUN` until then.
- Single-note limit (product limit): a payer without one large private note makes a flow fail with `Saldo ... tidak cukup di satu note privat`; `IROHA3_TOPUP=1` tops up through the normal issue flow and is itself a live write (`W0`); without it the flow is `SKIP` (precondition), not FAIL. `iroha3` DFABI is minted through the driver, not a batch top-up (shared-pool mode).
- Blocked: S17 (leg exchange, ADR 0001) and S12 (ADR 0002). The two-leg DvP limit stays recorded.

## 1. Requests for a user word
| W | Action | Duration | Restore | Expected | Rollback |
|---|---|---|---|---|---|
| W0 | optional: `IROHA3_TOPUP=1` top-ups under the flock, cap from the brief | per top-up | none | payer holds one large note | none possible (append-only) |
| W1 | qa runs the 6 flows under the flock (`POST /api/tx`, model `iroha3`; APS txs take minutes: `txDeadlineMs`) | about 6 txs | none | `6 passed`; `BI-DELTA iroha3 ...: PASS` | none possible |
| W2 | R3 forced failure: `iroha` makes one bundle fail at prepare (named in the word request) | one attempt | none | the bundle settles neither leg; balances unchanged | none |
| W3 | R2 observation only (platform is EXEMPT): `iroha` stops one peer pod (not BI) in `rd-iroha3-bank-b` | until the Expected checks are read (state, no fixed time) | scale back | a flow does not commit while the peer is down (accepted limit) | restore, peer `up` in `/api/network?model=iroha3`, one fresh tx commits |

## 2. R1 (iroha3): ALIGNED protocol, GAP in Lensa
- `R1`: `<T>` = the `rd-transfer` A to B of W1. Per party wallet reads through `GET /api/history?model=iroha3&party=A|B|BI|C`: A shows the sent row with `role sender` and `fee` "1" (the RD-leg payer pays the sponsor reimbursement); B shows the received row (`receiver`); BI shows both legs in its auditor store; C (outsider) has no item for `<T>`. Lenses: A, B, BI amount non-null and not `sealed`; C `amount: null`, `sealed`. `GET /api/receipt?...&party=C&tx=<T>` carries no private part.
- Positive control: the same history call returns A's, B's and BI's rows. Negative control: C's call returns no `<T>` row (quoted).
- Recorded, not FAIL: DataspaceRestricted is not a node-level privacy; only APS on the shared pools is relied on (C:123).
- Line: `L6 iroha3 R1: PASS|FAIL`.

## 3. R2 (iroha3): EXEMPT, accepted
Any single peer down stops user txs; an auditor down means no Prepare (A:118-120; G1 liveness test). Record once with W3 if the word is given; else `L6 iroha3 R2: EXEMPT accepted limit (A:4,118)`. qa never runs the stop.

## 4. R3 (iroha3): ALIGNED
- `R3-happy`: `dvp` in W1: one bundle settles both legs: A DFABI -1 and RD +1,000,000 less the fee 1; B DFABI +1 and RD -1,000,001 (`/api/balance` before and after).
- `R3-fail`: W2: neither leg settles; `event: error` quoted; balances unchanged. The two-leg limit (BI sponsor path) is recorded.

## 5. BI-balance proof (BAL)
`L6-COMMON.md` section 5 with the Iroha 3 fee cells (`bi-delta.ts`, iroha `aps.rs:105,1143-1147`, `pools.rs:300-306`): `rd-issue` C RD +1000, BI RD -(1000+1); `dfabi-issue` C DFABI +3, BI RD -1 and DFABI -3 (needs BI DFABI total > 3, else `SKIP`); `rd-transfer` BI 0; `dfabi-transfer` BI RD -1 (companion leg); `dvp` BI 0 (the buyer pays the fee); `award` BI RD +1,000,000 and DFABI -1. P1 baseline: balances from each peer's own read (the wallet read, `iroha` names the command) equal `/api/balance`; the BI auditor store is the BI side of R1; the state file has no balance keys.

## 6. Lensa flows and history
`FLOW`: `6 passed`. `HIST`: A, B, BI list the run's ids; payer rows carry `fee`; C lists its issues only; `x-history-pending` empty.

## 7. Decentralization per bank (read-only)
| ID | Check | PASS | FAIL |
|---|---|---|---|
| D1 | one peer Ready per namespace (`kubectl -n rd-iroha3-<p> get pods`); the roster has 4 distinct PeerIds, each derived from that peer's own BLS key (genesis epoch 0, `next_epoch_roster` none) | 4 distinct, 1 per party | a peer outside its namespace |
| D2 | own submit: each bank's tx goes through its own namespace client and key; BI sponsor path (`cfg.sponsor("bi")`) is the recorded exception until S17 (ADR 0001): `PARTIAL` for full self-submit, not FAIL | per party; S17 PARTIAL noted | a bank key used by another party |
| D3 | no shared key: Secret names per namespace (`bi-auditor-key` keys `bi-auditor.hybrid`, `bi-auditor.seed` only in `rd-iroha3-bi`, key names only); mint-finality keys are per-org triples; public identities pairwise distinct | distinct x4 | an equal identity |
| D4 | 12 ordered `can-i get secrets` = `no`; Lensa host holds no cluster-admin | as stated | any `yes` |
| D5 | all four `p2p` Services: ACL annotations on (`status on`, `type white`, one `id` per cluster) and the netpol `100.64.0.0/10` element present and its own element; positive control (peer cluster egress connects) before negative | per `deviation-LB.py` | an ACL missing |

## 8. Four-of-four matrix (`L6-COMMON.md` section 7; run first)
| Component (per party) | Where to read | Cells |
|---|---|---|
| consensus peer | the Iroha peer pod in `rd-iroha3-<p>` (not Running before S7: then FAIL/NOT-RUN with the reason) | 4 |
| driver (client) | the driver pod/Job in `rd-iroha3-<p>` `[unverified]` | 4 |
| keys | per-party key Secrets (names only; `bi-auditor-key` in `rd-iroha3-bi`) | 4 (BI auditor key 1) |
| gateway + OPA | per party gateway | 4 |
| bundle server | per party `[unverified]` | 4 |
RD/DFABI are in genesis (one instance). Placement: BI, A, B `ap-southeast-5`; C `ap-southeast-1`. Line `L6 iroha3 4OF4`.

## 10. P-check / open R-rows (`L6-COMMON.md` section 9; register `agents/qa/REGISTER.md`)
- P1: D3 + host key listing; P2: D4 + kubeconfig modes; P3: consensus row of section 8; P5: image refs vs the pins in `final-design/iroha3/PLAN.md`; P6: section 8 matrix.
- P4 allowed third parties (cited, everything else FAIL): the APS online auditor (BI today; 2-of-3 auditors BI + bank-a + bank-b built in S11-S13 (README row 19; each auditor key in its own namespace), k-of-n up to 32 supported upstream).
- Open R-rows for this platform: R1, R8 (gateway/OPA 0/4 + 2-of-3 auditors: closes at iroha S14 + S11-S13), R10 (`bi-gov` seed host backup: closes when moved off-host, then shredded), R12 (window-A host forwards + read-lens NOT-RUN: closes at the window-B gateways). `L6 iroha3 OPEN-R` quotes each with its state read now; also R13 FINAL (every RBAC object in `rd-iroha3-<party>` operator-created); any open row = PARTIAL unless `lead` accepts it in writing. R1, R2, R9, R10 = OPEN-PARKED.

## 11. Rerun readiness: pull test (`L6-COMMON.md` gate item 6) and S11-S14 proofs
Pull-test image list per cluster (qa lists, the owner pulls under the GO, qa quotes `PULLED <digest>` per line; cluster 2 on its own):
| Image | Reference (PLAN line) | Used by |
|---|---|---|
| node | `ghcr.io/radityaaa43/iroha3-rd-node:071e281e-stark` (PLAN L104) | the four peers |
| driver | `ghcr.io/radityaaa43/iroha3-rd-driver:<tag from S10>` (tag open, not a digest); the old one is `:c1afa678` (PLAN L137) | pay/pool/auditor driver, scenario Jobs |
| `bi-auditor` | NOT STATED (`deploy/k8s-apps/bi-auditor.yaml`, PLAN L149) | `bi-auditor` |
| Envoy, OPA of `gateway` | NOT STATED (PLAN S14) | `gateway` x4 |
A tag-only or "not stated" reference is a P5 finding to fix before the apply, not a PASS.
S11-S14 proofs: `final-design/iroha3/VERIFY.md` rows S11-S14 (updated 2026-11-12: 2-of-3 A+B decided; auditor keys only in their own namespaces; S14 gateways + `torii-bootstrap` deleted in all four namespaces, probes run by iroha's probe pods and quoted).
Register: R8 (gateway/OPA 0/4 + 2-of-3 auditors) closes only when S11, S12, S13 AND S14 are all done, with the `L6 iroha3 4OF4` gateway row at 4/4 and the policy read `min_approvals` 2 of 3. R12 closes at the S14 window-B gateways: quote that `lensa.env` and `forwards.conf` no longer list Iroha forwards. R10 is not moved by S11-S14 (user-only, OPEN-PARKED). The "bundle server per party" row of section 8 stays `[unverified]`: the PLAN does not describe one for Iroha.
