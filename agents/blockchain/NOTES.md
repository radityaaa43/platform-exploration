# Blockchain operational notes

Live state and hazards that the next session must know. Keep each entry dated and short.

## Paladin (ns paladin), updated 2026-11-03 04:10Z

1. RESOLVED 2026-11-03 04:19Z (S8): the paladin-operator is back at 1 replica. ConfigMap `paladin-operator`
   `paladin.image` = `ghcr.io/radityaaa43/paladin@sha256:6f113f3829fefd7f954d3377935d7613ab78a90ba89c6af8e79159617b339f71`,
   byte-identical to all 4 StatefulSets; the 5-min watch showed no pod restart and no StatefulSet update. Operator v1.0.0
   copies that string verbatim into every StatefulSet on reconcile, so any future image change goes ConfigMap first
   (byte-identical string), or the operator is paused (scale 0) before a per-node `set image`. CM backups:
   besu/zeto/out/s8-20261103T041331Z/.
2. RESOLVED 2026-11-03: mixed fleet. node1 moved to the digest at 04:05Z (node2/3/4 earlier), so all 4 nodes run prepfix2.
3. Ceiling with prepfix2: a prepare-only transaction (Zeto prepareSpendLock, any submitMode external) stays in the
   coordinator's memory until the pod restarts. About 500 (`maxInflightTransactions`) per (node, token contract) per pod
   lifetime; after that the node rejects new transactions for that token (PD012642) until a restart. Each Zeto DvP adds one
   on the seller's DFABI coordinator and one on the buyer's RD coordinator. Every restart or image rollout resets it.
4. RESOLVED 2026-11-03: node1's 7 old spike rows (6 external spendLock + createLock 66f4043e, bondCustodian@node1,
   10-21) were backed up to besu/zeto/out/stuck-tx-backup-20261103T040501Z/ (gitignored) and deleted (6/6/7, history
   cascade). Restore only with a new GO.
5. Restart rule: restart a Paladin node only when no node has an in-flight transaction. A node that resumes a transaction
   needing a remote verifier right after start can lose the ResolveVerifier response (PD030015, no retry); the transaction
   then stays `Resolving` and blocks later ones on the same contract.

## Fabric-X (ns fabricx), award image, updated 2026-11-03 05:12Z

1. Image `ghcr.io/radityaaa43/rdbi-node@sha256:71e3b6782215c4c9451148ec318ee39b2d9809a4bc2c4bdeea7d8527572bd675`
   (tag award-69f7e16, private; code 053fb2e + 8659e10 + 579e91e on feat/fabric-x-multibank). Only these containers run it:
   rdbi-bank2/bank2, rdbi-bank3/bank3, rdbi-bank4/bank4, rdbi-bi/issuer, rdbi-driver/driver. The endorser-N containers, the
   committers, the DB and the orderer/CA pods are unchanged (endorser-N still `rdbi-node:ebbb28f1d552`).
2. Rollback, one container at a time, then a 1-unit transfer smoke:
   `kubectl -n fabricx set image deploy/rdbi-bankN bankN=ghcr.io/radityaaa43/rdbi-node:ebbb28f1d552` (bank2/3/4),
   `deploy/rdbi-bi issuer=…:ebbb28f1d552`, `deploy/rdbi-driver driver=ghcr.io/radityaaa43/rdbi-node:82fa0e65271c`.
   The old images only lack the award command and views; ledger data needs no change. Deploy backups:
   besu/zeto/out/fabricx-award-rollout-20261103T045711Z/.
3. Live proof: award BI -> bank2 tx 93650e89… (1 DFABI-2027A for 1,000,000 RD) in one transaction with the old endorsers;
   bank3/bank4 hold no record. Evidence: besu/zeto/out/award/fabricx-award-phase2.txt.
4. Hazard: panurus's ttxdb (store.go:542-558) labels BI's DFABI issue in an award as `transfer bank2->bank2`; code that
   reads records must detect an award by shape (DFABI to a bank and RD from that bank to the issuer in one tx).
5. Hazard: the deployments are `strategy: Recreate`, so a bank's FSC node, endorser and committer pod restart together
   (about 10-60 s); run no Fabric-X write while one rolls.
6. Price: the award views accept only RD = DFABI x 1,000,000 (PricePerUnit in rdbi/award/checks.go); a change of the
   Lensa PRICE_PER_UNIT needs the same change there and a new image.

## Parked ideas

- 2026-11-03 award: Lensa's BI RD balance reads Noto's cashIssuer, but award RD lands on bondCustodian (and on BI's own
  accounts/addresses in Iroha/Stealth/Zeto). Proposal: BI's RD = sum over BI's RD-holding identities per model
  (Noto: cashIssuer + bondCustodian). Lead decides after all models. -> DECIDED 67dd1d0 (§7.1 "BI balance"), fixed on fix/award-bi-balance.
- 2026-11-03 Fabric-X: the existing panurus SwapResponderView (party SDK) signs blind like the first award responder did:
  it does not check the initiator's identity, the counter-leg amount or recipient before endorsing. The award views now check
  the exact request shape (rdbi/award/checks.go); swap is unchanged. Proposal: a rdbi-side swap responder with the same checks.
