# VERIFY-L6: Stealth (model `stealth`), cutover proof

Owner: `qa`. Status: DRAFT 2026-11-12, not run. Rules, verdict line, API calls and templates: `L6-COMMON.md`. Per-step proofs: `final-design/stealth/VERIFY.md` (S20 cites this file).
Parties: `rd-stealth-bi`, `-bank-a`, `-bank-b` (cluster 1), `-bank-c` (cluster 2). Chain = the Zeto Besu QBFT validators. Each party runs `besu-rpc` (JWT, ETH/NET/WEB3 only, non-validator) peered to its OWN party's validator only (user decision 2026-11-11).

## 0. Preconditions
- Depends on the Zeto validators: stealth runs after Zeto L0-L5 and S21; before that `NOT-RUN` (precondition).
- `rd-stealth-bank-c` was empty with B1c on hold: if it is still empty, the platform is not ready.
- Blocked: S12, S13, S14 (ADR 0001, 0002, 0003): the DFABI certificate-signer proof waits for ADR 0002.

## 1. Requests for a user word
| W | Action | Duration | Restore | Expected | Rollback |
|---|---|---|---|---|---|
| W1 | qa runs the 6 flows under the flock (`POST /api/tx`, model `stealth`, demo amounts, cap from the brief) | about 6 txs | none | `6 passed`; `BI-DELTA stealth ...: PASS` | none possible (append-only) |
| W2 | R2: `besu` stops the DFABI certificate signer in `rd-stealth-bi` (pod name from S10 `[unverified]`) | 300 s | scale back | RD transfer, `settle()`, `cancel()` work; a DFABI transfer is refused (GAP) | restore, signer Ready, one fresh DFABI tx |
| W3 | R3 forced failure: let one dvp expire, then `cancel()` by a non-party (`besu` runs it) | one attempt | none | both balances unchanged | none |
| W4 | D-tail: `besu` stops `besu-rpc-0` in `rd-stealth-bank-a` only | 120 s | scale back | bank-b and BI keep reading and sending; bank-a's reads fail | restore, Ready, block height within 2 |

## 2. R1 (stealth): ACCEPTED limit
- Public by design, recorded not FAIL: amount, token and sender address; the recipient is hidden (user 2026-11-10; Lensa view-key GAP).
- `R1`: `<T>` = `rd-transfer` A to B of W1. Positive: `GET /api/receipt?model=stealth&party=B&tx=<T>` (B scans with its own view key) finds the payment; lens B `receiver`; lens BI verdict `viewkey` (BI's registered view key); lens A `sender`. Negative: `party=C` lens verdict `partial`, `counterparty` null (recipient not linkable), and C's history does not show `<T>` as received.
- Endpoint control (read-only, JWT never printed): a call to `besu-rpc` without the JWT from an allowed pod = `401`; with a valid JWT = `200`; `rpc-http-api` is ETH/NET/WEB3 only (`kubectl -n rd-stealth-<p> get cm besu-rpc-config -o yaml`, no ADMIN).
- Detective: a bank re-registering a new viewing key blinds BI (A:133); the S11 compare job is the check. `L6 stealth R1: LIMIT <evidence>`.

## 3. R2 (stealth): LIMIT for DFABI
Before: signer Ready, `GET /api/network?model=stealth`. During W2: `POST /api/tx` `rd-transfer` A to B ok; `dfabi-transfer` A to B refused with the quoted `reason`. After: a fresh `dfabi-transfer` ok. `L6 stealth R2: LIMIT RD ok, DFABI refused while signer down`. Blocked until ADR 0002: `NOT-RUN`.

## 4. R3 (stealth): ALIGNED
- `R3-happy`: `dvp` in W1: A DFABI -1, RD +1,000,000; B +1, -1,000,000; one `settle()` tx.
- `R3-fail`: W3: balances unchanged; `cancel()` by anyone after expiry returns the escrow.

## 5. BI-balance proof (BAL)
`L6-COMMON.md` section 5 with the stealth cells: issues mint straight to the receiver (`mintStealth`): `rd-issue` C RD +1000, BI 0/0; `dfabi-issue` C DFABI +3, BI 0/0; transfers and `dvp` BI 0/0; `award` BI RD +1,000,000, DFABI -1 (BI inventory, per free BI address: skip if BI DFABI total < 1). P1 baseline: balances read by `eth_call` `balanceOf` through each party's own `besu-rpc` equal `/api/balance`; `state/stealth.json` has no key or balance fields (S21).

## 6. Lensa flows and history
`FLOW`: `6 passed`. `HIST`: B lists `<T>` as received; A as sent; BI lists it (`viewkey`); C does not list it as received (outsider verdict `partial`).

## 7. Decentralization per bank (read-only)
| ID | Check | PASS | FAIL |
|---|---|---|---|
| D1 | `kubectl -n rd-stealth-<p> get cm besu-static-nodes,besu-rpc-config -o yaml`: static-nodes has exactly ONE enode = the own party's validator pod `IP:30303`; `sync-min-peers=1`; `discovery-enabled=false` | x4 | 3 enodes, or another party's |
| D2 | the party's signer and scanner run in its own namespace (BI in `rd-stealth-bi`); Lensa submits through that party's `st-gw-<N>` with a per-party mTLS cert; no key fields in `state/stealth.json` | per party | shared `deployerKey` or key fields in the state file |
| D3 | `besu-rpc-nodekey` and `stealth-rpc-jwt` per namespace (names; keys `private.pem`, `public.pem`); the pod mounts only `public.pem`; `sha256` of each party's `public.pem` (a public file) pairwise distinct | distinct x4 | equal, or `private.pem` mounted |
| D4 | 12 ordered `can-i get secrets` = `no`; `create pods --subresource=exec` = `no` except the named `pods/vault-0` rule; no cluster-admin on the Lensa host | as stated | any `yes` |
| D5 | `deployerKey` retired (S15): the old holder's roles removed (user-only; qa reads the state after) | removed | role remains |
| D-tail | W4: others unaffected | pass | other parties fail |
