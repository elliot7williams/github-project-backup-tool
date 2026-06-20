<# 
.SYNOPSIS
  Scan drives for source-code projects and optionally back them up to private GitHub repositories.

.EXAMPLE
  .\Backup-GitHubProjects.ps1 -Roots I:\,J:\ -Owner elliot7williams

.EXAMPLE
  .\Backup-GitHubProjects.ps1 -Roots I:\,J:\ -Owner elliot7williams -Upload
#>

[CmdletBinding()]
param(
  [string[]]$Roots,
  [string]$Owner = "elliot7williams",
  [string]$StagingRoot = "H:\CodexUploadStaging\auto-project-backups",
  [switch]$Upload,
  [switch]$IncludeThirdParty,
  [switch]$AllowSuspiciousFiles,
  [string]$ReportPath = ".\project-backup-report.csv"
)

$ErrorActionPreference = "Stop"

$ProjectMarkers = @(
  "package.json", "vite.config.*", "next.config.*", "Cargo.toml", "pyproject.toml",
  "requirements.txt", "go.mod", "pubspec.yaml", "pom.xml", "build.gradle*",
  "settings.gradle*", "Package.swift", "*.xcodeproj/project.pbxproj", "*.csproj",
  "*.sln", "*.pde", "*.ino", "AppxManifest.xml", "sketch.properties"
)

$ExcludeDirs = @(
  ".git", "node_modules", "build", "dist", "DerivedData", ".next", ".gradle",
  ".gradle-build", ".build", ".xcodebuild", ".xcode-derived", "Pods", "Carthage",
  "xcuserdata", "bin", "obj", ".idea", ".vs", ".swiftpm", ".dart_tool",
  ".Spotlight-V100", ".fseventsd", "System Volume Information", "CodexUploadStaging",
  "PackageRoot", "VFS", "AppPackages", "UniversalMsixPackagerDist",
  "UniversalMsixPackagerMsix", "windows-amd64", "linux-aarch64", "linux-amd64",
  "linux-arm", "macos-aarch64", "macos-x86_64", "application.windows64"
)

$ExcludeFiles = @(
  ".DS_Store", "Thumbs.db", "*.user", "*.suo", "*.zip", "*.dmg", "*.ipa", "*.apk",
  "*.aab", "*.msix", "*.exe", "*.dll", "*.pdb", "*.mov", "*.mp4", "*.mp3",
  "*.tar.gz", "*.7z", "*.rar", "*.jks", "*.keystore", "*.idsig",
  "local.properties", "google-services.json", "GoogleService-Info.plist", ".env"
)

$ThirdPartyHints = @(
  "Processing\modes", "Processing\java", "Processing\lib", "SteamLibrary",
  "Epic Games", "GOG Galaxy", "XboxGames", "Program Files", "tool.next2d.app",
  "node_modules"
)

$SuspiciousPattern = '(^|/)(\.gradle-build|\.build|\.xcode-derived|\.xcodebuild|DerivedData|windows-amd64|linux-(aarch64|amd64|arm)|macos-(aarch64|x86_64)|application\.windows64|node_modules|bin|obj|Build|PackageRoot|VFS|release)/|local\.properties$|\.jks$|\.keystore$|\.idsig$|GoogleService-Info\.plist$|google-services\.json$|(^|/)\.env$|\.(zip|dmg|ipa|apk|aab|msix|exe|dll|pdb|mov|mp4|mp3|tar\.gz|7z|rar)$'

