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
| W2 | R2: `besu` stops the BI Paladin node in `rd-zeto-bi` (method: the S9-supported one, operator CR or sts scale; `besu` names it in the word request) | 300 s | `besu` reverses it the same way | `rd-transfer` A to B and `dvp` A to B settle; BI's report row is missing (LIMIT) | restore, node `up` in `/api/network?model=zeto`, one fresh tx |
| W3 | R3 forced failure: `besu` makes one dvp leg fail (named in the word request: expired or underfunded leg) | one attempt | none | both balances unchanged | none |
| W4 | D-tail: `besu` stops only `besu-validator-0` in `rd-zeto-bi` | 120 s | scale back to 1 | the three other validators keep sealing blocks (4 validators, 3 needed) | restore; block height equal within 2 on all four |

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
| D1 | `kubectl -n rd-zeto-<p> get sts besu-validator -o jsonpath='{.status.readyReplicas}'` for the 4 parties (cluster 2 named read for bank-c); validator address list from the genesis `extraData` or `qbft_getValidatorsByBlockNumber` through a port-forward `[unverified: the API may be off on validators]` | 1 Ready each; 4 distinct addresses | fewer than 4, or a duplicate |
| D2 | `lensa.env` has per-party gateway URLs and no `KUBECONFIG`/kubectl entry (names only); in `GET /api/receipt?...&party=<P>` the submitter of a tx is that party's own Paladin identity | per party | one party's tx signed by another's key |
| D3 | `kubectl -n rd-zeto-<p> get secret -o name` (names only): `besu-nodekey` and the Paladin key Secret in each namespace; public identities pairwise distinct | distinct x4 | any equal |
| D4 | `can-i get secrets` across all 12 ordered pairs of `party-admin` = `no`; `kubectl --kubeconfig <Lensa host file> auth can-i '*' '*' --all-namespaces` = `no` or the file absent (after S20) | all `no` | any `yes` |
| D5 | W4: during the stop the other three validators' `eth_blockNumber` keeps rising; after restore all four within 2 | pass | blocks stall |
