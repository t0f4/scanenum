# scanenum
 
**tool:** scanenum  
**author:** t0f4  
**version:** 0.1

---

## what is scanenum?

`scanenum` is a compact, practical Bash recon script focused on quick web triage. It automates an initial assessment workflow so you can get readable, actionable results fast:

- Runs an aggressive `nmap` service/version scan to discover open ports and services.
- Performs directory enumeration (Gobuster by default) and filters out noisy 403 results.
- Runs `nikto` and produces a concise, deduplicated summary containing **only High & Medium** severity findings (collapses repeated RFI noise and long garbage lines).
- Saves raw outputs and clean summaries per target/port inside a neat `scanenum_<target>/` directory.

This makes the tool ideal for quick triage, reporting, and handing off to teammates for deeper testing.

---

## Requirements

Tested on Debian/Ubuntu-like systems. Required tools (should be in your `$PATH`):

- `bash` (>= 4)
- `nmap`
- `nikto`
- `gobuster` (optional but recommended)

> The script will attempt to `apt-get install` `nikto`/`gobuster` if missing (requires `sudo`). If you prefer not to auto-install, install dependencies manually.

---

## Get it (git)

```bash
# clone the repo
git clone https://github.com/t0f4/scanenum.git

cd scanenum

```

## Install / Quick setup

```bash
# make the main script executable
chmod +x scanenum.sh

# (optional) move to /usr/local/bin for global access
# sudo mv scanenum.sh /usr/local/bin/scanenum
```

## Usage

Basic run (no extra flags required — the script is opinionated to produce compact Nikto output):

```bash
# run against an IP or hostname
./scanenum.sh 192.168.0.131

# if installed globally:
# scanenum 192.168.0.131
```

What happens when you run it:

Ping host to verify it’s alive.

nmap -A scan saved to scanenum_<target>/nmap.txt.

Extracts web ports it finds (http/https) and runs Gobuster (default wordlist).

Runs nikto per web port and writes:

scanenum_<target>/nikto_<port>.txt (raw)

scanenum_<target>/nikto_summary_<port>.txt (compact HIGH + MED summary)

Example output files:

```bash
scanenum_192.168.0.131/
├─ nmap.txt
├─ gobuster_8080.txt
├─ gobuster_8080.clean.txt
├─ nikto_8080.txt
└─ nikto_summary_8080.txt
```

Open the summary to quickly see High and Medium Nikto findings without repetitive noise:
```bash
less scanenum_192.168.0.131/nikto_summary_8080.txt
```

Example terminal run (short)

```bash
tool: scanenum
author: t0f4
version: 0.1
[*] Starting at: 2025-09-24 15:07:04Z

[+] Host 192.168.0.131 is alive
[+] Nmap scan saved to scanenum_192.168.0.131/nmap.txt
[+] Gobuster cleaned saved to scanenum_192.168.0.131/gobuster_8080.clean.txt
[+] Nikto summary (HIGH+MED) saved to scanenum_192.168.0.131/nikto_summary_8080.txt

Final Summary (HIGH+MED Nikto only) for 192.168.0.131
[+] Nikto summary on port 8080:
HIGH: PHP info or test script found - reveals server details
HIGH: Possible Remote File Inclusion (RFI) vectors found
MED: Missing or misconfigured security header
[*] Done. All outputs: scanenum_192.168.0.131/
```
## DISCLAIMER (IMPORTANT) - read before using

This tool is intended for educational purposes and authorized security testing only. Do not run scanenum against systems you do not own or for which you do not have explicit, documented permission.

Unauthorized scanning, enumeration, or exploitation is illegal in many jurisdictions and can result in civil or criminal penalties. Use responsibly.
Happy Hacking.
