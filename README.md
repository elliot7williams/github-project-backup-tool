# GitHub Project Backup

Scan external drives for source-code projects and back them up to private GitHub repositories.

This is a Windows-first backup utility for messy project/archive drives. It can run as a small GUI app or as a PowerShell script.

## What It Does

- Finds project roots from markers like `package.json`, `Package.swift`, `.xcodeproj`, `.csproj`, `.sln`, `.pde`, `.ino`, `pubspec.yaml`, and Gradle files.
- Skips common noise such as build folders, packaged app exports, game libraries, installed tool examples, `node_modules`, `DerivedData`, `bin`, `obj`, and staging folders.
- Stages clean copies before upload, leaving original external-drive files untouched.
- Creates private GitHub repositories with GitHub CLI.
- Blocks upload if suspicious files are still tracked, such as signing keys, Firebase mobile configs, local properties, installers, archives, build outputs, package outputs, or large media/runtime files.
- Writes a CSV report for review.

## Quick Start

1. Install Git and GitHub CLI.
2. Authenticate GitHub CLI:

```powershell
gh auth login
gh auth status
```

3. Run a scan-only pass first:

```powershell
.\Backup-GitHubProjects.ps1 -Roots I:\,J:\ -Owner YOUR_GITHUB_USERNAME -ReportPath .\scan-report.csv
```

4. Review the CSV report.
5. Upload private repos:

```powershell
.\Backup-GitHubProjects.ps1 -Roots I:\,J:\ -Owner YOUR_GITHUB_USERNAME -Upload -ReportPath .\upload-report.csv
```

## Requirements

- Windows PowerShell or PowerShell 7.
- Git.
- GitHub CLI (`gh`) authenticated to your GitHub account.
- .NET 8 Desktop Runtime for the GUI EXE. You do not need it if you run the `.ps1` script directly.
- `rg` / ripgrep is recommended for faster scans. The script has a slower fallback.

## GUI EXE

The Windows app bundle lives in `dist/`:

```text
dist/GitHubProjectBackup.exe
dist/Backup-GitHubProjects.ps1
dist/github-project-backup-icon.ico
```

Run `GitHubProjectBackup.exe`, choose roots such as `I:\,J:\`, then run a scan-only pass first. Check `Upload private repos` when you want the tool to create private GitHub repositories.

Keep `Backup-GitHubProjects.ps1` next to the EXE. The GUI launches that script so the scanning and upload behavior stays shared between the command-line and app versions.

## Scan Only

This is the safest first pass. It does not upload anything.

```powershell
.\Backup-GitHubProjects.ps1 -Roots I:\,J:\ -Owner YOUR_GITHUB_USERNAME -ReportPath .\scan-report.csv
```

If you omit `-Roots`, the tool scans ready removable/fixed drives except `C:\` and `D:\`.

```powershell
.\Backup-GitHubProjects.ps1 -Owner YOUR_GITHUB_USERNAME
```

## Upload

Creates private repos for candidates whose repo slug does not already exist.

```powershell
.\Backup-GitHubProjects.ps1 -Roots I:\,J:\ -Owner YOUR_GITHUB_USERNAME -Upload -ReportPath .\upload-report.csv
```

## Suspicious File Blocking

By default, upload is blocked if the staged Git index contains files matching risky patterns:

- `local.properties`
- `.env`
- `google-services.json`
- `GoogleService-Info.plist`
- `*.jks`, `*.keystore`, `*.idsig`
- installers, archives, packages, large media, DLLs, PDBs
- build/cache/package folders such as `bin`, `obj`, `Build`, `PackageRoot`, `VFS`, `DerivedData`, `node_modules`

You can override this, but use it sparingly:

```powershell
.\Backup-GitHubProjects.ps1 -Roots I:\ -Owner YOUR_GITHUB_USERNAME -Upload -AllowSuspiciousFiles
```

## Include Third-Party Downloads

The tool skips paths that look like bundled examples, game libraries, or third-party downloads. To include them:

```powershell
.\Backup-GitHubProjects.ps1 -Roots J:\ -Owner YOUR_GITHUB_USERNAME -IncludeThirdParty
```

## Output

The CSV report includes:

- `Name`
- `Repo`
- `Path`
- `UploadedBySlug`
- `Files`
- `SizeMB`
- `Status`
- `Url`
- `Notes`

Common statuses:

- `candidate`
- `created`
- `skipped-existing-repo`
- `skipped-empty-after-filter`
- `blocked-suspicious-files`

## Notes

- The tool stages clean copies first. It does not modify original files on the external drives.
- Uploads are private by default.
- Always run scan-only first and review the report before uploading.
- Repo names are generated from folder names. If two folders would produce the same slug, upload the first and rename the second manually or move it into a uniquely named folder before rerunning.

## License

No license has been added yet. If you plan to accept contributions or want others to reuse the code, add an open-source license such as MIT.
