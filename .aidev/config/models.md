# Model Routing Configuration

Agent model assignments live in `.claude/agents/<name>.md` frontmatter.
Edit the `model:` field there to change any agent's model.

---

## Current Assignment (Claude Pro)

| Agent | File | Model | Rationale |
|-------|------|-------|-----------|
| Team Lead (plan + review) | `.claude/agents/team-lead.md` | `claude-opus-4-7` | Architecture decisions, deep code review |
| Frontend Developer | `.claude/agents/team-frontend.md` | `claude-sonnet-4-6` | Strong UI/TS coding, balanced cost |
| .NET Developer | `.claude/agents/team-dotnet.md` | `claude-sonnet-4-6` | Strong C#/SQL coding, balanced cost |
| Business Analyst | `.claude/agents/team-ba.md` | `claude-haiku-4-5-20251001` | Conversational Q&A, doc writing |
| QA Engineer | `.claude/agents/team-qa.md` | `claude-haiku-4-5-20251001` | Structured analysis, report writing |

---

## GitHub Copilot Alternatives

Use these when you want to save Claude credits. Change the `model:` in the agent file.

| Agent | Copilot Model | When to use |
|-------|-------------|-------------|
| Team Lead | `o3` | Strong reasoning for architecture decisions |
| Frontend Developer | `gpt-4o` | Strong TypeScript/Angular/React coding |
| .NET Developer | `gpt-4o` | Strong C# coding |
| Business Analyst | `gemini-2.0-flash` | Fast, cheap for conversational tasks |
| QA Engineer | `o4-mini` | Reasoning model, good for test logic |

### Switching to Copilot models

Edit the relevant `.claude/agents/<name>.md` file and change the `model:` value:

```yaml
# Before (Claude)
---
model: claude-sonnet-4-6
---

# After (GitHub Copilot)
---
model: gpt-4o
---
```

---

## Available Model IDs

### Claude (via Claude Pro subscription)
| Model ID | Speed | Best for |
|----------|-------|---------|
| `claude-opus-4-7` | Slow | Architecture, complex review, reasoning |
| `claude-sonnet-4-6` | Medium | Implementation, coding tasks |
| `claude-haiku-4-5-20251001` | Fast | Q&A, docs, structured writing |

### GitHub Copilot (via Copilot subscription)
| Model ID | Best for |
|----------|---------|
| `gpt-4o` | General coding, TypeScript, C# |
| `o3` | Complex reasoning, architecture |
| `o4-mini` | Reasoning tasks, faster/cheaper than o3 |
| `gemini-2.0-flash` | Fast, cheap, good for simple tasks |

---

## Cost Profile per Task Type

### Full-stack feature (`/team-task`)
| Phase | Agent | Model | Approx. usage |
|-------|-------|-------|--------------|
| 1. BA | team-ba | Haiku | Low (conversation) |
| 2. Planning | team-lead | Opus | Medium (architecture) |
| 3a. Frontend | team-frontend | Sonnet | High (implementation) |
| 3b. Backend | team-dotnet | Sonnet | High (implementation) |
| 4. QA | team-qa | Haiku | Medium (test writing) |
| 5. Review | team-lead | Opus | Medium (diff review) |

### To minimize cost on simple tasks
Temporarily set all agents to Haiku or Gemini Flash for routine boilerplate tasks.
Restore before complex architecture or security-critical work.

---

## Upgrading QA for Complex Tasks

QA is on Haiku by default, which handles most verification tasks well.
For complex features with intricate business logic, upgrade QA to Sonnet:

```yaml
# .claude/agents/team-qa.md
---
model: claude-sonnet-4-6   # upgraded from haiku for complex features
---
```
