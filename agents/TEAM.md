# Team rulebook (agents/TEAM.md)

## 0. Preamble

Shared rules for every agent on the team. Read this file, then your role file `agents/<role>/AGENT.md`.
- If a role file and this file clash, this file wins. A role file may be stricter than this file, never looser.
- Role files cite sections as `TEAM.md §N`. Style rules for every agent file: [STYLE.md](STYLE.md).
- This file holds shared rules only. Role duties live in role files. Check: `wc -l agents/TEAM.md` prints 270 or less.

Terms used in every file:
- cluster write: any change to the ACK cluster (`kubectl apply/delete/set/patch/rollout`, pod restart, image, ConfigMap, operator or CR change, contract deploy, OPA bundle publish, channel config update).
- live write: a cluster write, or a transaction sent to a live chain.
- GO: `lead`'s written approval of one named live write, with all conditions in one message.
- standing approval: an action listed in §5 that needs no GO.
- user-only: an item on the list in §4 that only the user decides.
- brief, status report: the shapes in §6.
- chain developer: `besu`, `fabric` or `iroha`. Developer: a chain developer or `fe`.

## 1. Mission, R1-R3

Prove, on live infrastructure, that Rupiah Digital (RD) and DFABI settle between banks with transaction privacy on several DLT platforms, and show the result side by side in the Lensa frontend.

Acceptance bar for every track:

| Rule | Meaning |
|------|---------|
| R1 visibility | BI, sender and receiver see the full transaction. Every other bank sees nothing useful. |
| R2 BI offline | Settlement completes when BI is offline. |
| R3 atomic DvP | The RD leg and the DFABI leg settle together, or neither does. |

Exemptions (reopen only with new evidence; only the user decides):
- Noto + Pente: notary model, exempt from R2.
- Iroha 3 (APS): BI is an online auditor, exempt from R2.
- Fabric-X: not exempt since 2026-11-01 (auditor-less PP, report to BI, 3-of-4 endorsement).

Proof per track: read the transaction from four views (BI, sender, receiver, outsider bank); quote the command and the output line. Paladin returns `PD011658` to an outsider: the expected R1 result, not a defect.

## 2. Team, addresses, architecture

- Hierarchy: user -> `orchestrator` (user-facing coordinator) -> `lead` (tech lead, sole architect) -> developers `besu` (`besu/`), `fabric` (`fabric-x/`), `iroha` (`iroha3/`), `fe` (`frontend/`), and tester `qa` (QA gate for every track and the frontend). `analyst` is a sibling of `lead` under `orchestrator`.
- A SendMessage address is the role name: `orchestrator`, `lead`, `besu`, `fabric`, `iroha`, `fe`, `qa`, `analyst`. Check the live addresses with `ListAgents`.
- `analyst`: independent evaluator vs pinned upstream docs/repos; read-only; reports to `orchestrator`; findings copied to `lead`; only the user and `orchestrator` assign it work.
- A ref like `[f98c18]` is valid until the next restart. Address by role name.

`lead` is the only architect. `lead` decides and writes down: module and directory structure, layering, interfaces and contracts between modules, data shapes, dependency choices, design patterns.
`lead` reads the code its design touches and cites `path:line` in the brief. `lead` reads the full diff of every change. `lead` does not survey code its design does not touch, and does not re-read a passed diff unless the branch changed.

Every developer:
1. Learns the project first: reads the code, the docs and `lead`'s design before coding.
2. Studies the own area and sends `lead` short, factual reports that cite `path:line`: how it works today, constraints, risks, what a task needs from the design. Reports add to `lead`'s reading and never replace it.
3. Implements inside the given design.
4. Raises instead of improvising. If the design is unclear, missing or wrong, stop and send `lead` the question with the options. Do not restructure code, add layers or abstractions, change interfaces or add dependencies alone.

Code-level choices inside the design (naming, local logic, tests) stay with the developer.

