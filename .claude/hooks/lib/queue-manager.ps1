# queue-manager.ps1 - Markdown work queue management
#
# CRUD operations for work/queue.md

$ScriptDir = $PSScriptRoot
$ProjectDir = (Get-Item "$ScriptDir\..\..\..").FullName
$QueueFile = Join-Path $ProjectDir "work\queue.md"
$HistoryFile = Join-Path $ProjectDir "work\history.md"
$CurrentFile = Join-Path $ProjectDir "work\current.md"
$BlockersFile = Join-Path $ProjectDir "work\blockers.md"

# Initialize queue file if missing
function Init-Queue {
    if (-not (Test-Path $QueueFile)) {
        New-Item -ItemType Directory -Force -Path (Split-Path $QueueFile) | Out-Null
        $content = @"
# Work Queue

## In Progress

## Pending

## Blocked

## Completed
"@
        Set-Content -Path $QueueFile -Value $content -Encoding UTF8
    }
}

# List all items in queue
function Get-QueueList {
    Init-Queue
    Get-Content $QueueFile
}

# Count items by section
function Measure-QueueItems {
    param([string]$section = "Pending")
    Init-Queue
    
    $content = Get-Content $QueueFile
    $currentSection = ""
    $count = 0
    
    foreach ($line in $content) {
        if ($line -match "^## (.*)") {
            $currentSection = $matches[1].Trim()
            continue
        }
        
        if ($currentSection -eq $section -and $line -match "^- \[ \]") {
            $count++
        }
    }
    return $count
}

# Get next pending item
function Get-NextItem {
    Init-Queue
    
    $content = Get-Content $QueueFile
    $inPending = $false
    
    foreach ($line in $content) {
        if ($line -match "^## Pending") {
            $inPending = $true
            continue
        }
        if ($line -match "^## ") {
            $inPending = $false
        }
        
        if ($inPending -and $line -match "^- \[ \]") {
            return $line
        }
    }
    return $null
}

# Add item to queue
function Add-QueueItem {
    param(
        [string]$id,
        [string]$description,
        [string]$priority = "medium",
        [string]$agent = "developer",
        [string]$depends = ""
    )
    Init-Queue
    
    $entry = "- [ ] **[$id]** $description"
    $metadata = @("  - Priority: $priority", "  - Agent: $agent")
    if ($depends) { $metadata += "  - Depends: $depends" }
    
    $content = Get-Content $QueueFile
    $newContent = @()
    
    foreach ($line in $content) {
        $newContent += $line
        if ($line -match "^## Pending") {
            $newContent += $entry
            $newContent += $metadata
        }
    }
    
    Set-Content -Path $QueueFile -Value $newContent -Encoding UTF8
    Write-Host "Added: [$id] $description"
}

# Helper to remove item by ID and return the removed lines
function Remove-QueueItemHelper {
    param([string]$id)
    
    $content = Get-Content $QueueFile
    $newContent = @()
    $removedLines = @()
    $skipping = $false
    
    foreach ($line in $content) {
        # Check if line marks start of the item
        if ($line -match "^\- \[ \].*\[$([Regex]::Escape($id))\]") {
            $skipping = $true
            $removedLines += $line
            continue
        }
        
        # If we are skipping, check if next line is metadata (indented)
        if ($skipping) {
            if ($line -match "^  -") {
                $removedLines += $line
                continue
            } else {
                $skipping = $false
            }
        }
        
        $newContent += $line
    }
    
    Set-Content -Path $QueueFile -Value $newContent -Encoding UTF8
    return $removedLines
}

# Remove item from queue
function Remove-QueueItem {
    param([string]$id)
    Init-Queue
    $removed = Remove-QueueItemHelper -id $id
    if ($removed) {
        Write-Host "Removed: [$id]"
    } else {
        Write-Host "Item not found: [$id]"
    }
}

