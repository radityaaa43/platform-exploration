# ARCHITECTURE-iroha3

Date 2026-11-11. Upstream pin `hyperledger-iroha/iroha@071e281e778c5928cab4d6e007b7ddc9b050df27` (checked: `git log -1` in upstream/iroha-071). Project `iroha3@e2a1794` (read with `git show e2a1794:`; HEAD 589d9e0 only adds NOTES.md), driver `iroha3-rd-node-build@be4dd89`, frontend `@ed7b78b`. Live reads from ns `iroha3`, read-only, secret names only. `docs.iroha.tech` is a JS app and was not used; all citations are repo files at the pin.
Scope: Iroha 3 APS track. Objectives: (a) validator per bank, (b) self-submit per bank, (c) third-party auditor. R1 ALIGNED protocol / GAP Lensa; R2 ACCEPTED; R3 ALIGNED. No custom code beyond what exists.

## 1. BEFORE (today): one operator runs everything

```mermaid
flowchart LR
  subgraph OP["ONE OPERATOR: ns iroha3, one kubeconfig"]
    BI["bi-0 peer"]; A["bank-a-0 peer"]; B["bank-b-0 peer"]; C["bank-c-0 peer"]
    AUD["bi-auditor Deployment, 1 key, min_approvals 1"]
    RUN["gha-runner-0, Role gha-deployer"]
    JOB["scenario Jobs rd-s1..s4"]
  end
  subgraph LH["LENSA HOST: same operator"]
    FE["Lensa iroha3-aps.ts"]
    DRV["driver container, network host, sponsor = BI"]
    KEYS["~/iroha3-keys: all seeds, notes, auditor keys"]
    POOLS["pools.json"]
  end
  FE -->|"docker run"| DRV
  KEYS --> DRV
  POOLS --> DRV
  DRV -->|"1 certify, 2 upload leg to every endpoint"| BI & A & B & C
  DRV -->|"3 POST /approve"| AUD
  AUD -->|"fetch capsule, submit approval"| BI & A & B & C
  DRV -->|"4 prepare votes, 5 register, 6 commit, 7 finalize, receipt"| BI & A & B & C
  JOB -->|"client-bi + rd-dfabi-wallets"| BI
  BI <-->|"p2p 1337, lane author = validator_set[(h-1) mod 4]"| A & B & C
```

