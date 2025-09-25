# 20_nmap_scan.sh
run(){
  log_phase "Port & Service Scan (nmap)"
  if ! check_cmd nmap; then warn "nmap not installed; skipping"; return 0; fi
  nmap $NMAP_FLAGS "$TARGET" -oN "$RESULTS_DIR/nmap.txt" &
  wait $! || true
  if [[ "$skip_current" == true ]]; then return 0; fi
  ok "Nmap scan saved to $RESULTS_DIR/nmap.txt"

  # Extract web ports (http/https services) to a helper file for other plugins
  grep -E '^[0-9]+/tcp.*open.*(http|https)' "$RESULTS_DIR/nmap.txt" | cut -d/ -f1 | tr '\n' ' ' | sed 's/ $//' > "$RESULTS_DIR/web_ports.txt" || true
  if [[ ! -s "$RESULTS_DIR/web_ports.txt" ]]; then
    warn "No web ports found"
  else
    ok "Web ports discovered: $(cat "$RESULTS_DIR/web_ports.txt")"
  fi
}
