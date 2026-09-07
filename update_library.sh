#!/usr/bin/env bash
# update_library.sh

set -euo pipefail

STEAM_API_KEY="${STEAM_API_KEY:?Set STEAM_API_KEY}"
STEAM_ID="${STEAM_ID:?Set STEAM_ID}"
STEAM_USER="${STEAM_USER:?Set STEAM_USER}"

LIBRARY_BASE="/library"
SKIP_APPIDS="${SKIP_APPIDS:-}"
RETRY_ATTEMPTS="${STEAM_RETRY_ATTEMPTS:-3}"
RETRY_DELAY="${STEAM_RETRY_DELAY:-30}"

mkdir -p "${LIBRARY_BASE}"

# ── Check if an app is already installed ──────────────────────────────────────
# steamcmd writes appmanifest_<id>.acf on successful install
check_installed() {
  local APPID="$1"
  find "${LIBRARY_BASE}/${APPID}" -name "appmanifest_${APPID}.acf" 2>/dev/null | grep -q .
}

# ── Download a single app with retries ───────────────────────────────────────
download_app() {
  local APPID="$1"
  local NAME="$2"
  local ATTEMPT=0
  local INSTALL_DIR="${LIBRARY_BASE}/${APPID}"

  mkdir -p "$INSTALL_DIR"

  while [[ $ATTEMPT -lt $RETRY_ATTEMPTS ]]; do
    ATTEMPT=$((ATTEMPT + 1))
    echo "    [Attempt $ATTEMPT/$RETRY_ATTEMPTS] $NAME ($APPID)..."

    steamcmd \
      +@sSteamCmdForcePlatformType windows \
      +@ShutdownOnFailedCommand 0 \
      +set_download_throttle "${STEAM_DOWNLOAD_THROTTLE:-0}" \
      +login "${STEAM_USER}" \
      +force_install_dir "$INSTALL_DIR" \
      +app_update "$APPID" \
      +quit

    if check_installed "$APPID"; then
      echo "    ✓ Installed: $NAME ($APPID)"
      return 0
    fi

    echo "    ✗ Not verified after attempt $ATTEMPT."
    if [[ $ATTEMPT -lt $RETRY_ATTEMPTS ]]; then
      echo "    Waiting ${RETRY_DELAY}s before retry..."
      sleep "$RETRY_DELAY"
    fi
  done

  echo "    ✗ Gave up on $NAME ($APPID) after $RETRY_ATTEMPTS attempts."
  return 1
}


# ── Fetch game list ───────────────────────────────────────────────────────────
echo "[$(date)] Fetching owned games for SteamID $STEAM_ID..."

API_URL="https://api.steampowered.com/IPlayerService/GetOwnedGames/v1/"

HTTP_RESPONSE=$(curl -s -w "\n%{http_code}" "${API_URL}?key=${STEAM_API_KEY}&steamid=${STEAM_ID}&include_appinfo=1&include_played_free_games=1&format=json")
HTTP_BODY=$(echo "$HTTP_RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$HTTP_RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" != "200" ]]; then
  echo "ERROR: Steam API returned HTTP $HTTP_CODE."
  echo "Response body: $HTTP_BODY"
  exit 1
fi

GAME_LIST=$(echo "$HTTP_BODY" | jq -r '.response.games[] | "\(.appid) \(.name)"')

if [[ -z "$GAME_LIST" ]]; then
  echo "ERROR: No games returned. Check your Steam profile is public and API key/SteamID are correct."
  echo "Raw response: $HTTP_BODY"
  exit 1
fi


TOTAL=$(echo "$GAME_LIST" | wc -l)
echo "[$(date)] Found $TOTAL games."

SKIPPED=()
FAILED=()
COUNT=0

# ── Main loop ─────────────────────────────────────────────────────────────────
while IFS= read -r line; do
  APPID=$(echo "$line" | awk '{print $1}')
  NAME=$(echo "$line" | cut -d' ' -f2-)
  COUNT=$((COUNT + 1))

  echo ""
  echo "[$COUNT/$TOTAL] $NAME ($APPID)"

  if echo "$SKIP_APPIDS" | grep -qw "$APPID"; then
    echo "  [SKIP] In skip list."
    SKIPPED+=("$APPID: $NAME")
    continue
  fi

  if check_installed "$APPID"; then
    echo "  [SKIP] Already installed — skipping."
    continue
  fi

  if ! download_app "$APPID" "$NAME"; then
    FAILED+=("$APPID: $NAME")
  fi

done <<< "$GAME_LIST"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "[$(date)] All done."
echo "  Total   : $TOTAL"
echo "  Skipped : ${#SKIPPED[@]}"
echo "  Failed  : ${#FAILED[@]}"

if [[ ${#SKIPPED[@]} -gt 0 ]]; then
  echo "Skipped:"; for s in "${SKIPPED[@]}"; do echo "    - $s"; done
fi
if [[ ${#FAILED[@]} -gt 0 ]]; then
  echo "Failed:"; for f in "${FAILED[@]}"; do echo "    - $f"; done
fi

