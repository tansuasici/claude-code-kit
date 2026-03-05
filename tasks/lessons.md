# Lessons Learned

Track corrections and mistakes here. Review at every session start.

---

## Format

```markdown
### [Short title]
- **Issue**: What went wrong
- **Root Cause**: Why it happened
- **Rule**: What to do differently going forward
```

---

## Example

### Edited wrong config file
- **Issue**: Changed `tsconfig.json` instead of `tsconfig.build.json`, broke the build
- **Root Cause**: Assumed there was only one tsconfig without checking
- **Rule**: Always `ls tsconfig*` before editing any TypeScript config

---

<!-- Add new lessons below this line -->