## 3. Repos and git

| Path | Owner | Git |
|------|-------|-----|
| `besu/` (`zeto/`, `noto+pente/`, `stealth-address/`, `opa/`) | besu | `radityaaa43/rd-besu` |
| `fabric-x/` (`multiorg/`, `panurus-itest/`, `opa/`) | fabric | `radityaaa43/rd-fabric-x` |
| `iroha3/` | iroha | `radityaaa43/iroha3-rd-dfabi` |
| `frontend/` (`server/` Fastify, `web/` React + Vite) | fe | `radityaaa43/rd-lensa-frontend` |
| Test files in every area (`*.test.ts`, `e2e/`, `test/`, `*_test.go`) | qa, shared with the area owner | the repo of that area |
| `agents/`, root `CLAUDE.md` | lead | `radityaaa43/platform-exploration` (coordination only) |

- Each project folder is its own git repo, nested in the platform-ekplorasi checkout and ignored by it. Commit, branch and open PRs there (`git -C <folder> ...`). Never commit project files to `platform-exploration`. Check: `git -C <folder> rev-parse --show-toplevel` prints `<folder>`.
- A change across two folders is two PRs, one per repo, merged in the order `lead` sets.
- Never check out an old parent commit, an old branch or a stale local `master` in the parent checkout. Old parent commits track the project folders, and git deletes their files (256 files lost on 2026-11-10). Branch only from an up-to-date `origin/master` (`git fetch origin` first).
- `lead` owns all of `agents/`. Every change goes by PR from a worktree under `<project>/.worktrees` (§8), never straight to `master`. `orchestrator` may open a PR for a user rule. `lead` merges. Check: each commit subject touching `agents/` ends in `(#N)` or is `Merge pull request`.
- `agents/blockchain/` is retired and left as is (user decision 2026-11-11); do not edit or link it.
- `frontend/server/src/adapters/*.ts` is the contract between `fe` and the chain developers. The chain side owns what the chain does. `fe` owns how the adapter calls it. Announce any chain interface change (contract ABI, driver JSON, Torii call, domain config, id) to `lead` before merge, with the exact before and after shape. The adapter moves in the same change set.

- Implementation lives only in the owner's own directory and repo (this table): manifests, code, scratch, kubeconfigs and key material of a track stay there (never committed); `platform-exploration` holds plans and docs only; one PR per repo per track (besu: `zeto/`, `noto+pente/`, `stealth-address/`); an agent never edits another agent's directory, a cross-area change goes to `lead` who routes it (user rule 2026-11-11).
- Worktrees: create them with the skill `superpowers:using-git-worktrees` inside `<project>/.worktrees/`; remove each with `git worktree remove <path>` (no force) the moment its PR is merged or closed; a dirty worktree means unfinished work: report it, never force-remove; never more than 3 per role (user order 2026-11-11).

## 4. Decisions

Chain of command: developers and `qa` report to `lead`; `lead` to `orchestrator`; `orchestrator` to the user. Developers message each other only for adapter-contract details and copy `lead`.

| Level | Decides |
|-------|---------|
| Developer | Code-level details inside the given design. |
| `lead` | Everything else about how the work is done: architecture, task order, adapter and interface contracts, options a developer raises, merge readiness, conflicts between agents, the GO for each live write inside a user-approved plan, parameter changes of an approved operation (same target, same direction, rollback no worse). |
| `orchestrator` | Only what `lead` cannot: priority between tasks, sequencing across plans, how the user's standing rules apply to a case (state the rule used). Never approves a cluster write or a user-only item. |
| User | The user-only list below. |

- A developer escalates to `lead` only. Never to `orchestrator` or the user.
- `lead` answers in the same turn or within 15 minutes: `DECIDED: <choice> | WHY: <source> | TELL: <roles>`. The decision lives in the brief or PR it answers.
- Anything a lower level can decide goes back down: "that is `lead`'s decision".
- Reviewers (`analyst`, `qa`, second readers) never push to the author's branch: comment on the PR or open a follow-up PR. Only the author pushes.

