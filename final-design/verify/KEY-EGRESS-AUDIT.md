# Key-holder egress audit, merged (qa, 2026-11-12, read-only)

Format: ANALYST KEY-EGRESS-AUDIT-FORMAT (2026-11-12). Scope: every rd-* namespace on c1 and the named rd-*-bank-c namespaces on c2 (rd-zeto, rd-stealth, rd-fabricx, rd-iroha3; rd-lensa on c1). No Secret value is read anywhere: Secret NAMES only.
Sources: owner files from `besu` (rd-zeto-*, rd-stealth-*), `fabric` (rd-fabricx-*), `iroha` (rd-iroha3-*), `fe` (rd-lensa). Each owner row was re-read by qa: the table below is qa's own live read (`kubectl get sts,deploy,ds,job,cronjob,pod` templates + `get networkpolicy`, effective egress = UNION of every NetworkPolicy that selects the template labels with policyTypes Egress; none selecting = ALL), cross-checked against the owners' files. Reproduce: `egress-union.py` / `key-egress-scan.py` (qa scratchpad; read-only; self-test with a RED mutant).

## Cross-check result
- Rows: 85 key-mounting workload templates read live; every one has an owner row (iroha lists its bank-c rows under 'rd-iroha3-bank-c (c2)'), and every owner row that is live is in qa's read; the only owner rows not live are the ones the iroha file itself marks as render only (`Deployment/gateway`, `Deployment/auditor`, `Job/pool-init`: confirmed absent live today, so nothing to hold yet).
- Effective egress agrees with the owners on every row: all long-running key holders are open (ALL) except the Lensa pod (DNS only = narrower than intended). The Zeto Paladin nodes are now UNRESTRICTED: `rehearsal-no-9000-egress` was deleted in S21 attempt 3 (besu: 04:54:44 and 04:55:17 CST); an earlier qa scan at ~04:50 still saw it selecting them (stale, not a difference).
- `rd-fabricx-*`: 13 rows per namespace (fabric: 13 per ns = 52) and `allow-dns-egress` now selects only pods WITHOUT the `rd/egress-locked` label in all four namespaces (qa re-read the selector: `matchExpressions rd/egress-locked DoesNotExist`, bi, bank-a, bank-b, bank-c). No live workload carries the label yet (fabric: label `-` on all 52).
- Name heuristic caveat: qa classifies key Secrets by NAME pattern (key, keys, peer, credential, mtls, tls, admin, endorser, auditor, gov, jwt, signing, nodekey, seed, token, cert, password, secret); a key Secret with an unrelated name would be missed by qa's scan, which is why the owners' lists win.

