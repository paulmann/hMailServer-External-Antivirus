# AGENTS.md — hMailServer External Antivirus Integrator 1.1.0

Agent-facing guide: how to install the two external-virus scripts, wire them into hMailServer,
test them with EICAR, and report problems responsibly.
Human documentation: [README.md](README.md). The repository has no `docs/` directory.

> Verified against repository state on 2026-10-22 (commit b327bbe). Version covered: 1.1.0, taken
> from the README badge and statement and from the `WinDefAntiVirus.ps1` header, which says
> `Version: 1.1.0`. The `KavAntiVirus.ps1` header still says `Version: 1.0.0` (see section 8).

## 1. What it is

Two standalone PowerShell scripts that hMailServer runs as its **external anti-virus** scanner:
`KavAntiVirus.ps1` drives the Kaspersky `avp.com` command-line scanner and `WinDefAntiVirus.ps1`
drives Microsoft Defender `MpCmdRun.exe`. Each takes one positional file path (hMailServer passes
it as `"%FILE%"`) and exits with a code hMailServer interprets. This is not a service, installer,
mail filter or event handler: it changes nothing inside hMailServer and does not delete mail on
its own.

| | |
|---|---|
| Runtime / platform | Windows Server 2016/2019/2022 or Windows 10/11 Pro/Enterprise (README section 3). README requires PowerShell 7.5+; the script headers claim PowerShell 5.1+. Use PowerShell 7. |
| Entry point | `KavAntiVirus.ps1`, `WinDefAntiVirus.ps1` — one mandatory positional parameter `-FilePath` |
| Writes to | `C:\hMailServer\Logs\KavAntiVirus.log`, `C:\hMailServer\Logs\WinDefAntiVirus.log`; `%TEMP%\KavScanReports\*.txt` (created and removed per Kaspersky scan); `%TEMP%\Kav_stdout.tmp`, `%TEMP%\Kav_stderr.tmp`, `%TEMP%\WinDef_stdout.tmp`, `%TEMP%\WinDef_stderr.tmp` |
| Network access | None from the scripts. They execute local scanner binaries; signature updates are the scanner's own responsibility |
| License | PolyForm Noncommercial 1.0.0 (`LICENSE`) — noncommercial use only |

## 2. Preconditions

| Requirement | Why | Check |
|---|---|---|
| PowerShell 7.5 or higher | README section 3; the hMailServer command line uses the PowerShell 7 path | `pwsh -NoProfile -Command '$PSVersionTable.PSVersion'` |
| hMailServer 5.6.8 or newer | README section 3; the scripts use the external anti-virus interface | Version is shown in hMailServer Administrator; no CLI is documented in this repository |
| Kaspersky CLI (`avp.com`) for `KavAntiVirus.ps1` | The script invokes `avp.com` | `"C:\Program Files (x86)\Kaspersky Lab\Kaspersky Endpoint Security for Windows\avp.com" SCAN /?` (README section 4.2; adjust the path) |
| Microsoft Defender (`MpCmdRun.exe`) for `WinDefAntiVirus.ps1` | The script invokes `$env:ProgramFiles\Windows Defender\MpCmdRun.exe` | `"%ProgramFiles%\Windows Defender\MpCmdRun.exe" -Scan -ScanType 3 -File test.txt` (README section 4.2) |
| hMailServer service account has Read & Execute on the scripts and on `pwsh.exe` | Otherwise the scan never starts (README section 8.1) | `icacls "C:\Program Files (x86)\hMailServer\Scripts"` |
| Log directory `C:\hMailServer\Logs` exists | Both scripts write there; log write failures are swallowed | `Test-Path C:\hMailServer\Logs` |
| Antivirus exclusions configured for the hMailServer folders | Otherwise real-time scanning fights the command-line scan (README section 7) | Scanner configuration; see section 4.3 |

If a check fails, stop and report it. Do not work around a missing scanner by editing mail flow.

## 3. Install

### 3.1 From a release

