PLATFORM: STEALTH @ besu@927f572 frontend@aa6e09b   Upstream: EIP-5564, EIP-6538 (text not re-fetched this review), besu 26.8.1. No Paladin node: validator + Lensa server are the whole stack. Shared rows in 2026-11-11-platform-zeto.md.

DECENTRALIZATION: validator=GAP | self-submit=GAP (BLOCKER) | third-party=GAP

component | runs today | per-bank or shared | upstream rec (source)
- Besu validator | bank txs via LENSA_BESU_RPC_BANKS to bank-gw-2..4 -> validator-2..4; BI txs, reads, receipts via bank-gw-1 -> validator-1; not set in lensa.env so unconfirmed live | validator per bank on paper, one admin | as zeto file
- Announcer / registry | ERC5564Announcer, ERC6538Registry, deployed by deployer key (BI) | shared, open (minor) | standard needs the announcer open (besu/stealth-address/src/ERC5564Announcer.sol:4-5)
- Who scans | Lensa server scans all banks' announcements with each bank's view and spend key (frontend/server/src/adapters/stealth.ts:167,200,237) | shared (blocker) | only the view-key holder scans (EIP-5564)
- Keys | frontend/server/state/stealth.json mode 600, dir 700; names: deployerKey, banks.{A,B,C}.{spendKey,viewKey,metaAddress,identityKey}, biMeta.{spendKey,viewKey,metaAddress}, pool entries privateKey | all banks' keys in one file on one host (blocker) | each recipient holds its own spend and view keys (EIP-5564)
- Custodian / certificate signer | deployerKey signs every DFABI certificate (stealth.ts:27 "deployer plays BI", :362-365, :390); DvPFactory.create OnlyCustodian | BI (shared) | project design; upstream not opened
- Lensa server | lensa.service one host, signs for every bank | shared (blocker) | n/a

FINDING: Lensa holds spend, view and identity keys of banks A, B, C plus BI's deployer key; signs and scans for everyone   SEVERITY: blocker   KIND: deviation
  UPSTREAM: EIP-5564 keys belong to each recipient (text not re-fetched).
  EVIDENCE: state/stealth.json key names; stealth.ts:113,117,348-349 (`new Wallet(...privateKey...)`).
  FIX:      per-bank keys in bank-owned signers (HSM/Vault); Lensa becomes a relay.   OWNER: user (scope), fe, lead
FINDING: DFABI transfers need a certificate signed by deployerKey; custodian role collapsed into BI inside Lensa   SEVERITY: major   KIND: deviation
  EVIDENCE: stealth.ts:27,362-365,390; architecture-brief.md:12; DvPFactory.sol:31.
  FIX:      lead decides custodian-or-BI; certificate service outside Lensa is project-side.   OWNER: lead
FINDING: DvP escrow bond refund needs a certificate still valid after expiry + refundWindow   SEVERITY: major   KIND: deviation
  EVIDENCE: DvPEscrow.sol:131-136 (BondRefundFailed).
  FIX:      certificate lifetime policy.   OWNER: besu
FINDING: public tx shows amount, token, sender address; by design   SEVERITY: major   KIND: accepted (user decision 2026-11-10 "stealth ok", relayed by orchestrator 2026-11-11; was missing from the team's list)
  UPSTREAM: EIP-5564 (ethereum/ERCs master ERCS/erc-5564.md, fetched 2026-11-11, status Final) scope = recipient privacy only: Motivation "observers are unable to associate the recipient's stealth address with their identity ... leaving the sender as the only party privy"; Announcement metadata bytes 26-57 carry the amount in a public event. Amount and sender are outside the standard's scope. Project: ERC5564Announcer.sol:6-12,14-18.
  EVIDENCE: architecture-brief.md:11 ("Jumlah, token, dan alamat pengirim on-chain memang publik").
  FIX:      none within stealth; scope decision.   OWNER: user
FINDING: ERC-6538 registers each bank's identity address with its meta-address publicly   SEVERITY: minor   KIND: unverified
  FIX:      confirm registry layout against the EIP.   OWNER: besu

R1: ACCEPTED (user decision 2026-11-10) with a GAP at the Lensa layer. Receiver hidden: linking needs the viewing key (EIP-5564 definitions: "viewing key ... determine if funds sent to a stealth address belong to the recipient"); holders today: each bank for its own, BI for all (brief), Lensa for all (stealth.json) = GAP. Amount, token, sender public by the standard's scope (EIP-5564 Motivation; metadata bytes 26-57): accepted.
R2: GAP (DFABI). RD transfer, escrow settle and cancel need no BI call; DFABI transfers need the custodian certificate.
R3: ALIGNED with caveats. Settle moves both legs in one tx or reverts (DvPEscrow.sol:103-119), only before expiry (:107); cancel from expiry, returns each funded leg, anyone can call (:124-142); only custodian creates an escrow (DvPFactory.sol:30-31), a mandatory third party; both legs pre-funded.

SOURCES: besu/stealth-address/{src,docs}, frontend/server/src/adapters/stealth.ts, state/stealth.json (key names only), lensa.env (names only); EIP-5564 https://raw.githubusercontent.com/ethereum/ERCs/master/ERCS/erc-5564.md (fetched 2026-11-11, Final); EIP-6538 per contracts-tokens review (contract layout matches, forge 84 tests pass).
UNVERIFIED: LENSA_BESU_RPC_BANKS live value; ERC6538Registry line-by-line vs EIP-6538 text.
