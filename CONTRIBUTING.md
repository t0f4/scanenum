# Contributing to scanenum

Thanks for considering contributing!  
This project aims to stay small, clean, and easy to use. Contributions are welcome — from bug fixes to new plugins.

---

## How to Contribute

### 1. Fork & Clone
```bash
git clone https://github.com/t0f4/scanenum.git
cd scanenum
```

### 2. Create a branch
Never work directly on main. Create a new branch:
```bash
git checkout -b feature/my-change
```
Examples:
```bash
i. feature/plugin-gobuster

ii. fix/nmap-output-bug
```

### 3. Make your changes
Keep scripts readable and portable (bash preferred).

If adding a new phase, place it in plugins/enabled/ with a numeric prefix (e.g., 20_nmap.sh).

New scripts should:
```bah
i. accept the target as the first argument ($1),

ii. write results to $RESULTS_DIR,

iii.  gracefully skip if dependencies are missing.
```

### 4. Test locally
Run the tool against a safe test target:

```bash
./scanenum.sh <target-ip>
```

### 5. Commit & Push
```bash
git add .
git commit -m "Add Gobuster plugin for directory enumeration"
git push origin feature/my-change
```

### 6. Open a Pull Request
Describe the change clearly.
Note new dependencies (if any).
Keep PRs focused — one feature or fix per PR.

## Branch Naming Convention
| Prefix    | Use case                                    | Example                     |
|-----------|---------------------------------------------|-----------------------------|
| `feature/`| New features or enhancements                | `feature/plugin-architecture` |
| `fix/`    | Bug fixes                                   | `fix/nmap-timeout`          |
| `docs/`   | Documentation updates                      | `docs/update-readme`        |
| `refactor/` | Code restructuring without behavior change | `refactor/logging-api`      |
| `test/`   | Adding or updating tests                   | `test/add-nikto-tests`      |
| `chore/`  | Maintenance tasks (dependencies, CI, etc.) | `chore/dependency-bump`     |

## ✅ PR Checklist
- [ ] 🔍 Code tested locally  
- [ ] 🛠 No hard failures if optional dependencies missing  
- [ ] 📖 README/docs updated if behavior changed  
- [ ] 🌱 Branch follows naming convention  

## Disclaimer
This project is for educational and authorized testing only.
Do not use it on systems you don’t own or have explicit permission to test.
