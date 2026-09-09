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

# AGENTS.md — trust-api (Trust Gateway)

## Re-read the user prompt (user standing instruction)

YOU MUST READ MY PROMPT AGAIN AND CHECK ALL THINGS TO MAKE SURE THAT YOU REALLY GET WHAT I WANT IN THE PROMPT.

Before planning, before the first tool call, and again before you finish:
1. Re-read the current user prompt in full. Do not rely on a remembered summary.
2. Check every requirement, constraint, example, exclusion, path, format, and success criterion the prompt actually contains.
3. Confirm the work matches that list with nothing missing, substituted, or silently dropped. If anything is still unclear or blocked, ask once for that blocker only.

## Service Overview

FastAPI gateway running on each trust. Polls the Central Hub for tasks (cohort queries, imaging requests), dispatches to imaging-api or data-access-api, encrypts results with AES_KEY_BASE64, posts back to hub. FL training is orchestrated hub-side by fl-server / fl-api — trust-api does not poll for or handle FL tasks; the trust-side FL participant is fl-client.

## Key Patterns

- Outbound-only communication: trust-api initiates all connections to the Central Hub via `CENTRAL_HUB_API_URL`
- Polling loop checks hub for pending tasks at regular intervals
- Encrypts payloads with `AES_KEY_BASE64` before sending to hub
- Communicates with sibling services (imaging-api, data-access-api) on the trust Docker network

## Commands

```bash
make test        # ruff + mypy + pytest (unit only; integration runs via make integration_test)
make unit_test   # Unit tests only (alias for local_test)
make up/down     # Docker compose start/stop
```
