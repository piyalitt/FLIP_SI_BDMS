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

# AGENTS.md — flip-api (Central Hub API)

## Re-read the user prompt (user standing instruction)

YOU MUST READ MY PROMPT AGAIN AND CHECK ALL THINGS TO MAKE SURE THAT YOU REALLY GET WHAT I WANT IN THE PROMPT.

Before planning, before the first tool call, and again before you finish:
1. Re-read the current user prompt in full. Do not rely on a remembered summary.
2. Check every requirement, constraint, example, exclusion, path, format, and success criterion the prompt actually contains.
3. Confirm the work matches that list with nothing missing, substituted, or silently dropped. If anything is still unclear or blocked, ask once for that blocker only.

## Service Overview

Central Hub REST API. FastAPI + psycopg2 + SQLModel (sync sessions). Handles user auth (Cognito), project management, trust coordination, FL run orchestration, cohort queries, file management, and scheduling.

## Key Files

| File | Purpose |
|------|---------|
| `src/flip_api/main.py` | FastAPI app factory, middleware, router registration |
| `src/flip_api/config.py` | Pydantic settings, env var loading |
| `src/flip_api/db/database.py` | SQLModel sync `Session` via `get_session()`; lazily-built engine; RDS Proxy + IAM auth `do_connect` hook in prod (FLIP#556); `with Session(...)` block load-bearing on error paths (FLIP#773) |
| `src/flip_api/db/models/main_models.py` | SQLModel ORM: Project, Trust, Model, File, etc. |
| `src/flip_api/db/models/user_models.py` | User, Role, Permission models |
| `src/flip_api/db/seed/` | DB seed data: roles, permissions, FL kit slots, FL scheduler, banners |
| `src/flip_api/db/migrations/` | Alembic migrations (`env.py`, `versions/`); `alembic.ini` at the service root. **Alembic owns the schema** |
| `src/flip_api/domain/schemas/` | Pydantic request/response schemas |
| `src/flip_api/domain/interfaces/` | Repository interfaces (Dependency Inversion) |
| `src/flip_api/auth/` | Cognito JWT verification, auth middleware |
| `src/flip_api/scripts/` | Trust registration + deletion CLIs (`register_trust.py`, `delete_trust.py`), internal-service-key + trust-key + XNAT-credential generation, demo user seeding (`create_demo_users.py`), env utils |

## Service Modules

| Module | Purpose |
| -------- | --------- |
| `user_services/` | Register, authenticate, update/delete users, roles, permissions |
| `project_services/` | Project CRUD, approval workflows |
| `model_services/` | ML model management, metrics, logs, approvals |
| `fl_services/` | FL training initiation, status, stop, file pull |
| `trusts_services/` | Trust registration, health checks, imaging creation |
| `cohort_services/` | Cohort query submission, results retrieval |
| `step_functions_services/` | Step function orchestration (register user, approve, cohort) |
| `file_services/` | S3 model-file upload/download, plus the scan-and-promote pipeline (`services/malware_scan_service.py`) that gates the `uploaded/` → `scanned/` quarantine boundary (#52) |
| `private_services/` | Trust-to-hub internal endpoints (tasks, cohort results) |
| `site_services/` | Site configuration, details |
| `role_services/` | Role CRUD |
| `scheduler/` | APScheduler background jobs (FL scheduling, trust polling, malware-scan reconcile sweep) |
| `shared/` | Shared utilities, middleware |

## Commands (from `flip-api/`)

```bash
make test          # ruff + mypy + pytest (unit + integration)
make unit_test     # ruff + mypy + pytest unit + step function tests (--skip-client)
make integration_test  # Integration tests only
make local_test    # Tests without Docker (--skip-client --skip-db)
make lint          # ruff check --fix (in Docker)
make mypy          # mypy type check (in Docker)
make build         # docker compose build
make up            # Start flip-db then flip-api
make down          # Stop flip-api then flip-db
make debug         # Restart in debug mode (port 5678)
make migrate       # alembic upgrade head (apply migrations)
make migration MESSAGE="..."   # autogenerate a revision from the model diff (flip-db must be up)
make migration_downgrade       # alembic downgrade -1
make migration_history         # alembic history
make migration_current         # alembic current
make demo_video    # record the end-to-end demo video against the running stack (tests/demo_video.py; DEMO_ARGS=...)
make create_demo_users         # provision the demo Cognito users (DEMO_*_PASSWORD from env; restart flip-api after)
make seed_demo_projects        # seed the curated radiology catalogue (EXTRA_ARGS="--cleanup" removes it)
```

## Conventions

- FastAPI `Depends()` for DI. Repository pattern in `domain/interfaces/`.
- Sync SQLModel `Session` via `get_session()` dependency (`db/database.py`); the `with Session(...)` context is load-bearing on FastAPI error paths — a bare `yield` + `session.close()` strands the connection `idle in transaction` (FLIP#773).
- DB schema is owned by **Alembic** (`db/migrations/`), not `SQLModel.metadata.create_all`. The entrypoint runs `alembic upgrade head` before seeding at boot (fail-fast). Every schema-affecting change to `db/models/*.py` must ship a revision — the integration drift guard (`tests/integration/test_migrations.py`) enforces it. Native-PG-enum gotcha: `ALTER TYPE … ADD VALUE` needs `op.get_context().autocommit_block()`, and downgrades dropping an enum-typed table must `DROP TYPE`.
- pytest + factory_boy for test data. Fixtures in `conftest.py`.
- Ruff config: line-length 120, select I/F/E/W/PT + UP006/UP007/UP035/UP042/UP045 (`UP042` enforces `StrEnum` over the legacy `(str, Enum)` pattern).
- All tests in `tests/unit/` and `tests/integration/`.
