#!/usr/bin/env bash
# Usage: ./scanenum.sh <IP|HOST>

set -o pipefail

# ===== Colors =====
RED="\e[1;31m"
GREEN="\e[1;32m"
YELLOW="\e[1;33m"
CYAN="\e[1;36m"
MAGENTA="\e[1;35m"
RESET="\e[0m"

# ===== Trap Handling =====
CURRENT_PID=0
skip_phase=false
trap_handler() {
  if [ $CURRENT_PID -ne 0 ]; then
    echo -e "${YELLOW}[!] Skipping current phase...${RESET}"
    kill -TERM $CURRENT_PID 2>/dev/null || kill -9 $CURRENT_PID 2>/dev/null
    skip_phase=true
  fi
}
trap trap_handler SIGINT

# ===== Banner =====
echo -e "${CYAN}====================================${RESET}"
echo -e "${YELLOW}tool: scanenum
author: t0f4
version: 0.1${RESET}"
echo -e "${CYAN}====================================${RESET}"
echo -e "${GREEN}[*] Starting at: $(date -u +"%Y-%m-%d %H:%M:%SZ")${RESET}\n"

TARGET=$1
if [ -z "${TARGET}" ]; then
  echo -e "${RED}Usage: $0 <IP|HOST>${RESET}"
  exit 1
fi

RESULTS="scanenum_${TARGET}"
mkdir -p "$RESULTS"

# ===== Phase 1: Ping =====
echo -e "${MAGENTA}---[ Phase 1: Host Discovery ]---${RESET}"
if ping -c 1 -W 2 "$TARGET" &>/dev/null; then
  echo -e "${GREEN}[+] Host $TARGET is active and ready for NMAP ${RESET}\n"
else
  echo -e "${RED}[-] Host $TARGET is unreachable${RESET}"
  exit 1
fi

# ===== Phase 2: Nmap Aggressive Scan =====
echo -e "${MAGENTA}---[ Phase 2: Port & Service Scan ]---${RESET}"
skip_phase=false
nmap -A "$TARGET" -T4 -oN "$RESULTS/nmap.txt" &
CURRENT_PID=$!
wait $CURRENT_PID 2>/dev/null || true
CURRENT_PID=0
[ "$skip_phase" = true ] && echo -e "${YELLOW}[!] Skipped Nmap phase${RESET}\n" || echo -e "${GREEN}[+] Nmap scan saved to $RESULTS/nmap.txt${RESET}\n"

# Extract web ports (http/https services)
WEB_PORTS=$(grep -E '^[0-9]+/tcp.*open.*(http|https)' "$RESULTS/nmap.txt" | cut -d/ -f1 | tr '\n' ' ' | sed 's/ $//')

# --- New logic: ensure port 1311 is included as web (HTTP or HTTPS) if it's open ---
HTTPS_PORTS=""
if grep -E '^1311/tcp.*open' "$RESULTS/nmap.txt" >/dev/null 2>&1; then
  # add 1311 to WEB_PORTS if not already present
  if [ -z "$WEB_PORTS" ] || ! echo "$WEB_PORTS" | grep -w -q '1311'; then
    WEB_PORTS="$(echo "$WEB_PORTS 1311" | tr -s ' ' | sed 's/^ //; s/ $//')"
  fi
  # determine whether 1311 looks like an SSL/HTTPS service in nmap output
  if grep -Ei '^1311/tcp.*open.*(https|ssl|tls)' "$RESULTS/nmap.txt" >/dev/null 2>&1; then
    HTTPS_PORTS="$HTTPS_PORTS 1311"
  fi
fi
# trim spaces
WEB_PORTS="$(echo "$WEB_PORTS" | tr -s ' ' | sed 's/^ //; s/ $//')"
HTTPS_PORTS="$(echo "$HTTPS_PORTS" | tr -s ' ' | sed 's/^ //; s/ $//')"

if [ -z "$WEB_PORTS" ]; then
  echo -e "${RED}[-] No web ports found, skipping web enumeration${RESET}"
  exit 0
fi
echo -e "${GREEN}[+] Web ports discovered: $WEB_PORTS${RESET}"
if [ -n "$HTTPS_PORTS" ]; then
  echo -e "${GREEN}[+] Ports treated as HTTPS: $HTTPS_PORTS${RESET}\n"
else
  echo -e "${YELLOW}[!] No additional HTTPS ports auto-detected (1311 will be HTTP unless Nmap showed SSL/HTTPS)${RESET}\n"
fi

# ===== Phase 3: Gobuster (no prompt, default wordlist) =====
# We run gobuster but keep it quiet; cleaned output excludes 403 entries.
if ! command -v gobuster &>/dev/null; then
  echo -e "${YELLOW}[!] Gobuster not found. Attempting apt-get install (requires sudo)...${RESET}"
  sudo apt-get update && sudo apt-get install -y gobuster || echo -e "${YELLOW}[!] Could not install gobuster; skipping gobuster phase${RESET}"
fi

