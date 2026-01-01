# session-start.ps1 - Protocol injection and queue loading at session start
#
# This hook runs at the start of every Claude Code session.
# It injects the STATUS protocol and loads the current work queue.

$ScriptDir = $PSScriptRoot
$ProjectDir = (Get-Item "$ScriptDir\..\..").FullName
$LibDir = Join-Path $ScriptDir "lib"

# Source library functions
. "$LibDir\loop-control.ps1"

# Read loop state
Read-LoopState

# Output protocol injection
$Protocol = @"
# Autonomous Agent Protocol

## STATUS Signal (Required)

At the END of every work unit, emit:

```
STATUS: COMPLETE | BLOCKED | WAITING | ERROR
SUMMARY: What was done (1-2 sentences)
FILES: Changed files (comma-separated)
NEXT: Suggested next action
```

## Loop Mode
"@
Write-Output $Protocol

if ($global:LOOP_ACTIVE -eq "true") {
    Write-Output ""
    Write-Output "**LOOP ACTIVE** - Iteration: $global:LOOP_ITERATION"
    Write-Output "Original task: $global:LOOP_PROMPT"
    Write-Output ""
    Write-Output "Continue working on the task. Emit STATUS when done."
} else {
    Write-Output ""
    Write-Output "Loop is **inactive**. Use `/loop ""task""` to start."
}

# Show current work queue summary
$QueueFile = Join-Path $ProjectDir "work\queue.md"
if (Test-Path $QueueFile) {
    Write-Output ""
    Write-Output "## Work Queue Summary"
    Write-Output ""

    $content = Get-Content $QueueFile
    
    # Count items in each section
    $InProgress = 0
    $Pending = 0
    
    # Simple regex counting (approximate but sufficient)
    $InProgress = ($content | Select-String "^\- \[ \]").Count
    
    # Find next item
    $NextItem = "None"
    $FoundPendingHeader = $false
    foreach ($line in $content) {
        if ($line -match "^## Pending") {
            $FoundPendingHeader = $true
            continue
        }
        if ($FoundPendingHeader -and $line -match "^\- \[ \]") {
            $NextItem = $line
            break
        }
    }

    Write-Output "- In Progress: ~$InProgress items"
    Write-Output "- Next up: $NextItem"
}

# Show current work context if exists
$CurrentFile = Join-Path $ProjectDir "work\current.md"
if (Test-Path $CurrentFile) {
    $currentContent = Get-Content $CurrentFile -TotalCount 20
    $contentString = $currentContent -join "`n"
    
    if ($contentString -notmatch "No work in progress") {
        Write-Output ""
        Write-Output "## Active Work Context"
        Write-Output ""
        Write-Output $contentString
    }
}