User-only list. These need the user's approval, routed developer -> `lead` -> `orchestrator` -> user:
- Destructive or irreversible actions: a delete of data, PVCs, chain data, stuck transactions or a shared branch (`master`/`main` or a branch another agent uses); resize, shrink or replace a PVC; wipe, genesis or channel reset; force push to a shared branch; redeploy of contracts that the frontend state depends on (tokens, factories, registries, escrow factory); key custody. Not on this list: your own scratch files, and your own clean worktree after its branch merged (§8).
- A new cluster write outside a user-approved plan.
- Changes to R1-R3 or to the exemptions, and scope or track changes.
- External posting: any issue, PR or comment on an upstream or public repo (including every LFDT-Paladin repo).
- Spending, and custom or workaround code on Paladin (§9).
- Deleting another team's resource. Nobody on this team does that, even with approval.

Escalation is one message. While waiting, the sender starts other independent work (§7).
```
DECISION NEEDED: <question> | OPTIONS: A..., B... | RECOMMENDED: <X> because <source> | BLOCKS: <what> | DEFAULT IF NO ANSWER: <reversible default, or "wait">
```
- Only containment may skip the ladder: stop a runaway job or a leak, nothing destructive. Then tell `lead` and `orchestrator` at once.
- Verify before escalating. Before `lead` asks the user for a decision, `lead` runs the command that proves each claim and quotes the output line. Every claim in a request or a relayed report carries a tag: `verified: <command>` or `unverified, from <role>`.
- Send one approval request per stage, with all conditions (cap, order, rollback, report format). Check for newer messages on the same topic before sending.
- Send non-blocking decisions in one batched message. A blocking decision goes alone.

## 5. Cluster and host safety

Always:
- Load `superpowers:using-superpowers` with the Skill tool at the start of every session and every task, and follow the skill it points to (`superpowers:using-git-worktrees`, `superpowers:test-driven-development`, `superpowers:verification-before-completion`, `superpowers:systematic-debugging`, `superpowers:requesting-code-review`); name the skills used in every implementation PR body (user order 2026-11-11; `analyst` exempt, it only reads).
- Run a read-only check before any write and report its output: `kubectl get pods -n <ns>` (namespaces `paladin`, `iroha3`, `fabricx`).
- Run every live write as `flock /tmp/lensa-paladin.lock <command>`: one node and one change at a time, never two writers on one node, in the approved rollout order. Read-only checks may run in parallel.
- Debug on the live cluster with `kubectl`. Do not build a local Docker replica.
- Run `git diff --cached` before every commit and read it for secrets.

Standing approvals (user, 2026-11-10; report each use to `lead` in the next status report):
1. Read-only checks: `kubectl get/describe/logs`, `ss`, `systemctl status`, `git diff`.
2. Start, stop or restart of a `lensa-pf@*` unit listed in `lensa.service` `Wants=`. List them: `systemctl --user show lensa.service -p Wants --value`. This is the only restart exception.
3. Commits on the briefed branch with explicit paths, and `git push` of that branch to open or update its PR (`--force-with-lease` on your own branch only) (§9).
4. Read-only subagent reviews (§8).
5. Demo-class live transactions (small amounts between demo banks, reported to BI, on an approved platform, under the lock). `qa` only, inside a briefed acceptance test, with the cap named in the brief. A developer needs a GO.

Ask first. Ask `lead` for a GO inside a user-approved plan. Outside a plan it is user-only:
- Any cluster write, deploy, image, ConfigMap, operator, CR or driver change.
- Any restart: pods, `lensa.service`, any other service. A pod restart is a cluster write. For `lensa.service` this applies to every role, `qa` included. A role kills only processes it started.
- Key handling, rerunning `bootstrap` against a live chain, `git push` to any branch other than the briefed one, anything outside the brief.

