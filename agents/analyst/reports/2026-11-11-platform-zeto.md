PLATFORM: ZETO @ besu@927f572 frontend@aa6e09b   Upstream: paladin@v1.0.0 (operator), zeto@v0.5.1, besu 26.8.1; nodes run the fork ghcr.io/radityaaa43/paladin@sha256:6f113f38 (accepted).
Reviewer: analyst subagent (sonnet), read-only, live reads 2026-11-11. Rows marked (all) are shared with Noto+Pente and Stealth and are not repeated in those files.

DECENTRALIZATION: validator=GAP | self-submit=GAP | third-party=ACCEPTED

component | runs today | per-bank or shared | upstream rec (source)
- Besu validator (all) | ns besu sts besu-node-validator-1..4, hyperledger/besu:26.8.1, secret besu-node-validator-N-keys (keys accountPrivate.key, nodekey.pub) | 4 validators, one ns, one admin; owner per validator not labelled; netpol pairs validator-N with paladin-nodeN and bank-gw-N, mapping 1=BI 2=A 3=B 4=C inferred | QBFT >= 2/3 up, 4 tolerate 1 down (docs.besu-eth.org/private-networks/concepts/poa "Liveness"); operator sample runs all validators in one cluster for dev (paladin@v1.0.0:doc-site/docs/concepts/cloud_native.md:18)
- Paladin node (all) | ns paladin sts paladin-node1..4, fork image, each node on its own validator-N RPC | node1=BI, 2/3/4=A/B/C; per bank, one cluster | one node per org (architecture/overview.md, not line-pinned)
- Paladin operator (all) | deploy paladin-operator v1.0.0, 1 replica, manages all 4 CRs | shared (minor) | dev/sample convenience (cloud_native.md:15-23)
- Postgres (all) | sidecar postgres:17.6 per node, 20Gi PVC, secret paladin-nodeN-db (username, password) | per bank sidecar | sidecar is "testing and development"; production HA PostgreSQL (cloud_native.md:5,21)
- Key custody (all) | autoHDWallet, secret nodeN.keys (keys.yaml); keyStore static, keyStoreSigning false, keyManager.disableSignRPC=false | per-bank seed, all 4 readable by one cluster-admin (`kubectl auth can-i get secrets -n paladin` yes); alibaba.yaml mode 664 at repo root (major) | HSM/Vault/remote signing module for production (architecture/key_management.md "Signing Modules"); disableSignRPC to stop external signing (configuration.md:9,344)
- Zeto prover/circuits | libzeto.so + /app/domains/zeto/zkp in each node image; static domain config per CR (defaultGasLimit 30000000, allowSigning true) | per bank (ALIGNED) | allowSigning needed by sample (getting-started/installation-manual.md:166)
- Registry + factories | evm-registry 0x99f3…7874, noto/pente/zeto factories all deployed by node1 (BI) | shared, BI-owned | IdentityRegistry owner = msg.sender unless rootless (solidity/contracts/registry/IdentityRegistry.sol:45-47); our `rootless` arg not read
- Pente groups {bank, bi@node1} | one per bank, carry the Zeto reports (R1 mechanism) | BI in every group | threshold 100% (domains/pente/.../PenteDomain.java:102)
- OPA gateway | ns paladin deploy bank-gw-1..4 (envoy 1.38.9 + opa 1.21.1), secret bank-gw-N-mtls; Lensa path only, node-to-node direct | one per bank (ALIGNED); policy is BI's, identical on all 4 | not covered upstream
- bundle-server | ns paladin 1 replica nginx + python | shared (minor) | not covered upstream
- Ingress | nginx paladin-nodeN.apse5…; all 4 share ONE basic-auth secret paladin-basic-auth (key auth) | shared credential (major) | per-org credentials (doc-site/docs/administration/auth.md, opened, not line-cited)
- kubeconfig / Lensa host (all) | one cluster-admin alibaba.yaml (4 identical copies, mode 664); one host runs lensa.service 127.0.0.1:8790 + lensa-pf@*; ~/.opa-keys holds bi.pem, bank-a/b/c.pem together; ~/.opa-mtls holds ca.key + every gw client key | shared (blocker for Stealth, major here) | not covered upstream
- Lensa keys, Zeto | frontend/server/state/zeto.json: contract/address names only, no private keys | n/a | Paladin signs on each node

FINDING: validators 1-4 + Paladin nodes 1-4 in one cluster under one admin; no bank owns its consensus node   SEVERITY: major   KIND: deviation
  UPSTREAM: dev sample does the same (cloud_native.md:18); Besu BFT >= 2/3, 1 of 4 down tolerated.
  EVIDENCE: `kubectl -n besu get sts` 4 sts, 20d; besu-genesis cm qbft n=4.
  FIX:      each bank runs its own validator + Paladin node in its own cluster/account.   OWNER: user (scope), lead
