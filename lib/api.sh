#!/usr/bin/env bash
set -euo pipefail

_die(){ echo -e "\e[1;31m[!] $*\e[0m" 1>&2; exit 1; }

load_config(){
  local cfg="${1:-}"
  [[ -f "$cfg" ]] && source "$cfg"
}

check_cmd(){
  local c="$1"
  if ! command -v "$c" &>/dev/null; then
    echo -e "\e[1;33m[!] Missing dependency: $c (plugin may skip)\e[0m"
    return 1
  fi
  return 0
}

require_cmd(){
  local c="$1"
  check_cmd "$c" || _die "Required command not found: $c"
}

plugin_id(){
  local f="$1"
  basename "$f" | cut -d'_' -f1
}

plugin_name(){
  local f="$1"
  local base; base="$(basename "$f")"
  echo "${base#*_}" | sed 's/\.sh$//'
}

resolve_plugins(){
  local only="${1:-}"
  local dir="$SCANENUM_ROOT/plugins/enabled"
  local list
  mapfile -t list < <(find "$dir" -maxdepth 1 -type f -name '*.sh' | sort)
  if [[ -z "$only" ]]; then
    printf "%s\n" "${list[@]}"
  else
    IFS=',' read -r -a wanted <<< "$only"
    for p in "${list[@]}"; do
      pid="$(plugin_id "$p")"
      for w in "${wanted[@]}"; do
        if [[ "$pid" == "$w" ]]; then echo "$p"; fi
      done
    done
  fi
}

list_plugins(){
  local dir="$SCANENUM_ROOT/plugins/enabled"
  printf "Available plugins (execution order):\n"
  find "$dir" -maxdepth 1 -type f -name '*.sh' -print0 | sort -z | while IFS= read -r -d '' p; do
    local id name
    id="$(plugin_id "$p")"; name="$(plugin_name "$p")"
    printf "  %s  %s  (%s)\n" "$id" "$name" "$p"
  done
}

log_phase(){
  local msg="$1"
  echo -e "\e[1;36m[*] $msg\e[0m"
}

ok(){
  local msg="$1"
  echo -e "\e[1;32m[+] $msg\e[0m"
}

warn(){
  local msg="$1"
  echo -e "\e[1;33m[!] $msg\e[0m"
}

err(){
  local msg="$1"
  echo -e "\e[1;31m[-] $msg\e[0m"
}
