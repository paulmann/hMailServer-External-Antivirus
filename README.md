# hMailServer External Antivirus Integration

[![Version](https://img.shields.io/badge/version-1.1.0-blue.svg)](https://github.com/paulmann/hMailServer-External-Antivirus)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![PowerShell](https://img.shields.io/badge/PowerShell-7.x%20%2F%205.1-blue.svg)](https://docs.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%20Server%202022%2B-blue.svg)](https://www.microsoft.com/windows/)
[![hMailServer](https://img.shields.io/badge/hMailServer-5.x-orange.svg)](https://www.hmailserver.com/)

Robust PowerShell-based antivirus integration scripts for **hMailServer**, supporting **Kaspersky Security** and **Windows Defender**. Designed to secure email delivery pipelines through high-performance external scanning without compromising server stability.

---

## 📖 Table of Contents

1. [Architectural Philosophy & Security Imperatives](#1-architectural-philosophy--security-imperatives)
2. [Key Features](#2-key-features)
3. [System Requirements](#3-system-requirements)
4. [Installation Guide](#4-installation-guide)
5. [hMailServer Configuration](#5-hmailserver-configuration)
6. [Antivirus Engine Workflows](#6-antivirus-engine-workflows)
    - [Kaspersky Integration](#kaspersky-integration)
    - [Windows Defender Integration](#windows-defender-integration)
7. [🛡️ Critical: Antivirus Exclusions](#7-critical-antivirus-exclusions)
8. [Troubleshooting & Best Practices](#8-troubleshooting--best-practices)
9. [License](#9-license)

---

## 1. Architectural Philosophy & Security Imperatives

### The Architectural Gap
hMailServer is engineered around principles of minimalism and efficiency. While this ensures a low resource footprint, it inherently excludes built-in antivirus engines. This is a foundational architectural choice to avoid licensing complexities and performance bottlenecks associated with bundling proprietary security software.

### Why External Integration is Critical
Deploying this solution addresses three critical architectural constraints:

1.  **Licensing & Compliance:** Antivirus engines (Kaspersky, Microsoft, etc.) are protected by intellectual property rights. This solution delegates scanning to legally licensed external tools installed on the host OS.
2.  **Performance Isolation:** Modern antivirus scanning involves heuristic analysis and deep content inspection, which are computationally intensive. These scripts execute scans in separate processes, ensuring the mail server remains responsive even during heavy scanning loads.
3.  **Modular Security:** This approach allows administrators to choose best-of-breed security tools without being locked into a specific vendor, aligning with modern microservices architecture principles.

---

## 2. Key Features

*   **Dual-Engine Support:** Pre-configured scripts for **Kaspersky Security** (`KavAntiVirus.ps1`) and **Windows Defender** (`WinDefAntiVirus.ps1`).
*   **Engine Auto-Detection:** Scripts automatically locate antivirus binaries via standard installation paths and registry keys.
*   **Parameterized Workflow:** Seamlessly handles file paths passed directly from hMailServer's external scanner interface.
*   **Fail-Safe Error Handling:** Structured logic to catch timeouts, access denials, and engine failures, preventing mail delivery deadlocks.
*   **Comprehensive Logging:** Detailed execution logs for auditing and rapid troubleshooting.

---

## 3. System Requirements

| Component | Requirement |
| :--- | :--- |
| **Operating System** | Windows Server 2016/2019/2022 or Windows 10/11 |
| **hMailServer** | Version 5.x or newer |
| **PowerShell** | PowerShell Core 7.x (Recommended) or Windows PowerShell 5.1 |
| **Antivirus** | Kaspersky Endpoint Security / Internet Security OR Windows Defender |
| **Permissions** | hMailServer Service Account must have Read/Execute rights on scripts and AV binaries |

---

## 4. Installation Guide

### 4.1 Script Deployment
1.  Clone this repository or download the `.ps1` files.
2.  Create a dedicated directory for security scripts (e.g., `C:\Program Files (x86)\hMailServer\Scripts\`).
3.  Copy `KavAntiVirus.ps1` or `WinDefAntiVirus.ps1` to this folder.

### 4.2 Logging Preparation
1.  Ensure the directory `C:\hMailServer\Logs\` exists.
2.  Grant the hMailServer service account **Write** access to this folder.

---

## 5. hMailServer Configuration

To integrate the script, follow these steps in the hMailServer Administrator:

1.  Navigate to **Settings** > **Anti-virus**.
2.  Select the **External anti-virus** tab.
3.  Enable **Use external anti-virus**.
4.  Configure the settings as follows:

### Scanner Configuration (Example for PowerShell 7)
*   **Scanner executable:** `"C:\Program Files\PowerShell\7\pwsh.exe"`
*   **Command line:** `-NoProfile -NonInteractive -File "C:\Program Files (x86)\hMailServer\Scripts\KavAntiVirus.ps1" "%FILE%"`
*   **Return code for infected:** `2`

> [!IMPORTANT]
> Ensure the path to `pwsh.exe` and the script matches your actual installation directory. Use `-ExecutionPolicy Bypass` if your system policy restricts script execution.

---

## 6. Antivirus Engine Workflows

### Kaspersky Integration
The `KavAntiVirus.ps1` script utilizes the `avp.com` command-line utility.
1.  **Trigger:** hMailServer passes the temporary message file path.
2.  **Scan:** The script invokes `avp.com` with the `SCAN` command.
3.  **Analysis:** Interprets Kaspersky's exit codes (0 = Clean, 1/2 = Infected).
4.  **Feedback:** Returns `2` to hMailServer if a threat is detected.

### Windows Defender Integration
The `WinDefAntiVirus.ps1` script leverages the native `MpCmdRun.exe` utility.
1.  **Trigger:** hMailServer passes the temporary message file path.
2.  **Scan:** Invokes Defender with `-Scan -ScanType 3 -File`.
3.  **Analysis:** Interprets Defender's exit codes (0 = Clean, 2 = Infected).
4.  **Feedback:** Returns `2` to hMailServer if a threat is detected.

---

## 7. 🛡️ Critical: Antivirus Exclusions

To prevent file locking conflicts and performance degradation, you **must** configure your Antivirus to exclude the following directories:

*   `C:\Program Files (x86)\hMailServer\Data\` (Message Storage)
*   `C:\Program Files (x86)\hMailServer\Temp\` (Scanning Buffer)
*   `C:\hMailServer\Logs\` (Log Files)

---

## 8. Troubleshooting & Best Practices

| Problem | Likely Cause | Solution |
| :--- | :--- | :--- |
| **Infected mail delivered** | Incorrect Return Code | Verify "Return code for infected" is set to `2`. |
| **Access Denied** | Permissions | Ensure the service account has execute rights on `pwsh.exe`. |
| **Scanning Hangs** | Timeout | Increase script timeout or optimize AV scan profile. |
| **False Positives** | Heuristics | Adjust AV heuristic sensitivity or add specific exclusions. |

---

## 9. License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---
**Author:** Mikhail Deynekin ([@paulmann](https://github.com/paulmann))  
**Website:** [deynekin.com](https://deynekin.com/)
