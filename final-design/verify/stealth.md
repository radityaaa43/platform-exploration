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
| W2 | R2: NOT-RUN until S10 (the BI signer code does not exist yet): then `besu` stops the DFABI certificate signer in `rd-stealth-bi` (pod name from S10 `[unverified]`) | until the Expected checks are read (state, no fixed time) | scale back | RD transfer, `settle()`, `cancel()` work; a DFABI transfer is refused (GAP) | restore, signer Ready, one fresh DFABI tx |
| W3 | R3 forced failure: let one dvp expire, then `cancel()` by a non-party (`besu` runs it) | one attempt | none | both balances unchanged | none |
| W4 | D-tail: `besu` stops `besu-rpc-0` in `rd-stealth-bank-a` only | until the Expected checks are read (state, no fixed time) | scale back | bank-b and BI keep reading and sending; bank-a's reads fail | restore, Ready, block height within 2 |

## 2. R1 (stealth): ACCEPTED limit
- Public by design, recorded not FAIL: amount, token and sender address; the recipient is hidden (user 2026-11-10; Lensa view-key GAP).
- `R1`: `<T>` = `rd-transfer` A to B of W1. Positive: `GET /api/receipt?model=stealth&party=B&tx=<T>` (B scans with its own view key) finds the payment; lens B `receiver`; lens BI verdict `viewkey` (BI's registered view key); lens A `sender`. Negative: `party=C` lens verdict `partial`, `counterparty` null (recipient not linkable), and C's history does not show `<T>` as received.
- Endpoint control (read-only, JWT never printed): a call to `besu-rpc` without the JWT from an allowed pod = `401`; with a valid JWT = `200`; `rpc-http-api` is ETH/NET/WEB3 only (`kubectl -n rd-stealth-<p> get cm besu-rpc-config -o yaml`, no ADMIN).
- Detective: a bank re-registering a new viewing key blinds BI (A:133); the S11 compare job is the check. `L6 stealth R1: LIMIT <evidence>`.

## 3. R2 (stealth): LIMIT for DFABI
Before: signer Ready, `GET /api/network?model=stealth`. During W2: `POST /api/tx` `rd-transfer` A to B ok; `dfabi-transfer` A to B refused with the quoted `reason`. After: a fresh `dfabi-transfer` ok. `L6 stealth R2: LIMIT RD ok, DFABI refused while signer down`. `NOT-RUN` until S10 (signer code) and ADR 0002 land.

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

## 8. Four-of-four matrix (`L6-COMMON.md` section 7; run first)
| Component (per party) | Where to read | Cells |
|---|---|---|
| consensus node | the zeto validators `besu-validator` in `rd-zeto-<p>` (the chain); stealth adds none | 4 |
| `besu-rpc` | sts `besu-rpc` in `rd-stealth-<p>` | 4 |
| signer + scanner | the party's signer and scanner `[unverified: S10; BI signer exists only after S10; banks' signing is per bank]` | 4 |
| keys | `besu-rpc-nodekey`, `stealth-rpc-jwt` (names only), the party's signer key Secret | 4 |
| gateway + OPA | `st-gw-<N>` | 4 |
| bundle server | per party `[unverified]` | 4 |
Placement: BI, A, B `ap-southeast-5`; C `ap-southeast-1`. Line `L6 stealth 4OF4`.

## 9. Standing condition: `stealth-viewkey-compare` (ANALYST, via lead 2026-11-12; active once the S11 CronJob is live)
At EVERY window start, until BI's Lensa lens shows the job status, qa quotes the last run of the CronJob `stealth-viewkey-compare` in `rd-stealth-bi`, read-only: Job name, completion time, result, and the 4 per-party lines. Output as built (rd-besu #63 at `d38f9cc`, `stealth-address/signer/src/compare.ts`, `compareMain.ts once`): one line per party in this fixed order, `<status> <bank> [detail]` for `bi`, `bank-a`, `bank-b`, `bank-c`, then one summary line `compare: 4/4 OK` or `compare: FAIL (<n> not OK)`; exit code 0 only when all four are `OK`. Statuses: `OK`, `MISMATCH` (registry view key differs from BI's held copy, or the registered meta-address is missing/has the wrong length), `unregistered` (no meta-address in ERC-6538), `bad_copy` (BI's copy is not a valid view key for that meta-address), `registry_error` (the RPC read failed: code + short message, any 64+ hex run redacted, cut to 80 chars), `missing_copy` (BI holds no copy for that party); extra copy ids print `ignored` and never count. Nothing in the output is a key (ids, public addresses, lengths only).
Commands (names and job output only; the job's token Secret `stealth-compare-jwt` is never read): `kubectl -n rd-stealth-bi get cronjob stealth-viewkey-compare -o jsonpath='{.status.lastSuccessfulTime}'`; `kubectl -n rd-stealth-bi get jobs -l app=stealth-viewkey,role=compare --sort-by=.status.startTime` (take the last; `.status.succeeded` = 1 means exit 0); `kubectl -n rd-stealth-bi logs job/<name>`. The schedule is every 5 minutes (CronJob `*/5`, `activeDeadlineSeconds` 240): a product feature, not a work pause. A run is current when its completion time is later than the last apply that touched the stealth keys; otherwise read again until a newer Job exists (event: a Job created after the apply).
PASS to start: the last Job succeeded, the summary line is `compare: 4/4 OK` and the four lines are `OK bi`, `OK bank-a`, `OK bank-b`, `OK bank-c`. Any other status on a party, or no current Job: stop and report. `MISMATCH`, `unregistered`, `bad_copy` and `missing_copy` mean the registered key and BI's copy disagree (a bank re-registering a viewing key blinds BI, A:133); `registry_error` means the read failed (RPC, token or registry address): not a proof either way, so also stop. Line `L6 stealth VIEWKEY: PASS|FAIL <job, time, 4 lines + summary>`.
## 10. P-check / open R-rows (`L6-COMMON.md` section 9; register `agents/qa/REGISTER.md`)
- P1: D3 + host key listing; P2: D4 + kubeconfig modes; P3: consensus row of section 8; P5: image refs vs the pins in `final-design/stealth/PLAN.md`; P6: section 8 matrix.
- P4 allowed third parties (cited, everything else FAIL): none required upstream; BI as the registered view-key holder is a deployment choice recorded with `stealth-viewkey-compare`.
- Open R-rows for this platform: R1, R2 (stealth keys copied from the host file: user-exempted, closes only with the S22 destruction record), R3 (`issuerKey` = copy of `deployerKey`: closes at the S12 role moves), R8 (signer/gateway/OPA 0/4: closes at S8-S12), R9 (validator set 8). `L6 stealth OPEN-R` quotes each with its state read now; also R13 FINAL (every RBAC object in `rd-stealth-<party>` operator-created); any open row = PARTIAL unless `lead` accepts it in writing. R1, R2, R9, R10 = OPEN-PARKED.

## 11. Rerun readiness: pull test (`L6-COMMON.md` gate item 6) and S7-S12, S17 proofs
Pull-test image list per cluster (qa lists, the owner pulls under the GO, qa quotes `PULLED <digest>` per line; cluster 2 on its own): the only image the PLAN names is `hyperledger/besu:26.8.1` (S4, a tag, no digest). The `stealth-signer` image (S8, image build only), the scanner (same pod), the BI signer/scanner (S10), the compare-job image (S11) and the Envoy/OPA of `st-gw` (S17) are NOT STATED. A "not stated" reference is a P5 finding to fix before the apply, not a PASS.
Step notes (from PLAN, 2026-11-12):
- S7: plain Secret `stealth-keys` per namespace (no Vault); read `get secret stealth-keys -o name` per ns, names and sizes only; `can-i get secrets` as `party-admin` = `no`.
- S9: also read `party-admin-token` (NotFound before, present after, name only) and `can-i get secrets` still `no`; holdings and meta-address equal in three places (signer, Lensa state, `ERC6538Registry`). No key rotation (cancelled): the keys are copies, R2 stays OPEN-PARKED.
- S10 and S11 are UNBUILT (PLAN L125, L136): `ROLE=bi` and the BI key store `stealth-bi-keys` do not exist yet, so their rows are `NOT-RUN (precondition)`; W2 stays NOT-RUN until S10. The compare job's output is built in rd-besu #63 (4 per-party lines + summary, section 9); VERIFY.md S11 is aligned to it.
- S12 (custodian + roles) is BLOCKED (custodian party, ADR 0004): read-only proof by `eth_call` only: `bond.owner()`, `controllers()`, `isMinter(new)`, `validator.isCertificateSigner(bond,new)`, `isAllowlisted(bond,new)`, `DvPFactory(new).custodian()`, `bond.isControllable()` = true.
- The gateway + OPA of stealth is S17 (not S8-S12); cluster 2 gets one extra CLB `st-gw-1-ext`.
Register: R8 (stealth part) needs S8-S10 AND S17 deployed 4/4 (`L6 stealth 4OF4`); R3 closes only at the S12 role moves (quote the role reads above); R2 stays OPEN-PARKED (S22 destruction record).
