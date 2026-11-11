# Agent file style (agents/STYLE.md)

Purpose: one style for every agent file. Applies to agents/TEAM.md, agents/<role>/AGENT.md, STATE.md, RETRO and ADR files.
Sources: [1] subagents, [2] CLAUDE.md memory, [3] best practices, [4] AGENTS.md. "Team convention" = not stated by a source.

## Role file order
1. Role statement, two lines: who the agent is, when the file applies. Sources: [1] "write a clear description so Claude knows when to use it". Two-line limit: team convention.
2. How to start: files to read, commands to run, in order. Sources: [3] "exact test, typecheck, and lint commands"; [4] "Build and test commands". Order and heading: team convention.
3. Boundaries: Always / Ask first / Never. Sources do not define tiers. Team convention. [4] lists "Security considerations" only.
4. Duties and procedures for this role. Team convention. [4]: "Use any headings you like".
5. Report shape: the fields of the report this role returns. Team convention.
Group lines under headers and bullets, not dense paragraphs [2].

## Writing rules
- Write short imperative sentences. One idea each. Team convention.
- Put exact commands, paths and names in code blocks [3].
- Make each rule verifiable: name the check that proves it. [2]: "concrete enough to verify".
  - Good: "Run `npm test` before committing". Bad: "Test your changes" [2].
- Use one term per concept. Do not use two words for one thing. Team convention.
- Write no filler and no marketing tone. [3]: every line costs attention "on every task".
- Write only what the agent cannot work out from the repo [3]. Do not describe file layout [3].
- Add a rule only after the same mistake was corrected twice [3].
- Do not use IMPORTANT or ALL CAPS [3]. A rule that cannot bend goes in a hook or deny rule [2][3].
- Disclose in layers: link to a doc, do not paste it. Imports do not cut context cost [2].
- Keep shared rules once in agents/TEAM.md. Link to them. Never copy them. Conflicting copies break the agent [2].
- Subagents get only their own file plus basic environment details [1]. Put in the file what the role needs; link the rest.
- Write no secrets. Team convention.
- Write English only. Team convention.
- Review agent files like code: PR, second reader [1] "Check them into version control". Second reader: team convention.
- Treat files as living documents [4]. Remove outdated lines [2].

## Limits
- Role file: 150 lines at most. Source [2] gives under 200 for CLAUDE.md; 150 is team convention.
- agents/STYLE.md: 60 lines at most. Check: `wc -l agents/STYLE.md`.
- agents/TEAM.md: shared rules only. No role duties.
- Keep descriptions short [1].

## Avoid
- Vague advice: "be careful", "as needed". Use "Format code properly" -> "Use 2-space indentation" [2].
- Duplicated sections or contradicting rules [2].
- A rule with no check.
- Appending without removing. Prune on every edit [2][4].
- Rules that must never fail written only as prose. Use a hook [3].

## Example Always / Ask first / Never
```
Always: run `kubectl get pods -n fabricx` before any write; report the output.
Ask first: restart any pod; change any ConfigMap.
Never: delete a PVC; run `docker system prune`; commit a secret.
```

## Sources (all fetched 2026-11-11)
- [1] https://code.claude.com/docs/en/sub-agents (from docs.anthropic.com/en/docs/claude-code/sub-agents)
- [2] https://code.claude.com/docs/en/memory (from docs.anthropic.com/en/docs/claude-code/memory)
- [3] https://code.claude.com/docs/en/best-practices (from anthropic.com/engineering/claude-code-best-practices)
- [4] https://agents.md/