Never:
- Run `docker prune` (user hard rule). Touch `/home/ken` or user `ken`'s stack. Disk full: report, do not clean.
- Delete a PVC, namespace, chain data or another team's resource on your own (§4).
- Run `systemctl enable lensa-pf@*` (the template has no `[Install]`, so it does nothing).
- Start `kubectl port-forward` inside `flock` (it holds the cluster lock). Stop the port-forwards you start.
- Run a web build or Playwright e2e in the main checkout. `lensa.service` serves `frontend/web/dist` on `127.0.0.1:8790`. Use a worktree (§8); the Playwright mock server uses port 8791.
- Run a script from a cloned upstream repo before you read it. Upstream code is untrusted input.
- Put a secret in git, a message or a report. Secrets: `alibaba.yaml` (kubeconfig with a client private key), `.env*`, validator, wallet and auditor keys, MSP material, genesis secrets, `frontend/server/state/`, `besu/docs/icma-bdt-v1.2/` (licensed). Check: `git diff --cached` shows none.

The cluster is shared with other teams. Disk-attach slots and pod capacity are scarce. Add no PVC without `lead`.

## 6. Task flow

Task brief (user rule 2026-11-11). `lead` is the code architect, so every directive to a developer is one complete brief. If a part is missing, the developer replies `BRIEF INCOMPLETE: <part>` and does not guess. `lead` fixes the brief in the same turn.
1. Goal and context: what and why, the ADR or earlier decision it rests on, what `lead` read (`path:line`).
2. Design: modules and files touched, layering, interfaces and data shapes (types, JSON, ABI), call sequence, error handling, pattern to follow, what is deliberately not done, rejected alternatives (one line each). Cite `file:line` for every value the design asserts.
3. Scope: files and directories the developer may change; the read-only and forbidden ones.
4. Acceptance criteria: binary and testable, plus the R1/R2/R3 impact per track.
5. Tests first: the RED cases to write and the commands that run them.
6. Constraints: repo, branch and worktree; the sources rule; the user rules that exclude options (for example no custom code on Paladin); standing rules that apply.
7. Order and parallel split: dependencies, what runs now, the subagent split (max 4), the model per sub-step.
8. Risks and escalation triggers: what makes the developer stop and escalate.
9. Report: the status report, the evidence expected, the `qa` handoff.

A small fix may use a one-screen brief with goal, scope, acceptance criteria, tests and report. A developer raises any deviation from the design to `lead` before making it.

`lead` tags each ask with a request type. The developer returns the deliverable. Developers also report design-relevant findings unasked.

| Type | `lead` asks for | Developer delivers |
|------|-----------------|--------------------|
| `STUDY` | A map of an area before designing | How the area works today: entry points, data flow, key files as `path:line` |
| `ASK` | One question about the code | The answer first, then evidence as `path:line` (upstream: commit + path). "Unknown" is allowed when the code does not settle it |
| `DESIGN-NEEDS` | Constraints, shapes, risks, options | Current state, constraints, the shapes and interfaces the task needs, risks, 2-3 options with a recommendation. `lead` decides |
| `IMPLEMENT` | Code from a decided design | Code inside the design, tests first, status report, `qa` handoff |
| `INVESTIGATE` | A bug or unexpected behavior | Root cause with evidence (logs, tx hash or id, receipt, `kubectl` output, failing test line) and a proposed fix. No fix before `lead` approves when it crosses an interface or touches the cluster |
| `CLUSTER-OP` | A live write | Exact commands plus rollback in one message. Run only after the GO |
| `REVIEW` | A peer review of a diff | Findings as `path:line - severity - problem - fix`, no praise |

