#!/usr/bin/env bash
# check-ibm-links.sh
# Finds all ibm.com links in tracked md/yaml/yml files and checks each one.

# This is here for troubleshooting lychee failures due to bots.

# Usage:
#   ./scripts/check-ibm-links.sh            # coloured output
#   ./scripts/check-ibm-links.sh --no-color # plain output (CI-friendly)
#
# Exit code: 0 if all links return 200/redirect, 1 if any return an unexpected status.
# Note: ibm.com/docs returns 403 for all automated requests regardless of User-Agent.
#       This script treats 403 as a warning (not a hard failure) so you can spot real
#       404s (deleted pages) while ignoring the bot-block noise.

set -euo pipefail

ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
cd "$ROOT"

# ── colors ──────────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--no-color" ]] || [[ ! -t 1 ]]; then
  RED="" GREEN="" YELLOW="" CYAN="" RESET="" BOLD="" DIM=""
else
  RED="\033[0;31m" GREEN="\033[0;32m" YELLOW="\033[0;33m"
  CYAN="\033[0;36m" RESET="\033[0m" BOLD="\033[1m" DIM="\033[2m"
fi

# ── collect URLs with their source files ────────────────────────────────────
# Output format: "url\tfile:line"
declare -A URL_SOURCES   # url -> "file:line, file:line, ..."

while IFS= read -r raw; do
  # Format is "file:linenum:url" but url contains ":" (https://…), so split on the
  # first two colons only and treat everything after as the URL.
  file="${raw%%:*}"; rest="${raw#*:}"
  line="${rest%%:*}"; url="${rest#*:}"
  # strip leading ./
  file="${file#./}"
  if [[ -n "${URL_SOURCES[$url]+_}" ]]; then
    URL_SOURCES[$url]+="  ${DIM}${file}:${line}${RESET}"
  else
    URL_SOURCES[$url]="${DIM}${file}:${line}${RESET}"
  fi
done < <(
  grep -rnoP 'https?://[^\s<>"()#\]]+ibm\.com[^\s<>"()#\]]*' \
    --include='*.md' --include='*.yaml' --include='*.yml' \
    . \
    2>/dev/null \
  | grep -v '^\./\.git/' \
  | grep -v '^\./temp/'
)

URLS=("${!URL_SOURCES[@]}")
# Sort for stable output
IFS=$'\n' URLS=($(printf '%s\n' "${URLS[@]}" | sort)); unset IFS

if [[ ${#URLS[@]} -eq 0 ]]; then
  echo "No ibm.com URLs found."
  exit 0
fi

echo -e "${BOLD}Checking ${#URLS[@]} unique ibm.com URLs...${RESET}"
echo ""

PASS=0 FAIL=0 WARN=0 REDIRECT=0

for url in "${URLS[@]}"; do
  response=$(curl -s -o /dev/null \
    -w "%{http_code} %{url_effective}\n" -I -L \
    --max-time 15 \
    "$url" 2>&1) || response="000 $url"

  http_code="${response%% *}"
  final_url="${response#* }"
  sources="${URL_SOURCES[$url]}"

  case "$http_code" in
    200)
      if [[ "$final_url" != "$url" ]]; then
        echo -e "  ${YELLOW}[REDIRECT → $http_code]${RESET} $url"
        echo -e "             ${DIM}→ $final_url${RESET}"
        REDIRECT=$((REDIRECT + 1))
      else
        echo -e "  ${GREEN}[OK $http_code]${RESET} $url"
        PASS=$((PASS + 1))
      fi
      ;;
    403)
      # IBM docs always 403 bots — treat as warning, not failure
      echo -e "  ${YELLOW}[WARN $http_code]${RESET} $url"
      echo -e "             ${DIM}(bot-blocked; verify manually in a browser)${RESET}"
      WARN=$((WARN + 1))
      ;;
    404|410)
      echo -e "  ${RED}[BROKEN $http_code]${RESET} $url"
      FAIL=$((FAIL + 1))
      ;;
    000)
      echo -e "  ${RED}[TIMEOUT]${RESET} $url"
      FAIL=$((FAIL + 1))
      ;;
    *)
      echo -e "  ${RED}[FAIL $http_code]${RESET} $url"
      FAIL=$((FAIL + 1))
      ;;
  esac

  # Print source locations, indented
  while IFS= read -r src; do
    echo -e "             ${CYAN}↳ $src${RESET}"
  done <<< "${sources//  /$'\n'}"
  echo ""
done

echo -e "${BOLD}Results:${RESET}  ${GREEN}${PASS} ok${RESET}  |  ${YELLOW}${REDIRECT} redirected${RESET}  |  ${YELLOW}${WARN} bot-blocked (403)${RESET}  |  ${RED}${FAIL} broken${RESET}  |  ${#URLS[@]} total"
echo ""

if [[ $FAIL -gt 0 ]]; then
  echo -e "${RED}${BOLD}✗ ${FAIL} broken link(s) found.${RESET}"
  exit 1
else
  echo -e "${GREEN}${BOLD}✓ No broken links detected.${RESET}"
  echo -e "${DIM}  (403s are expected from ibm.com — open those URLs in a browser to verify.)${RESET}"
  exit 0
fi
