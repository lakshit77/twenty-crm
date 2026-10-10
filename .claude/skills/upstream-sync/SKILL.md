---
name: upstream-sync
description: Sync a Twenty CRM fork with upstream twentyhq/twenty — fetch, detect merge conflicts with fork-only commits, merge upstream/main, and push to origin. Use when the user asks to upstream, sync with upstream, merge upstream, update the fork from twentyhq, or run /upstream-sync.
---

# Upstream Sync (Twenty CRM Fork)

Automates syncing this fork with [twentyhq/twenty](https://github.com/twentyhq/twenty).

## Defaults

| Setting | Value |
|---------|-------|
| Upstream remote | `upstream` → `https://github.com/twentyhq/twenty.git` |
| Upstream branch | `main` |
| Push target | `origin` (user's fork) |
| Current branch | whatever is checked out (usually `main`) |

Override with env vars: `UPSTREAM_URL`, `UPSTREAM_REMOTE`, `UPSTREAM_BRANCH`, `PUSH=false`.

## Workflow

Run the steps below in order. Prefer the script when shell access is available.

### Step 1: Preflight

```bash
git status
git remote -v
git branch -vv
```

Stop and ask the user if:

- Working tree is **dirty** (uncommitted changes) — offer to stash or commit first
- User is not on the branch they intend to sync (usually `main`)

### Step 2: Ensure upstream remote and fetch

```bash
git remote add upstream https://github.com/twentyhq/twenty.git 2>/dev/null || true
git fetch upstream
```

### Step 3: Analyze divergence

```bash
BASE=$(git merge-base HEAD upstream/main)
git rev-list --count HEAD..upstream/main    # commits behind upstream
git rev-list --count upstream/main..HEAD    # fork-only commits
git log --oneline upstream/main..HEAD       # fork-only commit list
git diff --name-only "$BASE"..HEAD          # files changed only on fork
```

If already up to date (`HEAD..upstream/main` count is 0), report that and stop.

### Step 4: Conflict check (required before merge)

```bash
BASE=$(git merge-base HEAD upstream/main)
git merge-tree "$BASE" HEAD upstream/main 2>&1 | grep -E "CONFLICT|changed in both" || true
```

Also list overlapping files (touched on both sides since merge-base):

```bash
comm -12 \
  <(git diff --name-only "$BASE"..HEAD | sort) \
  <(git diff --name-only "$BASE"..upstream/main | sort)
```

**If conflicts or overlapping files with incompatible changes:**

1. Do **not** merge or push
2. Report to the user:
   - Fork-only commits and files
   - Upstream commit range being pulled
   - Overlapping files (likely conflict zones)
   - Conflict type (e.g. both sides edited same lines in `docker-compose.yml`)
3. Suggest resolution: rebase fork commits onto upstream, or manual merge

**If no conflicts:** proceed to Step 5.

### Step 5: Merge upstream

Only when working tree is clean and Step 4 found no conflicts:

```bash
git merge upstream/main -m "$(cat <<'EOF'
Merge upstream/twentyhq/twenty main into fork

Brings in latest upstream changes while preserving fork-specific commits.
EOF
)"
```

If merge fails unexpectedly, run `git merge --abort` and report the error.

### Step 6: Verify fork changes preserved

After merge, confirm fork-only files still contain expected customizations:

```bash
git log --oneline upstream/main..HEAD --not --merges
git diff upstream/main..HEAD --stat
```

### Step 7: Push (default: yes)

Unless the user said not to push (`PUSH=false` or "don't push"):

```bash
git push origin HEAD
```

Report the remote URL and new HEAD SHA.

## One-shot script

From repo root:

```bash
# Sync + merge + push
bash "${CLAUDE_SKILL_DIR}/scripts/sync-upstream.sh"

# Sync + merge, no push
PUSH=false bash "${CLAUDE_SKILL_DIR}/scripts/sync-upstream.sh"
```

The script exits non-zero on conflicts or dirty tree; read its stdout for the report.

## User-facing report template

**Success:**

```markdown
## Upstream sync complete

- **Behind upstream:** N commits (now merged)
- **Fork commits preserved:** N
- **Conflicts:** none
- **Pushed:** yes → origin/main @ `<sha>`

### Fork-only files (unchanged by upstream)
- `path/to/file`
```

**Blocked (conflicts):**

```markdown
## Upstream sync blocked — conflicts detected

### Your fork changed
- `<commit>` — `<message>`
- Files: ...

### Upstream would change (overlapping)
- `path/to/file` — both sides modified since `<base>`

### What you need to resolve
Describe per file whether to keep fork changes, take upstream, or combine.

Do not push until resolved.
```

## Safety rules

- Never force-push unless the user explicitly asks
- Never skip hooks (`--no-verify`)
- Never merge with a dirty working tree without user approval
- Never push if merge was aborted or conflicts remain
