# VERIFY-L6: Zeto (model `zeto`), cutover proof

Owner: `qa`. Status: DRAFT 2026-11-12, not run. Rules, verdict line, API calls and templates: `L6-COMMON.md` (read it first). Per-step proofs: `final-design/zeto/VERIFY.md` (S21 cites this file).
Parties: `rd-zeto-bi`, `rd-zeto-bank-a`, `rd-zeto-bank-b` (cluster 1), `rd-zeto-bank-c` (cluster 2). Four Besu QBFT validators (`besu-validator`) + one Paladin node per party; tokens are Zeto_AnonNullifier V1.

## 0. Preconditions
- Zeto cutover S21 is not done: until Lensa serves the new stack, every Lensa check below is `NOT-RUN` (precondition). Checks marked (C) read the new chain without Lensa and can run earlier.
- Zeto flows are serialized (nullifier SMT divergence): one flow at a time, never two runs.
- Blocked ADRs (S7, S11, S12, S13, S18) keep their rows blocked; not part of this run.

## 1. Requests for a user word (nothing here runs without it)
| W | Action | Duration | Restore | Expected | Rollback |
|---|---|---|---|---|---|
| W1 | qa runs the 6 flows in one detached run under the flock: `POST /api/tx` for rd-issue, rd-transfer, dfabi-issue, dfabi-transfer, dvp, award (demo amounts, cap from the brief) | about 6 txs | none | `6 passed`; `BI-DELTA zeto <flow> ...: PASS` per cell | none possible (append-only); amounts are demo |
| W2 | R2: `besu` stops the BI Paladin node in `rd-zeto-bi` (method: the S9-supported one, operator CR or sts scale; `besu` names it in the word request) | until the Expected checks are read (state, no fixed time) | `besu` reverses it the same way | `rd-transfer` A to B and `dvp` A to B settle; BI's report row is missing (LIMIT) | restore, node `up` in `/api/network?model=zeto`, one fresh tx |
| W3 | R3 forced failure: `besu` makes one dvp leg fail (named in the word request: expired or underfunded leg) | one attempt | none | both balances unchanged | none |
| W4 | D-tail: `besu` stops only `besu-validator-0` in `rd-zeto-bi`. Run ONLY after S5b (old 4 validators voted out, QBFT set n=4). Before S5b the set is n=8 (old 4 + new 4), quorum 6, and the team rule is never two of bi/bank-a/bank-b down at once: restated for n=8 it is one new validator down, 7 of 8 sealing, quorum 6 still met; qa does not ask for it before S5b | until the Expected checks are read (state, no fixed time) | scale back to 1 | after S5b: the three other validators keep sealing (4 validators, 3 needed); before S5b: `NOT-RUN` | restore; block height equal within 2 on all validators |

## 2. R1 (zeto): LIMIT, partial by design
- Check `R1`: tx `<T>` = the `rd-transfer` A to B of W1 (`event: result` `txHash`).
- Positive control: `GET /api/receipt?model=zeto&party=A&tx=<T>` and `party=B` and `party=BI`: `node` present (Paladin states), `lenses[]` for A (role `sender`), B (`receiver`), BI (`regulator`) have `amount` non-null and verdict not `sealed`.
- Negative control: `party=C` (outsider): the call returns the public receipt only and `node` is null or carries `PD011658` (the Paladin refusal on the base receipt), quoted; C's lens `amount: null`, verdict `sealed`; `GET /api/history?model=zeto&party=C` does not list `<T>`.
- Recorded, not FAIL: BI is not a passive observer on Zeto (the on-chain event shows `msg.sender`); BI learns the tx through the bank's Pente report `{bank, BI}` (A:153).
- Line: `L6 zeto R1: LIMIT <evidence>` if the controls hold; FAIL if C's lens shows an amount.