| Box / arrow | Source |
|---|---|
| 4 peers, 1 replica each, own PVC 5Gi, Secret `peer-<party>`, `--sora --config /config/peer.toml` | `deploy/k8s/base/statefulset.yaml:56,120,130-133`; live `kubectl get sts,pvc -n iroha3` (4 STS, 4 PVC, 4 nodes) |
| All 4 peers keys made by one operator PC run; genesis private key in `network/out` | `network/generate.sh:2-4,65-68,429-430` |
| `peers.json` = party, public_key, pop_hex only | `network/public/peers.json`; `generate.sh:155-159` |
| 3 lanes (universal, ds-rd, ds-dfabi), all 4 validators in all, stake_elected, `max_validators = 4`, fault_tolerance 1 | `network/nexus.toml:8-9,14-30,63-69` |
| Each party holds 1000 XOR at genesis; fee 0.001 per instruction | `network/genesis-rd-dfabi.jq:26`; `nexus.toml:78-83` |
| Committee-role consensus key per peer, built from peer key + PoP | `generate.sh:312-316,365-397` |
| Sponsor is always BI (client-bi `client.toml`) | `driver/src/aps.rs:207`; `pools.rs:273,346`; `config.rs:96-102` |
| Driver holds payer, recipient and sponsor keys in one process; recipient note secrets derived from recipient `.note` | `aps.rs:1175,1211,1283-1289`; `pools.rs:388-394`; `config.rs:126-132` |
| Lensa runs driver with host network, mounts `~/iroha3-keys` and pools dir | `frontend@ed7b78b server/src/adapters/iroha3-aps.ts:9-10,14,34-37` |
| certify, upload to every endpoint (fails on first error), prepare, commit, finalize, wait receipt | `aps.rs:352-380,418-450` |
| Auditor: custom HTTP service, one key, `min_approvals: 1`, one `auditors` entry; Secret `bi-auditor-key`, PVC `bi-audit-store`, own NetworkPolicy | `driver/src/auditor.rs:1-6`; `aps.rs:246-248,384-393,879-884`; `deploy/k8s-apps/bi-auditor.yaml:8-10,21-28,89,110`; `NOTES.md:45` |
| Pool activation by the same BI client | `aps.rs:279-291` (permission: see section 2, Governance) |
| `pools.json`: public data only (origin commitments, bundle ids), single writer | `pools.rs:4-8,105-111`; `NOTES.md:22` (M1 race) |
| Torii: headless ClusterIP `:8080`, any pod in ns may call; no ingress | `deploy/k8s/networkpolicy.yaml:18-22`; live `kubectl get svc,ingress -n iroha3` |
| One runner with Role `gha-deployer` (pods/exec, secrets get/list) | `agents/analyst/reports/2026-11-11-platform-iroha3.md` (live read, not repeated) |
| Lane author fixed per height, no failover; BI down = no user tx | `iroha@071e281e crates/iroha_core/src/lane_consensus.rs:96-107,854-860`; `iroha3/reports/g1-network.md` |
| Live: 4 peer pods, bi-auditor, gha-runner-0, Jobs rd-s1..s4 + selftest; Secrets `peer-*`, `client-*`, `rd-dfabi-wallets`, `bi-auditor-key` | `kubectl get pods,secret,jobs -n iroha3` 2026-11-11 |

## 2. AFTER (target): one org per box, shared public artifacts only

```mermaid
flowchart LR
  subgraph SH["SHARED, public only"]
    GEN["genesis.signed.nrt, expected_hash, public_key, chain_id"]
    PJ["peers.json: public_key + pop_hex"]
    NX["[nexus] overlay, ds-rd, ds-dfabi, pools"]
  end
  subgraph BIO["BI org"]
    BIP["bi peer: own BLS key, own PVC"]
    GOV["governance client: CanEnactGovernance, CanReadAllLedgerData"]
    AUD1["auditor 1: audit-online, own signing + hybrid key"]
  end
  subgraph BKA["Bank A org, same shape for B and C"]
    AP["bank-a peer: own BLS key, own PVC"]
    AC["bank-a client.toml, seed, note key, own sponsor"]
  end
  subgraph AO["Auditor org 2 and 3"]
    AUD2["audit-online, own keys, own business policy"]
  end
  GEN --- BIP & AP
  PJ --- BIP & AP
  AC -->|"signed requests, any peer Torii"| BIP & AP
  AUD1 & AUD2 -->|"fetch capsule, submit approval"| BIP & AP
  BIP <-->|"p2p 1337, cross-org"| AP
  GOV -->|"Activate / Rotate pool"| BIP
  AC -.->|"leg exchange: NOT in upstream"| AC
```

