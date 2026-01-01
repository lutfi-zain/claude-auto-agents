# install.ps1 - One-command setup for claude-auto-agents template (Windows)

$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot
Set-Location $ScriptDir

Write-Host "=== Claude Auto-Agents Setup (Windows) ==="
Write-Host ""

# Check if this is being run as a plugin install or template clone
if (Test-Path -Path ".claude-plugin") {
    Write-Host "Detected: Plugin mode"
} else {
    Write-Host "Detected: Template mode"
}

# Ensure directories exist
if (-not (Test-Path "work")) {
    New-Item -ItemType Directory -Force -Path "work" | Out-Null
}
if (-not (Test-Path ".claude\hooks\lib")) {
    New-Item -ItemType Directory -Force -Path ".claude\hooks\lib" | Out-Null
}

# Initialize work directory with templates if empty
if (-not (Test-Path "work\queue.md")) {
    Write-Host "Initializing work queue..."
    $queueContent = @"
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
"@
    Set-Content -Path "work\queue.md" -Value $queueContent -Encoding UTF8
}

if (-not (Test-Path "work\current.md")) {
    Write-Host "Creating current work tracker..."
    $currentContent = @"
# Current Work

No work in progress.

## Context
<!-- Active work context will be written here -->
"@
    Set-Content -Path "work\current.md" -Value $currentContent -Encoding UTF8
}

if (-not (Test-Path "work\history.md")) {
    Write-Host "Creating history log..."
    $historyContent = @"
# Work History

## Completed Items

| Date | ID | Summary | Agent | Iterations |
|------|----|---------|-------|------------|
"@
    Set-Content -Path "work\history.md" -Value $historyContent -Encoding UTF8
}

if (-not (Test-Path "work\blockers.md")) {
    Write-Host "Creating blockers log..."
    $blockersContent = @"
# Blockers

## Active Blockers

| ID | Reason | Since | Resolution |
|----|--------|-------|------------|

## Resolved Blockers

| ID | Reason | Resolved | How |
|----|--------|----------|-----|
"@
    Set-Content -Path "work\blockers.md" -Value $blockersContent -Encoding UTF8
}

# Create loop state file
if (-not (Test-Path ".claude\hooks\lib\.loop-state")) {
    Write-Host "Initializing loop state..."
    $loopStateContent = @"
LOOP_ACTIVE=false
LOOP_ITERATION=0
LOOP_MAX_ITERATIONS=50
LOOP_PROMPT=""
LOOP_STARTED=""
"@
    Set-Content -Path ".claude\hooks\lib\.loop-state" -Value $loopStateContent -Encoding UTF8
}

# Update settings.json to use PowerShell hooks
$SettingsFile = Join-Path $ScriptDir ".claude\settings.json"
if (Test-Path $SettingsFile) {
    Write-Host "Updating settings.json for Windows/PowerShell..."
    
    try {
        $settings = Get-Content $SettingsFile -Raw | ConvertFrom-Json
        
        # Update SessionStart hook
        if ($settings.hooks.SessionStart) {
            foreach ($hookGroup in $settings.hooks.SessionStart) {
                foreach ($hook in $hookGroup.hooks) {
                    if ($hook.command -match "session-start.sh") {
                        $hook.command = 'powershell -ExecutionPolicy Bypass -File "$CLAUDE_PROJECT_DIR\.claude\hooks\session-start.ps1"'
                    }
                }
            }
        }
        
        # Update Stop hook
        if ($settings.hooks.Stop) {
            foreach ($hookGroup in $settings.hooks.Stop) {
                foreach ($hook in $hookGroup.hooks) {
                    if ($hook.command -match "on-stop.sh") {
                        $hook.command = 'powershell -ExecutionPolicy Bypass -File "$CLAUDE_PROJECT_DIR\.claude\hooks\on-stop.ps1"'
                    }
                }
            }
        }

        # Add powershell permission
        if ($settings.permissions.allow -notcontains "Bash(powershell:*)") {
            $settings.permissions.allow += "Bash(powershell:*)"
        }
        
        $settings | ConvertTo-Json -Depth 10 | Set-Content $SettingsFile -Encoding UTF8
    }
    catch {
        Write-Warning "Failed to update settings.json: $_"
        Write-Warning "You may need to manually configure hooks to use .ps1 files."
    }
}

Write-Host ""
Write-Host "=== Setup Complete ==="
Write-Host ""
Write-Host "Available commands:"
Write-Host "  /loop [task]     - Start autonomous iteration"
Write-Host "  /stop            - Stop the loop"
Write-Host "  /status          - Check progress"
Write-Host "  /queue list      - View work queue"
Write-Host "  /spawn <agent>   - Launch specific agent"
Write-Host ""
Write-Host "Start with: /loop ""your task description"""
