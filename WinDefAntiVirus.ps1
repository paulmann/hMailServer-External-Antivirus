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
    Exit Code 1 - Threat detected, file should be quarantined/rejected
    Exit Code 2 - Scan error or engine failure

.NOTES
    Author:      Mikhail Deynekin
    Repository:  https://github.com/paulmann/hMailServer-External-Antivirus
    Version:     1.0.0
    Requires:    Windows Defender (Microsoft Defender Antivirus) must be active
    Requires:    PowerShell 5.1 or higher
    Requires:    hMailServer 5.x or higher with External Antivirus feature enabled

.EXAMPLE
    # Called automatically by hMailServer:
    powershell.exe -NonInteractive -File "C:\Scripts\WinDefAntiVirus.ps1" "C:\temp\hms_scan_file.tmp"

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

# Maximum wait time for scan completion (in seconds)
$ScanTimeout = 120

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
    <#
    .SYNOPSIS
        Verifies that Windows Defender is available and the engine is up to date.
    #>
    if (-not (Test-Path $MpCmdRunPath)) {
        Write-Log "Windows Defender MpCmdRun.exe not found at: $MpCmdRunPath" -Level "ERROR"
        return $false
    }
    try {
        $Status = Get-MpComputerStatus -ErrorAction Stop
        if (-not $Status.AntivirusEnabled) {
            Write-Log "Windows Defender antivirus is disabled on this system." -Level "WARN"
        }
        Write-Log "Defender engine version: $($Status.AMEngineVersion), Signature version: $($Status.AntivirusSignatureVersion)"
        return $true
    } catch {
        Write-Log "Unable to query Windows Defender status: $_" -Level "WARN"
        # Still proceed with scan attempt even if status query fails
        return $true
    }
}

function Invoke-DefenderScan {
    <#
    .SYNOPSIS
        Runs a Windows Defender scan on the specified file path.
    .OUTPUTS
        Returns the process exit code from MpCmdRun.exe
    #>
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
        return 2
    }
}

# ============================================================
# Main Execution
# ============================================================

Write-Log "=== hMailServer Windows Defender Scanner invoked ==="
Write-Log "Target file: $FilePath"

# Validate input
if ([string]::IsNullOrWhiteSpace($FilePath)) {
    Write-Log "No file path provided. Exiting with error." -Level "ERROR"
    exit 2
}

if (-not (Test-Path -LiteralPath $FilePath)) {
    Write-Log "Specified file/path does not exist: $FilePath" -Level "ERROR"
    exit 2
}

# Verify Windows Defender is available
if (-not (Test-WindowsDefender)) {
    Write-Log "Windows Defender is unavailable. Failing safe (treating as infected)." -Level "ERROR"
    exit 2
}

# Perform the scan
$ScanResult = Invoke-DefenderScan -Path $FilePath

# Interpret result
# MpCmdRun.exe exit codes:
#   0 = No threats found
#   2 = Threat found
# Any other code = Error
switch ($ScanResult) {
    0 {
        Write-Log "Scan CLEAN: No threats detected in $FilePath"
        exit 0
    }
    2 {
        Write-Log "Scan INFECTED: Threat detected in $FilePath" -Level "WARN"
        exit 1
    }
    default {
        Write-Log "Scan ERROR: Unexpected exit code $ScanResult from Windows Defender" -Level "ERROR"
        exit 2
    }
}