## 3. R2 (zeto): LIMIT
- Before W2: `GET /api/network?model=zeto` all nodes `up`; baseline `GET /api/balance` for A and B.
- During W2: `GET /api/network?model=zeto` shows the BI Paladin node `down`; `POST /api/tx` `rd-transfer` A to B, then `dvp` A to B. PASS for settlement: `txHash` returned and A, B balances moved by the flow amounts. `[unverified: whether /api/tx tolerates BI's lens being unreadable (adapter.lens for BI); if the run errors at the lens step, settlement is proven by the A/B balance reads and the A/B history rows, and the error line is quoted]`.
- After restore: BI's row for those tx ids is missing from `GET /api/history?model=zeto&party=BI` (live test 2026-11-10: `pgroup_sendMessage` reports fail unqueued); qa records the tx ids.
- Line: `L6 zeto R2: LIMIT settlement ok, BI report row missing, tx <ids>`.

## 4. R3 (zeto): ALIGNED, Atom.cancel open
- `R3-happy`: `dvp` in W1: A DFABI -1 and RD +1,000,000; B DFABI +1 and RD -1,000,000 (`/api/balance` before and after); one `txHash`.
- `R3-fail`: W3: `event: error` quoted; both balances equal to before; `GET /api/trace?model=zeto&party=A&tx=<T>` shows no completed leg without the other.
- Atom.cancel with BI down: BLOCKED (ADR 0003): `L6 zeto R3-cancel: NOT-RUN blocked ADR 0003`.

## 5. BI-balance proof (BAL)
Per `L6-COMMON.md` section 5: P1 baseline (`/api/balance` x4 plus the direct chain read `besu` names; state file `state/zeto.json` has no balance keys). In W1: `rd-issue`: C RD +1000, BI 0/0. `dfabi-issue`: C DFABI +3, BI 0/0. `rd-transfer` and `dfabi-transfer` BI 0/0. `dvp` BI 0/0. `award`: BI RD +1,000,000, BI DFABI -1 (needs BI DFABI >= 1, else a batch top-up mints first: `SKIP`, not FAIL). The S21 compare also reads tx `0x664c1faf2f09...` on each party before and after cutover.
Lines: `L6 zeto BAL-P1`, `BAL-issue`, `BAL-award`, each PASS/FAIL/SKIP.

## 6. Lensa flows and history (FLOW, HIST)
- `FLOW`: W1 prints `6 passed`; each flow's `result.lenses` has four entries (BI, A, B, C).
- `HIST`: after W1, `GET /api/history?model=zeto&party=A|B|BI` list the run's tx ids (A: `role sender`, B: `receiver`, BI: `regulator`); `party=C` lists the two issues it received and not the A-to-B transfers; `x-history-pending` empty.

## 7. Decentralization per bank (read-only; (C) rows run before S21)
| ID | Check | PASS | FAIL |
|---|---|---|---|
| D1 | `kubectl -n rd-zeto-<p> get sts besu-validator -o jsonpath='{.status.readyReplicas}'` for the 4 parties (cluster 2 named read for bank-c); validator address list from the genesis `extraData` or `qbft_getValidatorsByBlockNumber` through a port-forward `[unverified: the API may be off on validators]` | 1 Ready each; BEFORE S5b: 8 distinct validators (old 4 + new 4), quorum 6; AFTER S5b: 4 distinct (the new ones), the old 4 gone | fewer than expected for the phase, or a duplicate |
| D2 | `lensa.env` has per-party gateway URLs and no `KUBECONFIG`/kubectl entry (names only); in `GET /api/receipt?...&party=<P>` the submitter of a tx is that party's own Paladin identity | per party | one party's tx signed by another's key |
| D3 | `kubectl -n rd-zeto-<p> get secret -o name` (names only): `besu-nodekey` and the Paladin key Secret in each namespace; public identities pairwise distinct | distinct x4 | any equal |
| D4 | `can-i get secrets` across all 12 ordered pairs of `party-admin` = `no`; `kubectl --kubeconfig <Lensa host file> auth can-i '*' '*' --all-namespaces` = `no` or the file absent (after S20) | all `no` | any `yes` |
| D5 | W4 (after S5b only; before it `NOT-RUN`): during the stop the other three validators' `eth_blockNumber` keeps rising; after restore all four within 2 | pass | blocks stall |