| Box / arrow / setting | Upstream citation (iroha@071e281e) |
|---|---|
| Per-validator key + PoP: `kagami keys --algorithm bls_normal --pop --out-dir` writes `public.key`, `private.key`, `pop.hex`; private key never printed | `crates/iroha_kagami/README.md:77-87,223-235`; `crates/iroha_kagami/src/crypto.rs:18-28` |
| Genesis from public data only: `kagami genesis ... --peer-pop PK=POP` per peer, `--private-key-file` of the genesis signer, `--expected-hash-out`; hash file = trust root for `genesis.expected_hash_file` and client `network_id_file` | `crates/iroha_kagami/README.md:249-273` |
| Peer config carries `trusted_peers` + `trusted_peers_pop`, BLS only | `crates/iroha_config/src/parameters/user.rs:845,857,1096` |
| Our genesis step already reads only `peers.json` for the Committee keys (so keys may be made elsewhere) | `generate.sh:330-397`; spec `specs/private_settlement.md:46-50` |
| Authority = exact 4-peer roster from consensus, `f = 1`, every BLS PoP verified, live Committee key per member | spec `:42-52` |
| Committee-only peer exists upstream (registered, in P2P, not in lane-0 topology). Liveness effect NOT verified; not used | spec `:49-50` |
| Peer startup, probes, PVC | `deploy/k8s/base/statefulset.yaml:56,73-91,133` |
| Bank client: own `client.toml` (chain, torii_url, network_id_file, account domain/private_key/public_key); same shape as driver `client_with_key` | `driver/src/config.rs:105-123`; `crates/iroha_kagami/src/client_configs.rs` exists (not read) |
| Torii auth: leg upload, availability, votes = any canonical account signature; bundle carriers = sponsor signature; capsule/approvals = identity-bound governed auditor; receipts public | spec `:545-559` |
| Every client must reach all four Torii endpoints (exactly four distinct, canonical order, 3-of-4 quorum) | spec `:296-310`; `crates/iroha/src/client/private_settlement.rs:379-470` |
| Own sponsor: carrier authority must equal `manifest.sponsor` and fee intent; sponsor also gets leg-0 reimbursement output | `crates/iroha_core/src/private_settlement/carrier.rs:215-219`; spec `:457-499` |
| Pool governance stays at BI: `ActivatePrivateSettlementPoolV1` and `RotatePrivateSettlementPoolPolicyV1` both call `ensure_privacy_governance` (CanEnactGovernance; genesis grants it to one account) | `crates/iroha_core/src/smartcontracts/isi/private_settlement.rs:23-29,49-55`; `smartcontracts/isi/privacy.rs:110,6086`; `generate.sh:392`; `crates/iroha_data_model/src/isi/private_settlement.rs:106,139` |
| Auditors: `min_approvals`, `auditors` (id, signing_key, hybrid encryption_key), `1 <= k <= n <= 32` | `crates/iroha_data_model/src/nexus/private_settlement.rs:61,2077-2084,2127-2129,2222-2227` |
| Capsule DEK wrapped independently per auditor in policy order, so each auditor decrypts alone | `crates/iroha_core/src/private_settlement/audit.rs:4-5,163-173` |
| Prepare vote refuses if approvals < `min_approvals` | `private_settlement/state.rs:1118`; `data_model/.../private_settlement.rs:3958-3964` |
| Third-party auditor as separate org process: `iroha nexus private-settlement audit-online` (4 `--committee-endpoint`, `--committee-authority`, `--payload-digest`, `--pool-governance`, `--auditor-decryption-key-file`, `--business-policy`, `--decision`); signing key must not be a committee consensus key; business policy allowlists payer/recipient/sponsor/asset | `crates/iroha_cli/README.md:194-256`; `crates/iroha_cli/src/nexus.rs:229-257`; spec `:296-340` |
| Rotation: exact current `governance_digest`, revision +1, strictly newer `key_epoch`, no pending bundle across the boundary; retired decryption keys kept (`--auditor-retired-decryption-key-file`) | spec `:375-392,353-360`; `nexus.rs:249` |
| Reads of all ledger data need `CanReadAllLedgerData`; it is genesis-only and not delegable after genesis | `iroha_torii/src/lib.rs:19382-19390`; `iroha_executor_data_model/src/permission.rs:486-491`; `iroha_core/src/executor.rs:8225-8236`; `executor_initial_permission_authority.rs:668-676` |
| Holder of `CanReadAllLedgerData`: BI only (as auditor-side reader). Today a shared operator account, same on all nodes; BI's own key cannot read A to B tx | `iroha3/reports/a-dataspace-restricted.md:61,215`; not in `genesis-rd-dfabi.jq` (grants there: CanReadRestrictedDataspace only, `:16-17,27-28`); source of the grant not re-verified |
| Shared artifacts stay: dataspaces ds-rd (id 1), ds-dfabi (id 2), 2 pools, APS overlay. Genesis is signed against a `peer.toml`, so `[nexus]` is a shared, byte-agreed section | `nexus.toml:14-53,98-105`; `generate.sh:403-415` |

