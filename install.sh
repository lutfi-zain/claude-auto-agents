#!/bin/bash
# install.sh - One-command setup for claude-auto-agents template

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Claude Auto-Agents Setup ==="
echo ""

# Check if this is being run as a plugin install or template clone
if [[ -d ".claude-plugin" ]]; then
    echo "Detected: Plugin mode"
else
    echo "Detected: Template mode"
fi

# Make hooks executable
echo "Making hooks executable..."
chmod +x .claude/hooks/*.sh 2>/dev/null || true
chmod +x .claude/hooks/lib/*.sh 2>/dev/null || true

# Initialize work directory with templates if empty
if [[ ! -f "work/queue.md" ]]; then
    echo "Initializing work queue..."
    cat > work/queue.md << 'EOF'
# Work Queue

## In Progress
<!-- Items currently being worked on -->

## Pending
<!-- Items waiting to be picked up -->
- [ ] **[SETUP-001]** Initial project setup
  - Priority: high
  - Agent: developer

## Blocked
<!-- Items that cannot proceed -->

## Completed
<!-- Moved here after completion -->
EOF
fi

if [[ ! -f "work/current.md" ]]; then
    echo "Creating current work tracker..."
    cat > work/current.md << 'EOF'
# Current Work

No work in progress.

## Context
<!-- Active work context will be written here -->
EOF
fi

if [[ ! -f "work/history.md" ]]; then
    echo "Creating history log..."
    cat > work/history.md << 'EOF'
# Work History

## Completed Items

| Date | ID | Summary | Agent | Iterations |
|------|----|---------|-------|------------|
EOF
fi

if [[ ! -f "work/blockers.md" ]]; then
    echo "Creating blockers log..."
    cat > work/blockers.md << 'EOF'
# Blockers

## Active Blockers

| ID | Reason | Since | Resolution |
|----|--------|-------|------------|

## Resolved Blockers

| ID | Reason | Resolved | How |
|----|--------|----------|-----|
EOF
fi

# Create loop state file
if [[ ! -f ".claude/hooks/lib/.loop-state" ]]; then
    echo "Initializing loop state..."
    mkdir -p .claude/hooks/lib
    cat > .claude/hooks/lib/.loop-state << 'EOF'
LOOP_ACTIVE=false
LOOP_ITERATION=0
LOOP_MAX_ITERATIONS=50
LOOP_PROMPT=""
LOOP_STARTED=""
EOF
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Available commands:"
echo "  /loop [task]     - Start autonomous iteration"
echo "  /stop            - Stop the loop"
echo "  /status          - Check progress"
echo "  /queue list      - View work queue"
echo "  /spawn <agent>   - Launch specific agent"
echo ""
echo "Start with: /loop \"your task description\""
