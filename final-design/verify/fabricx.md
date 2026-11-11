# VERIFY-L6: Fabric-X (model `fabricx`), cutover proof

Owner: `qa`. Status: DRAFT 2026-11-12, not run. Rules, verdict line, API calls and templates: `L6-COMMON.md`. Per-step proofs: `final-design/fabricx/VERIFY.md` (S18 cites this file; its S20 is the matching step row).
Parties: `rd-fabricx-bi`, `-bank-a`, `-bank-b` (cluster 1), `-bank-c` (cluster 2). One CA per org (`fca-org1..4`), per-org gateway `fx-gw-<N>` (NodePort on cluster 1, LoadBalancer on cluster 2, mTLS), 3 of 4 endorsement, 3/1 genesis.

## 0. Preconditions
- The Fabric-X token namespace S14 is not done: until it is, every flow below is `NOT-RUN` (precondition: S14), and so are R1 on a tx, R3 and BAL. Decentralization rows (D1-D4) read network objects only and can run earlier.
- Live `rd_dfabi_v2` policy before the S4 query client: not testable.
- Blocked: party placement X/Y (S9-S11, S18) and ADR 0001-0003 until the decision lands.

## 1. Requests for a user word
| W | Action | Duration | Restore | Expected | Rollback |
|---|---|---|---|---|---|
| W1 | qa runs the 6 flows under the flock (`POST /api/tx`, model `fabricx`, demo amounts, cap from the brief) | about 6 txs | none | `6 passed`; `BI-DELTA fabricx ...: PASS` | none possible (append-only ledger) |
| W2 | R2a: `fabric` stops ONE bank's endorsing pod (not BI), e.g. `rd-fabricx-bank-b` | 300 s | scale back | `rd-transfer` and `dvp` between the other two parties still settle | restore, pod Ready, one fresh tx |
| W3 | R2b: `fabric` stops BI's endorsing pod | 300 s | scale back | a transfer settles in about 267 s, inside the 300 s cap | restore, Ready, one fresh tx |
| W4 | R2c: `fabric` stops BI plus one bank | 120 s | scale back | a transfer is refused (accepted, aligned) | restore, Ready, one fresh tx |
| W5 | R3 forced failure: `fabric` makes one action of a dvp tx invalid (named in the word request) | one attempt | none | the whole tx is rejected; both balances unchanged | none |
The pod names and the stop method are named by `fabric` in each word request.

## 2. R1 (fabricx): ALIGNED for non-parties; BI detective
- `R1`: `<T>` = the `rd-transfer` A to B of W1. Positive: lenses A `sender`, B `receiver`, BI `regulator`: amount non-null, verdict not `sealed`; `GET /api/receipt?model=fabricx&party=A|B|BI&tx=<T>` full.
- Gateway read (mTLS with Lensa's cert, each org gateway): `{"op":"records","txid":"<T>"}`: BI returns both rows, A its row, B its row, C exactly `{"records":[]}` (negative control, quoted). Playwright outsider `sealed`, no `Rp`.
- Recorded, not FAIL: the spending graph (input ids) is visible to ledger readers (A:170); the ledger itself holds only Pedersen commitments + ZK proof for C.
- Line: `L6 fabricx R1: PASS|FAIL`.

## 3. R2 (fabricx): ALIGNED, not exempt
`R2a`: W2: `GET /api/network?model=fabricx` shows the stopped node `down`; the flow between the other two parties settles (`txHash`, balances of those two moved). `R2b`: W3: BI down, a transfer still settles (about 267 s, inside the cap; the Lensa tx deadline must be above that `[unverified: adapter.txDeadlineMs]`). `R2c`: W4: refused, `event: error` quoted. Lines: `L6 fabricx R2a|R2b|R2c`.

## 4. R3 (fabricx): ALIGNED
- `R3-happy`: `dvp` in W1: one tx, two actions: A DFABI -1 and RD +1,000,000; B +1 and -1,000,000.
- `R3-fail`: W5: tx rejected as a whole; balances unchanged.

## 5. BI-balance proof (BAL)
`L6-COMMON.md` section 5 with the Fabric-X cells: `rd-issue` C RD +1000, BI 0/0; `dfabi-issue` C DFABI +3, BI 0/0; transfers and `dvp` BI 0/0; `award` BI RD +1,000,000 and BI DFABI stays 0 (BI holds no DFABI stock: its DFABI leg is an issue, `fabricx.ts:140/227`). P1 baseline: balances through each org's own gateway equal `/api/balance`; `state/fabricx.json` has no `kubeconfig`, `namespace` or balance keys (S19).

## 6. Lensa flows and history
`FLOW`: `6 passed`. `HIST`: A, B, BI list the run's ids with the right roles; C lists its issues only.

## 7. Decentralization per bank (read-only)
| ID | Check | PASS | FAIL |
|---|---|---|---|
| D1 | each org's consenter and committer pods Ready in its own namespace: `kubectl -n rd-fabricx-<p> get pods`; the genesis consenter set has 4 distinct certificates | 4 distinct, 1 per org | a consenter outside its org |
| D2 | each org's FSC node runs in its own namespace with its own admin cert (S13): `core.yaml` view-API client cert path is that node's own (ConfigMap read, no Secret); Lensa reaches only gateways | per org | one shared admin cert |
| D3 | no shared CA: `openssl x509 -noout -issuer -subject` on each org's public CA cert gives 4 distinct issuers (`fca-org1..4`); Secret names per namespace (names only) | 4 distinct | a shared issuer |
| D4 | 12 ordered `can-i get secrets` = `no`; no cluster-admin on the Lensa host; `party-admin` Role has `pods/portforward` (create) and no `pods/exec` | as stated | any `yes` |
| D-tail | W2: a bank down does not stop the others (R2a) | pass | stall |
