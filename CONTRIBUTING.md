# 🤝 Contributing to HydroFlow

This document defines how to work on this project — branching strategy, commit conventions,
and code style standards.

---

## 🌿 Branching Strategy

```
main                    ← Production-ready code only. Protected.
  └── develop           ← Integration branch. All features merge here first.
        ├── feat/auth                  ← New features
        ├── feat/predictive-thirst
        ├── feat/mpesa-integration
        ├── fix/leak-detection-bug     ← Bug fixes
        └── docs/api-documentation     ← Documentation updates
```

### Rules
- **Never commit directly to `main`**
- Create a branch from `develop` for every task
- Branch name format: `type/short-description` (e.g., `feat/tank-api`, `fix/jwt-expiry`)
- Merge back to `develop` when task is complete
- `develop` merges to `main` at the end of each sprint

---

## 📝 Commit Message Convention

Format: `type: short description`

| Type | When to use |
|------|-------------|
| `feat` | New feature added |
| `fix` | Bug fixed |
| `docs` | Documentation only changes |
| `test` | Adding or fixing tests |
| `refactor` | Code restructured (no new feature, no bug fix) |
| `ci` | CI/CD pipeline changes |
| `deploy` | Deployment configuration |
| `release` | Version release |

**Examples:**
```
feat: add predictive thirst algorithm
fix: correct TDS threshold comparison operator
docs: update API.md with sensor endpoints
test: add unit tests for leakDetectionService
```

---

## 🗂️ GitHub Issues

Always create an issue before starting work on a task.

**Issue Titles:**
- `[FEAT] Predictive Thirst Engine`
- `[FIX] JWT not expiring correctly`
- `[DOCS] Write DATABASE_SCHEMA.md`
- `[TEST] Unit tests for qualityService`

**Labels to use:**
- `sprint-1`, `sprint-2`, `sprint-3`, `sprint-4`
- `backend`, `frontend`, `mobile`, `simulator`
- `bug`, `feature`, `documentation`

---

## 🧹 Code Standards

### JavaScript / Node.js
- Use `async/await` — no raw `.then()` chains
- All async functions must have `try/catch`
- Use `const` by default, `let` only when reassignment needed
- File names: `camelCase.js` for files, `PascalCase.js` for classes

### React
- Functional components only (no class components)
- One component per file
- Props destructured in function signature

### Flutter / Dart
- Follow Flutter's standard conventions
- Use `Riverpod` for all state — no `setState` in screens
- All API calls go through `api_service.dart` only

---

## 🔐 Security Rules

- **Never commit `.env` files** — they are gitignored
- **Never hardcode API keys** in code — use `.env` always
- **Never log passwords or tokens** in `console.log`
- Run `git status` before every commit to check no sensitive files are staged