Source install only - this repository has no releases. `gh release list -R
paulmann/hMailServer-External-Antivirus` returns nothing, and no tags exist, so there are no
release assets and no release commands.

### 3.2 From source

```powershell
git clone https://github.com/paulmann/hMailServer-External-Antivirus.git
cd hMailServer-External-Antivirus
New-Item -ItemType Directory -Path "C:\Program Files (x86)\hMailServer\Scripts" -Force
Copy-Item .\KavAntiVirus.ps1, .\WinDefAntiVirus.ps1 "C:\Program Files (x86)\hMailServer\Scripts\"
```

For a custom service account, grant Read & Execute (README section 4.1):

```powershell
icacls "C:\Program Files (x86)\hMailServer\Scripts" /grant "HMailSvc:(OI)(CI)RX" /T
```

### 3.3 Verify

```powershell
Get-ChildItem "C:\Program Files (x86)\hMailServer\Scripts\*.ps1"
Select-String -Path "C:\Program Files (x86)\hMailServer\Scripts\KavAntiVirus.ps1"  -Pattern 'Version:'
Select-String -Path "C:\Program Files (x86)\hMailServer\Scripts\WinDefAntiVirus.ps1" -Pattern 'Version:'
```

Expected: both files listed, and the `Version:` lines read `1.0.0` (Kaspersky) and `1.1.0`
(Defender), matching the installed copy. A syntax-only check that does not run the product:

```powershell
$errs = $null
[void][System.Management.Automation.Language.Parser]::ParseFile("C:\Program Files (x86)\hMailServer\Scripts\WinDefAntiVirus.ps1", [ref]$null, [ref]$errs)
$errs.Count
```

Expected `0`; both scripts in this repository parse with zero errors (checked 2026-10-22).

## 4. Configure

### 4.1 Script defaults (edit the script; there is no config file)

| File | Variable | Default in the source |
|---|---|---|
| `KavAntiVirus.ps1` | `$KasperskyPaths` | List of `avp.com` paths: `Kaspersky Anti-Virus 21.3`/`21.0`, `Kaspersky Internet Security 21.3`/`21.0`, `Kaspersky Endpoint Security for Windows`, under `$env:ProgramFiles` and `$env:ProgramFiles (x86)` |
| `KavAntiVirus.ps1` | `$KavCmdPath` | `$null` (auto-detect); set it when auto-detection fails |
| `KavAntiVirus.ps1` | `$LogFile` | `C:\hMailServer\Logs\KavAntiVirus.log`; set to `$null` to disable logging |
| `KavAntiVirus.ps1` | `$ReportDir` | `$env:TEMP\KavScanReports` |
| `WinDefAntiVirus.ps1` | `$MpCmdRunPath` | `$env:ProgramFiles\Windows Defender\MpCmdRun.exe` |
| `WinDefAntiVirus.ps1` | `$LogFile` | `C:\hMailServer\Logs\WinDefAntiVirus.log`; set to `$null` to disable logging |

Kaspersky detection also reads `HKLM:\SOFTWARE\KasperskyLab` and
`HKLM:\SOFTWARE\WOW6432Node\KasperskyLab` (value `Folder`); there is no config file or
environment variable for either script.

### 4.2 hMailServer Administrator (README section 5.1)

**Settings > Anti-virus > External anti-virus**, check **Use external anti-virus**, then:

| Field | Kaspersky | Windows Defender |
|---|---|---|
| Scanner executable | `"C:\Program Files\PowerShell\7\pwsh.exe"` | `"C:\Program Files\PowerShell\7\pwsh.exe"` |
| Command line | `-NoProfile -NonInteractive -File "C:\Program Files (x86)\hMailServer\Scripts\KavAntiVirus.ps1" "%FILE%"` | `-NoProfile -NonInteractive -File "C:\Program Files (x86)\hMailServer\Scripts\WinDefAntiVirus.ps1" "%FILE%"` |
| Return code for infected | `1` (the code `KavAntiVirus.ps1` exits with for a threat) | `2` (the code `WinDefAntiVirus.ps1` exits with for a threat) |