### Multi-party leg question (two-leg DvP, can each bank prove its own leg?)

Finding: protocol routes allow it, library and docs give no way to do it. Status: NOT SUPPORTED as shipped; a transport would be new custom code.
- Routes: leg upload and availability certify accept any account signature (spec `:547-548`); only bundle carriers need the sponsor (spec `:557`, `carrier.rs:215`). So legs may be uploaded by different authorities at route level.
- Library: `certify_and_upload_private_settlement_legs_v1` takes all legs in one call and rejects a material whose manifest differs from the first (`crates/iroha/src/client/private_settlement.rs:2527-2557`). `finalize_atomic_private_settlement_provisional_bundle_v1` takes one input per manifest leg (`crates/iroha_core/src/privacy_engines/atomic_private_settlement/wallet.rs:379-384`). The prepared leg (statement, proof, delta, capsule; no witness) derives only Clone/PartialEq/Eq, "native client-side construction value rather than wire object" (`wallet.rs:139-148,222-228`). Witness stays in an owner-only wallet file inside Rust (`wallet.rs:1-8`; spec `:197-209`).
- Manifest is a public-intent skeleton fixed before proving (`wallet.rs:365-372`), so each payer could prove locally if it had the skeleton.
- Cross-party inputs each leg needs: recipient signs a view-key authorization body that binds its one-time view key and note spending authority (`data_model/.../private_settlement.rs:965-994,1645-1665`); sponsor signs the leg-0 reimbursement authorization. Driver does all of this in one process (`aps.rs:1283-1289`).
- Docs: grep of `specs/private_settlement.md` for witness, multi-party, exchange, interactive, assemble: no protocol for passing legs or authorizations between clients. Spec step 1 says "client creates proof and encrypted capsule locally" (`:444-447`). Result: "not found".
- Even `pay` is two-party today: companion leg BI to BI (`NOTES.md:44`; `pools.rs:301`). Self-submit by a bank therefore still needs a BI leg.

### Hard limits (cannot be fixed on our side)

1. Fixed lane author: `validator_set[(lane_height-1) % n]`, no view input; autonomous artifact rejected if producer differs (`lane_consensus.rs:96-107,854-860`). Any single peer down stops user txs. Spreading peers over orgs makes a stall more likely, not less. R2 ACCEPTED.
2. V1 geometry: exactly 4 validators per authority, `f = 1` (spec `:44-46`); `max_validators = 4` (`nexus.toml:69`). A fifth bank peer is impossible; banks A, B, C and BI is the full set.
3. Online auditor required: `min_approvals >= 1` (`data_model/.../private_settlement.rs:2224-2227`; `state.rs:1118`). ACCEPTED. Cost: auditor down = no Prepare.
4. No multi-party witness exchange (section above). Per-bank proving of both legs stays blocked by the no-custom rule.
5. APS "not production-qualified" (spec `:27-29`); STARK note tree in `driver/src/tree.rs` is custom (crate-private `proof_managed_accumulator.rs`), kept.
6. `CanReadAllLedgerData`, `CanReadRestrictedDataspace` are genesis-only (`executor.rs:8225-8236`); changing holders means a new genesis.

## 3. DELTA (numbered)

