# on-stop.ps1 - Ralph-loop continuation logic
#
# This hook runs when Claude tries to exit.
# If loop is active and STATUS is COMPLETE, it continues to next item.
# If BLOCKED/ERROR, it pauses and logs.

$ScriptDir = $PSScriptRoot
$ProjectDir = (Get-Item "$ScriptDir\..\..").FullName
$LibDir = Join-Path $ScriptDir "lib"

# Source library functions
. "$LibDir\loop-control.ps1"

# Read loop state
Read-LoopState

# If loop is not active, allow normal exit
if ($global:LOOP_ACTIVE -ne "true") {
    exit 0
}

# Check iteration limit
if ([int]$global:LOOP_ITERATION -ge [int]$global:LOOP_MAX_ITERATIONS) {
    Write-Host "LOOP: Max iterations ($global:LOOP_MAX_ITERATIONS) reached. Stopping."
    Update-LoopState -active "false" -iteration "0" -prompt ""
    exit 0
}

# Get the last output from Claude
# CLAUDE_LAST_OUTPUT is passed as an environment variable
$LastOutput = $env:CLAUDE_LAST_OUTPUT

if (-not $LastOutput) {
    # Fallback if empty (shouldn't happen if interaction occurred)
    $LastOutput = ""
}

# Parse STATUS from output
$Status = ""
$Summary = ""
$Files = ""
$Next = ""
$Blocker = ""

if ($LastOutput -match "(?m)^STATUS:\s*(.*)$") { $Status = $matches[1].Trim() }
if ($LastOutput -match "(?m)^SUMMARY:\s*(.*)$") { $Summary = $matches[1].Trim() }
if ($LastOutput -match "(?m)^FILES:\s*(.*)$") { $Files = $matches[1].Trim() }
if ($LastOutput -match "(?m)^NEXT:\s*(.*)$") { $Next = $matches[1].Trim() }
if ($LastOutput -match "(?m)^BLOCKER:\s*(.*)$") { $Blocker = $matches[1].Trim() }

# Increment iteration
$NewIteration = [int]$global:LOOP_ITERATION + 1

$Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"

switch ($Status) {
    "COMPLETE" {
        Write-Host "LOOP: Iteration $NewIteration - Work completed."

        # Log to history
        $HistoryFile = Join-Path $ProjectDir "work\history.md"
        $LogEntry = "| $Timestamp | - | $Summary | - | $NewIteration |"
        Add-Content -Path $HistoryFile -Value $LogEntry -Encoding UTF8

        # Update loop state
        Update-LoopState -active "true" -iteration $NewIteration -prompt $global:LOOP_PROMPT

        # Continue - output prompt for next iteration
        Write-Host ""
        Write-Host "Continue with the next work item from queue."
        Write-Host "Current iteration: $NewIteration / $global:LOOP_MAX_ITERATIONS"
        if ($Next) {
            Write-Host "Suggested next: $Next"
        }

        # Block exit to continue loop (exit code 2 is intercepted)
        exit 2
    }

    "BLOCKED" {
        Write-Host "LOOP: Iteration $NewIteration - Blocked."
        Write-Host "Reason: $Blocker"

        # Log blocker
        $BlockersFile = Join-Path $ProjectDir "work\blockers.md"
        $LogEntry = "| - | $Blocker | $Timestamp | - |"
        Add-Content -Path $BlockersFile -Value $LogEntry -Encoding UTF8

        # Pause loop
        Update-LoopState -active "false" -iteration $NewIteration -prompt $global:LOOP_PROMPT
        Write-Host "Loop paused. Use /loop to resume after resolving blocker."
        exit 0
    }

    "WAITING" {
        Write-Host "LOOP: Iteration $NewIteration - Waiting for external event."

        # Update state but don't increment iteration (retry same step?) 
        # Actually bash script keeps iteration same.
        Update-LoopState -active "true" -iteration $global:LOOP_ITERATION -prompt $global:LOOP_PROMPT

        Write-Host "Will retry on next iteration."
        exit 2
    }

    "ERROR" {
        Write-Host "LOOP: Iteration $NewIteration - Error encountered."

        # Log error
        $BlockersFile = Join-Path $ProjectDir "work\blockers.md"
        $LogEntry = "| - | ERROR: $Summary | $Timestamp | - |"
        Add-Content -Path $BlockersFile -Value $LogEntry -Encoding UTF8

        # Pause on error
        Update-LoopState -active "false" -iteration $NewIteration -prompt $global:LOOP_PROMPT
        Write-Host "Loop paused due to error. Review and use /loop to resume."
        exit 0
    }

    Default {
        # No STATUS found - check if there's still work to do
        Write-Host "LOOP: Iteration $NewIteration - No STATUS signal detected."
        Write-Host "Reminder: Emit STATUS signal at end of work."

        # Continue anyway
        Update-LoopState -active "true" -iteration $NewIteration -prompt $global:LOOP_PROMPT
        exit 2
    }
}