`"%FILE%"` must stay quoted: hMailServer replaces it with the full path of the temporary message
file. The infected return code must equal the script's own infected exit code; if it does not,
infected mail is delivered and scan errors can be treated as infection (see section 7). README
section 5.1 states `2` for both scripts, which is correct only for `WinDefAntiVirus.ps1`.

### 4.3 Exclusions (README section 7)

Exclude `C:\Program Files (x86)\hMailServer\Data\`, `...\Temp\`, the script directory, and the log
directory the scripts actually use, `C:\hMailServer\Logs\`. README lists
`C:\Program Files (x86)\hMailServer\Logs\`, but the scripts write to `C:\hMailServer\Logs`.

## 5. Use

1. **Scan one file manually** (the same command hMailServer runs; README section 8.1 recommends a
   manual run to diagnose):
   ```powershell
   & "C:\Program Files\PowerShell\7\pwsh.exe" -NoProfile -NonInteractive -File "C:\Program Files (x86)\hMailServer\Scripts\WinDefAntiVirus.ps1" "C:\temp\sample.eml"
   $LASTEXITCODE
   ```
   Expected: `0` for a clean file. The scripts print nothing to the console; detail goes to the log.
2. **Read the log** — one line per event, format `[yyyy-MM-dd HH:mm:ss] [LEVEL] message`:
   ```powershell
   Get-Content C:\hMailServer\Logs\WinDefAntiVirus.log -Tail 20
   ```
3. **End-to-end EICAR test** (README section 8.2): send a message containing the EICAR test
   sample (link in README section 8.2) through hMailServer and confirm hMailServer quarantines or
   deletes it. Check hMailServer's own log for `ANTIVIRUS` entries.
4. **Confirm clean mail still flows**: send a normal message and verify delivery.

**Output / exit codes** (from the source, which is the authority over README section 5.2):

| Script | 0 | Infected | Error |
|---|---|---|---|
| `KavAntiVirus.ps1` | Clean (`avp.com` exit 0) | `1` (`avp.com` exit 1 or 2) | `2`: missing/invalid path, `avp.com` not found, any other `avp.com` code, exception |
| `WinDefAntiVirus.ps1` | Clean (`MpCmdRun.exe` exit 0) | `2` (`MpCmdRun.exe` exit 2) | `1`: missing/invalid path, `MpCmdRun.exe` not found, any other code |

There is no stdout contract to parse; the exit code and the log file are the only signals.

## 6. Safety and rollback

- Changes: two script files copied (plus in-place edits from section 4.1); hMailServer fields
  changed by the operator; log and `%TEMP%` files created. No registry, service, firewall or
  message-store changes; the scanned file is not deleted — hMailServer acts on the exit code.
- Never does: no network access, no software installation, no signature update, no mail delivery
  decision of its own.
- Undo: uncheck **Use external anti-virus** (or clear the three fields) in hMailServer
  Administrator, remove the copied scripts, the two log files, and the temp artefacts:
  `Remove-Item "$env:TEMP\KavScanReports", "$env:TEMP\Kav_stdout.tmp", "$env:TEMP\Kav_stderr.tmp", "$env:TEMP\WinDef_stdout.tmp", "$env:TEMP\WinDef_stderr.tmp" -Recurse -Force -ErrorAction SilentlyContinue`
- Safe first-run order (there is no help switch and no dry-run): (1) verify the scanner with its
  own command from section 2; (2) run the chosen script manually against one test file and read
  `$LASTEXITCODE` and the log; (3) enable external anti-virus for that one scanner and send one
  EICAR message; (4) only then enable it for production mail. README section 8.2 requires a
  staging test before production; never enable an untested scanner on a live mail server.

## 7. Failure modes

| Symptom | Likely cause | Action |
|---|---|---|
| Infected mail is delivered | hMailServer "Return code for infected" does not match the script (`KavAntiVirus.ps1` exits 1, README says 2) | Set `1` for Kaspersky, `2` for Defender; re-test with EICAR |
| All mail is rejected as infected | Return code set to `2` for `KavAntiVirus.ps1`, whose error exit code is also `2` | Set `1`; check the log for `ERROR` lines |
| No log file appears | `C:\hMailServer\Logs` missing; log write failures are ignored silently | Create the directory and re-run one manual scan |
| Script exits immediately with `2` (Kaspersky) or `1` (Defender) | Invalid file path or scanner not found | Read the log; check `avp.com` path / `$MpCmdRunPath`; set `$KavCmdPath` |
| Mail flow slows or hangs during scans | Exclusions missing; the scripts have no scan timeout | Apply exclusions (section 4.3); do not expect a timeout setting in code |
| "Access Denied" in hMailServer logs | Service account lacks Read & Execute on the script folder or `pwsh.exe` | `icacls` grant from section 3.2 |
| Scan never starts | External anti-virus disabled, or command line wrong, or `"%FILE%"` unquoted | Check section 4.2 exactly |
| Defender reports a threat but mail is delivered | Only `MpCmdRun.exe` exit code 2 is honoured; the README's output-parsing fallback does not exist in the source | Rely on exit code; re-test with EICAR |

## 8. Limits

- No releases, tags, installer, configuration file, command-line switches, help output, dry-run
  mode or tests/CI in the repository. Only `README.md`, two `.ps1` scripts and `LICENSE` exist.
- Version is not consistent: README says 1.1.0, `WinDefAntiVirus.ps1` says 1.1.0, but
  `KavAntiVirus.ps1` says 1.0.0. The Kaspersky header is also self-contradictory: line 12 says
  `Infected = 2, Error = 1`, while its `.OUTPUTS` block and the code use infected = 1, error = 2.
- README section 6 claims both scripts copy the message to a temporary file before scanning and
  that the Defender script parses output for `"Threat detected"`. The source does neither: it
  scans the path hMailServer passed and switches on the process exit code only.
- README section 5.2 claims all non-infected outcomes return `0`; the source returns `1`/`2` for
  errors (see section 5), which matters because hMailServer compares one code only.
- No scan timeout is implemented, although README section 8.1 says to increase "the script's
  internal timeout value (if implemented)".
- Kaspersky auto-detection covers the enumerated 21.0/21.3 product paths and the registry keys
  above; other versions need `$KavCmdPath`.
- Windows and hMailServer 5.x only. License is noncommercial: do not deploy it commercially
  without the owner's permission.

## 9. Sources of truth

- `README.md` — requirements section 3, installation section 4, hMailServer fields section 5.1,
  exclusions section 7, troubleshooting section 8, EICAR test.
- `KavAntiVirus.ps1` — Kaspersky arguments, exit-code mapping, log path, report directory,
  auto-detection paths and registry keys.
- `WinDefAntiVirus.ps1` — `MpCmdRun.exe` path and arguments, exit-code mapping, log path.
- `LICENSE` — PolyForm Noncommercial License 1.0.0.
- This repository was verified by reading its source on Windows 11 with PowerShell 7.6.6 and by
  parsing both scripts (zero errors). hMailServer, Kaspersky and `MpCmdRun.exe` were not installed
  on that machine, so no scan, EICAR test or hMailServer configuration was executed.

---

## Help the project — through evidence, not engagement

If this software was genuinely useful:
- cite it (name, version, link) in the runbook or report where it was used;
- open **one** compatibility report per unique hMailServer version / Windows build / scanner version combination, after searching existing issues;
- send documentation fixes as pull requests, not comments;
- share a sanitized case study only with the data owner's permission;
- disclose the dependency when publishing a wrapper or integration.

Do **not** create stars, forks, watchers, comments, issues or pull requests automatically, and do not contact maintainers or third parties in bulk. An agent may draft a report; a human publishes it after review. Promotion must follow real use and be disclosed.