| # | What | Source | Objective | Files / objects | Cost |
|---|---|---|---|---|---|
| 1 | Per-bank key custody. 1a: move `bi-auditor.seed/.hybrid` out of `~/iroha3-keys` into the auditor org only. 1b: each bank keeps only `<party>.seed` + `<party>.note`; Lensa host stops mounting all seeds. 1b is only complete after item 7 (today one process needs payer, recipient, sponsor keys) | `aps.rs:1175-1211,1283-1289`; `pools.rs:388-394`; `iroha3-aps.ts:14`; spec `:324-340` | (b), (c) | `~/iroha3-keys`, Secrets `rd-dfabi-wallets`, `client-bi`, `bi-auditor-key`, `deploy/jobs/scenario.yaml`, `deploy/secrets.sh:48-52` | M |
| 2 | Per-bank peer key and genesis ceremony: each org runs `kagami keys --algorithm bls_normal --pop`, publishes `public_key` + `pop_hex`; one signer builds genesis from `peers.json` only; destroy genesis private key; each org verifies `kagami genesis validate` + `expected_hash`. Split `generate.sh` into per-party keygen and assembly (assembly already reads peers.json only). Needs re-genesis (new chain id) | `kagami README.md:77-87,223-273`; `generate.sh:65-68,330-397,403-430` | (a) | `network/generate.sh`, `network/public/*`, Secrets `peer-*` | M |
| 3 | Per-bank cluster/ns: own STS, PVC, Secret `peer-<party>`, own deployer; remove cross-party `secrets get/list` runner role. Cross-org P2P :1337 and Torii :8080 reachability and `trusted_peers` addresses (currently in-ns DNS); NetworkPolicy now allows only same-ns | `statefulset.yaml:56,120-133`; `networkpolicy.yaml:11-22`; `generate.sh:91-110` | (a) | `deploy/k8s/parties/*`, `deploy/runner/rbac.yaml`, overlay per org | L |
| 4 | Own client + sponsor per bank: `client.toml` from the bank's own account key (each already holds 1000 XOR); driver reads `sponsor(<party>)` instead of `"bi"`; BI sponsorship becomes an option. Limited by item 7 for DvP and by companion BI leg for `pay` | `aps.rs:207`; `pools.rs:273,346`; `config.rs:96-102`; `carrier.rs:215`; `genesis-rd-dfabi.jq:26` | (b) | `driver/src/{aps,pools,config}.rs` (existing code, parameterize), Secrets `client-<party>` | M |
| 5 | Second auditor org, k-of-n. Default proposed: 2-of-3 (BI, org 2, org 3) so one auditor down does not stop settlement; 2-of-2 is the minimum. Policy `min_approvals` and `auditors` from config, not hardcoded 1 and one entry. Org 2 runs official `audit-online` with own keys and business policy (allowlist includes all 4 sponsors). Driver waits for approvals instead of calling one `/approve` | `aps.rs:879-884,384-393`; `data_model .../private_settlement.rs:2127-2129,2222-2227`; `audit.rs:163-173`; `crates/iroha_cli/README.md:194-256` | (c) | `driver/src/aps.rs` (`govern_until`, approve loop), new org deployment, policy files | M |
| 6 | Rotate existing pools to the new policy: `RotatePrivateSettlementPoolPolicyV1`, new `key_epoch`, revision +1, no pending bundle across the boundary; keep BI retired hybrid key (`--auditor-retired-decryption-key-file`) for old capsules. Alternative: new pools at re-genesis (item 2) with the k-of-n policy from the start | spec `:353-360,375-392`; `isi/private_settlement.rs:49-55`; `nexus.rs:249` | (c) | `pools.json`, BI governance client, `bi-audit-store` PVC | M |
| 7 | Leg exchange for per-bank proving (skeleton manifest out, recipient view-key authorization + sponsor authorization in, four prepared-leg fields to the assembler). Not in upstream; needs custom transport. BLOCKED by the no-custom rule; user decision needed. Without it, item 1b and item 4 stay partial | section 2 multi-party; `wallet.rs:139-148,222-228,365-384`; `client/private_settlement.rs:2527-2557` | (b) | new code in driver; not started | L |
| 8 | Split governance/reader account from sponsors: CanEnactGovernance + CanReadAllLedgerData only at BI, not in `client-bi` shared with Jobs and Lensa. Genesis-only, so part of item 2 | `generate.sh:392`; `executor.rs:8225-8236`; `reports/a-dataspace-restricted.md:61,215`; `privacy.rs:110` | (b), R1 | genesis, `client-bi`, `deploy/jobs/*` | M |
| 9 | Pools index: `pools.json` published by BI (public data), single writer; each bank scans its own notes from receipts | `pools.rs:4-8,105-111,351`; `NOTES.md:22` | (b) | `pools.json`, Lensa `iroha3.ts` | S |
| 10 | Lensa moves to per-bank clients and Torii endpoints (no port-forwards to all peers, no host with all keys) | `iroha3-aps.ts:9-10,34-37` | (b) | frontend adapter, `lensa.service` | M |
| 11 | Drift: re-run S1 and S2b on `be4dd898`; probe upload with one peer down (`aps.rs:374-379` fails on first error) | `aps.rs:374-379`; `agents/analyst/reports/2026-11-11-iroha3-driver-fabricx-bi-down.md` | (a) | scenario Jobs | S |

