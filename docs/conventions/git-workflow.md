---
title: Git Workflow
sidebar_position: 3
---

# Git Workflow

Git conventions for contributing to Nevermore. These apply to both Luau packages and TypeScript CLI tools.

## Commit messages

Use [conventional commits](https://www.conventionalcommits.org/): `feat(scope):`, `fix(scope):`, `chore(scope):`, `docs:`, `refactor(scope):`. Messages describe impact, not reasoning.

```
feat(cli): add GitHub Actions job summary reporter
fix(blend): handle nil parent during cleanup
chore(devcontainer): add GitHub CLI feature
docs: update testing guide with job summary details
```

The scope is typically the package name or area of the codebase. Omit the scope for cross-cutting changes.

## Interactive rebase

Use `git rebase -i` to craft clean commit history before pushing or requesting review:

- **Squash** related work into cohesive commits (e.g., implementation + fix-ups become one commit)
- **Separate** unrelated changes into distinct commits (e.g., a feature commit and a devcontainer fix should be separate)
- **Rebase** onto the target branch to resolve conflicts cleanly rather than creating merge commits
- **Reword** commit messages to be clear and descriptive after squashing

```bash
# Rebase onto main and clean up commits interactively
git fetch origin main
git rebase -i origin/main

# In the editor: pick, squash (s), fixup (f), reword (r)
# Then force-push the cleaned branch
git push --force-with-lease
```

### When to squash vs. keep separate

A PR with three commits like this is ideal:

```
feat(cli): add job summary reporter       # the feature
chore(devcontainer): add GitHub CLI        # unrelated improvement, separate commit
docs: document job summary and git rebase  # docs follow-up
```

A PR where every save was a commit should be squashed down. The goal is that each commit in the final history is a coherent, self-contained change.

## Pull request descriptions

PR descriptions are for reviewers and future readers browsing git history. They should answer "what changed and why?" — not "how was it implemented?" The code already shows the how.

**Good** — says what changed from the user's perspective:

```
Test and deploy results now appear on the GitHub Actions run summary
page in addition to PR comments.

Also reorganizes the GitHub reporter code into `reporting/github/`
with shared formatting and a separate API module.
```

**Bad** — restates the diff:

```
- Add `GithubJobSummaryReporter` that writes batch test/deploy results
  to `$GITHUB_STEP_SUMMARY`
- Refactor GitHub reporter code into a `reporting/github/` subfolder
  with shared formatting extracted into `formatting.ts`
- Wire up the new reporter in `batch test`, `batch deploy`, and
  `post-test-results` commands
```

Keep descriptions to 1-3 sentences. If a PR needs a long explanation, that's usually a sign it should be split up.

## Branching

- Branch from `main` for all work
- Use `users/{username}/{description}` branch names: `users/quenty/job-summary-reporter`, `users/quenty/fix-spinner-cursor`
- Releases are CI-driven via `auto shipit` — never release locally

## No co-authorship

Do not include `Co-Authored-By` on Nevermore commits (open source repo).
