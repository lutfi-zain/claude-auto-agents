# Claude Auto-Agents

A minimalist autonomous agent framework for Claude Code. Achieves continuous iteration and multi-agent workflows using **only hooks and markdown files** - no database, no server, no heavy infrastructure.

## Features

- **Ralph-loop Automation**: Continuous iteration until task completion
- **7 Specialized Agents**: Developer, Reviewer, Fixer, Orchestrator, Explorer, PR-Shepherd, Conflict-Resolver
- **Markdown Queue**: Human-readable work management in `work/queue.md`
- **STATUS Protocol**: Structured signals for agent communication
- **Dual-mode**: Use as Claude Code plugin or standalone template

## Quick Start

### As Plugin (Recommended)

```bash
# In Claude Code
/plugin install https://github.com/hanibalsk/claude-auto-agents
```

### As Template

```bash
git clone https://github.com/hanibalsk/claude-auto-agents.git
cd claude-auto-agents
./install.sh
```

## Usage

### Start Autonomous Loop

```bash
# Work on a specific task
/loop "implement user authentication with JWT"

# Or pick from queue
/queue add FEAT-001 "Add login page" high developer
/loop
```

### Manual Agent Spawning

```bash
/spawn developer "create REST API for users"
/spawn reviewer   # Review current changes
/spawn fixer "fix failing tests"
/spawn explorer "find database models"
```

### Queue Management

```bash
/queue list                    # View queue
/queue add ID "description"    # Add item
/queue start ID                # Move to In Progress
/queue complete ID             # Mark done
/queue block ID "reason"       # Mark blocked
```

### Control

```bash
/status    # Check loop and queue status
/stop      # Gracefully stop loop
```

## Architecture

```
claude-auto-agents/
├── .claude/
│   ├── hooks/
│   │   ├── session-start.sh   # Protocol injection
│   │   ├── on-stop.sh         # Ralph-loop continuation
│   │   └── lib/               # Shell libraries
│   ├── agents/                # 7 agent definitions
│   ├── commands/              # Slash commands
│   └── skills/                # Auto-invoke skills
├── work/
│   ├── queue.md               # Work items
│   ├── current.md             # Active context
│   ├── history.md             # Completion log
│   └── blockers.md            # Blocked items
└── CLAUDE.md                  # Protocol reference
```

## Agents

| Agent | Model | Tools | Purpose |
|-------|-------|-------|---------|
| `developer` | Sonnet | All + Task | Feature development with TDD |
| `reviewer` | Sonnet | Read-only | Code review and audit |
| `fixer` | Sonnet | All | Fix bugs, CI failures, issues |
| `orchestrator` | Opus | All + Task | Autonomous workflow control |
| `explorer` | Haiku | Read-only | Fast codebase exploration |
| `pr-shepherd` | Sonnet | All + Task | PR lifecycle management |
| `conflict-resolver` | Sonnet | All | Merge conflict resolution |

## STATUS Protocol

Agents emit structured signals:

```
STATUS: COMPLETE | BLOCKED | WAITING | ERROR
SUMMARY: Brief description
FILES: Changed files
NEXT: Suggested action
BLOCKER: Reason if blocked
```

The Stop hook parses these signals to:
- Continue to next item on COMPLETE
- Pause and log on BLOCKED/ERROR
- Retry on WAITING

## Comparison to Heavy Frameworks

| Aspect | Heavy (e.g., Orchestrate) | Claude Auto-Agents |
|--------|---------------------------|-------------------|
| Backend | Rust + SQLite | None |
| State | Database tables | Markdown files |
| API | REST endpoints | Claude Code commands |
| Infrastructure | Daemon process | Hooks only |
| Installation | Build from source | Clone or `/plugin install` |

## Configuration

### Max Iterations

Edit `.claude/hooks/lib/.loop-state`:

```bash
LOOP_MAX_ITERATIONS=100  # Default: 50
```

### Agent Customization

Edit agent files in `.claude/agents/` to modify:
- Tool access
- Model selection (haiku/sonnet/opus)
- Turn limits
- Behavioral instructions

## Safety

- **Max iterations**: Default 50, configurable
- **Auto-pause**: On BLOCKED, ERROR, or consecutive failures
- **Graceful stop**: `/stop` command
- **Force stop**: Ctrl+C

## Development

```bash
# Test hooks locally
bash .claude/hooks/session-start.sh
bash .claude/hooks/lib/queue-manager.sh summary

# Check loop state
bash .claude/hooks/lib/loop-control.sh status
```

## References

- [Ralph Wiggum Plugin](https://github.com/anthropics/claude-code/tree/main/plugins/ralph-wiggum) - Inspiration for loop pattern
- [Claude Code Plugins](https://github.com/anthropics/claude-code/tree/main/plugins) - Official examples
- [Claude Code Hooks](https://docs.anthropic.com/claude-code/hooks) - Hook documentation

## License

MIT
