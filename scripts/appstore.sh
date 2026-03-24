#!/bin/bash
set -euo pipefail

# StarPath — App Store Connect release script
# Builds, archives, and uploads iOS to App Store Connect.
#
# Usage:
#   ./scripts/appstore.sh v1.12              # full release
#   ./scripts/appstore.sh v1.12 --dry-run    # archive + validate, no upload
#
# One-time setup:
#   Uses the same App Store Connect API key as Cartogram (~/.cartogram-secrets).
#   The key is team-wide — it works for all apps under team 992N457T8D.
#
#   If you don't have it yet:
#   1. Go to App Store Connect → Users & Access → Integrations → App Store Connect API
#   2. Click "+" → Name: "CI" → Role: "App Manager"
#   3. Download the .p8 file to ~/.appstoreconnect/private_keys/
#   4. Create ~/.cartogram-secrets with:
#        ASC_KEY_ID=YOUR_KEY_ID
#        ASC_ISSUER_ID=YOUR_ISSUER_ID
#        ASC_KEY_PATH=~/.appstoreconnect/private_keys/AuthKey_YOUR_KEY_ID.p8

VERSION="${1:?Usage: appstore.sh <version-tag> [--dry-run]}"
MARKETING_VERSION="${VERSION#v}"

# Parse flags
DRY_RUN=false
shift
for arg in "$@"; do
    case "$arg" in
        --dry-run)  DRY_RUN=true ;;
        *) echo "Unknown flag: $arg"; exit 1 ;;
    esac
done

# ── Credentials ──────────────────────────────────────────────────────────────

SECRETS_FILE="$HOME/.cartogram-secrets"
if [[ ! -f "$SECRETS_FILE" ]]; then
    echo "ERROR: Missing $SECRETS_FILE"
    echo ""
    echo "Create it with your App Store Connect API key credentials:"
    echo "  ASC_KEY_ID=YOUR_KEY_ID"
    echo "  ASC_ISSUER_ID=YOUR_ISSUER_ID"
    echo "  ASC_KEY_PATH=~/.appstoreconnect/private_keys/AuthKey_YOUR_KEY_ID.p8"
    exit 1
fi

# shellcheck source=/dev/null
source "$SECRETS_FILE"

# Expand tilde in key path
ASC_KEY_PATH="${ASC_KEY_PATH/#\~/$HOME}"

for var in ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_PATH; do
    if [[ -z "${!var:-}" ]]; then
        echo "ERROR: $var not set in $SECRETS_FILE"
        exit 1
    fi
done

if [[ ! -f "$ASC_KEY_PATH" ]]; then
    echo "ERROR: API key file not found at $ASC_KEY_PATH"
    exit 1
fi

# ── Project paths ────────────────────────────────────────────────────────────

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$PROJECT_DIR/StarPath.xcodeproj"
ARCHIVE_DIR="$PROJECT_DIR/.build/archives"
EXPORT_DIR="$PROJECT_DIR/.build/export"
TEAM_ID="992N457T8D"

rm -rf "$ARCHIVE_DIR" "$EXPORT_DIR"
mkdir -p "$ARCHIVE_DIR" "$EXPORT_DIR"

# ── Version bump ─────────────────────────────────────────────────────────────

echo "==> Bumping version to $MARKETING_VERSION..."

CURRENT_BUILD=$(grep -m1 'CURRENT_PROJECT_VERSION' "$PROJECT/project.pbxproj" | head -1 | sed 's/[^0-9]//g')
NEW_BUILD=$((CURRENT_BUILD + 1))
echo "    Build number: $CURRENT_BUILD → $NEW_BUILD"

if ! $DRY_RUN; then
    sed -i '' "s/MARKETING_VERSION = [^;]*/MARKETING_VERSION = $MARKETING_VERSION/g" "$PROJECT/project.pbxproj"
    sed -i '' "s/CURRENT_PROJECT_VERSION = [^;]*/CURRENT_PROJECT_VERSION = $NEW_BUILD/g" "$PROJECT/project.pbxproj"
fi

echo "    Version: $MARKETING_VERSION ($NEW_BUILD)"

# ── Archive & Export ─────────────────────────────────────────────────────────

echo ""
echo "==> Archiving iOS..."
ARCHIVE_PATH="$ARCHIVE_DIR/iOS.xcarchive"

xcodebuild archive \
    -project "$PROJECT" \
    -scheme "StarPath" \
    -destination "generic/platform=iOS" \
    -archivePath "$ARCHIVE_PATH" \
    -configuration Release \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    MARKETING_VERSION="$MARKETING_VERSION" \
    CURRENT_PROJECT_VERSION="$NEW_BUILD" \
    CODE_SIGN_STYLE=Automatic \
    -allowProvisioningUpdates \
    -authenticationKeyPath "$ASC_KEY_PATH" \
    -authenticationKeyID "$ASC_KEY_ID" \
    -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
    2>&1 | tail -5

if [[ ! -d "$ARCHIVE_PATH" ]]; then
    echo "ERROR: Archive failed — $ARCHIVE_PATH not found"
    exit 1
fi
echo "    Archive: $ARCHIVE_PATH"

echo "==> Exporting & uploading to App Store Connect..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_DIR/iOS" \
    -exportOptionsPlist "$PROJECT_DIR/scripts/ExportOptions-iOS.plist" \
    -allowProvisioningUpdates \
    -authenticationKeyPath "$ASC_KEY_PATH" \
    -authenticationKeyID "$ASC_KEY_ID" \
    -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
    2>&1 | tail -5

echo "    Export: $EXPORT_DIR/iOS"

# ── Finalize ─────────────────────────────────────────────────────────────────

if $DRY_RUN; then
    echo ""
    echo "==> Dry run complete. Archive built but NOT uploaded."
    echo "    Run without --dry-run to upload to App Store Connect."
else
    echo ""
    echo "==> Committing version bump and tagging $VERSION..."
    git -C "$PROJECT_DIR" add -A
    git -C "$PROJECT_DIR" commit -m "Bump version to $MARKETING_VERSION ($NEW_BUILD) for App Store release"
    git -C "$PROJECT_DIR" tag "$VERSION"
    git -C "$PROJECT_DIR" push origin main --tags

    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "  StarPath $MARKETING_VERSION ($NEW_BUILD) uploaded!"
    echo ""
    echo "  Next: Check App Store Connect for build processing status"
    echo "  https://appstoreconnect.apple.com/apps"
    echo "════════════════════════════════════════════════════════════"
fi