# Move item to In Progress
function Start-QueueItem {
    param([string]$id)
    Init-Queue
    
    # Remove and capture
    $removedLines = Remove-QueueItemHelper -id $id
    
    if (-not $removedLines) {
        Write-Host "Item not found: [$id]"
        return
    }
    
    # Process lines: Add timestamp, keep others
    $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    $newLines = @()
    
    foreach ($line in $removedLines) {
        if ($line -match "- Priority:") {
            $newLines += "  - Started: $timestamp"
        }
        $newLines += $line
    }
    
    # Insert into In Progress
    $content = Get-Content $QueueFile
    $finalContent = @()
    
    foreach ($line in $content) {
        $finalContent += $line
        if ($line -match "^## In Progress") {
            $finalContent += $newLines
        }
    }
    
    Set-Content -Path $QueueFile -Value $finalContent -Encoding UTF8
    Write-Host "Started: [$id]"
}

# Complete item
function Complete-QueueItem {
    param(
        [string]$id,
        [string]$summary = "Completed",
        [string]$agent = "",
        [string]$iterations = "1"
    )
    Init-Queue
    
    Remove-QueueItem -id $id
    
    $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    $logEntry = "| $timestamp | $id | $summary | $agent | $iterations |"
    
    Add-Content -Path $HistoryFile -Value $logEntry -Encoding UTF8
    Write-Host "Completed: [$id]"
}

# Block item
function Block-QueueItem {
    param(
        [string]$id,
        [string]$reason
    )
    Init-Queue
    
    $removedLines = Remove-QueueItemHelper -id $id
    
    if (-not $removedLines) {
        Write-Host "Item not found: [$id]"
        return
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    $newLines = @()
    
    foreach ($line in $removedLines) {
        if ($line -match "- Priority:") {
            $newLines += "  - Blocker: $reason"
            $newLines += "  - Since: $timestamp"
        }
        $newLines += $line
    }
    
    # Insert into Blocked
    $content = Get-Content $QueueFile
    $finalContent = @()
    
    foreach ($line in $content) {
        $finalContent += $line
        if ($line -match "^## Blocked") {
            $finalContent += $newLines
        }
    }
    
    Set-Content -Path $QueueFile -Value $finalContent -Encoding UTF8
    
    # Log to blockers file
    $logEntry = "| $id | $reason | $timestamp | - |"
    Add-Content -Path $BlockersFile -Value $logEntry -Encoding UTF8
    
    Write-Host "Blocked: [$id] - $reason"
}

# Get queue summary
function Get-QueueSummary {
    Init-Queue
    
    $inProgress = Measure-QueueItems -section "In Progress"
    $pending = Measure-QueueItems -section "Pending"
    $blocked = Measure-QueueItems -section "Blocked"
    
    Write-Host "Queue Summary:"
    Write-Host "  In Progress: $inProgress"
    Write-Host "  Pending: $pending"
    Write-Host "  Blocked: $blocked"
    Write-Host ""
    Write-Host "Next item:"
    $next = Get-NextItem
    if ($next) { Write-Host $next }
}

# Command-line interface
if ($MyInvocation.MyCommand.Path -eq $PSCommandPath) {
    switch ($args[0]) {
        "list" { Get-QueueList }
        "count" { 
            $section = if ($args[1]) { $args[1] } else { "Pending" }
            Measure-QueueItems -section $section 
        }
        "next" { Get-NextItem }
        "add" { 
            $prio = if ($args[3]) { $args[3] } else { "medium" }
            $agt = if ($args[4]) { $args[4] } else { "developer" }
            $dep = if ($args[5]) { $args[5] } else { "" }
            Add-QueueItem -id $args[1] -description $args[2] -priority $prio -agent $agt -depends $dep 
        }
        "remove" { Remove-QueueItem -id $args[1] }
        "start" { Start-QueueItem -id $args[1] }
        "complete" { 
            $sum = if ($args[2]) { $args[2] } else { "Completed" }
            $agt = if ($args[3]) { $args[3] } else { "" }
            $iter = if ($args[4]) { $args[4] } else { "1" }
            Complete-QueueItem -id $args[1] -summary $sum -agent $agt -iterations $iter 
        }
        "block" { Block-QueueItem -id $args[1] -reason $args[2] }
        "summary" { Get-QueueSummary }
        Default {
            Write-Host "Usage: .\queue-manager.ps1 {list|count|next|add|remove|start|complete|block|summary}"
        }
    }
}
