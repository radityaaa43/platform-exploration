# 0002. Iroha 3 auditor orgs 2 and 3 and the k-of-n policy

Date: 2026-11-11
Status: proposed
Deciders: user

## Context
Objective (c), third-party auditor. Today one BI-run auditor holds the only key, `min_approvals: 1`, one `auditors` entry (`iroha3-rd-node-build@ceccc4d driver/src/aps.rs:917,919`; CURRENT.md section 2). Upstream supports `1 <= k <= n <= 32`, a capsule key wrapped per auditor so each decrypts alone, and a Prepare vote refused below `min_approvals` (`iroha@071e281e crates/iroha_data_model/src/nexus/private_settlement.rs:2127-2129,2222-2227`; `crates/iroha_core/src/private_settlement/audit.rs:163-173`; `crates/iroha_core/src/private_settlement/state.rs:1118`). An extra auditor runs the official `iroha nexus private-settlement audit-online` under its own org (`crates/iroha_cli/README.md:194-256`). The ARCHITECTURE file proposes 2-of-3 (BI, org 2, org 3) as default and names 2-of-2 as the minimum, but does not say who org 2 and org 3 are. The namespace naming rule (`rd-iroha3-<bi|bank-a|bank-b|bank-c>`) has no slot for them. Plan step: S12; S13 waits for it.

## Decision
Left to the user: the identity of the extra auditor orgs and the policy (k, n). Not decided by the drafter.

## Alternatives Considered
1. 2-of-3: BI plus two other orgs (analyst default).
   - Pros: one auditor down does not stop Prepare; removes BI as sole auditor.
   - Cons: needs two external orgs with their own namespace/cluster, keys and business policy; more WAN endpoints.
   - Why not: depends on who the user can name for orgs 2 and 3.
2. 2-of-2: BI plus one other org (analyst minimum).
   - Pros: only one extra org; ends the single-auditor gap.
   - Cons: either auditor down stops every Prepare (`min_approvals` unmet).
   - Why not: weaker availability than option 1.
3. Keep 1-of-1 (BI only; today).
   - Pros: no new org, no change.
   - Cons: third-party objective stays GAP (single auditor, single key); auditor down = no Prepare (accepted upstream limit).
   - Why not: leaves objective (c) open; acceptable only as a recorded accepted limit.

## Consequences
- Options 1 and 2: the new chain's pools are activated with the chosen policy from the start (S13); `RotatePrivateSettlementPoolPolicyV1` (specs `:375-392`) is needed only for a later change.
- The business policy of every auditor must allowlist all four sponsors (S10 makes each bank its own sponsor).
- Until decided, S12 and S13 stay BLOCKED: no pool is activated before the policy is chosen, so there is no later rotation. Option 3 (keep 1-of-1) is a user choice inside the AFTER's decision list, not a deviation.
