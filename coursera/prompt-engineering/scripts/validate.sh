#!/bin/bash
# composio-crusher v2 — environment readiness check
# Validates required + recommended env vars and CLI tools for all 10 waves.

FAIL=0
WARN=0

mask() {
  local val="$1"
  local len=${#val}
  if [ "$len" -lt 12 ]; then
    echo "****"
  else
    echo "${val:0:8}****${val: -4}"
  fi
}

echo "=== Composio Crusher v2 — Environment Check ==="
echo ""

# ─── Required ────────────────────────────────────────────
echo "[REQUIRED]"
for var in COMPOSIO_API_KEY FIRECRAWL_API_KEY SUPABASE_URL SUPABASE_ANON_KEY; do
  if [ -z "${!var}" ]; then
    echo "  [MISSING] $var"
    FAIL=1
  else
    echo "  [OK]      $var: $(mask "${!var}")"
  fi
done

# Embeddings — need at least one
echo ""
echo "[EMBEDDINGS — at least one required for Wave 8]"
if [ -z "$OPENAI_API_KEY" ] && [ -z "$VOYAGE_API_KEY" ] && [ -z "$ANTHROPIC_API_KEY" ]; then
  echo "  [MISSING] OPENAI_API_KEY / VOYAGE_API_KEY / ANTHROPIC_API_KEY (need one)"
  FAIL=1
else
  for var in OPENAI_API_KEY VOYAGE_API_KEY ANTHROPIC_API_KEY; do
    if [ -n "${!var}" ]; then
      echo "  [OK]      $var: $(mask "${!var}")"
    fi
  done
fi

# ─── Wave-expansion recommended ──────────────────────────
echo ""
echo "[WAVE 4 — browser pool (each one adds a provider)]"
for var in BROWSERBASE_API_KEY HYPERBROWSER_API_KEY ANCHOR_BROWSER_API_KEY; do
  if [ -z "${!var}" ]; then
    echo "  [OPTIONAL] $var: not set"
    WARN=$((WARN+1))
  else
    echo "  [OK]       $var: $(mask "${!var}")"
  fi
done

echo ""
echo "[WAVE 5 — specialized scraping]"
for var in APIFY_API_KEY SCREENSHOTONE_API_KEY; do
  if [ -z "${!var}" ]; then
    echo "  [OPTIONAL] $var: not set"
  else
    echo "  [OK]       $var: $(mask "${!var}")"
  fi
done

echo ""
echo "[WAVE 6 — anti-bot cascade]"
for var in SCRAPFLY_API_KEY ZYTE_API_KEY SCRAPE_DO_API_KEY; do
  if [ -z "${!var}" ]; then
    echo "  [OPTIONAL] $var: not set"
  else
    echo "  [OK]       $var: $(mask "${!var}")"
  fi
done

echo ""
echo "[WAVE 9 — delivery destinations]"
for var in NOTION_TOKEN GITHUB_TOKEN GOOGLE_DRIVE_CONNECTED GOOGLE_SHEETS_CONNECTED WEBHOOK_DELIVERY_URL S3_ACCESS_KEY_ID S3_SECRET_ACCESS_KEY S3_BUCKET; do
  if [ -z "${!var}" ]; then
    echo "  [OPTIONAL] $var: not set"
  else
    if [[ "$var" == *URL* ]] || [[ "$var" == *CONNECTED* ]] || [[ "$var" == *BUCKET* ]]; then
      echo "  [OK]       $var: ${!var}"
    else
      echo "  [OK]       $var: $(mask "${!var}")"
    fi
  fi
done

# ─── CLI tooling ─────────────────────────────────────────
echo ""
echo "[CLI TOOLS]"
for cmd in node curl jq python3 psql; do
  if command -v "$cmd" &> /dev/null; then
    echo "  [OK]      $cmd: $(which "$cmd")"
  else
    if [ "$cmd" = "psql" ]; then
      echo "  [OPTIONAL] $cmd: not found (only needed to apply schema.sql locally)"
    else
      echo "  [MISSING] $cmd: not found in PATH"
      FAIL=1
    fi
  fi
done

# ─── Composio CLI auth ───────────────────────────────────
echo ""
echo "[COMPOSIO CLI]"
if command -v composio &> /dev/null; then
  if composio whoami &> /dev/null; then
    echo "  [OK]      composio whoami: authenticated"
  else
    echo "  [WARN]    composio CLI found but not authenticated (run: composio login)"
    WARN=$((WARN+1))
  fi
else
  echo "  [OPTIONAL] composio CLI not in PATH (orchestrator can still use the API directly)"
fi

# ─── Result ──────────────────────────────────────────────
echo ""
if [ $FAIL -eq 1 ]; then
  echo "=== RESULT: NOT READY — fix [MISSING] items above ==="
  exit 1
else
  echo "=== RESULT: READY ==="
  if [ $WARN -gt 0 ]; then
    echo "    Note: $WARN optional providers are not configured. Pipeline will skip"
    echo "    their waves and degrade gracefully. Add keys to expand coverage."
  fi
  echo "    Composio Crusher v2 is go."
  exit 0
fi
