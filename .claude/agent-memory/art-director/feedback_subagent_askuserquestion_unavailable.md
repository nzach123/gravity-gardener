---
name: subagent-askuserquestion-unavailable
description: AskUserQuestion tool errors out when this agent runs as a Task subagent — structure decisions as text instead
metadata:
  type: feedback
---

When this agent (art-director) is invoked as a Task subagent (spawned by an
orchestrating skill/agent rather than running as the top-level session), calling
`AskUserQuestion` fails with "AskUserQuestion is not available inside subagents."

**Why:** The tool is only available in the top-level interactive session. A
subagent completes its task in one turnaround and returns findings to the
orchestrator — it cannot pause mid-task to collect a live user answer the way
the top-level agent can.

**How to apply:** When operating as a subagent, do not call `AskUserQuestion`.
Instead:
1. Present options with reasoning and an explicit recommendation in plain text,
   as the collaboration protocol's Step 2 already asks for.
2. If a decision is needed before drafting and no answer is available, proceed
   using the stated recommended default(s), clearly labeled as defaults taken
   in lieu of confirmation, and flag them prominently in the final response so
   the orchestrator/user can course-correct.
3. Do not write the deliverable to its final project path (e.g.
   `design/art/art-bible.md`) without explicit approval — write drafts to the
   scratchpad or return content inline instead, and ask "may I write this to
   [filepath]?" as the very next step, same as normal protocol.

This matches the system prompt's own instruction: "If running as a Task
subagent, structure text so the orchestrator can present options via
AskUserQuestion." The fix is behavioral (text-first), not a retry-the-tool
workaround — retrying `AskUserQuestion` in a subagent will fail again.
