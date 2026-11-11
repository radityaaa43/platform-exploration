# final-design: adjustment plans from CURRENT to the accepted design

Written 2026-11-11 by `lead` under the user's planning-only GO. Target = `agents/analyst/design/ARCHITECTURE-<platform>.md` (AFTER) plus the user's objectives (decentralization per bank: validator, self-submit, third-party; R1, R2, R3). Rules: `agents/TEAM.md` §11. Nothing in this directory executes anything; every CLUSTER-OP, spend and user-only item waits for the user's approval of the plan it sits in.

Skills used (this file): `superpowers:writing-plans`, `ecc:plan` (cross-platform order), `ecc:architecture-decision-records` (ADR shape for BLOCKED items), `superpowers:verification-before-completion` (every CURRENT.md claim carries its command and quoted output; drafts reviewed against the files, not from memory).

## Files

| Platform | CURRENT (engineer, read-only study) | PLAN | CONTRACTS | ADRs (user decisions) | Verify (qa) |
|---|---|---|---|---|---|
| Zeto | [zeto/CURRENT.md](zeto/CURRENT.md) (`besu`) | [zeto/PLAN.md](zeto/PLAN.md) | [zeto/CONTRACTS.md](zeto/CONTRACTS.md) | `zeto/adr/` | `zeto/VERIFY.md` |
| Noto + Pente | [noto-pente/CURRENT.md](noto-pente/CURRENT.md) (`besu`) | [noto-pente/PLAN.md](noto-pente/PLAN.md) | [noto-pente/CONTRACTS.md](noto-pente/CONTRACTS.md) | `noto-pente/adr/` | `noto-pente/VERIFY.md` |
| Stealth | [stealth/CURRENT.md](stealth/CURRENT.md) (`besu`) | [stealth/PLAN.md](stealth/PLAN.md) | [stealth/CONTRACTS.md](stealth/CONTRACTS.md) | `stealth/adr/` | `stealth/VERIFY.md` |
| Fabric-X | [fabricx/CURRENT.md](fabricx/CURRENT.md) (`fabric`) | [fabricx/PLAN.md](fabricx/PLAN.md) | [fabricx/CONTRACTS.md](fabricx/CONTRACTS.md) | `fabricx/adr/` | `fabricx/VERIFY.md` |
| Iroha 3 | [iroha3/CURRENT.md](iroha3/CURRENT.md) (`iroha`) | [iroha3/PLAN.md](iroha3/PLAN.md) | [iroha3/CONTRACTS.md](iroha3/CONTRACTS.md) | `iroha3/adr/` | `iroha3/VERIFY.md` |
| Lensa (shared) | [LENSA.md](LENSA.md) (`fe`): keys Lensa holds, forwards and state per namespace, "Namespace references" | steps live in each platform PLAN (Lensa pointer steps) | n/a | n/a | per platform |

Evidence tags in CURRENT.md: `[L]` live read-only command with quoted output, `[R]` repo `path:line` at the pinned sha, `[K]` Kubernetes object by name, `[H]` hash, `[F]` file on the operator host (names only), `[U]`/`[unverified]` not verified. Where CURRENT differs from the analyst's BEFORE, CURRENT wins and the file's "BEFORE vs found" table records it.

## Namespaces (lead's naming)

`rd-<platform>-<party>`: platform in `zeto`, `noto`, `stealth`, `fabricx`, `iroha3`; party in `bi`, `bank-a`, `bank-b`, `bank-c`. Twenty namespaces in total. One namespace = one full stack for that party on that platform (consensus node, privacy/domain node, token or settlement service, gateway, OPA, key custody, state). Lensa stays the only shared component, outside these namespaces, as a relay or one client per bank with no bank key (analyst principle 1).

| Cluster | Parties | Rule |
|---|---|---|
| Cluster 1 (ap-southeast-5) | `bi`, `bank-a`, `bank-b` | existing project namespaces (`besu`, `paladin`, `dfabi`, `fabricx`, `iroha3`) keep running until the cutover step of each plan; decommission is the last step of each PLAN.md |
| Cluster 2 (ap-southeast-1) | `bank-c` | only NEW namespaces this project creates; every namespace existing there today is foreign: never read at workload level, used, modified, reused or named as reusable (incl. `fabricx-bank-c`); node-level facts only; nothing is ever deleted on cluster 2; the first write there is a CLUSTER-OP that creates the new namespaces only |

The old namespace `kaleido` was not created by this project and is not read (zeto/CURRENT.md); it is out of scope for decommission unless the user says otherwise.

## Cross-platform order

Each PLAN.md is self-contained; this is the order in which `lead` would ask for the CLUSTER-OP approvals, so that shared items settle once and the cheapest proof of the topology comes first.