FINDING: all 4 HD seeds and node-RPC basic auth held by one kubeconfig and one host   SEVERITY: major   KIND: deviation
  UPSTREAM: key_management.md: key store outside the node (HSM/Vault); disableSignRPC exists and is false here.
  EVIDENCE: secrets node1..4.keys, can-i yes, alibaba.yaml 664, paladin-basic-auth shared by 4 ingresses.
  FIX:      disableSignRPC true (config change, user decision); per-bank credentials and kubeconfig.   OWNER: lead, user
FINDING: BI node in Pente group {bank, bi@node1} required for R1 reports   SEVERITY: minor   KIND: accepted
  UPSTREAM: threshold 100% (PenteDomain.java:102); `pgroup_sendMessage` checks target reachability before storing (core/go/internal/groupmgr/manager.go:157-172).
  EVIDENCE: besu/zeto/docs/r1-limitation.md; 2026-11-10 live test 6 of 6 reports lost with BI down.
  FIX:      none without upstream (observer role, paladin#610).   OWNER: accepted
FINDING: registry and all factories deployed by node1 (BI); root-owner control unconfirmed   SEVERITY: minor   KIND: unverified
  UPSTREAM: IdentityRegistry.sol:45-47.
  EVIDENCE: smartcontractdeployment registry/factories node=node1; rootless not read.
  FIX:      eth_call owner(); plan owner transfer or rootless registry.   OWNER: besu
FINDING: Zeto static per-CR domain config on the fork (upstream main + PR #1189), operator v1.0.0   SEVERITY: minor   KIND: drift
  EVIDENCE: node1 CR spec.config.domains.zeto; besu/zeto/README.md "Platform".
  FIX:      none (fork accepted).   OWNER: accepted

R1: ACCEPTED. Zeto_AnonNullifier hides consumed UTXOs; nullifier = hash(value, salt, owner private key), owner-only (zeto@v0.5.1:doc-site/docs/implementations/anon_nullifier.md, line not pinned). Event carries inputs, outputs, msg.sender (solidity/contracts/lib/zeto_fungible.sol:399). BI cannot name the sender from chain data; relies on the sending bank's report. No Paladin observer role (paladin@v1.0.0:domains/zeto/pkg/constants/constants.go:26-32, paladin#610). Full compliance needs the observer role or a Zeto variant with disclosure proof that has no lock path today (zeto doc-site implementations/index.md:10-15).
R2: ACCEPTED with one GAP. Settlement ran with BI node1 at 0 pods for 300 s (r1-limitation.md live test). What fails is BI visibility: 6 of 6 reports lost.
R3: ALIGNED with a major risk. Atom.execute runs all ops in one tx, reverts as a whole (paladin@v1.0.0:solidity/contracts/shared/Atom.sol:60-70). Atom.cancel has no access control (Atom.sol:102-107): anyone can cancel after both legs are delegated, both locks stranded (besu/zeto/README.md "DvP findings"). Mitigation: create, delegate, execute in one step. Fix needs the user's call under the no-custom rule; option: project RestrictedAtom (besu/noto+pente/contracts/src/RestrictedAtom.sol:219-224).

SOURCES: paladin@v1.0.0 (git describe verified) doc-site/docs/architecture/{noto,key_management,atomic_interop}.md, concepts/cloud_native.md, administration/configuration.md, getting-started/installation-manual.md, solidity/contracts/shared/Atom.sol, solidity/contracts/registry/IdentityRegistry.sol, domains/zeto/pkg/constants/constants.go, domains/pente/.../PenteDomain.java, core/go/internal/groupmgr/manager.go; zeto@v0.5.1 doc-site/docs/implementations/{index,anon_nullifier}.md, solidity/contracts/lib/zeto_fungible.sol; besu docs via context7 (poa, qbft); live read-only ns besu, paladin; ~/.config/systemd/user/lensa.service, ~/.config/lensa/lensa.env (names only); besu/zeto/{README.md,docs/r1-limitation.md}.
UNVERIFIED: validator ownership per org (not recorded; netpol hints 1=BI 2=A 3=B 4=C); IdentityRegistry rootless and owner; LENSA_BESU_RPC_BANKS live value; upstream notary rotation / multi-notary / observer role not proven absent; auth.md and overview.md not line-cited; examples/swap not opened (Zeto DvP detail rests on besu/zeto/README.md, fork build).
