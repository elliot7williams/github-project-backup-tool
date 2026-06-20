# GitHub Project Backup for macOS

This is a native SwiftUI version of the GitHub Project Backup app. It scans selected folders and external volumes for local project directories, stages clean copies, audits for suspicious secrets, and can create private GitHub repositories with the GitHub CLI.

## Requirements

- macOS 14 or newer
- Xcode 15 or newer
- Git
- GitHub CLI (`gh`) authenticated with `gh auth login`
- `ripgrep` (`rg`) recommended for faster scanning

## Open and Run

1. Open `GitHubProjectBackupMac.xcodeproj` in Xcode.
2. Select the `GitHubProjectBackupMac` scheme.
3. Press Run.
4. Choose scan roots, staging folder, report path, and whether to upload to GitHub.

The app bundles `backup-github-projects-mac.sh` and runs it through `/bin/zsh`, so the same backend can be inspected or run directly from Terminal.

## Terminal Backend

```zsh
./GitHubProjectBackupMac/Resources/backup-github-projects-mac.sh \
  --owner YOUR_GITHUB_USERNAME \
  --roots "$HOME/Documents,/Volumes/ExternalDrive" \
  --staging-root "$HOME/GitHubBackupStaging" \
  --report "$HOME/Desktop/github-project-backup-report.csv" \
  --upload
```

By default, the backend skips common dependency/cache folders and pauses uploads for projects with suspicious files such as `.env`, private keys, or Firebase configs unless `--allow-suspicious` is set.