## One-off Jobs
| ns | Job | key Secrets | effective egress | verdict | source |
|---|---|---|---|---|---|
| rd-zeto-bank-a, bank-b, bank-c | Job/pg-pw-rotate (option D, ran 04:41:18-04:42:01 CST, deleted) | paladin-pg-credentials (+ SA token) | paladin-pg:5432 + API server /32 on 443 and 6443 | OK (ran; recorded) | besu |
| rd-zeto-bi | Job/pg-pw-rotate (ran 04:42:15-22, deleted) | same | own `pg-pw-rotate` + `rehearsal-no-9000-egress` (present then, app=paladin): union = any destination except TCP 9000 = effectively open | DISCLOSED residual: not enforced on bi; no rotation recommended (the Job only contacted paladin-pg and the API; paladin-pg accepts only app=paladin pods of its own namespace, so an exfiltrated DB password is useless outside) | besu |
| rd-fabricx-bi / bank-c / bank-a | Job/s14-endorse-tx1 x3 (orderer-admin-1/4/2 secrets, ran 20:37:10-:21Z / ~20:40:50-:04Z / ~20:41:13-:19Z, removed by ttl 900 s) | orderer-admin-<N>-secret (msp key + cert) | open at the time (`allow-dns-egress` matched every pod), 0 egress seen | R16 (recorded residual: no evidence of misuse, 0 PRIVATE KEY in logs, bounded by MAJORITY 3-of-4 (ADR 0003), no rotation path, detective check on config txs) | fabric |
| rd-fabricx-* | submit + read-back Jobs (committer-tls, orderer-admin) | committer-tls + orderer-admin | locked: `s14-endorse-deny-all`, `s14-submit-egress`, `rd/egress-locked` label | HELD until the (iv) proof in rd-fabricx-bi (ACCEPTED by lead: probe e1 all CLOSED, e2 only router/sidecar/query/dns OPEN); R16 closed for FUTURE labelled Jobs in rd-fabricx-bi, the other 3 ns applied 20:58-21:00Z with the same probes quoted by fabric | fabric |
| rd-iroha3-bi | Job/pool-init (NOT live; render dfabi #46) | bi-gov-key, bi-keys (note only), iroha3-client-cert | would be DNS + BI Torii 8080 + 3 gateways 8443 | HELD until #46 is merged, applied and probe-proved | iroha |
| any future zeto / stealth / iroha / lensa Job | pattern | - | - | HELD until the (iv) pattern: `rd/egress-locked` label, allow-all excludes it, its own narrow policy, quote the union of ALL selecting Egress policies first, probe proof | besu / iroha |

## Findings for owners (not blocking)
- fabric: `rd-fabricx-bi` still holds the probe policies `s14-probe-e1-egress` and `s14-probe-e2-egress` (qa read `get netpol -o name`); delete them if they were throwaway (the probe window is closed).
- besu: stealth signers, gateways and vault are not deployed yet; only `besu-rpc` mounts `stealth-rpc-jwt` (a JWT public key); `allow-dns-egress` there selects every pod, so any future one-off key Job in `rd-stealth-*` starts HELD.
- iroha: all four namespaces have NO Egress-typed policy; peers x4 and drivers x4 are open (R17).
- R1 (one line): the host Lensa process (`lensa.service`) holds chain keys, bundle-signing keys, sink tokens and client certs on disk; it is not a pod and is not an egress row.

## Table: one row per key-mounting template (85 rows; verdict R17 = long-running key holder with open egress, end step: one narrow egress policy per role with a probe proof; HELD = one-off Job that does not run before the (iv) pattern; OK = effective egress equals or is narrower than intended)
| cl | ns | workload | one-off? | key-ish Secrets mounted (names only) | NetworkPolicies selecting it (Egress) | effective egress (UNION) | verdict | owner row |
|---|---|---|---|---|---|---|---|---|
| c1 | rd-fabricx-bank-a | statefulset/committer-db | no | committer-db-credentials, committer-db-tls | allow-dns-egress, committer-traffic | ALL (allow-dns-egress, committer-traffic) | R17 | fabric |
| c1 | rd-fabricx-bank-a | statefulset/committer-sidecar | no | committer-tls | allow-dns-egress, committer-traffic | ALL (allow-dns-egress, committer-traffic) | R17 | fabric |
| c1 | rd-fabricx-bank-a | statefulset/orderer-assembler-2 | no | orderer-assembler-2-secret | allow-dns-egress | ALL (allow-dns-egress) | R17 | fabric |
| c1 | rd-fabricx-bank-a | statefulset/orderer-batcher-2 | no | orderer-batcher-2-secret | allow-dns-egress | ALL (allow-dns-egress) | R17 | fabric |
| c1 | rd-fabricx-bank-a | statefulset/orderer-consenter-2 | no | orderer-consenter-2-secret | allow-dns-egress | ALL (allow-dns-egress) | R17 | fabric |
| c1 | rd-fabricx-bank-a | statefulset/orderer-router-2 | no | orderer-router-2-secret | allow-dns-egress | ALL (allow-dns-egress) | R17 | fabric |
| c1 | rd-fabricx-bank-a | deployment/committer-coordinator | no | committer-tls | allow-dns-egress, committer-traffic | ALL (allow-dns-egress, committer-traffic) | R17 | fabric |
| c1 | rd-fabricx-bank-a | deployment/committer-query | no | committer-db-credentials, committer-db-tls, committer-tls | allow-dns-egress, committer-traffic | ALL (allow-dns-egress, committer-traffic) | R17 | fabric |
| c1 | rd-fabricx-bank-a | deployment/committer-vc | no | committer-db-credentials, committer-db-tls, committer-tls | allow-dns-egress, committer-traffic | ALL (allow-dns-egress, committer-traffic) | R17 | fabric |
| c1 | rd-fabricx-bank-a | deployment/committer-verifier | no | committer-tls | allow-dns-egress, committer-traffic | ALL (allow-dns-egress, committer-traffic) | R17 | fabric |
| c1 | rd-fabricx-bank-a | deployment/fca-org2 | no | fca-org2-admin | allow-dns-egress | ALL (allow-dns-egress) | R17 | fabric |
| c1 | rd-fabricx-bank-a | deployment/fx-gw-2 | no | fx-gw-2-peer | allow-dns-egress | ALL (allow-dns-egress) | R17 | fabric |
| c1 | rd-fabricx-bank-a | deployment/rdbi-bank2 | no | fsc-endorser-2-secret | allow-dns-egress, rdbi-traffic | ALL (allow-dns-egress, rdbi-traffic) | R17 | fabric |
| c1 | rd-fabricx-bank-b | statefulset/committer-db | no | committer-db-credentials, committer-db-tls | allow-dns-egress, committer-traffic | ALL (allow-dns-egress, committer-traffic) | R17 | fabric |
| c1 | rd-fabricx-bank-b | statefulset/committer-sidecar | no | committer-tls | allow-dns-egress, committer-traffic | ALL (allow-dns-egress, committer-traffic) | R17 | fabric |
| c1 | rd-fabricx-bank-b | statefulset/orderer-assembler-3 | no | orderer-assembler-3-secret | allow-dns-egress | ALL (allow-dns-egress) | R17 | fabric |
| c1 | rd-fabricx-bank-b | statefulset/orderer-batcher-3 | no | orderer-batcher-3-secret | allow-dns-egress | ALL (allow-dns-egress) | R17 | fabric |
| c1 | rd-fabricx-bank-b | statefulset/orderer-consenter-3 | no | orderer-consenter-3-secret | allow-dns-egress | ALL (allow-dns-egress) | R17 | fabric |
| c1 | rd-fabricx-bank-b | statefulset/orderer-router-3 | no | orderer-router-3-secret | allow-dns-egress | ALL (allow-dns-egress) | R17 | fabric |
| c1 | rd-fabricx-bank-b | deployment/committer-coordinator | no | committer-tls | allow-dns-egress, committer-traffic | ALL (allow-dns-egress, committer-traffic) | R17 | fabric |
| c1 | rd-fabricx-bank-b | deployment/committer-query | no | committer-db-credentials, committer-db-tls, committer-tls | allow-dns-egress, committer-traffic | ALL (allow-dns-egress, committer-traffic) | R17 | fabric |
| c1 | rd-fabricx-bank-b | deployment/committer-vc | no | committer-db-credentials, committer-db-tls, committer-tls | allow-dns-egress, committer-traffic | ALL (allow-dns-egress, committer-traffic) | R17 | fabric |
| c1 | rd-fabricx-bank-b | deployment/committer-verifier | no | committer-tls | allow-dns-egress, committer-traffic | ALL (allow-dns-egress, committer-traffic) | R17 | fabric |
| c1 | rd-fabricx-bank-b | deployment/fca-org3 | no | fca-org3-admin | allow-dns-egress | ALL (allow-dns-egress) | R17 | fabric |
| c1 | rd-fabricx-bank-b | deployment/fx-gw-3 | no | fx-gw-3-peer | allow-dns-egress | ALL (allow-dns-egress) | R17 | fabric |
| c1 | rd-fabricx-bank-b | deployment/rdbi-bank3 | no | fsc-endorser-3-secret | allow-dns-egress, rdbi-traffic | ALL (allow-dns-egress, rdbi-traffic) | R17 | fabric |
| c1 | rd-fabricx-bi | statefulset/committer-db | no | committer-db-credentials, committer-db-tls | allow-dns-egress, committer-traffic | ALL (allow-dns-egress, committer-traffic) | R17 | fabric |
| c1 | rd-fabricx-bi | statefulset/committer-sidecar | no | committer-tls | allow-dns-egress, committer-traffic | ALL (allow-dns-egress, committer-traffic) | R17 | fabric |
| c1 | rd-fabricx-bi | statefulset/orderer-assembler-1 | no | orderer-assembler-1-secret | allow-dns-egress | ALL (allow-dns-egress) | R17 | fabric |
| c1 | rd-fabricx-bi | statefulset/orderer-batcher-1 | no | orderer-batcher-1-secret | allow-dns-egress | ALL (allow-dns-egress) | R17 | fabric |
| c1 | rd-fabricx-bi | statefulset/orderer-consenter-1 | no | orderer-consenter-1-secret | allow-dns-egress | ALL (allow-dns-egress) | R17 | fabric |
| c1 | rd-fabricx-bi | statefulset/orderer-router-1 | no | orderer-router-1-secret | allow-dns-egress | ALL (allow-dns-egress) | R17 | fabric |
| c1 | rd-fabricx-bi | deployment/committer-coordinator | no | committer-tls | allow-dns-egress, committer-traffic | ALL (allow-dns-egress, committer-traffic) | R17 | fabric |
| c1 | rd-fabricx-bi | deployment/committer-query | no | committer-db-credentials, committer-db-tls, committer-tls | allow-dns-egress, committer-traffic | ALL (allow-dns-egress, committer-traffic) | R17 | fabric |
| c1 | rd-fabricx-bi | deployment/committer-vc | no | committer-db-credentials, committer-db-tls, committer-tls | allow-dns-egress, committer-traffic | ALL (allow-dns-egress, committer-traffic) | R17 | fabric |
| c1 | rd-fabricx-bi | deployment/committer-verifier | no | committer-tls | allow-dns-egress, committer-traffic | ALL (allow-dns-egress, committer-traffic) | R17 | fabric |
| c1 | rd-fabricx-bi | deployment/fca-org1 | no | fca-org1-admin | allow-dns-egress | ALL (allow-dns-egress) | R17 | fabric |
| c1 | rd-fabricx-bi | deployment/fx-gw-1 | no | fx-gw-1-peer | allow-dns-egress | ALL (allow-dns-egress) | R17 | fabric |
| c1 | rd-fabricx-bi | deployment/rdbi-bi | no | fsc-endorser-1-secret | allow-dns-egress, rdbi-traffic | ALL (allow-dns-egress, rdbi-traffic) | R17 | fabric |
| c1 | rd-iroha3-bank-a | statefulset/bank-a | no | peer-bank-a | none | NARROW: `peers-egress` is the only Egress policy selecting the pod (iroha R17 applied 00:22-00:50Z 2026-11-12; owner report via lead: union exactly the named policy x8, negative probe 4 targets TIMEOUT, positive new connections; qa live read 2026-11-12: `peers-egress` exists in all four rd-iroha3-* namespaces, the union and the probes were NOT re-run by qa) | R17 CLOSED for this role on the owner report (qa re-proof pending) | iroha |
| c1 | rd-iroha3-bank-a | deployment/driver | no | bank-a-keys | none | NARROW: `driver-egress` is the only Egress policy selecting the pod (iroha R17 applied 00:22-00:50Z 2026-11-12; owner report via lead: union exactly the named policy x8, negative probe 4 targets TIMEOUT, positive new connections; qa live read 2026-11-12: `driver-egress` exists in all four rd-iroha3-* namespaces, the union and the probes were NOT re-run by qa) | R17 CLOSED for this role on the owner report (qa re-proof pending) | iroha |
| c1 | rd-iroha3-bank-b | statefulset/bank-b | no | peer-bank-b | none | NARROW: `peers-egress` is the only Egress policy selecting the pod (iroha R17 applied 00:22-00:50Z 2026-11-12; owner report via lead: union exactly the named policy x8, negative probe 4 targets TIMEOUT, positive new connections; qa live read 2026-11-12: `peers-egress` exists in all four rd-iroha3-* namespaces, the union and the probes were NOT re-run by qa) | R17 CLOSED for this role on the owner report (qa re-proof pending) | iroha |
| c1 | rd-iroha3-bank-b | deployment/driver | no | bank-b-keys | none | NARROW: `driver-egress` is the only Egress policy selecting the pod (iroha R17 applied 00:22-00:50Z 2026-11-12; owner report via lead: union exactly the named policy x8, negative probe 4 targets TIMEOUT, positive new connections; qa live read 2026-11-12: `driver-egress` exists in all four rd-iroha3-* namespaces, the union and the probes were NOT re-run by qa) | R17 CLOSED for this role on the owner report (qa re-proof pending) | iroha |
| c1 | rd-iroha3-bi | statefulset/bi | no | peer-bi | none | NARROW: `peers-egress` is the only Egress policy selecting the pod (iroha R17 applied 00:22-00:50Z 2026-11-12; owner report via lead: union exactly the named policy x8, negative probe 4 targets TIMEOUT, positive new connections; qa live read 2026-11-12: `peers-egress` exists in all four rd-iroha3-* namespaces, the union and the probes were NOT re-run by qa) | R17 CLOSED for this role on the owner report (qa re-proof pending) | iroha |
| c1 | rd-iroha3-bi | deployment/driver | no | bi-keys | none | NARROW: `driver-egress` is the only Egress policy selecting the pod (iroha R17 applied 00:22-00:50Z 2026-11-12; owner report via lead: union exactly the named policy x8, negative probe 4 targets TIMEOUT, positive new connections; qa live read 2026-11-12: `driver-egress` exists in all four rd-iroha3-* namespaces, the union and the probes were NOT re-run by qa) | R17 CLOSED for this role on the owner report (qa re-proof pending) | iroha |
| c1 | rd-lensa | deployment/lensa | no | lensa-gw-mtls-a, lensa-gw-mtls-b, lensa-gw-mtls-bi, lensa-gw-mtls-c | allow-dns-egress, default-deny-all, egress-party-gateways | NARROW: ns:{"matchLabels": {"kubernetes.io/metadata.name": "kube-system"}}pod:{"matchLabels": {"k8s- | OK (narrower than intended; no extra egress) | fe |
| c1 | rd-stealth-bank-a | statefulset/besu-rpc | no | besu-rpc-nodekey, stealth-rpc-jwt | allow-dns-egress | ALL (allow-dns-egress) | R17 | besu |
| c1 | rd-stealth-bank-b | statefulset/besu-rpc | no | besu-rpc-nodekey, stealth-rpc-jwt | allow-dns-egress | ALL (allow-dns-egress) | R17 | besu |
| c1 | rd-stealth-bi | statefulset/besu-rpc | no | besu-rpc-nodekey, stealth-rpc-jwt | allow-dns-egress | ALL (allow-dns-egress) | R17 | besu |
| c1 | rd-zeto-bank-a | statefulset/besu-validator | no | besu-nodekey | allow-dns-egress | ALL (allow-dns-egress) | R17 | besu |
| c1 | rd-zeto-bank-a | statefulset/paladin-node2 | no | node2.keys, paladin-node2-mtls | none | NARROW: `paladin-egress` is the only Egress policy selecting the node pod (besu, applied 07:35-07:43 CST; DNS, paladin-pg 5432, besu-validator 8545/8546, peers :9000 by selector or /32) | R17 CLOSED for this role (proof 3 PASS, `agents/qa/REGISTER.md` R17 progress record) | besu |
| c1 | rd-zeto-bank-a | statefulset/paladin-pg | no | paladin-pg-credentials | allow-dns-egress | ALL (allow-dns-egress) | R17 | besu |
| c1 | rd-zeto-bank-a | deployment/bank-gw-2 | no | bank-gw-2-mtls, bundle-sink-token | allow-dns-egress | ALL (allow-dns-egress) | R17 | besu |
| c1 | rd-zeto-bank-a | deployment/bundle-server | no | bundle-sink-token, opa-bundle-signing-bank-a | allow-dns-egress | ALL (allow-dns-egress) | R17 | besu |
| c1 | rd-zeto-bank-b | statefulset/besu-validator | no | besu-nodekey | allow-dns-egress | ALL (allow-dns-egress) | R17 | besu |
| c1 | rd-zeto-bank-b | statefulset/paladin-node3 | no | node3.keys, paladin-node3-mtls | none | NARROW: `paladin-egress` is the only Egress policy selecting the node pod (besu, applied 07:35-07:43 CST; DNS, paladin-pg 5432, besu-validator 8545/8546, peers :9000 by selector or /32) | R17 CLOSED for this role (proof 3 PASS, `agents/qa/REGISTER.md` R17 progress record) | besu |
| c1 | rd-zeto-bank-b | statefulset/paladin-pg | no | paladin-pg-credentials | allow-dns-egress | ALL (allow-dns-egress) | R17 | besu |
| c1 | rd-zeto-bank-b | deployment/bank-gw-3 | no | bank-gw-3-mtls, bundle-sink-token | allow-dns-egress | ALL (allow-dns-egress) | R17 | besu |
| c1 | rd-zeto-bank-b | deployment/bundle-server | no | bundle-sink-token, opa-bundle-signing-bank-b | allow-dns-egress | ALL (allow-dns-egress) | R17 | besu |
| c1 | rd-zeto-bi | statefulset/besu-validator | no | besu-nodekey | allow-dns-egress | ALL (allow-dns-egress) | R17 | besu |
| c1 | rd-zeto-bi | statefulset/paladin-node1 | no | node1.keys, paladin-node1-mtls | none | NARROW: `paladin-egress` is the only Egress policy selecting the node pod (besu, applied 07:35-07:43 CST; DNS, paladin-pg 5432, besu-validator 8545/8546, peers :9000 by selector or /32) | R17 CLOSED for this role (proof 3 PASS, `agents/qa/REGISTER.md` R17 progress record) | besu |
| c1 | rd-zeto-bi | statefulset/paladin-pg | no | paladin-pg-credentials | allow-dns-egress | ALL (allow-dns-egress) | R17 | besu |
| c1 | rd-zeto-bi | deployment/bank-gw-1 | no | bank-gw-1-mtls, bundle-sink-token | allow-dns-egress | ALL (allow-dns-egress) | R17 | besu |
| c1 | rd-zeto-bi | deployment/bundle-server | no | bundle-sink-token, opa-bundle-signing-bi | allow-dns-egress | ALL (allow-dns-egress) | R17 | besu |
| c2 | rd-zeto-bank-c | statefulset/besu-validator | no | besu-nodekey | allow-dns-egress | ALL (allow-dns-egress) | R17 | besu |
| c2 | rd-zeto-bank-c | statefulset/paladin-node4 | no | node4.keys, paladin-node4-mtls | none | NARROW: `paladin-egress` is the only Egress policy selecting the node pod (besu, applied 07:35-07:43 CST; DNS, paladin-pg 5432, besu-validator 8545/8546, peers :9000 by selector or /32) | R17 CLOSED for this role (proof 3 PASS, `agents/qa/REGISTER.md` R17 progress record) | besu |
| c2 | rd-zeto-bank-c | statefulset/paladin-pg | no | paladin-pg-credentials | allow-dns-egress | ALL (allow-dns-egress) | R17 | besu |
| c2 | rd-zeto-bank-c | deployment/bank-gw-4 | no | bank-gw-4-mtls, bundle-sink-token | allow-dns-egress | ALL (allow-dns-egress) | R17 | besu |
| c2 | rd-zeto-bank-c | deployment/bundle-server | no | bundle-sink-token, opa-bundle-signing-bank-c | allow-dns-egress | ALL (allow-dns-egress) | R17 | besu |
| c2 | rd-stealth-bank-c | statefulset/besu-rpc | no | besu-rpc-nodekey, stealth-rpc-jwt | allow-dns-egress | ALL (allow-dns-egress) | R17 | besu |
| c2 | rd-fabricx-bank-c | statefulset/committer-db | no | committer-db-credentials, committer-db-tls | allow-dns-egress, committer-traffic | ALL (allow-dns-egress, committer-traffic) | R17 | fabric |
| c2 | rd-fabricx-bank-c | statefulset/committer-sidecar | no | committer-tls | allow-dns-egress, committer-traffic | ALL (allow-dns-egress, committer-traffic) | R17 | fabric |
| c2 | rd-fabricx-bank-c | statefulset/orderer-assembler-4 | no | orderer-assembler-4-secret | allow-dns-egress | ALL (allow-dns-egress) | R17 | fabric |
| c2 | rd-fabricx-bank-c | statefulset/orderer-batcher-4 | no | orderer-batcher-4-secret | allow-dns-egress | ALL (allow-dns-egress) | R17 | fabric |
| c2 | rd-fabricx-bank-c | statefulset/orderer-consenter-4 | no | orderer-consenter-4-secret | allow-dns-egress | ALL (allow-dns-egress) | R17 | fabric |
| c2 | rd-fabricx-bank-c | statefulset/orderer-router-4 | no | orderer-router-4-secret | allow-dns-egress | ALL (allow-dns-egress) | R17 | fabric |
| c2 | rd-fabricx-bank-c | deployment/committer-coordinator | no | committer-tls | allow-dns-egress, committer-traffic | ALL (allow-dns-egress, committer-traffic) | R17 | fabric |
| c2 | rd-fabricx-bank-c | deployment/committer-query | no | committer-db-credentials, committer-db-tls, committer-tls | allow-dns-egress, committer-traffic | ALL (allow-dns-egress, committer-traffic) | R17 | fabric |
| c2 | rd-fabricx-bank-c | deployment/committer-vc | no | committer-db-credentials, committer-db-tls, committer-tls | allow-dns-egress, committer-traffic | ALL (allow-dns-egress, committer-traffic) | R17 | fabric |
| c2 | rd-fabricx-bank-c | deployment/committer-verifier | no | committer-tls | allow-dns-egress, committer-traffic | ALL (allow-dns-egress, committer-traffic) | R17 | fabric |
| c2 | rd-fabricx-bank-c | deployment/fca-org4 | no | fca-org4-admin | allow-dns-egress | ALL (allow-dns-egress) | R17 | fabric |
| c2 | rd-fabricx-bank-c | deployment/fx-gw-4 | no | fx-gw-4-peer | allow-dns-egress | ALL (allow-dns-egress) | R17 | fabric |
| c2 | rd-fabricx-bank-c | deployment/rdbi-bank4 | no | fsc-endorser-4-secret | allow-dns-egress, rdbi-traffic | ALL (allow-dns-egress, rdbi-traffic) | R17 | fabric |
| c2 | rd-iroha3-bank-c | statefulset/bank-c | no | peer-bank-c | none | NARROW: `peers-egress` is the only Egress policy selecting the pod (iroha R17 applied 00:22-00:50Z 2026-11-12; owner report via lead: union exactly the named policy x8, negative probe 4 targets TIMEOUT, positive new connections; qa live read 2026-11-12: `peers-egress` exists in all four rd-iroha3-* namespaces, the union and the probes were NOT re-run by qa) | R17 CLOSED for this role on the owner report (qa re-proof pending) | iroha (file lists it under 'rd-iroha3-bank-c (c2)') |
| c2 | rd-iroha3-bank-c | deployment/driver | no | bank-c-keys | none | NARROW: `driver-egress` is the only Egress policy selecting the pod (iroha R17 applied 00:22-00:50Z 2026-11-12; owner report via lead: union exactly the named policy x8, negative probe 4 targets TIMEOUT, positive new connections; qa live read 2026-11-12: `driver-egress` exists in all four rd-iroha3-* namespaces, the union and the probes were NOT re-run by qa) | R17 CLOSED for this role on the owner report (qa re-proof pending) | iroha (file lists it under 'rd-iroha3-bank-c (c2)') |

Totals: 84 R17 rows, 1 OK, 0 HELD (live templates).
