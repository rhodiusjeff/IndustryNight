# Post-Migration Checklist — M1 Max → M5 Max

**Context:** Development environment transferred from Jeff's M1 Max MacBook Pro to new M5 Max MacBook Pro.  
**When to run:** Immediately after migration/clone on the new machine, before resuming any CODEX work.

---

## Step 1 — Clone the repo

```bash
git clone https://github.com/rhodiusjeff/IndustryNight.git
cd IndustryNight
git checkout integration
git pull
```

---

## Step 2 — Recreate git worktrees (B0 lanes)

Worktrees are local filesystem links — they do NOT transfer via git clone or migration assist.

```bash
# From the IndustryNight repo root
mkdir -p ../IndustryNight-runs
git worktree add ../IndustryNight-runs/B0-claude feature/B0-react-scaffold-claude
git worktree add ../IndustryNight-runs/B0-gpt feature/B0-react-scaffold-gpt

# Verify
git worktree list
```

---

## Step 3 — Restore react-admin node_modules (B0-claude worktree)

`node_modules` is not in git. The B0-claude worktree react-admin scaffold needs deps installed before X2-A1 research or any B0 runtime testing.

```bash
cd ../IndustryNight-runs/B0-claude/packages/react-admin
npm install
```

---

## Step 4 — Update X2-A1 hardcoded path if directory structure changed

The X2-A1 spec contains a hardcoded local path. Check it:

```bash
grep "IndustryNight-runs" docs/codex/track-X/X2-admin-spec-rebase.md
```

Expected: `/Users/jmsimpson/Documents/GitHub/IndustryNight-runs/B0-claude/packages/react-admin/`

If the username or base directory changed on the new machine, update that line:

```bash
# Find and replace (adjust paths as needed)
sed -i '' 's|/Users/jmsimpson/Documents/GitHub/|/Users/NEW_USERNAME/Documents/GitHub/|g' \
  docs/codex/track-X/X2-admin-spec-rebase.md
git add docs/codex/track-X/X2-admin-spec-rebase.md
git commit -m "chore(codex): update X2-A1 worktree path for new machine"
git push
```

---

## Step 5 — API local dev setup

```bash
cd packages/api
npm install
```

Configure `.env` if needed (see `scripts/setup-local.sh` and `CLAUDE.md` → Development section).

Port-forward to RDS if working against dev database:
```bash
./scripts/pf-db.sh --env dev start
```

---

## Step 6 — Flutter setup

Verify Flutter SDK is installed and on PATH on the new machine:

```bash
flutter doctor
```

If not installed, follow Flutter macOS install guide. Then:

```bash
cd packages/social-app && flutter pub get
cd packages/admin-app && flutter pub get
cd packages/shared && flutter pub get
```

---

## Step 7 — AWS / kubectl

Verify AWS CLI profile transfers correctly:

```bash
aws sts get-caller-identity --profile industrynight-admin
```

Verify kubeconfig:

```bash
kubectl config get-contexts
kubectl --context <context-name> get pods -n industrynight-dev
```

If kubeconfig is missing, update it:

```bash
aws eks update-kubeconfig --name industrynight-dev --region us-east-1 --profile industrynight-admin
```

---

## Step 8 — Python venv (codex scripts)

```bash
cd /path/to/IndustryNight
python3 -m venv .venv-codex
source .venv-codex/bin/activate
# Install any required packages
pip install python-pptx  # for exec brief generator if needed
```

---

## Step 9 — VS Code extensions

Ensure these are installed and connected on the new machine:
- **GitHub Copilot** — for AI agent sessions
- **GitHub Pull Requests** — for PR integration
- **MCP server for GitHub** — check VS Code MCP settings; this was NOT connected on old machine (caused GitHub MCP unavailability). Re-establish connection on new machine.

---

## Step 10 — Smoke test

```bash
# Verify repo state
git log --oneline -5
git worktree list
gh pr list --state open

# Verify API can start (if DB port-forward is up)
cd packages/api && npm run dev
```

---

## What does NOT need to be redone

- Git history — all on GitHub, cloned fresh
- All CODEX governance artifacts — in repo
- Branch state (integration, feature branches) — remote
- Database — on AWS RDS, unaffected by machine change
- AWS infrastructure — unaffected

---

## Post-Checklist: Resume CODEX

Once all steps are green, the next task is **X2-A1** (ground-truth research session).  
See `docs/codex/track-X/X2-admin-spec-rebase.md` → X2-A1 section.

Confirm X2-A1 worktree path is correct (Step 4) before starting.
