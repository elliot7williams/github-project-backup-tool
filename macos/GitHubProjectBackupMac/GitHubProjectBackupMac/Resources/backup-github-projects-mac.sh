#!/bin/zsh
set -euo pipefail

OWNER=""
ROOTS=()
STAGING_ROOT="$HOME/GitHubProjectBackupStaging"
REPORT_PATH="$HOME/Desktop/github-project-backup-report.csv"
UPLOAD=false
INCLUDE_THIRD_PARTY=false
ALLOW_SUSPICIOUS=false

usage() {
  cat <<'USAGE'
Usage:
  backup-github-projects-mac.sh --owner USER [--roots PATH[,PATH...]] [--upload]

Options:
  --owner USER                 GitHub owner/user/org.
  --roots PATH[,PATH...]       Comma-separated roots to scan. Defaults to mounted Volumes.
  --staging-root PATH          Folder for clean staged copies.
  --report PATH                CSV report path.
  --upload                     Create private GitHub repos.
  --include-third-party        Include bundled examples/download-looking folders.
  --allow-suspicious           Do not block upload on suspicious tracked files.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --owner) OWNER="${2:-}"; shift 2 ;;
    --roots) IFS=',' read -rA ROOTS <<< "${2:-}"; shift 2 ;;
    --staging-root) STAGING_ROOT="${2:-}"; shift 2 ;;
    --report) REPORT_PATH="${2:-}"; shift 2 ;;
    --upload) UPLOAD=true; shift ;;
    --include-third-party) INCLUDE_THIRD_PARTY=true; shift ;;
    --allow-suspicious) ALLOW_SUSPICIOUS=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

if [[ -z "$OWNER" ]]; then
  echo "Missing --owner" >&2
  exit 2
fi

