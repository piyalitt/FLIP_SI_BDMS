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

# AGENTS.md — trust/omop-db

## Re-read the user prompt (user standing instruction)

YOU MUST READ MY PROMPT AGAIN AND CHECK ALL THINGS TO MAKE SURE THAT YOU REALLY GET WHAT I WANT IN THE PROMPT.

Before planning, before the first tool call, and again before you finish:
1. Re-read the current user prompt in full. Do not rely on a remembered summary.
2. Check every requirement, constraint, example, exclusion, path, format, and success criterion the prompt actually contains.
3. Confirm the work matches that list with nothing missing, substituted, or silently dropped. If anything is still unclear or blocked, ask once for that blocker only.

## What this directory is

Two halves of one pipeline (merged from the retired private `flip-omop-db` repo, FLIP#834):

1. **Image build source** for `ghcr.io/londonaicentre/omop-db`: `Dockerfile` on `postgres:17` bakes the
   `files/` init chain (create `omop` schema → OMOP CDM 5.4 DDL → primary keys → indices → read-only
   roles) plus the seed-time helpers (`load_core_vocab.sh`, `constraints.sql`, and `unzip` — the
   k8s vocab-load Job unpacks the bundle with the image's own copy so it installs nothing at
   run time, keeping S3 the only host it must reach). The image is
   **vocab-free** (FLIP#842) — nothing licensed in any layer — so it is published by CI
   (`docker_build_omop_db.yml`, gated on the "Trust - OMOP DB CI" test workflow like the other
   services). FK **constraints are deliberately absent from init** — they are applied only AFTER data
   load (loading after constraints fails).
2. **Consumer harness** for the dev trust stacks: `update_omop_data.sh` downloads ready-populated,
   **vocab-free** pgdata volumes (~11 MB each, versioned by `.data_version`) from the public HF dataset
   `aicentreflip/trust-data` into `volumes/Trust_<N>/db_data`, which
   `trust/deploy/compose_trust.<env>.yml` mounts.

`compose.yml` here is the **standalone build/populate stack** (one empty DB per trust + opt-in pgadmin
profile; config from gitignored `.env.build`), NOT the runtime trust stack.

## The vocabulary seeding model (FLIP#842/#843)

No published artifact (image, pgdata tarball, HF dataset) carries the licensed core vocabulary. Every
environment loads it ONCE into the running database via `files/load_core_vocab.sh` (client-side
`COPY FROM STDIN` over TCP — no mounts, no server-side files; idempotent via core-aware guards that
tolerate the DICOM vocab already present in the tarballs):

- **Dev**: `make load-omop-vocab [OMOP_DB_PORT=5436]` (after `update-omop-data` + stack up). Cohort
  queries joining `omop.concept` return nothing until this runs.
- **EC2**: the "load OMOP core vocabulary on Trust EC2" Ansible play (part of `seed-trust-data`;
  throwaway container on loopback port 15499; kit credentials passed by the AWS Makefile).
- **Kubernetes**: the chart's `omop-vocab-load` post-install/post-upgrade hook Job
  (`omopDb.vocabLoad` values; bundle from S3, loader + constraints from the image). Its first
  stage runs `load_core_vocab.sh --check` and skips the multi-GB fetch when the database is
  already loaded — the hook sits on the critical path of every `helm upgrade`, so the fetch
  must stay conditional. The loader still runs (constraints).

## Load-bearing facts

- **`.data_version` must not move**: its path is hardcoded in `deploy/providers/AWS/Makefile`, which
  passes the value on to Ansible (`-e omop_data_version=`); the Helm chart consumes it via the
  `OMOP_DATA_VERSION` env var in `generate_values.py`.
- **Vocabulary licensing**: the core vocab bundle — an OHDSI Athena export, 59 vocabularies incl.
  SNOMED CT, LOINC, Read, dm+d (roster + versions in README "The core vocabulary bundle") — is licensed
  material: `data/` is gitignored and must never be committed or published. Acquisition: org members via
  `make fetch-vocab-core` from `s3://$(VOCAB_S3_BUCKET)/vocab/` (default `flipdev-aicentre`, org AWS
  needed); external users self-serve an equivalent export from OHDSI Athena under their own licences.
  The DICOM vocab (byte-identical to DICOM2OMOP `files/OMOP CDM Staging/` @ upstream `1ef3354`, Apache
  2.0, pickle converted to CSV) is freely redistributable: it lives on the HF dataset and stays inside
  the published tarballs.
- **Read-only roles are a security boundary**: `files/create_readonly_users.sql` creates
  `omop_readonly_base` + `data_analyst_reader` (SELECT-only, explicit REVOKEs) — the database half of
  data-access-api's SQL-injection defence-in-depth (`data_access_api/services/cohort.py`). The analyst
  password is NOT in the image — it is set at first init from `DATA_ACCESS_POSTGRES_PASSWORD` and lives
  in the pgdata volume; rotate via `ALTER ROLE` + kit update, or rebuild volumes with a new `.env.build`
  value (see CONTRIBUTING.md).
- **Canonical dataset + N-trust split** (`src/omop_db_tools/dataset.py`): mock rows are ONE dataset on
  HF (`omop-csv/<version>/`), each row tagged `source_trust`. Partition modes: `legacy` (default —
  reproduces the original two-trust membership; REQUIRED for data consistent with the published mock
  Orthanc PACS volumes, whose studies match each trust's accession IDs) and `modulo`
  (`person_id % N`, any trust count, needs regenerated imaging data). All tables carry `person_id`, so
  person-level partitioning preserves referential integrity.
- The populate scripts run on the **host** against published ports (`OMOP_DB_HOST` defaults to
  localhost) and need postgresql-client (`psql`/`pg_isready`).

## Commands

```bash
make update-omop-data [TRUST=1|2]   # consumer path: sync vocab-free pgdata volumes from HF
make load-omop-vocab [OMOP_DB_PORT=5436]  # seed the licensed vocab + constraints into a running trust DB
cp .env.build.example .env.build    # once, before any build-pipeline target
make build                          # plain docker build — no data inputs, no credentials
make up-build / down-build          # the standalone per-trust build DBs
make populate [NUM_TRUSTS=N PARTITION=modulo]  # core vocab + DICOM vocab + N trust slices (shipped
                                               # stack is two-trust; N>2 needs a compose service + port)
make populate CORE_VOCAB=0          # vocab-free flavour for publishable tarballs (skip apply-constraints!)
make export-pgdata                  # tar each volume -> dist/trust<N>_pgdata_<.data_version>.tar
make apply-constraints              # AFTER a full populate
make push [OMOP_DB_TAG=...]         # manual publish escape hatch (CI publishes normally); confirms first
make local_test                     # ruff + mypy + pytest tests/unit (no DB needed)
```

## Conventions

- uv project `omop-db-tools` (`src/omop_db_tools/` layout); registered in root `Makefile` `UV_PROJECTS`
  and the `uv-lock` pre-commit hooks. Tests live in `tests/unit/` only — anything touching a real
  Postgres belongs in `tests/integration/` (none yet).
- SQL identifiers interpolated into statements must pass `import_tables.validate_identifier`.
- The vocab/dataset bundles under `data/`, exported tarballs under `dist/`, and the build env
  (`.env.build`) are gitignored — keep it that way.
