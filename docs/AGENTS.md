# AGENTS.md — FLIP Documentation

## Re-read the user prompt (user standing instruction)

YOU MUST READ MY PROMPT AGAIN AND CHECK ALL THINGS TO MAKE SURE THAT YOU REALLY GET WHAT I WANT IN THE PROMPT.

Before planning, before the first tool call, and again before you finish:
1. Re-read the current user prompt in full. Do not rely on a remembered summary.
2. Check every requirement, constraint, example, exclusion, path, format, and success criterion the prompt actually contains.
3. Confirm the work matches that list with nothing missing, substituted, or silently dropped. If anything is still unclear or blocked, ask once for that blocker only.

## Documentation Index (read on demand)

| File | Topic |
|------|-------|
| `source/overview.rst` | Project overview, architecture, motivation |
| `source/components.rst` | Component descriptions (API, UI, trust services, FL nodes) |
| `source/sys-admin.rst` | System administration, deployment, auth configuration |
| `source/user-guides.rst` | User-facing workflows and guides |
| `source/api-reference.rst` | REST API endpoint reference |
| `source/deploy-flip.rst` | Deployment instructions (central hub, TRE, on-prem) |
| `source/working-with-flip-apps.rst` | Building FL apps (NVFLARE / Flower) |
| `source/flip-workflow.rst` | End-to-end FLIP workflow |
| `source/faqs.rst` | Frequently asked questions |
| `source/glossary.rst` | Terminology definitions |

## Sub-docs

| Directory | Topic |
|-----------|-------|
| `source/components/` | Per-component deep dives (FL nodes, XNAT, OMOP, logging stack, architecture overview) |
| `source/sys-admin/` | Admin tasks (user roles, project/user management, platform support) |
| `source/user-guides/` | User guide files |
| `source/deploy-flip/` | Per-target deployment guides (central hub, TRE, on-prem) |
| `source/working-with-flip-apps/` | Step-by-step FLARE / Flower app authoring |

## How to Read

When implementing a feature that touches documentation, read the relevant `.rst` file(s) above. These are ReStructuredText format used by Sphinx for ReadTheDocs builds.

## Build Commands

```bash
cd docs && make clean    # Clean built docs
cd docs && make docs     # Build Sphinx HTML documentation
```
