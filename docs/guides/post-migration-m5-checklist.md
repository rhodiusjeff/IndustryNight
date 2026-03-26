# Post-Migration Checklist — M1 Max → M5 Max

**Context:** Development environment transferred from Jeff's M1 Max to new M5 Max via Migration Assistant (full filesystem copy).  
**When to run:** Immediately after first boot on the new machine, before resuming any CODEX work.

> **Premise:** Migration Assistant copies everything — VS Code (extensions, settings, MCP config, local storage), Flutter SDK, AWS CLI profiles, kubeconfig, node_modules, virtualenvs, `.env` files. Almost everything just works. This checklist is verification-first: check that it transferred, act only if broken.

---

## Step 1 — Confirm repo is present and on correct branch

```bash
cd ~/Documents/GitHub/IndustryNight   # adjust if path changed
git status
git log --oneline -5
```

Should show `integration` branch at `b2e8b3c` or later. If the directory exists and git is tracking correctly, **no action needed**. If somehow missing, clone:

```bash
git clone https://github.com/rhodiusjeff/IndustryNight.git
cd IndustryNight && git checkout integration
```

---

## Step 2 — Verify git worktrees (B0 lanes) ← Most likely thing to check

Git worktree metadata in `.git/worktrees/` contains absolute paths. If your username and directory structure are unchanged on the M5, they'll work. If anything changed, they'll be stale.

```bash
git worktree list
```

**If both worktrees show correctly** — done, no action needed.

**If stale/missing** (e.g. username changed or path changed), recreate them:

```bash
mkdir -p ../IndustryNight-runs
git worktree add ../IndustryNight-runs/B0-claude feature/B0-react-scaffold-claude
git worktree add ../IndustryNight-runs/B0-gpt feature/B0-react-scaffold-gpt
git worktree list  # verify
```

---

## Step 3 — Check X2-A1 hardcoded path

The X2-A1 spec contains a hardcoded local path to the B0-claude worktree. If path/username changed, update it.

```bash
grep "IndustryNight-runs" docs/codex/track-X/X2-admin-spec-rebase.md
```

Expected: `/Users/jmsimpson/Documents/GitHub/IndustryNight-runs/B0-claude/packages/react-admin/`

**If path is correct** — done. **If changed**, update and commit:

```bash
sed -i '' 's|/Users/jmsimpson/Documents/GitHub/|/Users/NEW_USERNAME/Documents/GitHub/|g' \
  docs/codex/track-X/X2-admin-spec-rebase.md
git add docs/codex/track-X/X2-admin-spec-rebase.md
git commit -m "chore(codex): update X2-A1 worktree path for new machine"
git push
```

---

## Step 4 — Quick smoke test

```bash
# Repo + worktrees
git worktree list
gh pr list --state open

# VS Code MCP (open VS Code, start a Copilot session, verify GitHub MCP tools load)

# AWS credentials
aws sts get-caller-identity --profile industrynight-admin

# Flutter
flutter doctor

# API (if you need local dev — requires DB port-forward)
./scripts/pf-db.sh --env dev start
cd packages/api && npm run dev
```

---

## App Reactivations

Migration Assistant copies app binaries and preferences but some apps require license reactivation on new hardware. Check:
- Any licensed dev tools (JetBrains, etc.) if applicable
- Anything that ties a license to hardware fingerprint

GitHub Copilot, GitHub CLI (`gh`), AWS CLI — these authenticate via tokens/profiles which transfer with the filesystem, no reactivation needed.

---

## What transferred automatically (no action needed)

- Git repo history and working tree — filesystem copy
- VS Code: extensions, settings, keybindings, MCP server config, local storage
- Flutter SDK — copied with PATH config
- AWS CLI credentials (`~/.aws/`) — copied
- kubeconfig (`~/.kube/config`) — copied
- `node_modules` — copied (both M1 and M5 are Apple Silicon, no arch issues)
- Python virtualenvs — copied (path-dependent; works if username/path unchanged)
- `.env` files (gitignored) — copied with filesystem
- Database — on AWS RDS, unaffected
- AWS infrastructure — unaffected

---

## Post-Checklist: Resume CODEX

Once all steps are green, the next task is **X2-A1** (ground-truth research session).  
See [docs/codex/track-X/X2-admin-spec-rebase.md](../codex/track-X/X2-admin-spec-rebase.md) → X2-A1 section.

Confirm X2-A1 worktree path (Step 3) before starting the research session.
