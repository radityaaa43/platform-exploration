PLATFORM: fabric-x @ fabric-x@3f7caeb frontend@aa6e09b   Upstream: committer v1.0.4 (08a469d), orderer v1.0.4 (dd296e3), Panurus v0.24.0 (5f3c49e2) + 4 patches + FSC go.mod replace.
Reviewer: analyst subagent (sonnet), read-only, live reads 2026-11-11.

DECENTRALIZATION: validator=GAP | self-submit=GAP | third-party=GAP

validator = GAP (deviation). Topology is per bank; one operator controls it.
- Each bank has its own Arma party and committer. 4 consenters, f=1 (orderer docs/architecture.md §8: F=floor(N/3), N>=3F+1, 4 minimum, 7 recommended for production).
- Single other party down: ALIGNED, verified live 2026-11-02 for BI down and bank4 down (panurus-itest/README.md test results). BI + one bank down refused (f=1).
- All in ns fabricx under one cluster-admin kubeconfig. Co-scheduling: rdbi-bank2/3/4, orderer-consenter-2, orderer-consenter-4, orderer-batcher-3, orderer-router-4 on `member-16045-node` (snapshot). Losing that node takes 2 of 4 consenters, above f=1.

self-submit = GAP. Each bank has its own FSC node and keys (rdbi-bankN-files), but the path runs through components other parties operate: rdbi-bankN-ingress allows only fx-gw-N (run from the one kubeconfig, secret holds that party's view-client key); Lensa is one host service (lensa.service 127.0.0.1:8790) reading the ledger with `kubectl exec` via FABRICX_KUBECONFIG; all nodes share one ledger submitter identity `ids/anon` (Org1MSP, README deviation 2).

third-party = GAP.
- Auditor not required: validator rejects auditor signatures and requires none when public params have no auditors (panurus token/core/common/validator_auditing.go:50-56).
- 3-of-4 endorsement is our choice (panurus-itest/rdbi/topology.go:84); committer docs/namespace-policy.md makes it configurable, example "2 out of 3". Needing 2 other banks = deployment decision.
- Report-to-BI (panurus-itest/rdbi/report) is ours, detective only. Settlement needs no BI; issue and burn do. BI as issuer comes from upstream (PublicParams.IssuerIDs): ACCEPTED.
- Policy distribution depends on bundle-server in ns paladin, not a bank service.

Component | runs today | per-bank or shared | upstream rec
- Arma parties 1..4 | ns fabricx STS orderer-{router,batcher,consenter,assembler}-N, secrets orderer-*-N-secret | one per bank, one operator, one ns | party = org, N>=3F+1, 7 for production (orderer docs/architecture.md §8)
- Committer BI | committer-{coordinator,validator,verifier,query-service}, committer-sidecar-0, committer-db-0 | BI's; Lensa labels it "Committer bersama" | sidecar/coordinator single-instance per deployment (committer docs/deployment-guide.md); per-org rule UNVERIFIED
- Committer banks | inside rdbi-bank2/3/4: verifier, vc, coordinator, sidecar, query, db postgres:17.10 | one per bank | same; Postgres no TLS (README deviation 6)
- CA / MSP | fca-org1 (Org1MSP), fca-orderer-org2/3/4 (OrdererOrgNMSP reused as bank MSPs); secret fca-orderer-org2 keys ca-private-key, IssuerSecretKey | one CA per org, all secrets in one ns | per-org CA UNVERIFIED in docs read
- Channel admin | none can sign (Ansible 0.8.26 genesis without capabilities; reset 2026-11-01 to V3_0) | shared | ACCEPTED per fabric-x/NOTES.md
- FSC nodes | rdbi-bi (issuer, endorser-1), rdbi-bankN (bankN, endorserN), secrets rdbi-*-files key rdbi.tgz | one per bank | one endorser per org (Panurus integration/token/fungible/topology)
- Endorsers | endorser-1..4 = Org1..4 in each bank's pod | one per bank | OutOf(3,4) our choice
- Auditor | none; BI issuer keeps audit tokens, receives reports (rdbi/report/report.go) | BI | optional (validator_auditing.go:50-56)
- Key custody | secret rdbi-driver-files (key rdbi.tgz) holds every party's view-client key; deploy rdbi-driver at 0, decision open (opa/DESIGN.md §9 item 7); fx-gw-N-files party N only | shared if scaled up | none upstream
- Gateways | fx-gw-1..4 (envoy, opa, fxapi), secrets fx-gw-N-mtls, fx-gw-N-files | one per bank, one kubeconfig | our design
- bundle-server | ns paladin | shared | our design
- Postgres | committer-db-0, block-explorer-db-0, fca-*-db-0, one per bank in-pod | mostly per bank | n/a
- Kubeconfig | one cluster-admin alibaba.yaml | shared | n/a
- Lensa server | host service, FABRICX_KUBECONFIG, kubectl exec + psql on BI DB | shared | n/a

Single-ns fabricx vs multiregion (fabricx-bi, bank-a, bank-b, bank-c): Lensa path is ns fabricx only (fabricx.ts hardcodes it; no refs to fabricx-* in frontend/server/src). Multiregion is closer to per-org (ns per org, restricted PSS, default-deny, own committer+DB, own orderer party, own endorser, token auditor in fabricx-bi, token-issuer-v2; bank-c Services only, no pods). Still one cluster, one kubeconfig, no repo definition, unlabelled digests. Health unclear: fabricx-bi committer sidecar last logs 2026-11-04; token-issuer-v2/token-owner-v2 TLS handshake EOFs 2026-11-11. Upstream namespace-per-org prescription: UNVERIFIED.

FINDING: bank nodes and orderer parties co-scheduled on one node   SEVERITY: major   KIND: drift
  PROJECT:  rdbi-bank2/3/4 + consenters 2 and 4 on member-16045-node.
  UPSTREAM: party = unit of failure, parties may be mutually untrusting orgs (orderer docs/architecture.md §8).
  EVIDENCE: `kubectl get pods -n fabricx -o wide` 2026-11-11 (snapshot).
  FIX:      anti-affinity per party and per bank.   OWNER: fabric
FINDING: rdbi-driver-files holds every party's key   SEVERITY: major   KIND: deviation
  PROJECT:  decision open; deploy at 0 but cluster-admin can scale it.
  UPSTREAM: no all-party key in upstream design.
  EVIDENCE: opa/DESIGN.md §9 item 7; secret key rdbi.tgz.
  FIX:      delete the secret or per-bank custody (destructive: user).   OWNER: lead, user
FINDING: single operator and single kubeconfig for all banks   SEVERITY: major   KIND: deviation
  PROJECT:  every CA, orderer and bank FSC key is a Secret in ns fabricx.
  UPSTREAM: parties are independent admin units (orderer docs/architecture.md §8).
  EVIDENCE: secret key names in the table; kubectl exec documented as open bypass (opa/DESIGN.md §9 items 1-3).
  FIX:      per-bank ns and credentials (multiregion attempt) or cluster per bank.   OWNER: lead, user
FINDING: shared Org1MSP submitter identity   SEVERITY: major   KIND: deviation
  PROJECT:  all nodes sign ledger txs with ids/anon.
  UPSTREAM: Idemix creator; official route = IdemixOrgMSP in channel config.
  EVIDENCE: panurus-itest/README.md deviation 2; now possible since the channel has capabilities.
  FIX:      config update adding an Idemix MSP.   OWNER: fabric
FINDING: gateway and bundle-server shared; BI-down latency   SEVERITY: major   KIND: deviation
  PROJECT:  fx-gw-N depends on bundle-server in ns paladin; BI down: ~2m10s submit + ~2m10s report (DESIGN.md §6, §9). Note: Lensa deadline now 340 s (rd-lensa-frontend 8ddfc93), see report 2026-11-11-iroha3-driver-fabricx-bi-down.md.
  UPSTREAM: none.
  FIX:      "pending" status in Lensa; shorter endorsement/report timeout needs a Panurus patch (out of scope).   OWNER: fabric, fe
FINDING: undocumented multiregion stack   SEVERITY: minor   KIND: unverified
  PROJECT:  3 ns + bank-c without pods, unpinned digests, no repo definition.
  EVIDENCE: `kubectl get ns --show-labels` part-of=fabricx-multiregion.
  FIX:      document or retire.   OWNER: fabric

R1: ALIGNED for non-parties; GAP (deviation) for BI visibility. ZKAT-DLOG NOGH hides amounts/types (Pedersen) and owners (Idemix); spending graph (input ids) visible (panurus docs/drivers/dlogwogh.md:38,50). Committer/orderer/readers see tx time, size, input ids, commitments, proofs. Endorsers get the serialized token request, not openings (token/services/ttx/collectendorsements.go:473-495). BI sees the full tx only via the bank's report: detective, not preventive (README known limits). UNVERIFIED: live endorsement payload not decoded.
R2: ALIGNED with latency caveats. OutOf(3,4) (topology.go:84), Arma f=1. Verified live 2026-11-02: BI down, banks transferred + DvP, reports caught up 82/82; bank4 down OK; BI + bank4 refused. Redelivery manual (rdbi-driver report / gateway op: report, driver at 0). Forged report refused via AuditCheck + finality-listener hash (README).
R3: ALIGNED. DvP = one token tx with two transfer actions, endorsed and committed atomically (Panurus docs/token_sdk_usage.md §5; integration/token/fungible/views/swap.go SwapInitiatorView). Caveats from our docs, not re-run: failed DvP can leave payer tokens locked (README known limits, UNVERIFIED); swap responder signs without checking the counter-leg (fabric-x/NOTES.md 2026-11-03).

ACCEPTED PATCHES (kept by decision; upstream path to compliance):
- fsc-full-certificate: add our certs to committer known_certs via config update; possible since the 2026-11-01 reset.
- panurus-endorser-failover: reachability-aware EndorserSelector upstream in token/services/network/fabric/endorsement/fsc/service.go + idempotent retried request.
- panurus-sequential-remote-signatures: upstream fix in token/services/ttx/collectendorsements.go for per-identity interleaving.
- panurus-issuer-keeps-audit-tokens: upstream option for the issuer to store audit tokens without an auditor (token/core/common/authorization.go).
- panurus-auditor-limits: demo view only; drop for production.

SOURCES: fabric-x/NOTES.md; panurus-itest/README.md; rdbi/topology.go:84; opa/DESIGN.md §6, §9; frontend/server/src/adapters/fabricx.ts; fabric-x-orderer@dd296e3 docs/architecture.md §8; fabric-x-committer@08a469d docs/deployment-guide.md, docs/namespace-policy.md; panurus@5f3c49e2 validator_auditing.go:50-56, docs/drivers/dlogwogh.md:38,50, docs/token_sdk_usage.md §5; read-only kubectl on fabricx, fabricx-bi, fabricx-bank-a/b/c.
UNVERIFIED: upstream committer-per-org or ns-per-org prescription; multiregion health and image provenance; fx-gw fail-closed when bundle-server down; live endorsement payload; co-location is one snapshot; Panurus line numbers beyond those cited.
