<#
.SYNOPSIS
    hMailServer External Antivirus - Windows Defender Integration

.DESCRIPTION
    This script integrates Windows Defender (Microsoft Defender Antivirus) as an
    external antivirus scanner for hMailServer. It is designed to be called by
    hMailServer's external antivirus feature to scan incoming and outgoing email
    attachments and message bodies for malware threats.

    The script accepts a file path as an argument, invokes a Windows Defender scan
    on the specified file, parses the scan results, and returns the appropriate
    exit code to hMailServer indicating whether the file is clean or infected.

.PARAMETER FilePath
    The full path to the file or directory to be scanned. This parameter is
    automatically passed by hMailServer when invoking the external scanner.

.OUTPUTS
    Exit Code 0 - File is clean, no threats detected
    Exit Code 1 - Scan error or engine failure
    Exit Code 2 - Threat detected, file should be quarantined/rejected

.NOTES
    Author:      Mikhail Deynekin
    Repository:  https://github.com/paulmann/hMailServer-External-Antivirus
    Version:     1.1.0
    Requires:    Windows Defender (Microsoft Defender Antivirus) must be active
    Requires:    PowerShell 5.1 or Core 7.x
    Requires:    hMailServer 5.x or higher with External Antivirus feature enabled

.EXAMPLE
    # Called automatically by hMailServer:
    pwsh.exe -NoProfile -NonInteractive -File "C:\hMailServer\Scripts\WinDefAntiVirus.ps1" "C:	emp\hms_scan_file.tmp"

.LINK
    https://github.com/paulmann/hMailServer-External-Antivirus
#>

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$FilePath
)

# ============================================================
# Configuration
# ============================================================

# Path to the Windows Defender command-line scanner
$MpCmdRunPath = "$env:ProgramFiles\Windows Defender\MpCmdRun.exe"

# Log file path (set to $null to disable logging)
$LogFile = "C:\hMailServer\Logs\WinDefAntiVirus.log"

# ============================================================
# Functions
# ============================================================

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    if ($LogFile) {
        $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $LogEntry  = "[$Timestamp] [$Level] $Message"
        try {
            Add-Content -Path $LogFile -Value $LogEntry -Encoding UTF8
        } catch {
            # Silently ignore log write failures to avoid interfering with scan result
        }
    }
}

function Test-WindowsDefender {
    if (-not (Test-Path $MpCmdRunPath)) {
        Write-Log "Windows Defender MpCmdRun.exe not found at: $MpCmdRunPath" -Level "ERROR"
        return $false
    }
    return $true
}

function Invoke-DefenderScan {
    param([string]$Path)

    Write-Log "Starting scan: $Path"

    try {
        $ProcessArgs = "-Scan -ScanType 3 -File `"$Path`" -DisableRemediation"
        $Process = Start-Process -FilePath $MpCmdRunPath `
                                 -ArgumentList $ProcessArgs `
                                 -Wait `
                                 -PassThru `
                                 -NoNewWindow `
                                 -RedirectStandardOutput "$env:TEMP\WinDef_stdout.tmp" `
                                 -RedirectStandardError  "$env:TEMP\WinDef_stderr.tmp"

        $ExitCode = $Process.ExitCode
        Write-Log "MpCmdRun.exe exited with code: $ExitCode"
        return $ExitCode
    } catch {
        Write-Log "Failed to execute MpCmdRun.exe: $_" -Level "ERROR"
        return 1
    }
}

# ============================================================
# Main Execution
# ============================================================

Write-Log "=== hMailServer Windows Defender Scanner invoked ==="
Write-Log "Target file: $FilePath"

if ([string]::IsNullOrWhiteSpace($FilePath) -or -not (Test-Path -LiteralPath $FilePath)) {
    Write-Log "Invalid file path: $FilePath" -Level "ERROR"
    exit 1
}

if (-not (Test-WindowsDefender)) {
    Write-Log "Windows Defender is unavailable." -Level "ERROR"
    exit 1
}

$ScanResult = Invoke-DefenderScan -Path $FilePath

# MpCmdRun.exe exit codes:
#   0 = No threats found
#   2 = Threat found
switch ($ScanResult) {
    0 {
        Write-Log "Scan CLEAN: No threats detected."
        exit 0
    }
    2 {
        Write-Log "Scan INFECTED: Threat detected." -Level "WARN"
        exit 2
    }
    default {
        Write-Log "Scan ERROR: Unexpected exit code $ScanResult" -Level "ERROR"
        exit 1
    }
}
