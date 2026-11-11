# Design principles: decentralized per bank + R1/R2/R3

Written 2026-11-11 by `analyst` (read-only review, user mandate phase 2). One file per platform. Each file has BEFORE (as it runs today, every box cited to the project source or live object), AFTER (target supported only by the official repo or docs at the pin), DELTA (numbered changes with objective, touched files or objects, cost S/M/L) and SOURCES. Diagrams are Mermaid. `lead` plans from the DELTA lists; owners are not assigned here.

Evidence rule: `repo@commit:path:line` or docs URL + version. Memory, NOTES.md, ADRs and agent messages are leads, never evidence. No upstream citation = UNVERIFIED. No custom code on Paladin, no workaround.

## Files

| Platform | File | Pins |
|---|---|---|
| Zeto | [ARCHITECTURE-zeto.md](ARCHITECTURE-zeto.md) | paladin v1.0.0, zeto v0.5.1, besu 26.8.1; nodes run the accepted fork |
| Noto + Pente | [ARCHITECTURE-noto-pente.md](ARCHITECTURE-noto-pente.md) | paladin v1.0.0, besu 26.8.1 |
| Stealth | [ARCHITECTURE-stealth.md](ARCHITECTURE-stealth.md) | EIP-5564, EIP-6538, besu 26.8.1, project contracts as they are |
| Fabric-X | [ARCHITECTURE-fabricx.md](ARCHITECTURE-fabricx.md) | fabric-x-committer 1.0.4, fabric-x-orderer 1.0.4, Panurus v0.24.0 (+4 accepted patches), FSC v0.24.0 |
| Iroha 3 | [ARCHITECTURE-iroha3.md](ARCHITECTURE-iroha3.md) | hyperledger-iroha/iroha 071e281e, driver iroha3-rd-node-build be4dd89 |

Phase 1 verdicts (source: `agents/analyst/reports/2026-11-11-matrix.md`):

| Platform | validator | self-submit | third-party | R1 | R2 | R3 |
|---|---|---|---|---|---|---|
| Zeto | GAP | GAP | ACCEPTED | ACCEPTED | ACCEPTED | ALIGNED (Atom.cancel open) |
| Noto+Pente | GAP | GAP | ACCEPTED | ALIGNED | ACCEPTED | ALIGNED |
| Stealth | GAP | GAP (blocker) | GAP | ACCEPTED (user 2026-11-10) + GAP Lensa view keys | GAP (DFABI certificate) | ALIGNED |
| Fabric-X | GAP | GAP | GAP | ALIGNED non-parties / GAP BI | ALIGNED | ALIGNED |
| Iroha 3 | GAP | GAP | ACCEPTED + GAP (one auditor) | ALIGNED protocol / GAP Lensa | ACCEPTED | ALIGNED |

## Principles that hold on every platform

1. **Keys stay with their owner.** Each bank signs with keys in its own custody (Paladin signing module or HSM/Vault, bank-owned EOA signer, bank FSC node secret, bank Iroha seed). Lensa holds no bank key and becomes a relay or one client per bank. DELTA item 1 on every platform.
2. **One admin domain per party.** Each bank and BI runs its own cluster or namespace with its own kubeconfig, RBAC and credentials. No shared cluster-admin kubeconfig, no shared basic-auth or ingress secret.
3. **Each bank runs its own consensus node.** Besu QBFT validator per bank (4 validators tolerate 1 down), Arma party + committer per org (f=1 with 4 parties; 7 recommended for production), Iroha peer per bank (V1 fixed at 4 validators; fixed lane author is an accepted upstream limit).
4. **Only upstream-required third parties remain, and each is cited.** Noto notary (BI) and Pente 100% endorsement; Iroha APS online auditor (k-of-n up to 32 is supported, our single auditor is the gap); Zeto report groups need BI reachable (no observer role). Fabric-X has no upstream-required third party: 3-of-4 endorsement and report-to-BI are deployment choices and stay documented as such.
5. **Settings over code.** Every AFTER setting cites the upstream file or doc that supports it. Where upstream has a hard limit it is stated with its citation and the best configuration under it. Open decisions for the user are listed per file (registry ownership, custodian party, proving-key ceremony, retire multiregion stack, Atom.cancel mitigation, Iroha 3 multi-party leg exchange: upstream has no protocol for passing prepared legs between clients, so full self-submit on Iroha 3 needs new custom code, which the no-custom rule blocks).

## How to use

- `lead`: take the DELTA lists, assign owners and order, and bring user-only items (destructive deletes, scope, spend) to the user through `orchestrator`.
- Engineers: before changing a component, read the BEFORE row that cites it and the AFTER row that replaces it. A change that needs a citation not in the file goes back to `analyst` first.
- `analyst`: re-verify a file when a pin moves. Update the SOURCES block with the new pin and date.
