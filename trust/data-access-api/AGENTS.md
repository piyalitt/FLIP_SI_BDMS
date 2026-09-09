<!-- USER-COMPLETION-REDEPLOY-GATE:BEGIN -->
## Latest request, complete execution, and verified delivery (user standing instruction)

1. Before planning or acting, and again immediately before any completion report, re-read the user's current request and every applicable follow-up in full. Preserve all outstanding requirements. A later correction replaces conflicting earlier wording, roles, ordering, defaults, scope, or destinations; never restore an older requirement or completion report as the current task.
2. Keep a concise requirement checklist for the active task. Include every requested change, exact name/title/label, order, language/default, exclusion, deliverable, destination/URL/environment, deployment, and external action. Mark each item pending, verified, or blocked with its evidence. A new message must update this checklist before work continues.
3. Before any completion claim ("done", "fixed", "updated", "complete", "ready", or equivalent), compare every checklist item against the actual latest result at the requested destination. Inspect the rendered/exported artifact or live behaviour, not only source files, a build, test counts, a previous screenshot, or an earlier release. Verify exact user-specified wording and defaults explicitly.
4. If any authorised, in-scope requirement is missing or incorrect, do the remaining work, correct it, and repeat the relevant checks before reporting completion. Do not stop at a partial result or ask the user to repeat an already clear instruction. If the user stops the task or an actual blocker prevents completion, report the unfinished item and the exact blocker honestly; never describe the whole task as finished.
5. Keep local edits, successful builds/tests, deployed revisions, live verification, and sent/submitted external actions distinct. Evidence for one does not prove the others. Use completion evidence from the latest requested version after the final correction, not an older version that passed tests.
6. If the user challenges a completion claim, check the actual instruction/action sequence before explaining it. Correct inaccurate claims directly. Do not invent a chronology or a reason, or blame an unclear prompt when the requirement was explicit.

## Every deployed-product fix includes redeployment (user standing instruction)

1. A user-requested fix to a deployed website, app, or service includes the full cycle: fix -> relevant validation -> redeploy to the authorised target -> inspect the live result. This includes copy, names, roles, ordering, default language, styling, and small UI fixes. Do not report such a fix as finished while it exists only locally or only on an earlier deployment.
2. Resolve the exact target from the user's latest instructions and current repository configuration. An explicit main/production URL requires that target; a DEV deployment cannot satisfy it. Carry forward existing authorisation for the same project's same target and in-scope follow-up fixes; do not ask for it again merely because another correction is needed.
3. Respect explicit stop/wait instructions, authentication and platform gates, and still-applicable repository deployment restrictions. Do not silently switch targets or broaden production, DNS, data, or external-message scope. If the required deployment is blocked, finish independent authorised work and report the deployment as incomplete with the exact blocker.
4. After the last fix and redeploy, reload the exact user-facing URL, confirm the corrected content/behaviour and affected language/responsive states, and verify the intended revision or content fingerprint where available. If another correction is made, repeat the relevant deploy-and-verify cycle. A deployment command succeeding is not sufficient proof that the user sees the fix.
5. This deployment requirement applies to deployable product changes. Instruction-only or other non-runtime file edits are verified in their saved files; they do not trigger deployment of unrelated websites or services. Explicit user requests for file-only or no-deploy work remain controlling.
<!-- USER-COMPLETION-REDEPLOY-GATE:END -->

# AGENTS.md — data-access-api (OMOP Queries)

## Re-read the user prompt (user standing instruction)

YOU MUST READ MY PROMPT AGAIN AND CHECK ALL THINGS TO MAKE SURE THAT YOU REALLY GET WHAT I WANT IN THE PROMPT.

Before planning, before the first tool call, and again before you finish:
1. Re-read the current user prompt in full. Do not rely on a remembered summary.
2. Check every requirement, constraint, example, exclusion, path, format, and success criterion the prompt actually contains.
3. Confirm the work matches that list with nothing missing, substituted, or silently dropped. If anything is still unclear or blocked, ask once for that blocker only.

## Service Overview

FastAPI service for querying the OMOP Common Data Model database. Receives cohort query requests from trust-api, translates them to SQL, executes against omop-db, and returns results.

## Key Patterns

- Connects to omop-db (PostgreSQL port 5432) on the trust network
- Receives internal requests from trust-api (all `/cohort` endpoints) and from imaging-api (`/cohort/accession-ids`); not directly exposed
- Every internal caller authenticates with the per-trust `TRUST_INTERNAL_SERVICE_KEY` header (see the root `AGENTS.md` "Trust-internal Service Authentication" section). `/health` stays unauthenticated
- OMOP CDM query translation layer
- `services/cohort.py::validate_query` is the **authority** on cohort-query safety: one parse-validate-emit pass that returns the query re-emitted from the AST it checked. Pass that return value to the engine, never the caller's raw string. The hub runs its own pre-check, but it is fast-feedback only and deliberately weaker — never relax a rule here on the assumption the hub filtered first, and do not mirror trust-local rules onto the hub. See [`README.md`](README.md#cohort-query-validation)
- Both row-level routes — `/cohort/dataframe` (FL training data) and `/cohort/accession-ids` (the accession list that decides whose imaging is pulled into XNAT) — are gated on `COHORT_QUERY_THRESHOLD` and share one fixed refusal string, so a below-threshold cohort is indistinguishable from an empty one and the refusal cannot act as a row-count oracle. The trust enforces this itself; the hub's staging guard is not relied on
- The gates evaluate the **live** cohort on every call, not the cohort as approved. The cohort query is re-run against OMOP at every stage (the imaging status poll alone re-runs it roughly every 10s while a project page is open), so a project can import cleanly and later start refusing. There is no frozen approved-cohort artefact anywhere in FLIP — see FLIP#857
- `COHORT_QUERY_THRESHOLD` is the trust's own disclosure floor (default 10), set per trust in its kit file. It is a `PositiveInt`: `0` would disable both row-level gates (`len(df) < 0` is never true) *and* the statistics suppression at once, so a non-positive value is rejected at import and the service refuses to start rather than run with no floor. Its default lives in one place — the module-level `DEFAULT_COHORT_QUERY_THRESHOLD`, read by both the field default and the empty-string coercion validator; do not re-inline the literal. Requiring the value to be at least the shipped 10 rather than merely positive is FLIP#870. Any new non-`str` setting needs its own empty-string coercion validator: the service Makefile's `export $(shell sed 's/=.*//' $(KIT_ENV_FILE))` strips values from commented lines too, so a commented-out entry arrives as `""` and pydantic rejects it at import

## Commands

```bash
make test        # ruff + mypy + pytest (unit only; integration runs via make integration_test)
make unit_test   # Unit tests only
```
