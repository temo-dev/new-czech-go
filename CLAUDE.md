@AGENTS.md

See also [AGENTS.md](AGENTS.md).

## Documentation Discipline

**Read AGENTS.md § "Documentation Convention" before writing any new
doc.** The doc surface was systematized in V21.1 (P1..P5) and the tree
is now strict:

```
ROOT: README · AGENTS · CLAUDE · CHANGELOG · SPEC       (5 files, fixed)
docs/: reference · specs · ideas · plans · guides ·
       architecture · features · design · screens · content
tasks/: plan.md (index) + todo.md (index) + <slice>-{plan,todo}.md
```

Quick decision routing:

| Writing | Path |
|---|---|
| Stable contract (api, lifecycle, env, etc) | `docs/reference/<topic>.md` |
| Slice spec (frozen on ship) | `docs/specs/<slice>.md` |
| Pre-spec idea | `docs/ideas/<slice>.md` |
| Slice plan / todo | `tasks/<slice>-plan.md` · `tasks/<slice>-todo.md` |
| Dev / deploy / smoke / admin guide | `docs/guides/<topic>.md` |
| Code shape snapshot | `docs/architecture/current-code-shape.md` |
| User-facing feature | `docs/features/<feature>.md` |

**Strict rules** (non-negotiable):

- ❌ No new files at repo root. Five exist; don't add a sixth.
- ❌ No drafts loose at `docs/` root — pick a subdirectory.
- ❌ No new top-level subdirectories under `docs/` — use the existing nine.
- ❌ No ephemeral notes (`next-session.md`, `scratch.md`, `todo-temp.md`).
- ❌ No backfilling frozen slice specs — V22+ updates land in V22's spec
  + `docs/reference/`, not in the V21 slice spec.
- ❌ No inlining slice content in `SPEC.md` — it's a digest table only.
- ❌ No absolute paths in markdown links — use relative paths.

When in doubt: read `docs/README.md` § "Pick by what you need" — it
routes by question.

<!-- code-review-graph MCP tools -->
## MCP Tools: code-review-graph

**IMPORTANT: This project has a knowledge graph. ALWAYS use the
code-review-graph MCP tools BEFORE using Grep/Glob/Read to explore
the codebase.** The graph is faster, cheaper (fewer tokens), and gives
you structural context (callers, dependents, test coverage) that file
scanning cannot.

### When to use graph tools FIRST

- **Exploring code**: `semantic_search_nodes` or `query_graph` instead of Grep
- **Understanding impact**: `get_impact_radius` instead of manually tracing imports
- **Code review**: `detect_changes` + `get_review_context` instead of reading entire files
- **Finding relationships**: `query_graph` with callers_of/callees_of/imports_of/tests_for
- **Architecture questions**: `get_architecture_overview` + `list_communities`

Fall back to Grep/Glob/Read **only** when the graph doesn't cover what you need.

### Key Tools

| Tool | Use when |
|------|----------|
| `detect_changes` | Reviewing code changes — gives risk-scored analysis |
| `get_review_context` | Need source snippets for review — token-efficient |
| `get_impact_radius` | Understanding blast radius of a change |
| `get_affected_flows` | Finding which execution paths are impacted |
| `query_graph` | Tracing callers, callees, imports, tests, dependencies |
| `semantic_search_nodes` | Finding functions/classes by name or keyword |
| `get_architecture_overview` | Understanding high-level codebase structure |
| `refactor_tool` | Planning renames, finding dead code |

### Workflow

1. The graph auto-updates on file changes (via hooks).
2. Use `detect_changes` for code review.
3. Use `get_affected_flows` to understand impact.
4. Use `query_graph` pattern="tests_for" to check coverage.
