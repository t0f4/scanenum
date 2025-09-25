# 40_nikto.sh
run(){
  log_phase "Nikto scan"
  if ! check_cmd nikto; then warn "nikto not installed; skipping"; return 0; fi
  if [[ ! -s "$RESULTS_DIR/web_ports.txt" ]]; then warn "No web ports file; skipping"; return 0; fi

  for PORT in $(cat "$RESULTS_DIR/web_ports.txt"); do
    proto="http"; [[ "$PORT" == "443" || "$PORT" == "8443" ]] && proto="https"
    URL="$proto://$TARGET:$PORT"

    nikto -h "$URL" $NIKTO_FLAGS -output "$RESULTS_DIR/nikto_${PORT}.txt" &
    pid=$!; wait $pid || true
    [[ "$skip_current" == true ]] && continue

    ok "Nikto raw saved to $RESULTS_DIR/nikto_${PORT}.txt"

    RAW="$RESULTS_DIR/nikto_${PORT}.txt"
    FILTERED="$RESULTS_DIR/nikto_${PORT}.filtered.txt"
    SUMMARY="$RESULTS_DIR/nikto_summary_${PORT}.txt"

    awk 'length($0) <= 300 { print }' "$RAW" | sed -E 's/^\+\s*//; s/^\s+//; s/\s+$//' | awk '!seen[$0]++' > "$FILTERED"

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

    if [[ ! -s "$SUMMARY" ]]; then
      echo "No HIGH or MED Nikto findings (summary empty)" > "$SUMMARY"
    fi

    ok "Nikto summary (HIGH+MED) saved to $SUMMARY"
  done
}
