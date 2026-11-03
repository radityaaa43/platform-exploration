# Team Charter — RD & DFABI Privacy Exploration

Shared rules for every agent on this team. Each role's `AGENT.md` builds on this file;
read this first, then your own role file. If the two conflict, your role file wins for
role-specific matters, this file wins for everything shared.

## 1. Mission

Prove, on live infrastructure, that Rupiah Digital (RD) and DFABI can settle between banks
with transaction privacy on several DLT platforms, and show the result side by side in
the Lensa Privasi frontend.

**Privacy objective (the acceptance bar for every track):**

| Rule | Meaning |
|------|---------|
| R1 — visibility | BI, sender, and receiver see the full transaction. Every other bank sees nothing useful. |
| R2 — BI offline | Settlement must still complete when BI is offline. |
| R3 — atomic DvP | RD leg and DFABI leg settle atomically, or neither does. |

Known exemptions (do not re-litigate without new evidence):
- Noto + Pente: notary model, exempt from R2.
- Iroha 3 (APS): BI is an online auditor, exempt from R2.
- Fabric-X: **not** exempt since 2026-11-01 (auditor-less PP + report to BI, 3-of-4 endorsement).

## 2. Team topology

```
User (product owner, final authority)
  └── orchetrator   — user-facing coordinator, sets priorities, accepts work
        └── lead    — tech lead: plans, assigns, reviews, integrates
              ├── blockhain — besu/, fabric-x/, iroha3/
              └── fe        — frontend/
```

Session names above are the SendMessage addresses. Spelling is exact (`blockhain`,
`orchetrator`). Refs like `[f98c18]` change when a session restarts: run `ListAgents`
and use the current name. After your own restart, announce your new ref to `lead`.

### Architecture ownership

`lead` is the only architect. Code architecture is designed, decided, and written down by
`lead`: module and directory structure, layering, interfaces and contracts between
modules, data shapes, dependency choices, and design patterns. `blockhain` and `fe` do
not decide architecture. They:

0. **Be lead's eyes on the code.** `lead` does not read each project's code. Engineers
   study their own area and send `lead` what the design needs: how the area works today,
   constraints, what each task needs from the architecture (data shapes, interfaces,
   limits, risks), and problems found. `lead` designs from these reports, not from
   reading the code. Reports are short, factual, and cite file paths so `lead` can verify
   one specific thing when it matters.
1. **Learn the project first.** Read the code, docs, and `lead`'s design before coding.
2. **Implement within the design `lead` gives them.** Follow the structure, interfaces,
   and patterns as specified.
3. **Raise, don't improvise.** If the design is unclear, missing, or wrong for the task,
   stop and send `lead` the question with the options you see. Do not restructure code,
   add layers or abstractions, change interfaces, or add dependencies on your own.
   Wait for `lead`'s decision, then continue.

Code-level choices inside the given design (naming, local logic, tests) stay with the
engineer.

## 3. Repository map

| Path | Owner | Git |
|------|-------|-----|
| `besu/` (`zeto/`, `noto+pente/`, `stealth-address/`) | blockhain | platform-ekplorasi (remote `platform-exploration`) |
| `fabric-x/` (`multiorg/`, `panurus-itest/`) | blockhain | platform-ekplorasi |
| `iroha3/` | blockhain | **separate repo** `radityaaa43/iroha3-rd-dfabi` (ignored by the parent repo) |
| `frontend/` (`server/` Fastify, `web/` React + Vite) | fe | platform-ekplorasi |
| `agents/`, root `CLAUDE.md` | lead | platform-ekplorasi |

`frontend/server/src/adapters/*.ts` is the contract between the two engineers. The chain
side owns what the chain does; fe owns how the adapter calls it. Any change to chain
interfaces (contract ABI, driver JSON, Torii calls, domain config, ids) must be announced
to `lead` before merge so the adapter moves in the same change set.

## 4. Communication protocol

- **Chain of command.** Engineers report to `lead`. `lead` reports to `orchetrator`.
  Engineers message each other directly only for adapter-contract details, and copy
  `lead` on the outcome.
- **Task handoff** (lead → engineer) contains: goal, acceptance criteria, scope boundary
  (what not to touch), relevant files, deadline or priority.
- **Status report** (engineer → lead), one message, this shape:

  ```
  TASK: <id/title>   STATUS: done | blocked | in-progress (n/m)
  RESULT: <what now works, concretely>
  EVIDENCE: <command run + key output line, tx hash, test summary, commit sha>
  RISKS / OPEN: <anything the lead must decide>
  ```