if [[ ${#ROOTS[@]} -eq 0 ]]; then
  ROOTS=(/Volumes/*)
fi

command -v git >/dev/null || { echo "git is required" >&2; exit 1; }
if [[ "$UPLOAD" == true ]]; then
  command -v gh >/dev/null || { echo "GitHub CLI gh is required for upload" >&2; exit 1; }
fi

mkdir -p "$STAGING_ROOT"
mkdir -p "$(dirname "$REPORT_PATH")"

slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/&/ and /g; s/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

is_excluded_path() {
  local p="$1"
  local common='/(.git|node_modules|build|dist|DerivedData|.next|.gradle|.build|.xcodebuild|.xcode-derived|Pods|Carthage|xcuserdata|bin|obj|.idea|.vs|.swiftpm|.dart_tool|.Spotlight-V100|.fseventsd|System Volume Information|CodexUploadStaging|PackageRoot|VFS|AppPackages|windows-amd64|linux-aarch64|linux-amd64|linux-arm|macos-aarch64|macos-x86_64|application.windows64)(/|$)'
  [[ "$p" =~ $common ]] && return 0
  if [[ "$INCLUDE_THIRD_PARTY" != true ]]; then
    [[ "$p" == *"/Processing/modes/"* || "$p" == *"/SteamLibrary/"* || "$p" == *"/Epic Games/"* || "$p" == *"/GOG Galaxy/"* || "$p" == *"/tool.next2d.app"* ]] && return 0
  fi
  [[ "$p" == *.xcarchive/* || "$p" == *.app/* ]] && return 0
  return 1
}

project_root_for_marker() {
  local marker="$1"
  local dir="${marker:h}"
  if [[ "$marker" == *.xcodeproj/project.pbxproj ]]; then
    echo "${marker:h:h}"
  elif [[ "$marker" == *.pde || "$marker" == *.ino ]]; then
    echo "$dir"
  elif [[ "${marker:t}" == "build.gradle" || "${marker:t}" == "build.gradle.kts" || "${marker:t}" == "settings.gradle" || "${marker:t}" == "settings.gradle.kts" ]] && [[ "${dir:t}" == "app" ]]; then
    echo "${dir:h}"
  else
    echo "$dir"
  fi
}

find_markers() {
  local root="$1"
  if command -v rg >/dev/null; then
    rg --files "$root" \
      -g 'package.json' -g 'vite.config.*' -g 'next.config.*' -g 'Cargo.toml' \
      -g 'pyproject.toml' -g 'requirements.txt' -g 'go.mod' -g 'pubspec.yaml' \
      -g 'pom.xml' -g 'build.gradle*' -g 'settings.gradle*' -g 'Package.swift' \
      -g '*.xcodeproj/project.pbxproj' -g '*.csproj' -g '*.sln' -g '*.pde' \
      -g '*.ino' -g 'AppxManifest.xml' -g 'sketch.properties' \
      -g '!**/.git/**' -g '!**/node_modules/**' -g '!**/build/**' -g '!**/dist/**' \
      -g '!**/DerivedData/**' -g '!**/.gradle/**' -g '!**/.build/**' 2>/dev/null || true
  else
    find "$root" -type f \( \
      -name package.json -o -name Cargo.toml -o -name pyproject.toml -o -name requirements.txt \
      -o -name go.mod -o -name pubspec.yaml -o -name pom.xml -o -name 'build.gradle*' \
      -o -name 'settings.gradle*' -o -name Package.swift -o -name project.pbxproj \
      -o -name '*.csproj' -o -name '*.sln' -o -name '*.pde' -o -name '*.ino' \
      -o -name AppxManifest.xml -o -name sketch.properties \) 2>/dev/null || true
  fi
}

repo_exists() {
  local repo="$1"
  gh repo view "$OWNER/$repo" >/dev/null 2>&1
}

stage_project() {
  local source="$1"
  local repo="$2"
  local stage="$STAGING_ROOT/$repo"
  rm -rf "$stage"
  mkdir -p "$stage"

  rsync -a "$source"/ "$stage"/ \
    --exclude '.git/' --exclude 'node_modules/' --exclude 'build/' --exclude 'dist/' \
    --exclude 'DerivedData/' --exclude '.gradle/' --exclude '.build/' --exclude '.xcodebuild/' \
    --exclude '.xcode-derived/' --exclude 'Pods/' --exclude 'Carthage/' --exclude 'xcuserdata/' \
    --exclude 'bin/' --exclude 'obj/' --exclude '.idea/' --exclude '.vs/' --exclude '.swiftpm/' \
    --exclude 'PackageRoot/' --exclude 'VFS/' --exclude 'AppPackages/' \
    --exclude 'windows-amd64/' --exclude 'application.windows64/' \
    --exclude '.DS_Store' --exclude '._*' --exclude '*.zip' --exclude '*.dmg' \
    --exclude '*.ipa' --exclude '*.apk' --exclude '*.aab' --exclude '*.msix' \
    --exclude '*.exe' --exclude '*.dll' --exclude '*.pdb' --exclude '*.mov' \
    --exclude '*.mp4' --exclude '*.mp3' --exclude '*.jks' --exclude '*.keystore' \
    --exclude '*.idsig' --exclude 'local.properties' --exclude 'google-services.json' \
    --exclude 'GoogleService-Info.plist' --exclude '.env'

  [[ -f "$stage/README.md" ]] || {
    print "# ${source:t}\n\nRecovered project source from an external-drive backup sweep.\n\nOriginal path: $source" > "$stage/README.md"
  }

  [[ -f "$stage/.gitignore" ]] || {
    cat > "$stage/.gitignore" <<'GITIGNORE'
.DS_Store
._*
.build/
.xcode-derived/
.xcodebuild/
DerivedData/
.gradle/
node_modules/
build/
dist/
bin/
obj/
PackageRoot/
VFS/
local.properties
google-services.json
GoogleService-Info.plist
.env
*.jks
*.keystore
*.idsig
*.zip
*.dmg
*.ipa
*.apk
*.aab
*.msix
*.exe
*.dll
*.pdb
*.mov
*.mp4
*.mp3
GITIGNORE
  }

  echo "$stage"
}

audit_repo() {
  local stage="$1"
  git -C "$stage" ls-files | grep -E '(^|/)(.gradle-build|.build|.xcode-derived|.xcodebuild|DerivedData|windows-amd64|application.windows64|node_modules|bin|obj|Build|PackageRoot|VFS|release)/|local.properties$|\.jks$|\.keystore$|\.idsig$|GoogleService-Info.plist$|google-services.json$|(^|/)\.env$|\.(zip|dmg|ipa|apk|aab|msix|exe|dll|pdb|mov|mp4|mp3|tar.gz|7z|rar)$' || true
}

typeset -A seen
print "Name,Repo,Path,Files,SizeMB,Status,Url,Notes" > "$REPORT_PATH"

for root in "${ROOTS[@]}"; do
  [[ -e "$root" ]] || continue
  echo "Scanning $root ..."
  while IFS= read -r marker; do
    [[ -n "$marker" ]] || continue
    is_excluded_path "$marker" && continue
    project_root="$(project_root_for_marker "$marker")"
    is_excluded_path "$project_root" && continue
    [[ -n "${seen[$project_root]:-}" ]] && continue
    seen[$project_root]=1

    name="${project_root:t}"
    if [[ "$name" == "source" || "$name" == "src" || "$name" == "app" ]]; then
      name="${project_root:h:t}-$name"
    fi
    repo="$(slugify "$name")"
    files="$(find "$project_root" -type f 2>/dev/null | wc -l | tr -d ' ')"
    size_mb="$(du -sm "$project_root" 2>/dev/null | awk '{print $1}')"
    status="candidate"
    url=""
    notes=""

    if [[ "$UPLOAD" == true ]]; then
      if repo_exists "$repo"; then
        status="skipped-existing-repo"
        url="https://github.com/$OWNER/$repo"
      else
        stage="$(stage_project "$project_root" "$repo")"
        git -C "$stage" init -b main >/dev/null
        git -C "$stage" add . >/dev/null
        bad="$(audit_repo "$stage")"
        if [[ -n "$bad" && "$ALLOW_SUSPICIOUS" != true ]]; then
          status="blocked-suspicious-files"
          notes="${bad//$'\n'/; }"
        elif [[ -z "$(git -C "$stage" status --short)" ]]; then
          status="skipped-empty-after-filter"
        else
          git -C "$stage" commit -m "Initial private import from macOS backup tool" >/dev/null
          gh repo create "$OWNER/$repo" --private --source "$stage" --remote origin --push >/dev/null
          status="created"
          url="https://github.com/$OWNER/$repo"
        fi
      fi
    fi

    escaped_path="${project_root//\"/\"\"}"
    escaped_notes="${notes//\"/\"\"}"
    print "\"$name\",\"$repo\",\"$escaped_path\",\"$files\",\"$size_mb\",\"$status\",\"$url\",\"$escaped_notes\"" >> "$REPORT_PATH"
    echo "$status $repo $project_root"
  done < <(find_markers "$root")
done

echo "Report: $REPORT_PATH"
