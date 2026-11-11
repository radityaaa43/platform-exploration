# 0001. Orderer and committer party placement across two clusters (X/Y)
Date: 2026-11-11
Status: accepted (user decision 2026-11-11, README row 13: option 3/1 re-genesis, balances do not carry; endpoint decision A `<role>-<N>.arma.rd` + hostAliases)
Deciders: user

## Context
User topology (2026-11-11): bank C runs on cluster 2, BI/A/B on cluster 1, one namespace per org. Fabric-X is a single Arma consensus group of 4 parties (SmartBFT, N=4, F=1; orderer@dd296e3:docs/architecture.md:182-185). Where each party runs is part of the genesis (`Host`/`Port`/`TLSCert` per role, orderer@dd296e3:config/party_shared_config.go:11-68). Changing a party address needs a restart; dynamic reconfig is a TODO (orderer@dd296e3:config/reconfig.go:68,96); `AddNewParty`/`RemoveParty` exist only as test helpers (testutil/configutil/config_update_utils.go:952,1087). No documented cross-cluster add or move path was found. Today all 4 parties run in ns `fabricx` on cluster 1 and the genesis names in-cluster hosts, so every move to `rd-fabricx-*` namespaces is also an address change. Each committer reads blocks from its own party's assembler (committer@08a469d:docs/deployment-guide.md:132-134); 4 parties tolerate one fault, and BI + one bank down is refused (ARCHITECTURE 2.5).

## Decision
Left to the user. Choose X parties on cluster 1 and Y on cluster 2 (X+Y=4), and the route: re-genesis (new channel and ledger, balances not carried) or an unverified config-tx path (`configtxlator compute_update`, Fabric-X MSP support UNVERIFIED).

## Alternatives Considered
- 3/1 (parties 1-3 cluster 1, party 4 cluster 2; AFTER 2a). Pros: matches the user topology and "bank C runs its own validator". Cons: every consensus round with party 4 crosses regions (RTT about 15 ms, <= 30 ms assumed; margin about 16x on the smallest timer, ARCHITECTURE 2a.4); cluster 1 loss halts the channel (3 parties down of 4). Why not default: needs the re-genesis and cross-cluster mTLS to be accepted.
- 4/0 (all Arma parties on cluster 1, bank C only gateway/FSC/committer on cluster 2). Pros: no cross-cluster consensus. Cons: bank C is not its own validator, fails objective (a) for C; party 4 lives in another org's cluster-admin domain.
- 2/2. Pros: symmetric. Cons: losing either cluster stops the channel (2 parties down > F=1); worse than 3/1.
- 7 parties (production recommendation, orderer@dd296e3:docs/architecture.md:185). Pros: F=2. Cons: out of PoC scale, capacity on cluster 2 (ARCHITECTURE 2a.3).

## Consequences
- Whatever X/Y is chosen, a new channel and ledger is built side by side with ns `fabricx` (PLAN S9-S11); balances of `fabricx` are not carried, BI re-issues (PLAN S14, S20).
- Steps S9, S10, S11, S18 stay BLOCKED until this ADR is decided.
- Disk-attach slots and memory on both clusters limit the side-by-side period.
