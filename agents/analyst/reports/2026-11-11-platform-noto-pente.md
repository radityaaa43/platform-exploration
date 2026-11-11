PLATFORM: NOTO+PENTE @ besu@927f572 frontend@aa6e09b   Upstream: paladin@v1.0.0. Shared rows (validators, nodes, operator, Postgres, keys, ingress, kubeconfig, Lensa host) in 2026-11-11-platform-zeto.md.

DECENTRALIZATION: validator=GAP | self-submit=GAP | third-party=ACCEPTED

component | runs today | per-bank or shared | upstream rec (source)
- Noto notary | cashIssuer, assetIssuer, bondCustodian all on node1 (BI); notaryMode hooks | shared, BI (by design) | one notary identity per token, "may be located at this node or another node" (doc-site/docs/architecture/noto.md:50); modes basic or hooks (:51); no rotation or multi-notary found in noto.md
- Pente groups | {bondIssuer, bondCustodian} (both BI); {investor, bondCustodian} per bank | BI in every group | 100% endorsement (PenteDomain.java:102)
- RestrictedAtom | project contract; execute() BI (executor) only; cancel() executor or party | shared, BI | upstream Atom.execute open (Atom.sol:60-70)
- Lensa keys, Noto | state/noto.json dataDir only; keys live in Paladin nodes | n/a | n/a

FINDING: Noto notary is BI on node1; every Noto operation needs it   SEVERITY: major   KIND: accepted
  UPSTREAM: "Uses the notary account to submit TX1 to the blockchain" (noto.md:569,580); notary receives cleartext states (domains/noto/internal/noto/handler_transfer_common.go:69).
  EVIDENCE: besu/noto+pente/docs/architecture-brief.md 8.4.
  FIX:      none under the exemption.   OWNER: accepted
FINDING: RestrictedAtom lets only BI execute; BI also executor for primary sales   SEVERITY: minor   KIND: deviation (project-added)
  UPSTREAM: Atom.execute open to anyone (Atom.sol:60-70); the hardening adds a mandatory third party.
  EVIDENCE: RestrictedAtom.sol:150-155, :219-224.
  FIX:      none now (R2 exempt); record as dependency.   OWNER: besu
FINDING: Pente groups need every member to endorse; BI in all   SEVERITY: major   KIND: accepted
  UPSTREAM: PenteDomain.java:102 ("threshold is 100% right now").
  EVIDENCE: architecture-brief.md:333,352.
  FIX:      none, upstream design.   OWNER: accepted
FINDING: cancel() while BI is down untested live; brief says delegated funds stay locked until notary returns   SEVERITY: major   KIND: unverified
  UPSTREAM: delegated locks can complete or roll back "without involvement of the notary" (noto.md:597).
  EVIDENCE: architecture-brief.md 8.4 last paragraph, "analysis not test".
  FIX:      live test of cancel with node1 down (user-approved write).   OWNER: besu
FINDING: Lensa reaches all 4 nodes via port-forward with the admin kubeconfig; node RPC auth is one shared secret   SEVERITY: minor   KIND: deviation
  EVIDENCE: lensa.service Wants lensa-pf@paladin-node1..4; env names KUBECONFIG, LENSA_GW_MTLS_DIR, OPA_KEYS_DIR, LENSA_BESU_RPC_BANKS.
  FIX:      per-bank client credentials.   OWNER: lead

R1: ALIGNED. Noto distributes states to {notary, sender, from, to} (handler_transfer_common.go:69); BI is notary. Pente data to group members only.
R2: ACCEPTED, exempt. Notary = BI submits every Noto tx (noto.md:569). Full compliance: a notary that is not BI, or a lock already delegated to an Atom (finishes without notary, noto.md:597; preparing the lock still needs it).
R3: ALIGNED. Noto lock prepared and delegated to an Atom; Atom executes both legs or cancels (noto.md:586-600, Atom.sol:60-70); project adds executor/party gating (RestrictedAtom.sol:150-155, :219-224).

SOURCES: as in platform-zeto.md plus noto.md:50-51,569,580,586-600; besu/noto+pente/docs/architecture-brief.md; contracts/src/RestrictedAtom.sol.
UNVERIFIED: Noto cancel() with BI down; upstream notary rotation / multiple notaries not proven absent.