WORDLIST="/usr/share/wordlists/dirb/common.txt"
for PORT in $WEB_PORTS; do
  URL="http://$TARGET:$PORT"
  # Use HTTPS for well-known HTTPS ports or if we auto-detected 1311 as HTTPS
  if [ "$PORT" = "443" ] || [ "$PORT" = "8443" ] || echo "$HTTPS_PORTS" | grep -w -q "$PORT"; then
    URL="https://$TARGET:$PORT"
  fi

  if command -v gobuster &>/dev/null; then
    echo -e "${MAGENTA}---[ Phase 3: Gobuster on $URL ]---${RESET}"
    skip_phase=false
    gobuster dir -u "$URL" -w "$WORDLIST" -q -o "$RESULTS/gobuster_$PORT.txt" 2>/dev/null &
    CURRENT_PID=$!
    wait $CURRENT_PID 2>/dev/null || true
    CURRENT_PID=0

    if [ "$skip_phase" = true ]; then
      echo -e "${YELLOW}[!] Skipped Gobuster on $URL${RESET}\n"
    else
      # Exclude lines that represent HTTP 403 status explicitly
      grep -v -E 'Status: *403|\(403\)|\b403\b' "$RESULTS/gobuster_$PORT.txt" > "$RESULTS/gobuster_$PORT.clean.tmp" || true
      if [ -s "$RESULTS/gobuster_$PORT.clean.tmp" ]; then
        awk 'NF' "$RESULTS/gobuster_$PORT.clean.tmp" | awk '!seen[$0]++' > "$RESULTS/gobuster_$PORT.clean.txt"
      else
        sort -u "$RESULTS/gobuster_$PORT.txt" > "$RESULTS/gobuster_$PORT.clean.txt" 2>/dev/null || cp -f "$RESULTS/gobuster_$PORT.txt" "$RESULTS/gobuster_$PORT.clean.txt" 2>/dev/null || true
      fi
      rm -f "$RESULTS/gobuster_$PORT.clean.tmp"
      echo -e "${GREEN}[+] Gobuster cleaned saved to $RESULTS/gobuster_$PORT.clean.txt${RESET}\n"
    fi
  else
    echo -e "${YELLOW}[!] Gobuster not available; skipping directory bruteforce for port $PORT${RESET}\n"
  fi
done

# ===== Phase 4: Nikto (default) - produce HIGH+MED summary only =====
if ! command -v nikto &>/dev/null; then
  echo -e "${YELLOW}[!] Nikto not found. Attempting apt-get install (requires sudo)...${RESET}"
  sudo apt-get update && sudo apt-get install -y nikto || { echo -e "${RED}[-] Nikto not installed; cannot run nikto${RESET}"; exit 0; }
fi

for PORT in $WEB_PORTS; do
  URL="http://$TARGET:$PORT"
  # Use HTTPS for well-known HTTPS ports or if we auto-detected 1311 as HTTPS
  if [ "$PORT" = "443" ] || [ "$PORT" = "8443" ] || echo "$HTTPS_PORTS" | grep -w -q "$PORT"; then
    URL="https://$TARGET:$PORT"
  fi

  echo -e "${MAGENTA}---[ Phase 4: Nikto scan on $URL ]---${RESET}"
  skip_phase=false
  nikto -h "$URL" -output "$RESULTS/nikto_$PORT.txt" &
  CURRENT_PID=$!
  wait $CURRENT_PID 2>/dev/null || true
  CURRENT_PID=0

  if [ "$skip_phase" = true ]; then
    echo -e "${YELLOW}[!] Skipped Nikto on $URL${RESET}\n"
    continue
  fi

  echo -e "${GREEN}[+] Nikto raw saved to $RESULTS/nikto_$PORT.txt${RESET}"

  # Post-process Nikto: remove very long junk lines, strip leading '+', dedupe
  RAW="$RESULTS/nikto_$PORT.txt"
  FILTERED="$RESULTS/nikto_$PORT.filtered.txt"
  SUMMARY="$RESULTS/nikto_summary_$PORT.txt"

  # Limit lines to 300 chars (discard giant junk), trim + prefixes, dedupe
  awk 'length($0) <= 300 { print }' "$RAW" | sed -E 's/^\+\s*//; s/^\s+//; s/\s+$//' | awk '!seen[$0]++' > "$FILTERED"

  # Classify and keep only HIGH and MED items (no LOW). Simpler phrasing (no long jargons).
  awk 'BEGIN{IGNORECASE=1}
    /phpinfo\(|phpinfo|output from the phpinfo|php reveals|php is installed|php test script/ { print "HIGH: PHP info or test script found - reveals server details"; next }
    /remote file inclusion|rfi|remote file inc/ { print "HIGH: Possible Remote File Inclusion (RFI) vectors found"; next }
    /osvdb|osvdb-[0-9]+/ { print "HIGH: OSVDB-related issue found"; next }
    /directory indexing|indexing found|apache default file|default file found/ { print "HIGH: Directory indexing or default file present"; next }
    /cgi directories|cgi-bin/ { print "HIGH: CGI directories or scripts detected"; next }
    /x-frame-options|x-content-type-options|httponly|httpOnly/ { print "MED: Missing or misconfigured security header"; next }
    /x-debug-token|debug token/ { print "MED: Debug token or debug header exposed"; next }
    /appears to be outdated|outdated/ { print "MED: Server or component appears outdated"; next }
    { next }
  ' "$FILTERED" | awk '!seen[$0]++' > "$SUMMARY"

  if [ ! -s "$SUMMARY" ]; then
    echo "No HIGH or MED Nikto findings (summary empty)" > "$SUMMARY"
  fi

  echo -e "${GREEN}[+] Nikto summary (HIGH+MED) saved to $SUMMARY${RESET}\n"
done

# ===== Final short summary printed to terminal =====
echo -e "${CYAN}====================================${RESET}"
echo -e "${YELLOW} Final Summary (HIGH+MED Nikto only) for $TARGET${RESET}"
echo -e "${CYAN}====================================${RESET}"

for PORT in $WEB_PORTS; do
  echo -e "\n${GREEN}[+] Nikto summary on port $PORT:${RESET}"
  if [ -f "$RESULTS/nikto_summary_$PORT.txt" ]; then
    sed -n '1,200p' "$RESULTS/nikto_summary_$PORT.txt"
  else
    echo -e "${YELLOW}No summary file for port $PORT${RESET}"
  fi
done

echo -e "\n${GREEN}[*] Done. All outputs: $RESULTS/${RESET}"

# End of script
