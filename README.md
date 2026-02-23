# hMailServer External Antivirus Integration

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://microsoft.com/powershell)
[![hMailServer](https://img.shields.io/badge/hMailServer-5.x-orange.svg)](https://www.hmailserver.com/)

A professional collection of PowerShell-based integration scripts for **hMailServer**, enabling seamless antivirus protection via **Microsoft Defender** and **Kaspersky Antivirus**.

## Overview

These scripts serve as high-performance bridges between hMailServer and industry-standard antivirus engines. By utilizing hMailServer's "External Antivirus" feature, these scripts scan incoming and outgoing email attachments and message bodies, ensuring your mail infrastructure remains secure against evolving malware threats.

### Included Scanners

*   **`WinDefAntiVirus.ps1`**: Integrates with **Microsoft Defender Antivirus** (Windows Defender) using the `MpCmdRun.exe` command-line utility.
*   **`KavAntiVirus.ps1`**: Integrates with **Kaspersky Antivirus**, **Internet Security**, and **Endpoint Security** using the `avp.com` command-line scanner.

## Key Features

*   **Engine Auto-Detection**: Scripts automatically locate antivirus executables in standard installation paths and registry keys.
*   **Comprehensive Logging**: Detailed scan logs are maintained for auditing and troubleshooting purposes.
*   **Fail-Safe Architecture**: Implements proper exit code mapping (Clean, Infected, Error) to ensure hMailServer handles scan results correctly.
*   **Lightweight & Non-Intrusive**: Designed to run with minimal overhead in a high-concurrency mail server environment.

## Prerequisites

*   **Operating System**: Windows Server 2012 R2 or newer / Windows 10 or newer.
*   **PowerShell**: Version 5.1 or higher (standard on modern Windows).
*   **hMailServer**: Version 5.x installed and configured.
*   **Antivirus Software**: Either Microsoft Defender or a supported Kaspersky product must be installed and active.

## Installation & Configuration

### 1. Script Deployment

1.  Clone this repository or download the script files.
2.  Place the scripts in a secure directory on your server (e.g., `C:\hMailServer\Scripts\`).
3.  Ensure the hMailServer service account has **Read & Execute** permissions for these scripts and **Write** permissions for the log directory (default: `C:\hMailServer\Logs\`).

### 2. hMailServer Setup

1.  Open the **hMailServer Administrator**.
2.  Navigate to **Settings** > **Anti-virus**.
3.  Go to the **External anti-virus** tab.
4.  Check **Use external anti-virus**.
5.  Configure the following settings (using the Defender script as an example):
    *   **Scanner executable**: `powershell.exe`
    *   **Command line**: `-ExecutionPolicy Bypass -NonInteractive -File "C:\hMailServer\Scripts\WinDefAntiVirus.ps1" "%FILE%"`
    *   **Return code for infected**: `1`
6.  Click **Save**.

## 🛡️ Critical: Exclusion Settings

To ensure optimal performance and prevent "double-scanning" or file lock conflicts, it is **mandatory** to configure your antivirus software to exclude the hMailServer Data and Temp directories.

**Configure your Antivirus (Defender/Kaspersky) to exclude the following paths:**
*   `C:\Program Files (x86)\hMailServer\Data\` (or your custom data path)
*   `C:\Program Files (x86)\hMailServer\Temp\`
*   `C:\hMailServer\Logs\`

Failure to set these exclusions may result in scanned emails being locked by the real-time protection engine, causing mail delivery delays or hMailServer service instability.

## Logging & Monitoring

The scripts generate detailed logs at `C:\hMailServer\Logs\WinDefAntiVirus.log` (or `KavAntiVirus.log`). Monitoring these logs is recommended during initial setup to verify that scans are being triggered and completed correctly.

```text
[2026-02-24 10:15:22] [INFO] === hMailServer Windows Defender Scanner invoked ===
[2026-02-24 10:15:22] [INFO] Target file: C:\hMailServer\Temp\{A1B2C3D4-E5F6}.tmp
[2026-02-24 10:15:23] [INFO] Scan CLEAN: No threats detected
```

## Troubleshooting

*   **Execution Policy**: If the script fails to run, ensure you are using `-ExecutionPolicy Bypass` in the hMailServer command line configuration.
*   **Permissions**: Verify that the account running hMailServer (usually `Local System` or a dedicated service account) has access to run `MpCmdRun.exe` or `avp.com`.
*   **Engine Path**: If your AV is installed in a non-standard location, update the `$MpCmdRunPath` or `$KavCmdPath` variable at the top of the respective script.

## Author

**Mikhail Deynekin**
*   GitHub: [@paulmann](https://github.com/paulmann)
*   Website: [deynekin.com](https://deynekin.com/)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