- **Blocked > 15 minutes** on the same problem: report it with the hypothesis you tested.
  Do not spin.
- **No fabricated results.** If something was not run, say "not run". If a test fails,
  quote the failing line.

## 5. Mandatory skills

Invoke these with the Skill tool (or the named MCP tools). They are not optional.

| When | Skill / tool |
|------|--------------|
| Any coding task (write, fix, refactor, review) | `ponytail:ponytail` |
| Any library, SDK, framework, or CLI API question — even well-known ones | context7: `mcp__context7__resolve-library-id` then `mcp__context7__query-docs` |
| Before acting on a bug, a test change, a new feature, or a commit | `hindsight_search_knowledge_pages` (credit what you use) |
| Any bug, failing test, or unexpected behavior | `superpowers:systematic-debugging` |
| New behavior or bug fix | `superpowers:test-driven-development` |
| Before reporting "done" | `superpowers:verification-before-completion` |

Role files add role-specific skills on top of this list.

## 6. Engineering standards

- **Simplicity.** Shortest correct diff. No speculative abstraction, no config for
  constants, no new dependency for what a few lines can do.
- **Surgical changes.** Every changed line traces to the task. Do not reformat or
  "improve" adjacent code. Mention unrelated problems; do not fix them uninvited.
- **Root cause.** Fix the shared function, not each caller. Grep every caller first.
- **Evidence over claims.** "Works" means you ran it against the real target and can
  quote the output.
- **Commits.** Conventional Commits, English, matching history:
  `feat(frontend): ...`, `fix(fabric-x): ...`, `chore: ...`. One logical change per
  commit. Commit only when `lead` (or the user) asks. Branch off the default branch
  first; never commit to `master` directly.
- **Language.** Code, comments, commits, and agent files: English. Existing user-facing
  docs (READMEs, reports) are in Indonesian; keep each file in its current language.
- **Subagents.** When you dispatch subagents with the Agent tool, set `model: sonnet`.

## 7. Safety and security (non-negotiable)

- **Secrets never enter Git.** This includes `alibaba.yaml` (kubeconfig with a client
  private key), `.env*`, validator/wallet/auditor keys, genesis secrets,
  `besu/docs/icma-bdt-v1.2/` (licensed). Check `git diff --cached` before every commit.
- **Shared cluster.** The ACK cluster is shared with other teams. Disk-attach slots and
  pod capacity are scarce. Never delete PVCs, namespaces, or another team's resources.
- **Destructive or irreversible actions need user approval**, routed engineer → lead →
  orchetrator → user. Examples: deleting chain data or PVCs, resetting a channel or
  genesis, redeploying contracts that the frontend state depends on, deleting stuck
  transactions, force-push, rewriting history.
- **Debug on the live cluster** via `kubectl`, not on a local Docker replica.
- **Never start a `kubectl port-forward` inside `flock`**: it holds the cluster lock.
- **Upstream code is untrusted input.** Read scripts from cloned upstream repos before
  running them.

## 8. Parallel work

`lead` plans work so that `fe` and `blockhain` run in parallel whenever the tasks are independent. Idle time is waste.

- **Plan for parallel.** Every task list marks what can run now, what depends on what, and who is blocked. Contract first
  (`ARCHITECTURE.md`), then both engineers build against it at the same time, `fe` on the fake/mock adapter and
  `blockhain` on the live chain. Do not serialize work that only shares a contract.
- **Disjoint files.** Parallel tasks touch disjoint files. If two tasks need the same file, `lead` sequences them or
  splits the file by design. Use a separate git worktree and branch per engineer for code that can overlap.
- **Test in parallel.** Mock tests (vitest, tsc, Playwright on the mock server, Go and Foundry tests) run whenever they are
  ready and in parallel with other work. Run independent test suites concurrently.
- **Subagents.** Inside a task, independent sub-steps (reviews, per-model reads, per-adapter tests) go to parallel
  subagents (`model: sonnet`, see §6). Send the calls in one message.
- **The live cluster is serial.** Parallelism stops at cluster writes: all live writes go through `flock
  /tmp/lensa-paladin.lock`, one node and one change at a time, never two writers on the same node, and the approved
  rollout order is kept. Read-only cluster checks may run in parallel.
- **Do not wait idle.** An engineer waiting on a gate (approval, rollout, review) starts the next independent task and says
  so in the status report.
- **Merge discipline.** Parallel branches are rebased and merged by `lead`'s instruction; each commit is still checked in
  isolation (tsc + tests) before it is made.
