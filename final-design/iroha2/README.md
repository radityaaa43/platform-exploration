# Iroha 2 (T5)

Since 2026-11-24 track T5 runs Hyperledger Iroha 2 instead of Iroha 3, following the blueprint
*Blueprint Pengembangan Hyperledger Iroha 2 — Six End-to-End Use Cases* v2.0 (2026-11-23).

- Code, deployment, CI/CD, findings and ADRs: private repo `radityaaa43/iroha2-rd-dfabi`, nested in this checkout
  at `iroha2/` (ignored here, like `iroha3/`). It stays private because its self-hosted runners can exec into
  the peers.
- Scope now: gates G0 (pinned, reproducible build of upstream `main` @ `fbe677b9`) and G1 (4 validators bi,
  bank-a, bank-b on cluster 1 and bank-c on cluster 2; finality with BI down, BI catch-up). ZK transfer, BI
  disclosure, DFABI and DvP (G2–G5) follow as separate work.
- Namespaces: `rd-iroha2-bi`, `rd-iroha2-bank-a`, `rd-iroha2-bank-b`, `rd-iroha2-ci` (cluster 1),
  `rd-iroha2-bank-c`, `rd-iroha2-ci` (cluster 2). Merging to that repo's `main` deploys to both clusters.
- Iroha 3 is kept and scaled to zero later with that repo's `scripts/scale-iroha3.sh`; nothing is deleted.