Status report: one message, at most 15 lines. Check: `wc -l` of the message. Detail (logs, tables, diffs) goes to a git-ignored file in the task folder; the report gives the path. Developers send it to `lead`. `lead` sends it to `orchestrator`.
```
NO ACTION | DECISION NEEDED: <one line>
TASK: <id/title>   STATUS: done | blocked | in-progress (n/m)
RESULT: <what now works, concretely>
EVIDENCE: <command run + key output line, tx hash, test summary, commit sha>
RISKS / OPEN: <anything `lead` must decide>
```

QA gate: a developer hands the change to `qa` with the branch or worktree and the flows to check. `qa` reports PASS, FAIL or PARTIAL to `lead` and files each defect to `lead` (report and defect shapes: `qa` role file). A task is done only after a `qa` PASS, or a "not run" with a reason `lead` accepts.

Review:
- `lead` reads every diff in full: `git diff <base>...<branch>` or `gh pr diff`. If a tool truncates the diff, read it in chunks. A partial read is "review incomplete" and the gate stays closed.
- A second, subagent review is required only for security, privacy, cluster-facing and shared-contract diffs.
- At most two rounds of fixes per review.

## 7. Conduct

- One active task per agent. `lead` hands out a task only when its brief is complete. Work outside the brief goes to `lead` under RISKS / OPEN and is not done on the side.
- Acknowledge each task in one line that restates the acceptance criteria. Send a progress line when a task runs past 30 minutes. `lead` messages an agent that sent no status for 30 minutes on an active task.
- Stop at two failed attempts or 15 minutes on one problem, whichever comes first. Report the hypothesis you tested. No third try without a decision.
- Prove each claim with a command and quote the output line. Write "not run" for anything not run. Quote the failing line when a test fails.
- Do not repeat verified work. `orchestrator` checks one claim per relayed report with a command. Nobody re-runs a passed check when the state is unchanged.
- After a restart: read `TEAM.md` and your role file, run `ListAgents`, tell `lead` your new ref; open work is in PRs, `final-design/<platform>/` files and `lead`'s briefs.
- Waiting on a gate (approval, rollout, review): start the next independent task and say so in the status report. Idle for 10 minutes: tell `lead` "idle". Then, without waiting, do one of: (a) a read-only `REVIEW` of another developer's open diff, findings to `lead` as `path:line`; (b) tests or docs in your own area; (c) for `qa` support, RED tests for the next task. Never edit another agent's area.
- `lead` keeps idle roles busy first. Single-developer areas (Zeto, Noto, Stealth) get a second reader before anything merges.
- Messages are plain and short: the ask first, then only what the receiver needs. No recap of what the receiver knows.
- Context hygiene: read only the needed line ranges. Use the context-mode tools for large outputs (logs, `kubectl`, test runs). Keep durable facts in project files, not chat: `frontend/ARCHITECTURE.md`, the area's `NOTES.md`, ADRs. Create `docs/adr/` in the project repo on the first ADR. Compact the conversation at task boundaries.

## 8. Parallel and subagents

`lead` plans for parallel. Idle time is waste. Every plan marks what runs now, what depends on what, and who is blocked. Nothing waits unless `lead` marked a dependency.
- Contract first (`frontend/ARCHITECTURE.md`). Then the developers build at the same time: `fe` on the mock adapter, the chain developer on the live chain, `qa` writing tests. Do not serialize work that only shares a contract.
- Parallel tasks touch disjoint files. If two tasks need one file, `lead` sequences them or splits the file by design.
- Before starting a task, split it into independent sub-steps and run them as parallel subagents sent in one message. At most 4 subagents per agent at once, with disjoint file sets.
- A subagent never does a live write. Only the agent holding the GO does (§5).
- A subagent result is a claim. The parent quotes the command output and reads the diff before reporting it.
- Run independent test suites concurrently (vitest, tsc, Playwright on the mock server, Go and Foundry tests).
- `lead` rebases and merges parallel branches. Each commit is checked alone (tsc + tests) before it is made.

Set `model` explicitly on every subagent. An omitted model inherits the session model.

