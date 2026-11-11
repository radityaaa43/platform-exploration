# 0003. RD issuer address: keep the key or redeploy RD
Date: 2026-11-11
Status: proposed
Deciders: user

## Context
`RupiahDigital.issuer` is immutable and the only account that may `mint` and `mintStealth` (`besu@9890701:stealth-address/src/RupiahDigital.sol:21,24-25,33-35`). Today it is the shared deployer account that also holds the bond, factory and registry roles (CURRENT.md section 2). The AFTER keeps the issuer as BI and moves only the key into BI's own store (ARCHITECTURE-stealth.md section 2 row "RD", DELTA 8): the issuer address does not change, so no redeploy is needed for the plan. Changing the issuer ADDRESS needs a new RD token (hard limit 5); RD has no migration function, so holders would move balances by ordinary stealth transfers, and every Lensa, announcement and state reference to RD changes.

## Decision
Left to the user. PLAN S14 stays BLOCKED(RD issuer redeploy); the default path (key moves, address stays) does not wait for it.

## Alternatives Considered
- (a) Keep the RD address; the issuer key moves into the BI store (cost S, in S10 and S15). Pros: no redeploy, balances and history stay, same address in CONTRACTS.md. Cons: the issuer address equals the old deployer address, whose key history (it sat in the Lensa state file) cannot be proven private: a trust reset that only moving the key to a new holder does not erase.
- (b) Deploy a new RD with a fresh BI issuer address and migrate (cost L). Pros: a clean issuer key with provable custody from day one. Cons: new token address everywhere; balances must be re-issued or moved; supply 30003001247009 raw to carry over; history split between two tokens; the DvP and DFABI flows that use RD change.

## Consequences
- (a): S15 strips the deployer's other roles; `issuer()` is unchanged.
- (b): a new `RupiahDigital(issuer_, announcer)` deployment, CONTRACTS.md and Lensa `deployed.rd` change, and a qa migration proof; goes through `analyst` as a DELTA addendum first.