1. **Shared ground (all platforms, cluster 1 then cluster 2).** Create the 20 namespaces with default-deny NetworkPolicies and per-namespace RBAC/ServiceAccounts; no workloads yet. Proof: `kubectl get ns,netpol -n <ns>` per namespace. Cluster 2 first write = namespaces only.
2. **Zeto** (Paladin stack per bank, keys already per Paladin node; smallest contract delta). Proves the per-bank Besu validator + Paladin + gateway + OPA pattern that Noto and Stealth reuse. Bank C on cluster 2 is the first cross-cluster Paladin transport test (port 9000, `directCertVerification`, no shared CA).
3. **Noto + Pente** (same Besu/Paladin pattern; notary stays BI by upstream requirement; Pente groups re-created per bank domain).
4. **Stealth** (same Besu pattern; the largest key-custody delta: Lensa holds every Stealth key today, LENSA.md section 2; custodian party = user decision).
5. **Iroha 3** (4 peers, one per party; peer-set change = re-signed genesis; sponsor per bank in the driver; auditor stays single until the user decides the leg-exchange item).
6. **Fabric-X** (re-genesis for the party placement across two clusters; the largest spend; set requests on every container before bank C's party goes to cluster 2).
7. **Decommission** (last step of every PLAN.md, cluster 1 only): only after qa PASS on the new namespaces for every flow + BI-balance proof, nothing in Lensa, `lensa-pf@*`, the OPA bundle server or CI still points at the old namespace (LENSA.md "Namespace references"), and surviving chain data snapshotted with a named backup. Reclaim policies on cluster 1 (quoted in each CURRENT.md decommission section): `fabricx` 28 PVs Delete, `iroha3` 6 PVs Delete, `paladin` 4 Postgres PVs Delete, `dfabi` 2 PVs Delete, `besu` 4 validator PVs Retain (Retain is not a backup: the disk stays and is released by hand). Deleting a PVC or a namespace with a Delete PV destroys the disk: an explicit retain or copy step precedes any delete. Destructive, user-only, own CLUSTER-OP approval at that time; rollback = none after delete, the named backup is what would be restored.

Cluster 2 sequencing inside each platform follows the analyst's capacity note (`agents/analyst/design/README.md`, "Deployment topology"): Besu + Paladin + gateways, then Iroha, then the Fabric-X party.

## Shared items that every plan references

- **Lensa relay.** Lensa today holds one mTLS client certificate accepted by all four `bank-gw-N` (de-facto key to every party), raw Stealth keys (`state/stealth.json`), Iroha signing material (`state/iroha3/*.toml`, `~/iroha3-keys`), four OPA bundle-signing keys and one admin-style kubeconfig reused for several platforms (LENSA.md sections 1-3). Target: one client identity per bank, bank keys in the bank's namespace, Lensa signs nothing for a bank. Each platform PLAN has the Lensa pointer steps (forwards, state files, env) owned by `fe`.
- **OPA / gateways.** One gateway + OPA per namespace; bundle server per party or signed bundles per party key; today's `bank-gw-1..4` and `fx-gw-1..4` live in the shared namespaces (zeto/fabricx CURRENT.md).
- **Keys and custody.** Paladin signing keys are already per node (zeto/noto); Stealth and Iroha keys move out of Lensa; the Iroha BI `[streaming] identity_private_key` exposure of 2026-11-11 (iroha3/CURRENT.md section 11, no value) is a pending user rotation decision and a prerequisite of the BI Iroha cutover.
- **Proofs.** Every live step has a RED proof (fails before, passes after) that `qa` runs from `VERIFY.md`; the BI-balance proof is the cutover gate on every platform.

## Open user decisions (BLOCKED steps, one ADR each, status proposed, decision left to the user)

| Decision | Platform(s) | ADR |
|---|---|---|
| Registry rootless (Paladin registry root key signs bank entries today) | Zeto, Noto+Pente | `zeto/adr/`, `noto-pente/adr/` |
| Stealth custodian party | Stealth | `stealth/adr/` |
| Proving-key ceremony (Zeto circuits) | Zeto | `zeto/adr/` |
| Atom.cancel mitigation | Zeto | `zeto/adr/` |
| Iroha 3 multi-party leg exchange (full self-submit needs custom code, blocked by the no-custom rule) | Iroha 3 | `iroha3/adr/` |
| Fabric-X orderer party placement across two clusters (re-genesis) | Fabric-X | `fabricx/adr/` |
| Retire the multiregion stack | per file | per platform |
| Iroha BI streaming identity key rotation | Iroha 3 | `iroha3/adr/` |

## How this is reviewed and approved

- One PR per platform directory plus this README; readers `analyst` (PASS required, TEAM.md §11) and `orchestrator`; `lead` merges. Reviewers comment or open a follow-up PR, never push to the author's branch (TEAM.md §4).
- Disagreement with an AFTER row = a "DEVIATION REQUEST" section in that PLAN.md, sent to `analyst` (copy `orchestrator`); `analyst` answers; the user decides. No custom Paladin code, fork, patch or workaround anywhere.
- After the user approves a PLAN.md, each CLUSTER-OP step still gets its own GO (TEAM.md §5), in the cross-platform order above unless the user changes it.
