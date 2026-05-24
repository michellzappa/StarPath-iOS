#!/bin/bash
set -euo pipefail

# Upload App Store screenshots to App Store Connect via the API.
#
# Usage:
#   ./scripts/upload-screenshots.sh
#   ./scripts/upload-screenshots.sh --dry-run
#
# Requires: ASC API key in ~/.cartogram-secrets (same as appstore.sh)

DRY_RUN=false
for arg in "$@"; do
    case "$arg" in
        --dry-run)  DRY_RUN=true ;;
    esac
done

# ── Credentials ──────────────────────────────────────────────────────────────

SECRETS_FILE="$HOME/.cartogram-secrets"
if [[ ! -f "$SECRETS_FILE" ]]; then
    echo "ERROR: Missing $SECRETS_FILE"
    exit 1
fi
source "$SECRETS_FILE"
ASC_KEY_PATH="${ASC_KEY_PATH/#\~/$HOME}"

# ── Generate JWT ─────────────────────────────────────────────────────────────

generate_jwt() {
    local now=$(date +%s)
    local exp=$((now + 1200))  # 20 min

    local header=$(printf '{"alg":"ES256","kid":"%s","typ":"JWT"}' "$ASC_KEY_ID" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
    local payload=$(printf '{"iss":"%s","iat":%d,"exp":%d,"aud":"appstoreconnect-v1"}' "$ASC_ISSUER_ID" "$now" "$exp" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
    local unsigned="${header}.${payload}"
    local signature=$(printf '%s' "$unsigned" | openssl dgst -sha256 -sign "$ASC_KEY_PATH" | openssl asn1parse -inform DER -out /dev/stdout 2>/dev/null | tail -c 64 | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')

    # Use python for reliable JWT signing
    python3 -c "
import jwt, time, sys
key = open('${ASC_KEY_PATH}').read()
token = jwt.encode(
    {'iss': '${ASC_ISSUER_ID}', 'iat': int(time.time()), 'exp': int(time.time()) + 1200, 'aud': 'appstoreconnect-v1'},
    key, algorithm='ES256', headers={'kid': '${ASC_KEY_ID}'}
)
print(token if isinstance(token, str) else token.decode())
"
}

JWT=$(generate_jwt)
ASC_API="https://api.appstoreconnect.apple.com/v1"
AUTH="Authorization: Bearer $JWT"
CT="Content-Type: application/json"

# ── Helpers ──────────────────────────────────────────────────────────────────

asc_get() {
    curl -s -H "$AUTH" "$ASC_API$1"
}

asc_post() {
    curl -s -H "$AUTH" -H "$CT" -X POST -d "$2" "$ASC_API$1"
}

asc_delete() {
    curl -s -H "$AUTH" -X DELETE "$ASC_API$1"
}

# ── Find app & version ───────────────────────────────────────────────────────

BUNDLE_ID="AestheticHermetics.StarPath"
echo "==> Finding app: $BUNDLE_ID"

APP_RESPONSE=$(asc_get "/apps?filter[bundleId]=$BUNDLE_ID")
APP_ID=$(echo "$APP_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['data'][0]['id'])")
echo "    App ID: $APP_ID"

# Get the editable version (PREPARE_FOR_SUBMISSION or similar)
echo "==> Finding editable app store version..."
VERSIONS_RESPONSE=$(asc_get "/apps/$APP_ID/appStoreVersions?filter[platform]=IOS")
VERSION_ID=$(echo "$VERSIONS_RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)['data']
# Prefer PREPARE_FOR_SUBMISSION, fall back to first editable state
for v in data:
    state = v['attributes']['appStoreState']
    if state in ('PREPARE_FOR_SUBMISSION', 'DEVELOPER_ACTION_NEEDED', 'INVALID_BINARY', 'DEVELOPER_REJECTED', 'REJECTED', 'METADATA_REJECTED', 'WAITING_FOR_REVIEW', 'IN_REVIEW', 'READY_FOR_REVIEW'):
        print(v['id'])
        sys.exit(0)
print(data[0]['id'] if data else '')
")
echo "    Version ID: $VERSION_ID"

# ── Screenshot display types ─────────────────────────────────────────────────

# Apple display types for iPhone screenshots
declare -A DISPLAY_TYPES=(
    ["1320x2868"]="APP_IPHONE_67"
    ["1284x2778"]="APP_IPHONE_65"
    ["1206x2622"]="APP_IPHONE_61"
    ["1125x2436"]="APP_IPHONE_58"
)

EXPORTS_DIR="$(cd "$(dirname "$0")/../app-store-screenshots/exports" && pwd)"

# ── Get existing localizations ───────────────────────────────────────────────

echo "==> Getting localizations..."
LOCS_RESPONSE=$(asc_get "/appStoreVersions/$VERSION_ID/appStoreVersionLocalizations")
LOC_ID=$(echo "$LOCS_RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)['data']
# Prefer en-US
for loc in data:
    if loc['attributes']['locale'] == 'en-US':
        print(loc['id'])
        sys.exit(0)
# Fall back to first
print(data[0]['id'] if data else '')
")
echo "    Localization ID: $LOC_ID (en-US)"

# ── Upload screenshots per display type ──────────────────────────────────────

for resolution in "${!DISPLAY_TYPES[@]}"; do
    display_type="${DISPLAY_TYPES[$resolution]}"
    echo ""
    echo "── $display_type ($resolution) ──"

    # Check if screenshot set exists
    SETS_RESPONSE=$(asc_get "/appStoreVersionLocalizations/$LOC_ID/appScreenshotSets?filter[screenshotDisplayType]=$display_type")
    SET_ID=$(echo "$SETS_RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)['data']
print(data[0]['id'] if data else '')
")

    if [[ -z "$SET_ID" ]]; then
        echo "  Creating screenshot set..."
        if ! $DRY_RUN; then
            CREATE_RESPONSE=$(asc_post "/appScreenshotSets" "$(printf '{
                "data": {
                    "type": "appScreenshotSets",
                    "attributes": { "screenshotDisplayType": "%s" },
                    "relationships": {
                        "appStoreVersionLocalization": {
                            "data": { "type": "appStoreVersionLocalizations", "id": "%s" }
                        }
                    }
                }
            }' "$display_type" "$LOC_ID")")
            SET_ID=$(echo "$CREATE_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['id'])")
        fi
        echo "  Set ID: $SET_ID"
    else
        echo "  Set exists: $SET_ID"
        # Delete existing screenshots in this set
        EXISTING=$(asc_get "/appScreenshotSets/$SET_ID/appScreenshots")
        EXISTING_IDS=$(echo "$EXISTING" | python3 -c "
import sys, json
data = json.load(sys.stdin)['data']
for s in data:
    print(s['id'])
" 2>/dev/null || true)
        if [[ -n "$EXISTING_IDS" ]]; then
            echo "  Removing existing screenshots..."
            while IFS= read -r sid; do
                if [[ -n "$sid" ]] && ! $DRY_RUN; then
                    asc_delete "/appScreenshots/$sid" > /dev/null
                    echo "    Deleted $sid"
                fi
            done <<< "$EXISTING_IDS"
        fi
    fi

    # Upload each slide for this resolution
    for png in "$EXPORTS_DIR"/*-"$resolution".png; do
        [[ -f "$png" ]] || continue
        filename=$(basename "$png")
        filesize=$(stat -f%z "$png")
        echo "  Uploading $filename ($filesize bytes)..."

        if $DRY_RUN; then
            echo "    [dry-run] Would upload $filename"
            continue
        fi

        # Reserve the screenshot
        RESERVE_RESPONSE=$(asc_post "/appScreenshots" "$(printf '{
            "data": {
                "type": "appScreenshots",
                "attributes": {
                    "fileName": "%s",
                    "fileSize": %d
                },
                "relationships": {
                    "appScreenshotSet": {
                        "data": { "type": "appScreenshotSets", "id": "%s" }
                    }
                }
            }
        }' "$filename" "$filesize" "$SET_ID")")

        SCREENSHOT_ID=$(echo "$RESERVE_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['id'])")
        UPLOAD_URL=$(echo "$RESERVE_RESPONSE" | python3 -c "
import sys, json
ops = json.load(sys.stdin)['data']['attributes']['uploadOperations']
for op in ops:
    print(op['url'])
    break
")
        UPLOAD_METHOD=$(echo "$RESERVE_RESPONSE" | python3 -c "
import sys, json
ops = json.load(sys.stdin)['data']['attributes']['uploadOperations']
for op in ops:
    print(op['method'])
    break
")
        UPLOAD_HEADERS=$(echo "$RESERVE_RESPONSE" | python3 -c "
import sys, json
ops = json.load(sys.stdin)['data']['attributes']['uploadOperations']
for op in ops:
    for h in op['requestHeaders']:
        print(h['name'] + ': ' + h['value'])
    break
")
        UPLOAD_OFFSET=$(echo "$RESERVE_RESPONSE" | python3 -c "
import sys, json
ops = json.load(sys.stdin)['data']['attributes']['uploadOperations']
for op in ops:
    print(op.get('offset', 0))
    break
")
        UPLOAD_LENGTH=$(echo "$RESERVE_RESPONSE" | python3 -c "
import sys, json
ops = json.load(sys.stdin)['data']['attributes']['uploadOperations']
for op in ops:
    print(op.get('length', 0))
    break
")

        # Upload the chunk
        HEADER_ARGS=""
        while IFS= read -r h; do
            [[ -n "$h" ]] && HEADER_ARGS="$HEADER_ARGS -H \"$h\""
        done <<< "$UPLOAD_HEADERS"

        # Extract chunk and upload
        dd if="$png" bs=1 skip="$UPLOAD_OFFSET" count="$UPLOAD_LENGTH" 2>/dev/null | \
            eval curl -s -X "$UPLOAD_METHOD" $HEADER_ARGS --data-binary @- "$UPLOAD_URL" > /dev/null

        # Commit the upload
        curl -s -H "$AUTH" -H "$CT" -X PATCH "$ASC_API/appScreenshots/$SCREENSHOT_ID" \
            -d "{\"data\":{\"type\":\"appScreenshots\",\"id\":\"$SCREENSHOT_ID\",\"attributes\":{\"uploaded\":true,\"sourceFileChecksum\":{\"type\":\"md5\",\"value\":\"$(md5 -q "$png")\"}}}}" > /dev/null

        echo "    ✓ Uploaded ($SCREENSHOT_ID)"
    done
done

echo ""
if $DRY_RUN; then
    echo "==> Dry run complete. No screenshots were uploaded."
else
    echo "════════════════════════════════════════════════════════════"
    echo "  Screenshots uploaded to App Store Connect!"
    echo ""
    echo "  Check: https://appstoreconnect.apple.com/apps/$APP_ID"
    echo "════════════════════════════════════════════════════════════"
fi
