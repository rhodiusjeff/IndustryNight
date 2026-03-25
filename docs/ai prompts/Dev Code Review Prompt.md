## Dev Code Review — Sanity Check

Run this in the track agent (same Copilot window doing the implementation) before opening a PR. Not a full adversarial review — just a quick self-check pass on the code you just wrote.

---

Review the changes in the current working branch against `integration`:

```bash
git diff integration...HEAD -- packages/
```

Check for:

1. **SQL injection** — any string interpolation in raw SQL queries? All user input must use parameterized queries (`$1`, `$2`, etc.).

2. **Auth gaps** — are any new routes missing `authenticate`, `authenticateAdmin`, or `requireAdmin` middleware where they should have it?

3. **snake_case JSON** — do any new Dart models use `@JsonSerializable()` without `fieldRename: FieldRename.snake`? (Exception: `AdminUser` which intentionally uses camelCase.)

4. **Dead code / TODOs** — any `TODO`, `FIXME`, or commented-out blocks left in? List them; decide if they should be removed or tracked as issues.

5. **Error handling at boundaries** — are user inputs (API request bodies, query params) validated with Zod before touching the DB? No validation needed for internal calls.

6. **Obvious logic errors** — wrong variable used, off-by-one, condition inverted, early return missing.

7. **Test coverage gap** — did you add a new route, model, or critical code path with no corresponding test? Note it.

---

Output: a short bulleted list of anything found. "Nothing found" is a valid result. Do not fix anything — flag only. The PR Copilot review in GitHub will do a deeper pass.
