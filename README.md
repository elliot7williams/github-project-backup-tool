# GitHub Project Backup Tool

PowerShell tool for scanning external drives for source-code projects and backing them up to private GitHub repositories.

It is designed for the workflow we used here:

- Find project roots from markers like `package.json`, `Package.swift`, `.xcodeproj`, `.csproj`, `.sln`, `.pde`, `.ino`, `pubspec.yaml`, and Gradle files.
- Skip obvious noise such as build folders, packaged app exports, game libraries, installed tool examples, `node_modules`, `DerivedData`, `bin`, `obj`, and staging folders.
- Stage clean copies under `H:\CodexUploadStaging\auto-project-backups` by default.
- Create private GitHub repositories with `gh repo create`.
- Block upload if suspicious files are still tracked, such as signing keys, Firebase mobile configs, local properties, installers, archives, build outputs, package outputs, or large media/runtime files.
- Write a CSV report.

## Requirements

- Windows PowerShell or PowerShell 7
- Git
- GitHub CLI (`gh`) authenticated to your GitHub account
- .NET 8 Desktop Runtime for the GUI EXE, unless you run the `.ps1` script directly
- `rg` / ripgrep is recommended for faster scans, but the script has a slower fallback

Check auth:

```powershell
gh auth status
```

## GUI EXE

The Windows app bundle is in `dist/`:

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
.\Backup-GitHubProjects.ps1 -Roots I:\,J:\ -Owner elliot7williams -ReportPath .\scan-report.csv
```

If you omit `-Roots`, the tool scans ready removable/fixed drives except `C:\` and `D:\`.

```powershell
.\Backup-GitHubProjects.ps1 -Owner elliot7williams
```

## Upload

Creates private repos for candidates whose repo slug does not already exist.

```powershell
.\Backup-GitHubProjects.ps1 -Roots I:\,J:\ -Owner elliot7williams -Upload -ReportPath .\upload-report.csv
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
.\Backup-GitHubProjects.ps1 -Roots I:\ -Owner elliot7williams -Upload -AllowSuspiciousFiles
```

## Include Third-Party Downloads

The tool skips paths that look like bundled examples, game libraries, or third-party downloads. To include them:

```powershell
.\Backup-GitHubProjects.ps1 -Roots J:\ -Owner elliot7williams -IncludeThirdParty
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

The tool stages clean copies first. It does not modify original files on the external drives.

Repo names are generated from folder names. If two folders would produce the same slug, upload the first and rename the second manually or move it into a uniquely named folder before rerunning.