function Test-Command {
  param([string]$Name)
  return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Convert-ToSlug {
  param([string]$Name)
  $slug = $Name.ToLowerInvariant()
  $slug = $slug -replace "&", " and "
  $slug = $slug -replace "[^a-z0-9]+", "-"
  $slug = $slug.Trim("-")
  if (-not $slug) { return "project" }
  return $slug
}

function Test-ExcludedPath {
  param([string]$Path)
  foreach ($dir in $ExcludeDirs) {
    if ($Path -match ("(^|[\\/])" + [regex]::Escape($dir) + "([\\/]|$)")) { return $true }
  }
  if (-not $IncludeThirdParty) {
    foreach ($hint in $ThirdPartyHints) {
      if ($Path -like "*$hint*") { return $true }
    }
  }
  if ($Path -match '\.(xcarchive|app)([\\/]|$)') { return $true }
  return $false
}

function Get-DefaultRoots {
  [System.IO.DriveInfo]::GetDrives() |
    Where-Object { $_.IsReady -and $_.DriveType -in @("Removable", "Fixed") -and $_.Name -notin @("C:\", "D:\") } |
    ForEach-Object { $_.Name }
}

function Get-ProjectRootFromMarker {
  param([string]$MarkerPath)
  $item = Get-Item -LiteralPath $MarkerPath -ErrorAction SilentlyContinue
  if (-not $item) { return $null }
  if ($MarkerPath -match '\.xcodeproj[\\/]project\.pbxproj$') {
    return Split-Path -Parent (Split-Path -Parent $MarkerPath)
  }
  if ($item.Name -match '\.(pde|ino)$') {
    return $item.Directory.FullName
  }
  if ($item.Name -in @("build.gradle", "build.gradle.kts", "settings.gradle", "settings.gradle.kts") -and $item.Directory.Name -eq "app") {
    return $item.Directory.Parent.FullName
  }
  return $item.Directory.FullName
}

function Get-GitHubRepoNames {
  param([string]$RepoOwner)
  $names = @{}
  if (-not (Test-Command "gh")) { return $names }
  try {
    gh repo list $RepoOwner --limit 1000 --json name | ConvertFrom-Json | ForEach-Object {
      $names[$_.name.ToLowerInvariant()] = $true
    }
  } catch {
    Write-Warning "Could not list GitHub repos for $RepoOwner. Continuing without duplicate detection."
  }
  return $names
}

function Find-ProjectCandidates {
  param([string[]]$ScanRoots, [hashtable]$ExistingRepos)
  $seen = @{}
  $candidates = New-Object System.Collections.Generic.List[object]

  foreach ($root in $ScanRoots) {
    if (-not (Test-Path -LiteralPath $root)) { continue }
    Write-Host "Scanning $root ..."

    $markers = @()
    if (Test-Command "rg") {
      $args = @("--files")
      foreach ($marker in $ProjectMarkers) { $args += @("-g", $marker) }
      foreach ($dir in $ExcludeDirs) { $args += @("-g", "!**/$dir/**") }
      $args += $root
      $markers = & rg @args 2>$null
    } else {
      $markers = Get-ChildItem -LiteralPath $root -File -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object {
          -not (Test-ExcludedPath $_.FullName) -and
          ($_.Name -in $ProjectMarkers -or $_.Name -match '\.(csproj|sln|pde|ino)$' -or $_.FullName -match '\.xcodeproj[\\/]project\.pbxproj$')
        } |
        ForEach-Object { $_.FullName }
    }

    foreach ($markerPath in $markers) {
      if (-not $markerPath -or (Test-ExcludedPath $markerPath)) { continue }
      $projectRoot = Get-ProjectRootFromMarker $markerPath
      if (-not $projectRoot -or (Test-ExcludedPath $projectRoot)) { continue }

      $key = $projectRoot.ToLowerInvariant()
      if ($seen.ContainsKey($key)) { continue }
      $seen[$key] = $true

      $name = Split-Path -Leaf $projectRoot
      if ($name -in @("source", "src", "app")) {
        $parentName = Split-Path -Leaf (Split-Path -Parent $projectRoot)
        if ($parentName) { $name = "$parentName-$name" }
      }
      $slug = Convert-ToSlug $name
      $files = Get-ChildItem -LiteralPath $projectRoot -File -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object {
          -not (Test-ExcludedPath $_.FullName) -and
          $_.Name -notlike "._*" -and
          $_.Name -ne ".DS_Store" -and
          $_.Name -notlike "Thumbs.db"
        }

      $candidates.Add([pscustomobject]@{
        Name = $name
        Repo = $slug
        Path = $projectRoot
        UploadedBySlug = $ExistingRepos.ContainsKey($slug.ToLowerInvariant())
        Files = $files.Count
        SizeMB = [math]::Round((($files | Measure-Object Length -Sum).Sum / 1MB), 2)
        Status = "candidate"
        Url = ""
        Notes = ""
      })
    }
  }

  return $candidates
}

function Stage-Project {
  param([object]$Candidate)
  $stage = Join-Path $StagingRoot $Candidate.Repo
  if (Test-Path -LiteralPath $stage) {
    Remove-Item -LiteralPath $stage -Recurse -Force
  }
  New-Item -ItemType Directory -Force -Path $stage | Out-Null

  $robocopyArgs = @($Candidate.Path, $stage, "/E", "/XD") + $ExcludeDirs + @("/XF") + $ExcludeFiles + @("/NFL", "/NDL", "/NJH", "/NJS", "/NP", "/R:1", "/W:1")
  & robocopy @robocopyArgs | Out-Null
  if ($LASTEXITCODE -gt 7) {
    throw "robocopy failed for $($Candidate.Path) with exit code $LASTEXITCODE"
  }

  Get-ChildItem -LiteralPath $stage -File -Recurse -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "._*" -or $_.Name -eq ".DS_Store" } |
    Remove-Item -Force

  if (-not (Test-Path -LiteralPath (Join-Path $stage "README.md"))) {
    @(
      "# $($Candidate.Name)"
      ""
      "Recovered project source from an external-drive backup sweep."
      ""
      "Original path: $($Candidate.Path)"
    ) | Set-Content -LiteralPath (Join-Path $stage "README.md") -Encoding UTF8
  }

  if (-not (Test-Path -LiteralPath (Join-Path $stage ".gitignore"))) {
    @(
      ".DS_Store", "._*", ".build/", ".xcode-derived/", ".xcodebuild/", "DerivedData/",
      ".gradle/", ".gradle-build/", ".idea/", ".vs/", ".dotnet-home/", "node_modules/",
      "build/", "dist/", "bin/", "obj/", "release/", "Build/", "PackageRoot/", "VFS/",
      "AppPackages/", "windows-amd64/", "linux-aarch64/", "linux-amd64/", "linux-arm/",
      "macos-aarch64/", "macos-x86_64/", "application.windows64/", "local.properties",
      "**/local.properties", "google-services.json", "GoogleService-Info.plist", ".env",
      "*.user", "*.suo", "*.jks", "*.keystore", "*.idsig", "*.zip", "*.dmg", "*.ipa",
      "*.apk", "*.aab", "*.msix", "*.exe", "*.dll", "*.pdb", "*.mov", "*.mp4", "*.mp3",
      "*.tar.gz", "*.7z", "*.rar"
    ) | Set-Content -LiteralPath (Join-Path $stage ".gitignore") -Encoding UTF8
  }

  return $stage
}

function Publish-Project {
  param([object]$Candidate)

  if ($Candidate.UploadedBySlug) {
    $Candidate.Status = "skipped-existing-repo"
    $Candidate.Url = "https://github.com/$Owner/$($Candidate.Repo)"
    return $Candidate
  }

  gh repo view "$Owner/$($Candidate.Repo)" --json name 1>$null 2>$null
  if ($LASTEXITCODE -eq 0) {
    $Candidate.Status = "skipped-existing-repo"
    $Candidate.Url = "https://github.com/$Owner/$($Candidate.Repo)"
    return $Candidate
  }

  $stage = Stage-Project $Candidate
  git config --global --add safe.directory ($stage.Replace("\", "/")) | Out-Null
  git -C $stage init -b main | Out-Null
  git -C $stage add . | Out-Null

  $bad = git -C $stage ls-files | Select-String -Pattern $SuspiciousPattern
  if ($bad -and -not $AllowSuspiciousFiles) {
    $Candidate.Status = "blocked-suspicious-files"
    $Candidate.Notes = (($bad | Select-Object -First 10) -join "; ")
    return $Candidate
  }

  $status = git -C $stage status --short
  if (-not $status) {
    $Candidate.Status = "skipped-empty-after-filter"
    return $Candidate
  }

  git -C $stage commit -m "Initial private import from project backup tool" | Out-Null
  gh repo create "$Owner/$($Candidate.Repo)" --private --source $stage --remote origin --push | Out-Null

  $Candidate.Status = "created"
  $Candidate.Url = "https://github.com/$Owner/$($Candidate.Repo)"
  return $Candidate
}

if (-not $Roots -or $Roots.Count -eq 0) {
  $Roots = @(Get-DefaultRoots)
}

if (-not (Test-Command "git")) { throw "git is required." }
if ($Upload -and -not (Test-Command "gh")) { throw "GitHub CLI (gh) is required for uploads." }

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $ReportPath) -ErrorAction SilentlyContinue | Out-Null
New-Item -ItemType Directory -Force -Path $StagingRoot | Out-Null

$existing = Get-GitHubRepoNames $Owner
$candidates = Find-ProjectCandidates -ScanRoots $Roots -ExistingRepos $existing

if ($Upload) {
  $results = foreach ($candidate in $candidates) {
    Publish-Project $candidate
  }
} else {
  $results = $candidates
}

$results | Sort-Object Status, Path | Export-Csv -LiteralPath $ReportPath -NoTypeInformation
$results | Sort-Object Status, Path | Format-Table -AutoSize
Write-Host ""
Write-Host "Report: $((Resolve-Path -LiteralPath $ReportPath).Path)"
