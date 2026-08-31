#!/usr/bin/env bats
#
# Regression guard for reusable-latex-release.yml.
#
# Background: spark-match-06-article ended up with v0.0.6 and v0.0.7 on the
# same commit. The workflow read the previous version with
# `git describe --tags --abbrev=0`, which answered v0.0.6, so every merge
# after that recomputed v0.0.7 -- a version that already existed.
# action-gh-release updates an existing release rather than failing, so three
# consecutive merges silently replaced the PDF attached to v0.0.7 and produced
# no new release, with every job reporting success.
#
# The tests below pin both halves of the fix: the version is derived from the
# highest tag (which cannot collide), and a collision is a hard error.

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  WORKFLOW="${REPO_ROOT}/.github/workflows/reusable-latex-release.yml"

  TEST_TEMP="$(mktemp -d)"
}

teardown() {
  if [ -n "${TEST_TEMP:-}" ] && [ -d "${TEST_TEMP}" ]; then
    rm -rf "${TEST_TEMP}"
  fi
}

# Builds a throwaway repo with one commit per argument-free call and applies
# every tag passed in to the single HEAD commit, which is exactly the shape
# that broke 07-article.
make_repo_with_tags() {
  local repo="${TEST_TEMP}/repo"
  mkdir -p "${repo}"
  cd "${repo}" || return 1
  git init -q .
  git config user.email t@example.com
  git config user.name t
  git commit -q --allow-empty -m init
  local tag
  for tag in "$@"; do
    git tag "${tag}"
  done
}

# The production version selector, kept byte-identical in intent to the
# workflow step. If the workflow changes, the assertions further down catch it.
next_version() {
  local latest clean major minor patch
  latest=$(git tag --list 'v[0-9]*.[0-9]*.[0-9]*' | sort -V | tail -n 1)
  latest=${latest:-v0.0.0}
  clean=${latest#v}
  IFS='.' read -r major minor patch <<< "${clean}"
  echo "v${major:-0}.${minor:-0}.$(( ${patch:-0} + 1 ))"
}

@test "reusable-latex-release.yml exists" {
  [ -f "$WORKFLOW" ]
}

@test "version is not derived from git describe" {
  # Comment lines are allowed to name it -- the fix is explained in prose
  # right above the replacement. Only executable lines are forbidden.
  run bash -c "grep -vE '^[[:space:]]*#' '$WORKFLOW' | grep -F 'git describe'"
  [ "$status" -ne 0 ]
}

@test "version is derived from the highest tag via sort -V" {
  run grep -F "git tag --list 'v[0-9]*.[0-9]*.[0-9]*' | sort -V | tail -n 1" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "an existing target tag aborts the run" {
  run grep -F 'git rev-parse -q --verify "refs/tags/${NEW_VERSION}"' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -F 'already exists' "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "checkout pins the pull request merge commit" {
  run grep -F 'ref: ${{ github.event.pull_request.merge_commit_sha }}' "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "the release tag is anchored to the merge commit" {
  run grep -F 'target_commitish: ${{ github.event.pull_request.merge_commit_sha }}' "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "no tags at all yields v0.0.1" {
  make_repo_with_tags
  run next_version
  [ "$output" = "v0.0.1" ]
}

@test "a single tag bumps the patch" {
  make_repo_with_tags v0.0.5
  run next_version
  [ "$output" = "v0.0.6" ]
}

@test "two tags on one commit yield the highest plus one, not the lowest" {
  # The exact 07-article shape. git describe --abbrev=0 answers v0.0.6 here.
  make_repo_with_tags v0.0.6 v0.0.7
  run next_version
  [ "$output" = "v0.0.8" ]
}

@test "the selector disagrees with git describe on the broken shape" {
  # Documents WHY the change was needed rather than only that it happened.
  make_repo_with_tags v0.0.6 v0.0.7
  run git describe --tags --abbrev=0
  [ "$output" = "v0.0.6" ]
  run next_version
  [ "$output" = "v0.0.8" ]
}

@test "double-digit patches sort numerically, not lexically" {
  make_repo_with_tags v0.0.9 v0.0.10
  run next_version
  [ "$output" = "v0.0.11" ]
}

@test "a higher minor wins over a higher patch" {
  make_repo_with_tags v0.1.0 v0.0.42
  run next_version
  [ "$output" = "v0.1.1" ]
}

@test "non-semver tags are ignored" {
  make_repo_with_tags v0.0.3 latest release-candidate
  run next_version
  [ "$output" = "v0.0.4" ]
}
