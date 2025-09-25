# scanenum (modular plugin architecture)

This is a modular rewrite of the original `scanenum.sh` tool. Each phase is a plugin with a clear lifecycle and no implicit global side-effects.

## Quick start

```bash
chmod +x scanenum
./scanenum <IP|HOST>
./scanenum <IP|HOST> --list-plugins
./scanenum <IP|HOST> --only 20,40      # run only selected plugin ids
```

Outputs are written to a per-run folder like `scanenum_<target>_<UTC timestamp>/`.

## Architecture

- `scanenum` — main runner; loads `lib/api.sh`, configuration, and executes plugins in numeric order.
- `lib/api.sh` — small helper "API" for logging, config, plugin discovery.
- `config/default.conf` — configurable knobs (Nmap flags, wordlists, etc.).
- `plugins/enabled/*.sh` — executable plugins with a `run()` function. The file name determines order and id.
  - Example: `20_nmap_scan.sh` → id `20`, name `nmap_scan`.

### Plugin contract

A plugin is a Bash file that defines a `run()` function and may use helpers from `lib/api.sh`:

```bash
# 50_example.sh
run(){
  log_phase "Do something"
  require_cmd somebin
  somebin "$TARGET" > "$RESULTS_DIR/example.txt"
  ok "Saved: $RESULTS_DIR/example.txt"
}
```

- Use `check_cmd` if a dependency is optional, `require_cmd` if it is mandatory.
- If the user presses Ctrl‑C, the current plugin gets skipped but the pipeline continues.
- Share data between plugins via files in `$RESULTS_DIR` (e.g., `web_ports.txt`).

## Extending

Create a new file in `plugins/enabled/NN_your_plugin.sh` (where `NN` is a two‑digit order). Keep single‑responsibility; prefer new plugins over growing a single one.

## Notes

- No auto-install with `sudo`; we only warn on missing tools.
- Safer defaults (`set -euo pipefail`), explicit config, and per-run result directories.
