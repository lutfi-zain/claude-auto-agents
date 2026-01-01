# loop-control.ps1 - Loop iteration tracking and control
# Manages the autonomous loop state: active/inactive, iteration count, limits

$ScriptDir = $PSScriptRoot
$LoopStateFile = Join-Path $ScriptDir ".loop-state"

# Default values
$DefaultMaxIterations = 50

# Initialize loop state file if missing
function Init-LoopState {
    if (-not (Test-Path $LoopStateFile)) {
        $content = @"
LOOP_ACTIVE=false
LOOP_ITERATION=0
LOOP_MAX_ITERATIONS=$DefaultMaxIterations
LOOP_PROMPT=""
LOOP_STARTED=""
"@
        Set-Content -Path $LoopStateFile -Value $content -Encoding UTF8
    }
}

# Read current loop state
function Read-LoopState {
    Init-LoopState
    $content = Get-Content -Path $LoopStateFile -ErrorAction SilentlyContinue
    $global:LOOP_ACTIVE = "false"
    $global:LOOP_ITERATION = 0
    $global:LOOP_MAX_ITERATIONS = $DefaultMaxIterations
    $global:LOOP_PROMPT = ""
    $global:LOOP_STARTED = ""

    foreach ($line in $content) {
        if ($line -match '^(\w+)=(.*)$') {
            $key = $matches[1]
            $value = $matches[2]
            # Remove quotes if present
            if ($value -match '^"(.*)"$') { $value = $matches[1] }
            Set-Variable -Name $key -Value $value -Scope Global
        }
    }
}

# Update loop state
function Update-LoopState {
    param(
        [string]$active = "false",
        [string]$iteration = "0",
        [string]$prompt = "",
        [string]$maxIterations = $DefaultMaxIterations,
        [string]$started = $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    )

    $content = @"
LOOP_ACTIVE=$active
LOOP_ITERATION=$iteration
LOOP_MAX_ITERATIONS=$maxIterations
LOOP_PROMPT="$prompt"
LOOP_STARTED="$started"
"@
    Set-Content -Path $LoopStateFile -Value $content -Encoding UTF8
    
    # Update global variables in memory
    $global:LOOP_ACTIVE = $active
    $global:LOOP_ITERATION = $iteration
    $global:LOOP_MAX_ITERATIONS = $maxIterations
    $global:LOOP_PROMPT = $prompt
    $global:LOOP_STARTED = $started
}

# Start a new loop
function Start-Loop {
    param(
        [string]$prompt,
        [string]$max = $DefaultMaxIterations
    )
    Update-LoopState -active "true" -iteration "0" -prompt $prompt -maxIterations $max
    Write-Host "Loop started with prompt: $prompt"
    Write-Host "Max iterations: $max"
}

# Stop the loop
function Stop-Loop {
    Read-LoopState
    $finalIteration = $global:LOOP_ITERATION
    Update-LoopState -active "false" -iteration "0" -prompt "" -maxIterations $global:LOOP_MAX_ITERATIONS -started ""
    Write-Host "Loop stopped after $finalIteration iterations."
}

# Check if loop is active
function Test-LoopActive {
    Read-LoopState
    return $global:LOOP_ACTIVE -eq "true"
}

# Get current iteration
function Get-Iteration {
    Read-LoopState
    return $global:LOOP_ITERATION
}

# Increment iteration
function Increment-Iteration {
    Read-LoopState
    $newIteration = [int]$global:LOOP_ITERATION + 1
    Update-LoopState -active $global:LOOP_ACTIVE -iteration $newIteration -prompt $global:LOOP_PROMPT -maxIterations $global:LOOP_MAX_ITERATIONS -started $global:LOOP_STARTED
    return $newIteration
}

# Check if at iteration limit
function Test-AtLimit {
    Read-LoopState
    return [int]$global:LOOP_ITERATION -ge [int]$global:LOOP_MAX_ITERATIONS
}

# Get loop status summary
function Get-LoopStatus {
    Read-LoopState
    Write-Host "Loop Status:"
    Write-Host "  Active: $global:LOOP_ACTIVE"
    Write-Host "  Iteration: $global:LOOP_ITERATION / $global:LOOP_MAX_ITERATIONS"
    if ($global:LOOP_PROMPT) {
        Write-Host "  Prompt: $global:LOOP_PROMPT"
    }
    if ($global:LOOP_STARTED) {
        Write-Host "  Started: $global:LOOP_STARTED"
    }
}

# Command-line interface logic
if ($MyInvocation.InvocationName -ne '.') {
    switch ($args[0]) {
        "start" { Start-Loop -prompt $args[1] -max $args[2] }
        "stop" { Stop-Loop }
        "status" { Get-LoopStatus }
        "active" { if (Test-LoopActive) { "true" } else { "false" } }
        "iteration" { Get-Iteration }
        "increment" { Increment-Iteration }
        Default {
            Write-Host "Usage: .\loop-control.ps1 {start|stop|status|active|iteration|increment}"
        }
    }
}
