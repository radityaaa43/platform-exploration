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

`rd-<platform>-<party>`: platform in `zeto`, `noto`, `stealth`, `fabricx`, `iroha3`; party in `bi`, `bank-a`, `bank-b`, `bank-c`. Twenty namespaces in total (sixteen if the user takes option A of decision 24: Noto+Pente share the Zeto namespace and Paladin node of each bank; Stealth keeps its own because it has no Paladin node). One namespace = one full stack for that party on that platform (consensus node, privacy/domain node, token or settlement service, gateway, OPA, key custody, state). Lensa stays the only shared component, outside these namespaces, as a relay or one client per bank with no bank key (analyst principle 1).

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
4. **Stealth** (same Besu pattern; the largest key-custody delta: Lensa holds every Stealth key today, LENSA.md section 1.2; custodian party = user decision).
5. **Iroha 3** (4 peers, one per party; peer-set change = re-signed genesis; sponsor per bank in the driver; auditor count = decision 19 (ADR 0002), leg exchange = decision 18 (ADR 0001)).
6. **Fabric-X** (re-genesis for the party placement across two clusters; the largest spend; set requests on every container before bank C's party goes to cluster 2).
7. **Decommission** (last step of every PLAN.md, cluster 1 only): only after qa PASS on the new namespaces for every flow + BI-balance proof, nothing in Lensa, `lensa-pf@*`, the OPA bundle server or CI still points at the old namespace (LENSA.md "Namespace references"), and surviving chain data snapshotted with a named backup. Reclaim policies on cluster 1 (quoted in each CURRENT.md decommission section): `fabricx` 28 PVs Delete, `iroha3` 6 PVs Delete, `paladin` 4 Postgres PVs Delete, `dfabi` 2 PVs Delete, `besu` 4 validator PVs Retain (Retain is not a backup: the disk stays and is released by hand). Deleting a PVC or a namespace with a Delete PV destroys the disk: an explicit retain or copy step precedes any delete. Destructive, user-only, own CLUSTER-OP approval at that time; rollback = none after delete, the named backup is what would be restored.

Cluster 2 sequencing inside each platform follows the analyst's capacity note (`agents/analyst/design/README.md`, "Deployment topology"): Besu + Paladin + gateways, then Iroha, then the Fabric-X party.

## Shared items that every plan references

- **Lensa relay.** Lensa today holds one mTLS client certificate accepted by all four `bank-gw-N` (de-facto key to every party), raw Stealth keys (`state/stealth.json`), Iroha signing material (`state/iroha3/*.toml`, `~/iroha3-keys`), four OPA bundle-signing keys and one admin-style kubeconfig reused for several platforms (LENSA.md sections 1.1-1.2). Target: one client identity per bank, bank keys in the bank's namespace, Lensa signs nothing for a bank and holds no kubeconfig of any org (gateways reached via NodePort/LoadBalancer + mTLS, no port-forward). One recorded exception until decision 18: Iroha `dvp-shared` on the Lensa host with all Iroha seeds (iroha3 S16). Each platform PLAN has the Lensa pointer steps (forwards, state files, env) owned by `fe`.
- **OPA / gateways.** One gateway + OPA per namespace; bundle server per party or signed bundles per party key; today's `bank-gw-1..4` and `fx-gw-1..4` live in the shared namespaces (zeto/fabricx CURRENT.md).
- **Keys and custody.** Paladin signing keys are already per node (zeto/noto); Stealth and Iroha keys move out of Lensa; the Iroha BI `[streaming] identity_private_key` exposure of 2026-11-11 (iroha3/CURRENT.md section 11, no value) is a pending user rotation decision and a prerequisite of the BI Iroha cutover.
- **Proofs.** Every live step has a RED proof (fails before, passes after) that `qa` runs from `VERIFY.md`; the BI-balance proof is the cutover gate on every platform.

## User decisions, in one place

Every user-only item from the five plans (30 rows), with the step it blocks and the default `lead` would apply if the user says nothing (the default is a recommendation, not a decision; ADRs are status proposed). `orchestrator` presents this table to the user once, after the README PR.

| # | Decision | Platform | Blocks step | Options (ADR has pros/cons) | Default if the user says nothing | ADR |
|---|---|---|---|---|---|---|
| 1 | Credentials: (a) the real cluster-2 (Singapore) kubeconfig, admin on the NEW namespaces only; (b) cluster-1 namespace-scoped credentials per party (ServiceAccount tokens), with the cluster-admin kubeconfig kept by the operator only (design principle 2) | all | first cluster-2 write: zeto S2, stealth S2, iroha3 S1a, fabricx S1 (cluster-2 sub-step) + S18; cluster-1 credentials: zeto S1, stealth S1, iroha3 S1b, fabricx S1 | supply / keep cluster 1 only | none; without (a) bank C stays on cluster 1 as a plan deviation; (b) issued by the operator at the first namespace step | - |
| 2 | Paladin CRDs on cluster 2 (cluster-scoped install, beyond new namespaces) | zeto, noto | zeto S9 (bank C node) | install `paladin-crds` chart / bank C Paladin node on cluster 1 | none; explicit yes needed (first cluster-scoped write on cluster 2) | - |
| 3 | Spend: LoadBalancers and NodePorts for cross-cluster peers and gateways (Besu bank C TCP 30303 zeto S3/S4; Paladin 9000 zeto S10; bundle server zeto S17; Iroha peer LBs iroha3 S6 and gateways S14; stealth JWT RPC/gateway S4/S17; Fabric-X bank-C party S18) | all | the steps named | minimum count per plan / relay hub (iroha3) | minimum count, TCP-only, one per cross-cluster endpoint | - |
| 4 | Registry rootless: today BI's root key signs bank registry entries | zeto, noto | zeto S11, noto S5 | keep BI root (cited upstream limit) / new rootless registry + re-registration | keep BI root, recorded as accepted limit; endpoint republish runs as a runbook | zeto/adr/0001, noto-pente/adr/0001 |
| 5 | Proving-key ceremony (Zeto circuits; replacing keys = rebuild of the running fork image) | zeto | zeto S12 | keep bundled keys / ceremony + image rebuild | keep bundled keys (research scope); ceremony listed as follow-up | zeto/adr/0002 |
| 6 | Atom.cancel mitigation and the BI-down cancel test (`Atom.sol:102-107`: cancel by any party once the atom is not executed; RestrictedAtom adds an executor, project contract, no Paladin change) | zeto, noto | zeto S13, noto S14 | accept the upstream limit (record) / test only, no contract change / contract change (RestrictedAtom executor rule) | test only, no contract change; result recorded | zeto/adr/0003, noto-pente/adr/0002 |
| 7 | Zeto seed custody: copy under party custody is a trust reset; rotate or not | zeto | zeto S6/S7 | copy only / rotate (new identities, balances moved) | copy under party custody now; rotation as follow-up | zeto/adr/0004 |
| 8 | Bank-side DvP flow (who drives seller and buyer legs) | zeto | zeto S18 | per ADR | keep today's flow until chosen | zeto/adr/0005 |
| 9 | Stealth custodian party (DvPFactory custodian, bond controller) | stealth | stealth S12, S13, S15 | BI / a bank / a new party | BI (status quo) | stealth/adr/0001 |
| 10 | DFABI certificate model (R2 for Stealth: BI must sign a certificate before a bank tx; `architecture-brief.md:461`, ARCHITECTURE-stealth.md hard limit 4) | stealth | stealth S13 | keep online BI signer (R2 stays GAP, documented) / change model | keep online signer, R2 GAP recorded | stealth/adr/0002 |
| 11 | RD issuer redeploy vs key move | stealth | stealth S14 | move key, keep address / redeploy | move key, keep address | stealth/adr/0003 |
| 12 | Stealth key reset after the custody move (keys sat in Lensa's shared state file) | stealth | stealth S9, S10, S21 | copy only / rotate per bank | copy now, rotate per bank as follow-up; Lensa copy destroyed at S21 | - |
| 13 | Fabric-X orderer/committer party placement across two clusters (re-genesis either way) | fabricx | fabricx S9, S10, S11, S18 | per ADR (X/Y) | none; the user picks (data does not carry across the re-genesis) | fabricx/adr/0001 |
| 14 | Retire the multiregion namespaces `fabricx-bi`, `fabricx-bank-a/b/c` on cluster 1 | fabricx | fabricx S21 | retire after inventory + backup / keep | retire, after inventory and named backup | fabricx/adr/0002 |
| 15 | LifecycleEndorsement policy | fabricx | fabricx S8 | 4-of-4 / MAJORITY | MAJORITY (one org down must not block lifecycle) | fabricx/adr/0003 |
| 16 | Delete `rdbi-driver` Deployment + `rdbi-driver-files` Secret (view keys of every node) | fabricx | fabricx S5 | delete after export / keep | delete after manifest export (Secret unrecoverable unless exported) | - |
| 17 | Post the accepted Panurus patches upstream | fabricx | fabricx S7 | post / keep local | keep local (standing rule: post nothing upstream) | - |
| 18 | Iroha leg exchange (full self-submit needs custom code; upstream has no protocol for passing prepared legs between clients) | iroha3 | iroha3 S17; iroha3 S16 interim | per ADR | keep the BI sponsor path (no custom code). COST: `dvp-shared` keeps running on the Lensa host with ALL Iroha seeds mounted (payer, recipient, BI sponsor; never the auditor key) as a recorded gap against the keyless-relay target (iroha3 S16, CONTRACTS dvp-shared row) until this is decided | iroha3/adr/0001 |
| 19 | Iroha auditor orgs 2 and 3 (k-of-n; design DELTA 5/6 = new pools carry k-of-n from the start) | iroha3 | iroha3 S12, S13 | 2-of-3 with orgs 2 and 3 named by the user (analyst proposal) / single auditor (accepted upstream gap) | none: the user names orgs 2 and 3 or picks single auditor; S13 holds until then | iroha3/adr/0002 |
| 20 | Iroha BI streaming identity key rotation (printed to one agent terminal 2026-11-11) | iroha3 | iroha3 S4 (BI cutover) | rotate at cutover / rotate now (peer restart) / accept | rotate at the BI namespace cutover (new peer.toml there) | - |
| 21 | Iroha new genesis = new network_id: balances and the 147 audit records do NOT carry | iroha3 | iroha3 S5 | accept (snapshot old audit store) / keep old chain | accept; old audit store snapshotted before decommission | - |
| 22 | Bond controllability (`isControllable` true; `renounceControl` is irreversible and strands DvPEscrow refunds that wait for the controller) | stealth | stealth S12 (renounce option only) | keep controllable with the custodian as controller / empty controllers / `renounceControl` | keep controllable, custodian = controller | stealth/adr/0004 |
| 23 | Decommission the old cluster-1 namespaces after cutover proof (destructive) | all | last step of every plan | per directive | as directed: own CLUSTER-OP at that time, named backup first | - |
| 24 | Zeto and Noto+Pente: one Paladin node + namespace per bank shared by both (A) or one node + namespace per platform per bank (B). Both are domains of one Paladin node (`paladin@v1.0.0` spec.domains); A halves nodes and keys with no decentralization loss inside one bank; B is the literal reading of "one namespace per bank per platform" (ARCHITECTURE-zeto.md:164, ARCHITECTURE-noto-pente.md:162) | zeto, noto | noto-pente S6/S12 (namespace ids), zeto S1/S9 | A / B | none; analyst recommends A, lead recommends A; the noto-pente plan writes `rd-zeto-<party>` ids with the option-B name beside them until decided | - |
| 25 | Cluster-1 admin credential custody: the cluster-admin kubeconfig can read every party Secret (Kubernetes limit); who holds it, and whether Secrets encryption at rest is configured on cluster 1 (cluster-config write) | zeto (shared with noto, stealth) | zeto S1 "Admin credential custody", S20 (Lensa loses its admin kubeconfig) | operator (the user) only, mode 600, never on the Lensa host / + encryption at rest / third-party key store | operator only + removed from the Lensa host at zeto S20; encryption at rest deferred | zeto/adr/0004 |
| 26 | Stealth BI view-key handover: each bank operator hands its own view key to BI (BI scans all banks' traffic today with keys held in Lensa) | stealth | stealth S11 | per-bank handover / keep today's BI-side copy | per-bank handover by each operator; no Lensa copy | - |
| 27 | Postgres product + spend for the per-party Paladin DBs (one instance + PVC per party, HA + restore test) | zeto (shared with noto) | zeto S8 | sidecar Postgres as today / managed Postgres | sidecar Postgres 17 per party with PVC; managed service deferred | - |
| 28 | Vault/KMS product + spend for Stealth key custody | stealth | stealth S7 | Kubernetes Secret per party (as the Paladin seeds) / Vault / cloud KMS | Kubernetes Secret per party now; Vault/KMS as follow-up | - |
| 29 | PVC spend: new per-party volumes on both clusters (zeto 3x40Gi Besu + 4x20Gi Postgres; stealth 4x40Gi RPC nodes; iroha3 4 peers + stores; fabricx per-org orderer/CA/committer PVCs) | all | zeto S3/S8, stealth S4/S5, iroha3 S7, fabricx S11/S13 | approve per plan / shrink sizes | sizes as in CURRENT.md today; capacity read before each step | - |
| 30 | Cutover windows (Lensa idle, lock held, live flows stopped): zeto S21 (Paladin node flip, shared with noto and stealth), stealth S20, fabricx S20, iroha3 S18 | all | those steps | user names the windows | lead proposes windows per step in the CLUSTER-OP request at that time | - |

## How this is reviewed and approved

- One PR per platform directory plus this README; readers `analyst` (PASS required, TEAM.md §11) and `orchestrator`; `lead` merges. Reviewers comment or open a follow-up PR, never push to the author's branch (TEAM.md §4).
- Disagreement with an AFTER row = a "DEVIATION REQUEST" section in that PLAN.md, sent to `analyst` (copy `orchestrator`); `analyst` answers; the user decides. No custom Paladin code, fork, patch or workaround anywhere.
- After the user approves a PLAN.md, each CLUSTER-OP step still gets its own GO (TEAM.md §5), in the cross-platform order above unless the user changes it.