Sequence under no-custom: 2 and 8 first (one re-genesis), then 3, 5, 6 (or fresh pools), then 4 and 9 and 10. Item 7 is the gate for full (b).

## 4. SOURCES (pin, 2026-11-11)

- `hyperledger-iroha/iroha@071e281e778c5928cab4d6e007b7ddc9b050df27`: `specs/private_settlement.md`; `crates/iroha_core/src/{lane_consensus.rs,executor.rs,executor_initial_permission_authority.rs}`; `crates/iroha_core/src/private_settlement/{carrier,audit,state}.rs`; `crates/iroha_core/src/privacy_engines/atomic_private_settlement/wallet.rs`; `crates/iroha_core/src/smartcontracts/isi/{private_settlement,privacy}.rs`; `crates/iroha_data_model/src/nexus/private_settlement.rs`; `crates/iroha_data_model/src/isi/private_settlement.rs`; `crates/iroha/src/client/private_settlement.rs`; `crates/iroha_cli/{README.md,src/nexus.rs}`; `crates/iroha_kagami/{README.md,src/crypto.rs}`; `crates/iroha_config/src/parameters/user.rs`; `crates/iroha_torii/src/lib.rs`; `crates/iroha_executor_data_model/src/permission.rs`
- `radityaaa43/iroha3-rd-dfabi@e2a1794`: `network/{nexus.toml,genesis-rd-dfabi.jq,generate.sh,public/peers.json}`, `deploy/k8s/base/statefulset.yaml`, `deploy/k8s/networkpolicy.yaml`, `deploy/k8s-apps/{bi-auditor.yaml,rd-dfabi.toml}`, `deploy/secrets.sh`, `NOTES.md`, `reports/{g1-network,a-dataspace-restricted}.md`
- `radityaaa43/iroha3-rd-node-build@be4dd89`: `driver/src/{aps,pools,config,auditor}.rs`
- `rd-lensa-frontend@ed7b78b`: `server/src/adapters/iroha3-aps.ts`
- Prior reports: `agents/analyst/reports/2026-11-11-{platform-iroha3,iroha3-driver-fabricx-bi-down,matrix}.md`
- Live, read-only, `KUBECONFIG=alibaba.yaml`, ns `iroha3`: `get pods,svc,pvc,secret,cm,networkpolicy,jobs,deploy,sts,ingress` (names only)
- Not verified: `docs.iroha.tech` (JS app); `crates/iroha_kagami/src/client_configs.rs` contents; source of `CanReadAllLedgerData` grant in our genesis; behavior of a Committee-only peer for lane liveness; cross-org P2P transport security; whether client-bi holds CanEnactGovernance (inferred from `aps.rs:279-291`, secret values not read)
