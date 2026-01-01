# status-parser.ps1 - Parse STATUS signals from Claude output
#
# Extracts STATUS, SUMMARY, FILES, NEXT, BLOCKER from output text

# Parse STATUS signal from text
function Parse-Status {
    param(
        [string]$text
    )

    $status = ""
    $summary = ""
    $files = ""
    $next = ""
    $blocker = ""

    if ($text -match "(?m)^STATUS:\s*(.*)$") { $status = $matches[1].Trim().ToUpper() }
    if ($text -match "(?m)^SUMMARY:\s*(.*)$") { $summary = $matches[1].Trim() }
    if ($text -match "(?m)^FILES:\s*(.*)$") { $files = $matches[1].Trim() }
    if ($text -match "(?m)^NEXT:\s*(.*)$") { $next = $matches[1].Trim() }
    if ($text -match "(?m)^BLOCKER:\s*(.*)$") { $blocker = $matches[1].Trim() }

    # Output as properties that can be captured
    $obj = [PSCustomObject]@{
        Status = $status
        Summary = $summary
        Files = $files
        Next = $next
        Blocker = $blocker
    }
    
    # If called as a script command, output key-value pairs for easy parsing or just the object
    # The bash version outputs STATUS_VALUE="...", which is meant for eval.
    # Here we'll return the object which is more useful in PS.
    return $obj
}

# Check if text contains a valid STATUS signal
function Test-HasStatus {
    param([string]$text)
    return $text -match "(?m)^STATUS:\s*(COMPLETE|BLOCKED|WAITING|ERROR)"
}

# Get just the status value (COMPLETE, BLOCKED, etc)
function Get-StatusValue {
    param([string]$text)
    if ($text -match "(?m)^STATUS:\s*(.*)$") {
        return $matches[1].Trim().ToUpper()
    }
    return ""
}

# Validate status value
function Test-ValidStatus {
    param([string]$status)
    return $status -match "^(COMPLETE|BLOCKED|WAITING|ERROR)$"
}

# Parse from file
function Parse-StatusFile {
    param([string]$file)
    if (Test-Path $file) {
        $content = Get-Content $file -Raw
        return Parse-Status -text $content
    } else {
        return [PSCustomObject]@{
            Status = ""
            Summary = ""
            Files = ""
            Next = ""
            Blocker = ""
        }
    }
}

# Create a STATUS signal
function New-Status {
    param(
        [string]$status,
        [string]$summary,
        [string]$files = "",
        [string]$next = "",
        [string]$blocker = ""
    )

    Write-Output "STATUS: $status"
    Write-Output "SUMMARY: $summary"
    if ($files) { Write-Output "FILES: $files" }
    if ($next) { Write-Output "NEXT: $next" }
    if ($blocker) { Write-Output "BLOCKER: $blocker" }
}

# Command-line interface
if ($MyInvocation.InvocationName -ne '.') {
    switch ($args[0]) {
        "parse" {
            if ($args[1]) {
                $obj = Parse-Status -text $args[1]
            } else {
                # Read from stdin
                $inputStr = $input | Out-String
                $obj = Parse-Status -text $inputStr
            }
            # Output in a way that mimics the bash script: key=value
            Write-Output "STATUS_VALUE=""$($obj.Status)"""
            Write-Output "STATUS_SUMMARY=""$($obj.Summary)"""
            Write-Output "STATUS_FILES=""$($obj.Files)"""
            Write-Output "STATUS_NEXT=""$($obj.Next)"""
            Write-Output "STATUS_BLOCKER=""$($obj.Blocker)"""
        }
        "parse-file" {
            $obj = Parse-StatusFile -file $args[1]
            Write-Output "STATUS_VALUE=""$($obj.Status)"""
            Write-Output "STATUS_SUMMARY=""$($obj.Summary)"""
            Write-Output "STATUS_FILES=""$($obj.Files)"""
            Write-Output "STATUS_NEXT=""$($obj.Next)"""
            Write-Output "STATUS_BLOCKER=""$($obj.Blocker)"""
        }
        "has" {
            if (Test-HasStatus -text $args[1]) { "true" } else { "false" }
        }
        "value" {
            Get-StatusValue -text $args[1]
        }
        "create" {
            New-Status -status $args[1] -summary $args[2] -files $args[3] -next $args[4] -blocker $args[5]
        }
        Default {
            Write-Host "Usage: .\status-parser.ps1 {parse|parse-file|has|value|create}"
        }
    }
}
