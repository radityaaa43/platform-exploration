# Design-principle break register (P1-P6 hard gates)

Source: orchestrator relay 2026-11-12 (analyst, user order "P1-P6 are HARD GATES"), via `lead`. Not yet in a repo elsewhere; `qa` keeps this copy for the L6 plans (`final-design/verify/`). Principles P1-P6 = `agents/analyst/design/README.md` principles 1-6 (P1 keys stay with their owner; P2 one admin domain per party; P3 each bank runs its own consensus node; P4 only upstream-required third parties; P5 settings over code; P6 four parties on every platform, every component).

Rule: a platform PASS lists its open R-rows. An open row makes the verdict PARTIAL unless `lead` accepts it in writing. A row closes only with a quoted proof line (command, value, time); a message that "it is done" closes nothing. `qa` never closes a row on its own word.

| Row | P | Break | Closes when | State (2026-11-12) |
|---|---|---|---|---|
| R1 | P1, P6 | The Lensa host holds chain keys, bundle-signing keys, sink tokens and client certs | keyless Lensa cutover + the S22 destruction record (user-only shred) | open |
| R2 | P1 | Stealth keys were copied from the host file. EXEMPTED by the user (cluster Secrets, no rotation) | ONLY with the S22 destruction record of the stealth key files | open (exempted) |
| R3 | P1 | The stealth `issuerKey` is a copy of `deployerKey` (cert signer / owner / controller) | the S12 role moves; issuer immutable = S22 residual | open |
| R4 | P2 | Fabric-X CA admin passwords of 4 orgs on one host | S15 + a password change per org at handover + host copy destroyed; blocks new uses | open |
| R5 | P2 | Namespace-ceremony admin keys must never be co-located (any co-location falls under R4) | n/a: standing prohibition, checked at every ceremony | standing |
| R6 | P1 | Fabric-X `ids/anon` creator key shared in every org pod | permanent on this channel; user exemption pending | open (exemption pending) |
| R7 | P6 | Paladin 0/0, live 4 in old Jakarta | S21 | open until S21 closes |
| R8 | P6 | Stealth signer/gateway/OPA 0/4; Fabric-X `fx-gw`/OPA 0/4 + `rd_dfabi_v2`; Iroha gateway/OPA 0/4 + 2-of-3 auditors | stealth S8-S12; fabricx S14/S16; iroha S14 + S11-S13 | open |
| R9 | P3, P6 | The QBFT validator set is 8 | S5b (user-only) | open |
| R10 | P1 | Iroha `bi-gov` seed host backup | moved off-host, then shredded (user) | open |
| R11 | P2 | `lensa-publisher` SA in `rd-zeto-bi` | zeto S20 | open |
| R12 | P1, P4 | Iroha window-A host forwards + read-lens NOT-RUN | the window-B gateways | open |
| R13 (PROPOSED, P2, awaiting decision) | P2 | Role/RoleBinding `reconcile` in `rd-fabricx-bi` created by cluster-admin | BI's own admin domain re-applies it | proposed |

Proof lines `qa` can quote read-only (names and modes only; no Secret value, no key content is ever read):
- R1: `ls -l ~/.opa-keys ~/.opa-sink-tokens ~/.opa-mtls-party` (listing and modes) and `grep -nE "KUBECONFIG|keyFile|deployerKey" lensa.env` (names only); closes when the directories are absent and the S22 record (names, date, no values) is quoted.
- R2, R10: the destruction record is a written line by the owner (names, date); qa quotes it and re-lists the path: absent.
- R3: the S12 role-move tx ids and `kubectl -n rd-stealth-bi get secret -o name` (names).
- R4, R5: `ls -l` of the CA admin password files on the host (absent) and the per-org handover record.
- R7, R9: `kubectl -n paladin get sts` (0/0) and `qbft_getValidatorsByBlockNumber latest` (4 addresses).
- R8: the 4/4 matrix (`L6-COMMON.md` section 7).
- R11: `kubectl -n rd-zeto-bi get sa lensa-publisher` NotFound.
- R12: `lensa.env` forwards absent, gateway URLs present.
- R13: `kubectl -n rd-fabricx-bi get role,rolebinding reconcile -o jsonpath='{.metadata.managedFields[*].manager}'` shows BI's own admin manager.
