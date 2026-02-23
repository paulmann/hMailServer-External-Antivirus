<#
.SYNOPSIS
    hMailServer External Antivirus - Kaspersky Antivirus Integration

.DESCRIPTION
    This script integrates Kaspersky Antivirus (Kaspersky Security) as an external
    antivirus scanner for hMailServer. It invokes the Kaspersky command-line scanner
    (avp.com) to scan files passed by hMailServer and returns the appropriate exit
    codes so that hMailServer can take action on infected or suspicious messages.

    Supports Kaspersky Antivirus, Kaspersky Internet Security, and
    Kaspersky Endpoint Security for Windows.

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
    Requires:    Kaspersky Antivirus / Internet Security / Endpoint Security
    Requires:    PowerShell 5.1 or higher
    Requires:    hMailServer 5.x or higher with External Antivirus feature enabled

.EXAMPLE
    # Called automatically by hMailServer:
    powershell.exe -NonInteractive -File "C:\Scripts\KavAntiVirus.ps1" "C:\temp\hms_scan_file.tmp"

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

# Common installation paths for Kaspersky products
# The script will auto-detect the correct path, or you can set it manually.
$KasperskyPaths = @(
    "$env:ProgramFiles\Kaspersky Lab\Kaspersky Anti-Virus 21.3\avp.com",
    "$env:ProgramFiles\Kaspersky Lab\Kaspersky Anti-Virus 21.0\avp.com",
    "$env:ProgramFiles\Kaspersky Lab\Kaspersky Internet Security 21.3\avp.com",
    "$env:ProgramFiles\Kaspersky Lab\Kaspersky Internet Security 21.0\avp.com",
    "$env:ProgramFiles (x86)\Kaspersky Lab\Kaspersky Anti-Virus 21.3\avp.com",
    "$env:ProgramFiles (x86)\Kaspersky Lab\Kaspersky Anti-Virus 21.0\avp.com",
    "$env:ProgramFiles\Kaspersky Lab\Kaspersky Endpoint Security for Windows\avp.com",
    "$env:ProgramFiles (x86)\Kaspersky Lab\Kaspersky Endpoint Security for Windows\avp.com"
)

# Override with a specific path if auto-detection fails (set to $null for auto)
$KavCmdPath = $null

# Log file path (set to $null to disable logging)
$LogFile = "C:\hMailServer\Logs\KavAntiVirus.log"

# Scan report output directory
$ReportDir = "$env:TEMP\KavScanReports"

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

function Find-KasperskyExecutable {
    <#
    .SYNOPSIS
        Auto-detects the Kaspersky avp.com executable path.
    #>

    # First check if a manual override is configured
    if ($KavCmdPath -and (Test-Path $KavCmdPath)) {
        Write-Log "Using configured Kaspersky path: $KavCmdPath"
        return $KavCmdPath
    }

    # Try known installation paths
    foreach ($Path in $KasperskyPaths) {
        if (Test-Path $Path) {
            Write-Log "Auto-detected Kaspersky at: $Path"
            return $Path
        }
    }

    # Try registry-based detection
    try {
        $RegPaths = @(
            "HKLM:\SOFTWARE\KasperskyLab",
            "HKLM:\SOFTWARE\WOW6432Node\KasperskyLab"
        )
        foreach ($RegPath in $RegPaths) {
            if (Test-Path $RegPath) {
                $Products = Get-ChildItem $RegPath -ErrorAction SilentlyContinue
                foreach ($Product in $Products) {
                    $InstDir = (Get-ItemProperty -Path $Product.PSPath -Name "Folder" -ErrorAction SilentlyContinue).Folder
                    if ($InstDir) {
                        $AvpPath = Join-Path $InstDir "avp.com"
                        if (Test-Path $AvpPath) {
                            Write-Log "Registry-detected Kaspersky at: $AvpPath"
                            return $AvpPath
                        }
                    }
                }
            }
        }
    } catch {
        Write-Log "Registry detection failed: $_" -Level "WARN"
    }

    Write-Log "Kaspersky avp.com executable not found." -Level "ERROR"
    return $null
}

function Invoke-KasperskyScan {
    <#
    .SYNOPSIS
        Runs a Kaspersky on-demand scan on the specified file path.
    .OUTPUTS
        Returns the translated hMailServer exit code (0=clean, 1=infected, 2=error)
    #>
    param(
        [string]$AvpPath,
        [string]$Path
    )

    # Ensure report directory exists
    if (-not (Test-Path $ReportDir)) {
        New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null
    }

    $ReportFile = Join-Path $ReportDir ("KavScan_" + [System.IO.Path]::GetRandomFileName() + ".txt")

    Write-Log "Starting Kaspersky scan: $Path"
    Write-Log "Using scanner: $AvpPath"

    try {
        # Kaspersky avp.com SCAN command arguments:
        #   SCAN          - Perform an on-demand scan
        #   /i0           - Do not prompt for action (silently report)
        #   /fa           - Scan archives
        #   /fm           - Scan mail databases
        #   /report       - Write report to file
        $ProcessArgs = "SCAN `"$Path`" /i0 /fa /fm /report:`"$ReportFile`""

        $Process = Start-Process -FilePath $AvpPath `
                                 -ArgumentList $ProcessArgs `
                                 -Wait `
                                 -PassThru `
                                 -NoNewWindow `
                                 -RedirectStandardOutput "$env:TEMP\Kav_stdout.tmp" `
                                 -RedirectStandardError  "$env:TEMP\Kav_stderr.tmp"

        $ExitCode = $Process.ExitCode
        Write-Log "avp.com exited with code: $ExitCode"

        # Log report content if available
        if (Test-Path $ReportFile) {
            $ReportContent = Get-Content $ReportFile -Raw -ErrorAction SilentlyContinue
            if ($ReportContent) {
                Write-Log "Scan report: $($ReportContent.Substring(0, [Math]::Min(500, $ReportContent.Length)))"
            }
            Remove-Item $ReportFile -Force -ErrorAction SilentlyContinue
        }

        # Kaspersky avp.com SCAN exit codes:
        #   0  = No threats detected
        #   1  = Threats detected (but some may have been disinfected)
        #   2  = Threats detected (not all were disinfected)
        #   3  = Scan not completed
        #   4  = Suspended
        #  -1  = Unknown error
        switch ($ExitCode) {
            0 {
                Write-Log "Scan CLEAN: No threats detected in $Path"
                return 0   # Clean
            }
            { $_ -in @(1, 2) } {
                Write-Log "Scan INFECTED: Threat detected in $Path (avp.com code: $ExitCode)" -Level "WARN"
                return 1   # Infected
            }
            default {
                Write-Log "Scan ERROR: avp.com returned code $ExitCode for $Path" -Level "ERROR"
                return 2   # Error
            }
        }
    } catch {
        Write-Log "Failed to execute avp.com: $_" -Level "ERROR"
        return 2
    }
}

# ============================================================
# Main Execution
# ============================================================

Write-Log "=== hMailServer Kaspersky Antivirus Scanner invoked ==="
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

# Locate Kaspersky executable
$AvpExecutable = Find-KasperskyExecutable
if (-not $AvpExecutable) {
    Write-Log "Kaspersky scanner not found. Cannot proceed with scan." -Level "ERROR"
    exit 2
}

# Perform the scan and get result
$Result = Invoke-KasperskyScan -AvpPath $AvpExecutable -Path $FilePath

Write-Log "Final result for $FilePath : exit $Result"
exit $Result
