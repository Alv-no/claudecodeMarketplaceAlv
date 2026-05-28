---
name: deploy-check
description: Run a pre-deployment checklist — tests, diffs, secrets scan, debug statements, TODOs, and changelog
command: deploy-check
---

# Deploy Check — Pre-Deployment Checklist

Run a comprehensive pre-deployment checklist and present the results as a status table.

## Steps

1. **Git Diff Summary**: Run `git diff --stat HEAD~1` to show what changed.
2. **Test Suite**: Run the project's test suite. Detect the runner:
   - `package.json` with test script → `npm test`
   - `pytest.ini` / `pyproject.toml` with pytest → `pytest`
   - `Cargo.toml` → `cargo test`
   - `go.mod` → `go test ./...`
3. **TODO/FIXME Scan**: Search for `TODO`, `FIXME`, `HACK`, `XXX` in changed files.
4. **Hardcoded Secrets Scan**: Search changed files for patterns like:
   - `password\s*=\s*["'][^"']+["']`
   - `(api[_-]?key|secret|token)\s*[:=]\s*["'][^"']+["']`
   - `-----BEGIN (RSA |EC |DSA )?PRIVATE KEY-----`
   - Strings that look like AWS keys: `AKIA[0-9A-Z]{16}`
5. **Debug Statement Scan**: Search changed files for:
   - JS/TS: `console.log`, `console.debug`, `debugger`
   - Python: `print(`, `breakpoint()`, `pdb.set_trace`
   - Rust: `dbg!`, `println!` (in non-main files)
   - Go: `fmt.Println` (in non-test, non-main files)
6. **CHANGELOG Check**: Verify that `CHANGELOG.md` (or `CHANGES.md`, `HISTORY.md`) was updated in the current diff.

## Output Format

Present results as a markdown table:

```
## 🚀 Deploy Readiness Report

| Check                  | Status | Details                          |
|------------------------|--------|----------------------------------|
| Git Changes            | ✅/❌  | N files changed, +X -Y lines    |
| Tests                  | ✅/❌  | All passed / N failures          |
| TODOs/FIXMEs           | ✅/⚠️  | None found / N items found       |
| Hardcoded Secrets      | ✅/❌  | None found / N potential leaks   |
| Debug Statements       | ✅/⚠️  | None found / N statements found  |
| CHANGELOG Updated      | ✅/❌  | Updated / Not updated            |

### Recommendation
[READY TO DEPLOY ✅ / NEEDS ATTENTION ⚠️ / DO NOT DEPLOY ❌]
```

If any check is ❌, the recommendation should be **DO NOT DEPLOY**.
If any check is ⚠️ but none are ❌, recommend **NEEDS ATTENTION**.
If all checks are ✅, recommend **READY TO DEPLOY**.