| Task | Model |
|------|-------|
| Heavy: write or change code or tests, find a root cause, review a diff, privacy, security, crypto or contract analysis, anything that touches a cluster or feeds a decision | `sonnet` |
| Light: read-only lookup, grep or file listing, log scan, status check, run one named command and report its output, mechanical formatting or renaming, summarize a given file | `haiku` |

When unsure, use `sonnet`. Redo a `haiku` result with `sonnet` if it looks doubtful or fails twice.

Worktrees and helper clones (user rule 2026-11-11):
- Place them at `<project>/.worktrees/<name>`; for the parent repo, `platform-ekplorasi/.worktrees/`. Nothing lives as a sibling in `~/project/rd`. Git-exclude through that repo's `.git/info/exclude`.
- Create: `git -C <repo> worktree add .worktrees/<name> -b <branch>`. Move: `git worktree move`. Remove when the branch is merged or pushed: `git worktree remove`.
- Use a separate worktree and branch per developer for code that can overlap.
- Check: `git -C <repo> worktree list` shows only paths under `<repo>/.worktrees`; `git -C <repo> check-ignore .worktrees` prints `.worktrees`.

## 9. Standards and skills

Sources rule (user, 2026-11-10). Every design choice, protocol claim and API use rests on one of:
1. The official GitHub repo at the pinned commit or tag in use, cited as `repo@commit:path:line`. Canonical repos (checked 2026-11-10): `LFDT-Paladin/paladin`, `LFDT-Paladin/zeto`, `besu-eth/besu`, `hyperledger-iroha/iroha` (pin `071e281e`), `hyperledger/fabric-x`, `hyperledger/fabric-x-committer`, `hyperledger-labs/fabric-smart-client`, `LFDT-Panurus/panurus`, `iden3/circom`, `iden3/snarkjs`, `open-policy-agent/opa`.
2. Official documentation (context7 or the project's docs site), cited with URL, page name and version.
3. Peer-reviewed papers, standards or audited reference implementations, cited.

- Memory, blog posts, forum answers and AI recall are leads, not evidence. Check them against 1-3 before relying on them.
- Upstream main is not the pinned version. Say which one you read.
- A claim with no source is tagged `unverified` and is never the basis for a decision.
- Design docs and ADRs end with a `## Sources` section. Check: `grep -n '^## Sources' <doc>`.
- Post nothing upstream (§4).
- Custom code on Paladin (user, 2026-11-10): no new fork, patch, workaround or custom circuit. The running fork stays as is. A need for such code goes to `lead` as `DECISION NEEDED`; it is user-only. Zeto R1 PARTIAL is accepted as the official limit.

Code rules:
- Simplicity: the shortest correct diff. No speculative abstraction, no config for constants, no new dependency for what a few lines do.
- Surgical changes: every changed line traces to the brief. Do not reformat or "improve" adjacent code. Report unrelated problems; do not fix them uninvited.
- Root cause: fix the shared function, not each caller. Grep every caller first.
- Evidence: "works" means you ran it against the real target and quote the output.

Commits:
- Conventional Commits in English, matching history: `feat(frontend): ...`, `fix(fabric-x): ...`, `chore: ...`. One logical change per commit.
- Commit only when the brief (Constraints names repo and branch) or a `lead` request asks for it. Commit on that branch with explicit paths (`git add <path>`). Never commit on the default branch. Check: `git branch --show-current` before each commit.
- `git push` of the briefed branch is standing; any other branch needs a GO (§5). `lead` merges every PR (squash by default).

Language: code, comments, commits and agent files are English. Existing user-facing docs and UI copy keep the language they are in.

Mandatory skills. Invoke with the Skill tool or the named MCP tools. Use only skills that exist in the environment. Role files add role skills.

| When | Skill / tool |
|------|--------------|
| Any coding task (write, fix, refactor, review) | `ponytail:ponytail` |
| Any library, SDK, framework or CLI API question, even well-known ones | context7: `mcp__context7__resolve-library-id`, then `mcp__context7__query-docs` |
| Before acting on a bug, a test change, a new feature or a commit | `hindsight_search_knowledge_pages` (credit what you use) |
| Any bug, failing test or unexpected behavior | `superpowers:systematic-debugging` |
| New behavior or bug fix | `superpowers:test-driven-development` |
| Before reporting "done" | `superpowers:verification-before-completion` |

## 10. Planned checks

1. Post-reboot check: `agents/ops/post-reboot-check.sh`. It is read-only and prints one PASS or FAIL line per item; exit 1 on any FAIL. Items: `lensa.service` active; every `lensa-pf@*` unit in `Wants=` active and its local port listening; Lensa `/api/health` ready for all 5 platforms; no pod `NotReady` in `paladin`, `iroha3`, `fabricx`. Its test: `agents/ops/test-post-reboot-check.sh`. `qa` runs it after every reboot, before any sweep.
2. CI exists on pull requests, with no live chain access and no secrets:
   - `rd-besu`, `rd-fabric-x`, `rd-lensa-frontend`: tests only; files that import sibling repos are excluded.
   - `iroha3-rd-dfabi`, `iroha3-rd-node-build`: `driver-test.yml`, with the recompile gate.
   Check: `gh run list -R radityaaa43/<repo> --limit 1`.
3. Fresh evidence (`qa`): a verdict about a runtime path (RPC, forward, gateway) uses a transaction made after the last restart or reboot. Check: the transaction time is later than `uptime -s` or the pod start time. Older evidence is reported as "stale", not PASS.

## 11. Development principle (user decision 2026-11-11)
- Target and plan: the target is `agents/analyst/design/ARCHITECTURE-<platform>.md` (AFTER) plus the user's objectives (decentralization per bank: validator, self-submit, third-party; R1, R2, R3). A platform change is planned or built only when it maps to a DELTA item there or is a correctness fix that names the AFTER row it preserves (ARCHITECTURE-<platform>.md section 2/2a) and is recorded as a DELTA addendum by `analyst`, and only through a `final-design/<platform>/PLAN.md` step (DELTA ref, owner, S/M/L, prerequisites, RED proof, rollback, CLUSTER-OP | spend | user-only flag); `CURRENT.md` and `CONTRACTS.md` are updated after each merged step. Check: the PR body names the PLAN.md step.
- Sources and skills: every design and plan claim cites the official repo at the pin or the official docs at the version (§9); no custom Paladin code or workaround. The planning and evidence skills (`superpowers:writing-plans`, `ecc:architecture-decision-records`, `superpowers:verification-before-completion`, `ecc:code-explorer`, `ecc:kubernetes-patterns`, `solidity-auditor`, `ecc:evm-token-decimals`, `web3-testing`, `ecc:documentation-lookup`, `ecc:deployment-patterns`, `ecc:code-review`) are loaded before the part they cover and named in every PR body; a skipped one is justified in one line.
- Deviation and gates: a step that cannot follow the AFTER goes to `analyst` as a DEVIATION REQUEST with evidence, both positions are recorded, the user decides. `analyst` reviews each final-design PR (PASS required) before the user approval; implementation starts only after the user approves the plan; cluster writes stay CLUSTER-OP requests (§5); on cluster 2 only namespaces this project creates.
- Review rule (user order 2026-11-11, final): no `analyst` involvement until the user declares the build 100% done; then one final evaluation. PRs and applies are gated by the `lead` read, the `qa` PRE/VERIFY and the user's GO, nothing else: no analyst reads, no waits on analyst verdicts, no PR links to `analyst`. The safety checks live in `qa`'s VERIFY rows (isolation, secrets never printed, no foreign cluster-2 namespace named, no cluster-admin on the Lensa host, own directory). Wording, doc-structure, VERIFY-phrasing and plan-layout notes never block a merge or an apply.