## 8. Four-of-four matrix (`L6-COMMON.md` section 7; run first)
| Component (per party) | Where to read | Cells |
|---|---|---|
| QBFT consensus node | sts `besu-validator` in `rd-zeto-<p>` (n=8 before S5b: also the old `besu` ns validators, which do not count toward 4/4) | 4 |
| Paladin node | sts `paladin-node<N>` (CR `node<N>`) in `rd-zeto-<p>` | 4 |
| Paladin Postgres | `paladin-pg` in `rd-zeto-<p>` | 4 |
| keys | Secrets `besu-nodekey`, `node<N>.keys` (names only) | 4 |
| gateway + OPA | `bank-gw-<N>` (Ready, OPA sidecar or pod) | 4 |
| bundle server | `bundle-server` per party `[unverified: BI only today; if it runs only in rd-zeto-bi, record PARTIAL, not 4/4]` | 4 |
Placement: BI, A, B `ap-southeast-5`; C `ap-southeast-1`. Line `L6 zeto 4OF4`.

## 10. P-check / open R-rows (`L6-COMMON.md` section 9; register `agents/qa/REGISTER.md`)
- P1: D3 + host key listing; P2: D4 + kubeconfig modes; P3: consensus row of section 8; P5: image refs vs the pins in `final-design/zeto/PLAN.md`; P6: section 8 matrix.
- P4 allowed third parties (cited, everything else FAIL): BI as the report-group member (Zeto has no observer role; analyst A:153); no other.
- Open R-rows for this platform: R1 (host keys), R7 (Paladin 0/0, live 4 in old Jakarta: closes at S21 with `kubectl -n paladin get sts` 0/0), R9 (validator set 8: closes at S5b), R11 (`lensa-publisher` SA in `rd-zeto-bi`: closes at zeto S20). `L6 zeto OPEN-R` quotes each with its state read now; also R13 FINAL (every RBAC object in `rd-zeto-<party>` operator-created; closes as in `agents/qa/REGISTER.md`); any open row = PARTIAL unless `lead` accepts it in writing. R1, R2, R9, R10 = OPEN-PARKED. R14 open (standing residual: the Paladin fork logs its DB DSN with the password at WARN on every start; every log read here is redacted of `postgres://...@`).

## 11. S21 rerun readiness (attempt 1 was rolled back: new nodes `ImagePullBackOff`, no new-node tx ever happened)
Entry gate for the rerun (all read now, `L6-COMMON.md` section 1 items 1-7): (1) the S21 rollback check PASS (old `paladin-node1..4` Ready, old operator 1, new sts 0, pending `[]` x4, Lensa active with 5 reads, one Zeto and one Noto history read per party); (2) served sha = `41607a7f173b477fea7977c8bc7b04cdae5b2115` and noto history 200 x4; (3) pull test of every image digest in each target namespace: the owner runs the pull pod per cluster under the GO, qa lists and quotes.
Pull-test image list (cluster 1 `rd-zeto-{bi,bank-a,bank-b}`, cluster 2 `rd-zeto-bank-c` on its own): the new Paladin node = the running fork image `ghcr.io/radityaaa43/paladin@sha256:6f113f38...` (S21 text D3; full digest and "equals the fork checkout HEAD" are `[unverified]`: the owner quotes the full digest); `hyperledger/besu:26.8.1` (validators; tag, no digest: P5 finding); the `paladin-pg` Postgres image `[unverified]`; the Paladin operator image `[unverified]`; the `bank-gw-<N>` Envoy and OPA images `[unverified]`. Which image failed to pull in attempt 1 is not stated here: the owner's pull-pod line per image answers it. A tag-only or unknown reference is a P5 finding, not a PASS.
The old stack stays untouched until S22; no qa, stress or script tx goes to the old Paladin nodes or Lensa zeto/noto/pente from 02:45 CST until S21 closes (analyst Q14).
Layer-7 entry gate also quotes proof 3 (R14 / R14-c2): per new node the two log counts = 0 (`L6-COMMON.md` gate item 8). Register: S21 closes R7 with besu's g1 read (new `paladin-node` per party Running in its own namespace and cluster, old at 0). R9 stays OPEN-PARKED (S5b parked), so the Zeto/Noto verdict is PARTIAL by design. R1 and R11 close at the keyless Lensa cutover (S19/S20); R13 at its end step.
