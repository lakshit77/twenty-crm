#!/usr/bin/env bash
# Sync Twenty CRM fork with upstream twentyhq/twenty.
# Usage: bash "${CLAUDE_SKILL_DIR}/scripts/sync-upstream.sh"
# Env: UPSTREAM_URL, UPSTREAM_REMOTE, UPSTREAM_BRANCH, PUSH (default true)

set -euo pipefail

UPSTREAM_URL="${UPSTREAM_URL:-https://github.com/twentyhq/twenty.git}"
UPSTREAM_REMOTE="${UPSTREAM_REMOTE:-upstream}"
UPSTREAM_BRANCH="${UPSTREAM_BRANCH:-main}"
PUSH="${PUSH:-true}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { printf "${GREEN}→${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}!${NC} %s\n" "$*"; }
fail() { printf "${RED}✗${NC} %s\n" "$*" >&2; exit 1; }

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  fail "Not inside a git repository."
fi

CURRENT_BRANCH="$(git branch --show-current)"
info "Branch: ${CURRENT_BRANCH}"

if ! git diff --quiet || ! git diff --cached --quiet; then
  fail "Working tree is dirty. Commit or stash changes before syncing."
fi

if git remote get-url "$UPSTREAM_REMOTE" >/dev/null 2>&1; then
  info "Remote '${UPSTREAM_REMOTE}' already configured"
else
  info "Adding remote '${UPSTREAM_REMOTE}' → ${UPSTREAM_URL}"
  git remote add "$UPSTREAM_REMOTE" "$UPSTREAM_URL"
fi

info "Fetching ${UPSTREAM_REMOTE}/${UPSTREAM_BRANCH}..."
git fetch "$UPSTREAM_REMOTE" "$UPSTREAM_BRANCH"

UPSTREAM_REF="${UPSTREAM_REMOTE}/${UPSTREAM_BRANCH}"
BEHIND="$(git rev-list --count HEAD.."${UPSTREAM_REF}")"
AHEAD="$(git rev-list --count "${UPSTREAM_REF}"..HEAD)"

info "Behind upstream: ${BEHIND} commit(s)"
info "Fork-only commits: ${AHEAD} commit(s)"

if [[ "$BEHIND" -eq 0 ]]; then
  info "Already up to date with ${UPSTREAM_REF}."
  exit 0
fi

BASE="$(git merge-base HEAD "${UPSTREAM_REF}")"

info "Fork-only files since merge-base:"
FORK_FILES="$(git diff --name-only "${BASE}"..HEAD | sort || true)"
if [[ -n "$FORK_FILES" ]]; then
  echo "$FORK_FILES" | sed 's/^/  - /'
else
  echo "  (none)"
fi

info "Checking for merge conflicts..."
MERGE_TREE_OUTPUT="$(git merge-tree "${BASE}" HEAD "${UPSTREAM_REF}" 2>&1 || true)"
CONFLICT_LINES="$(echo "$MERGE_TREE_OUTPUT" | grep -E "CONFLICT|changed in both" || true)"

OVERLAP="$(comm -12 \
  <(git diff --name-only "${BASE}"..HEAD | sort) \
  <(git diff --name-only "${BASE}.."${UPSTREAM_REF} | sort) || true)"

if [[ -n "$CONFLICT_LINES" || -n "$OVERLAP" ]]; then
  warn "Upstream sync blocked — potential conflicts detected."
  echo ""
  echo "Fork-only commits:"
  git log --oneline "${UPSTREAM_REF}"..HEAD | sed 's/^/  /'
  echo ""
  if [[ -n "$OVERLAP" ]]; then
    echo "Files changed on BOTH fork and upstream:"
    echo "$OVERLAP" | sed 's/^/  - /'
  fi
  if [[ -n "$CONFLICT_LINES" ]]; then
    echo ""
    echo "merge-tree conflict signals:"
    echo "$CONFLICT_LINES" | sed 's/^/  /'
  fi
  echo ""
  echo "Resolve conflicts manually, then re-run this script."
  exit 1
fi

info "No conflicts — merging ${UPSTREAM_REF}..."
git merge "${UPSTREAM_REF}" -m "$(cat <<'EOF'
Merge upstream/twentyhq/twenty main into fork

Brings in latest upstream changes while preserving fork-specific commits.
EOF
)"

info "Merge complete. Fork-only commits after merge:"
git log --oneline "${UPSTREAM_REF}"..HEAD --not --merges | sed 's/^/  /' || true

if [[ "$PUSH" == "true" ]]; then
  info "Pushing to origin..."
  git push origin HEAD
  info "Done. HEAD: $(git rev-parse --short HEAD)"
else
  warn "PUSH=false — merge committed locally, not pushed."
fi
