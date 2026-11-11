# VERIFY-L6: Noto + Pente (model `noto`), cutover proof

Owner: `qa`. Status: DRAFT 2026-11-12, not run. Rules, verdict line, API calls and templates: `L6-COMMON.md`. Per-step proofs: `final-design/noto-pente/VERIFY.md` (S13 cites this file).
Parties: the same four per-bank Paladin namespaces as Zeto (shared Paladin namespace per bank, user decision 2026-11-11). Noto notary = BI. Pente groups are `{one bank, BI}`.

## 0. Preconditions
- Runs after Zeto L0-L5 and Zeto S21 (Noto reuses the Zeto nodes). Until then `NOT-RUN` (precondition).
- BI DFABI stock: `dfabi-issue` and `award` are rejected before any lock if BI's DFABI custodian holds less than the amount (`outright.ts:143-144`); no top-up exists. `GET /api/balance?model=noto&party=BI` DFABI below 3 (issue) or 1 (award) gives `SKIP` (precondition), not FAIL.
- Blocked: S5, S14 (ADR 0001, 0002).

## 1. Requests for a user word
| W | Action | Duration | Restore | Expected | Rollback |
|---|---|---|---|---|---|
| W1 | qa runs the 6 flows under the flock (`POST /api/tx`, model `noto`, demo amounts, cap from the brief) | about 6 txs | none | `6 passed`; `BI-DELTA noto ...: PASS` | none possible (append-only) |
| W2 | R3 forced failure: `besu` makes one dvp leg fail (named in the word request) | one attempt | none | both balances unchanged; Atom reverts as a whole | none |
| W3 | Observation for the R2 EXEMPT record only: `besu` stops the BI Paladin node (BI is the notary) | until the Expected checks are read (state, no fixed time) | same method back | a Noto tx is refused while BI is down and succeeds after the restore | restore, node `up`, one fresh tx |

## 2. R1 (noto): ALIGNED with notary BI
- `R1`: `<T>` = the `rd-transfer` A to B of W1. Positive: `GET /api/receipt?model=noto&party=A|B|BI&tx=<T>` full; lenses A `sender`, B `receiver` with amount non-null; BI lens verdict `notarised` or `clear`. Negative: `party=C`: only the state hash, lens `amount: null`, `sealed`; `PD011658` on C's receipt read, quoted; C's history does not list `<T>`.
- Pente: read each group's member list (own namespace, names only): every group is exactly `{one bank, BI}`; two banks in one group breaks R1 (BI would leave the group): FAIL.
- Line: `L6 noto R1: PASS|FAIL <evidence>`.

## 3. R2 (noto, pente): EXEMPT
BI is the notary and submits every Noto tx; BI offline settlement is not claimed. Record once with W3 (if the word is given): refused while BI is down, ok after the restore. Without W3: `L6 noto R2: EXEMPT notary BI (F:145)`. Pente groups also stop with BI down (S9 record).

## 4. R3 (noto)
- `R3-happy`: `dvp` in W1: A DFABI -1 and RD +1,000,000; B DFABI +1 and RD -1,000,000.
- `R3-fail`: W2: balances unchanged, `event: error` quoted, `/api/trace` shows Atom reverted whole.
- Atom.cancel with BI down: BLOCKED (ADR 0002): `NOT-RUN`.

## 5. BI-balance proof (BAL)
`L6-COMMON.md` section 5 with the Noto cells: `rd-issue` C RD +1000, BI 0/0; `dfabi-issue` C DFABI +3 and BI DFABI -3 (the issue is a transfer from BI's custodian, `noto.ts:92`); `rd-transfer`, `dfabi-transfer`, `dvp` BI 0/0; `award` BI RD +1,000,000 and DFABI -1. P1 baseline: the custodian's DFABI balance from the chain equals `/api/balance` BI DFABI; the Noto state file holds no balance keys.

## 6. Lensa flows and history
`FLOW`: `6 passed`. `HIST`: A, B, BI list the run's ids (BI: role `regulator`, verdict `notarised`); C lists its issues only.

## 7. Decentralization per bank
Same D1-D4 as `zeto.md` section 7 (the nodes are shared with Zeto) plus: `D-notary`: the notary key Secret exists only in `rd-zeto-bi` (Secret names, `can-i` from bank namespaces = `no`); each bank's Noto-side signing key is in its own namespace.

## 8. Four-of-four matrix (`L6-COMMON.md` section 7; run first)
Noto and Pente run on the same per-party nodes as Zeto: quote the Zeto matrix cells (Paladin node, Postgres, keys, gateway + OPA, bundle server, consensus node) for `rd-zeto-<p>`, plus per party: the notary key Secret only in `rd-zeto-bi` (BI is the notary, so that one is 1 cell, not 4, and is recorded as the design), and one Pente group member per bank (names only). Placement as Zeto. Line `L6 noto 4OF4`.
