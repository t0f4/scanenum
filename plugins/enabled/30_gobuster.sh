# 30_gobuster.sh
run(){
  log_phase "Web content enumeration (gobuster)"
  if ! check_cmd gobuster; then warn "gobuster not installed; skipping"; return 0; fi
  if [[ ! -s "$RESULTS_DIR/web_ports.txt" ]]; then warn "No web ports file; skipping"; return 0; fi

  for PORT in $(cat "$RESULTS_DIR/web_ports.txt"); do
    proto="http"; [[ "$PORT" == "443" || "$PORT" == "8443" ]] && proto="https"
    URL="$proto://$TARGET:$PORT"

    gobuster dir -u "$URL" -w "$WORDLIST" -q -o "$RESULTS_DIR/gobuster_${PORT}.txt" 2>/dev/null &
    pid=$!; wait $pid || true

    if [[ "$skip_current" == true ]]; then continue; fi

    # Clean output: drop 403s, de-dup, keep non-empty
    grep -v -E 'Status: *403|\(403\)|\b403\b' "$RESULTS_DIR/gobuster_${PORT}.txt" > "$RESULTS_DIR/gobuster_${PORT}.clean.tmp" || true
    if [[ -s "$RESULTS_DIR/gobuster_${PORT}.clean.tmp" ]]; then
      awk 'NF' "$RESULTS_DIR/gobuster_${PORT}.clean.tmp" | awk '!seen[$0]++' > "$RESULTS_DIR/gobuster_${PORT}.clean.txt"
    else
      sort -u "$RESULTS_DIR/gobuster_${PORT}.txt" > "$RESULTS_DIR/gobuster_${PORT}.clean.txt" 2>/dev/null || cp -f "$RESULTS_DIR/gobuster_${PORT}.txt" "$RESULTS_DIR/gobuster_${PORT}.clean.txt" 2>/dev/null || true
    fi
    rm -f "$RESULTS_DIR/gobuster_${PORT}.clean.tmp"
    ok "Gobuster cleaned saved to $RESULTS_DIR/gobuster_${PORT}.clean.txt"
  done
}
