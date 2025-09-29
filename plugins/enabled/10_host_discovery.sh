# 10_host_discovery.sh
run(){
  log_phase "Host discovery"
  if check_cmd ping && ping -c 1 -W 2 "$TARGET" &>/dev/null; then
    ok "Host $TARGET is active and ready for Nmap"
    return 0
  else
    err "Host $TARGET is unreachable"
    # Non-fatal: allow other plugins like DNS checks to continue in the future.
    return 0
  fi
}
