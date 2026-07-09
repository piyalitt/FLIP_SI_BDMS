# LZA migration — working context log (FLIP#749)

> **Working document for the migration branch.** Session-continuity notes, not product docs — fold
> anything durable into `README.md` ("Deploying to the LZA account") and delete this file before the
> branch merges. Last updated: **2026-07-09**.

## Governing constraint: coexistence

**Legacy FLIP accounts and the LZA account run in parallel until LZA is proven to work fully.**
Nothing before the final, separately-approved decommission (WP6) may modify, degrade, or delete
anything in the legacy accounts. All TF adaptations are env-gated (`PROD=lza`), never replacements;
data migration is copy-based and re-runnable; cutover is DNS-only and reversible, gated on full e2e
parity + team sign-off. Legacy prod/stag deploy paths must stay byte-identical throughout (proven
via `make -n` diff on this branch).

## Accounts, profiles, timing

| | Legacy | LZA |
|---|---|---|
| Accounts | dev `723237626802` / stag `080369786334` / prod `046651569599` | **FLIPProduction `893493035022`** (only workload account; no dev/stag) |
| SSO | sso-session `FLIP`, profiles `stag`/`prod` | sso-session `FLIP_LZA`, profile `FLIPAdminAccess-893493035022` |
| Other LZA accounts | — | Management `878013574147`, SharedServices `270840513093`, Network `004246190022` |

`FLIPAdminAccess` = Allow `*` minus billing/priv-esc/tf-state denies; **not SCP-exempt**.

**Timing:** BDMS is live on legacy prod (Trust_2); DECAF/MICCAI deadline **24 Jul 2026** — no
cutover and no prod deploy-flow switch before then. Platform side is martinchapman
(`londonaicentre/lza` config repo, `londonaicentre/aicentre-lza-iac` TF repo).

## Issue map

- **FLIP#749** — umbrella (WP0 probe → WP1 env-gated TF → WP2 platform asks → WP3 fresh deploy →
  WP4 copy-based data migration w/ S3 audit-first → WP5 parity+cutover → WP6 decommission).
- **FLIP#751 / PR #752** — immutable `sha-<short7>` deploys + task-def revisions (green CI; soft
  prerequisite for WP3 — removes the pull-through-cache mutable-tag staleness class). This branch
  is stacked on `origin/751-immutable-sha-deploys`.
- **lza#33** — Martin's platform resources issue (VPN, CI/CD, DNS, …). Cross-linked from #749.
- **lza#34** — our central-endpoint asks (see WP2 below).

## WP0 — probe findings (done, comment on #749)

- LZA prod VPC **exists**: `vpc-0c4f4ee3ed29818c4` (`AWSAccelerator-eu-west-2-prod`, `10.12.0.0/22`);
  subnets `-app-a` `10.12.0.0/24`, `-data-a` `10.12.1.0/26` (isolated, local routes only),
  `-tgw-a` `10.12.1.64/28` — **all eu-west-2a: single-AZ**. TGW attachment to Network acct
  `available` since 2026-06-25. In-account endpoints: S3 + DynamoDB gateway only.
- `FLIPAdminAccess` is sufficient for the **entire app layer** (KMS/S3/IAM/Lambda/Cognito/Secrets/
  ECS/EFS/CloudMap/ACM/CloudFront/WAF/SES/Route53 all allowed). **us-east-1 is NOT region-denied**
  (CloudFront cert/WAF path fine).
- VPC-layer creates SCP-denied (`GRNETSEC2`: CreateVpc/Subnet/NatGateway/IGW/AllocateAddress/
  **CreateVpcEndpoint**); `GRTGWVPN` makes route edits pipeline-only. RDS subnet group fails
  `DBSubnetGroupDoesNotCoverEnoughAZs` — the single-AZ blocker, proven.

## WP2 — platform asks (endpoint-only; zero internet egress)

Design goal: **zero internet egress from FLIPProduction — no firewall `pass` rules, ever.** If an
egress-rule request appears on FLIP's behalf, that's a smell.

- **Multi-AZ subnets** (`-b`): the hard ALB+RDS blocker. Raised with Martin 2026-07-09, **in flight**.
- **Central interface endpoints** — filed as **lza#34**: `secretsmanager` + `cognito-idp` blocking
  (ECS `valueFrom` secret injection = tasks can't launch; JWKS/token verify + admin ops), `email`
  (SES API) deferrable (best-effort emails no-op without it). Target =
  `network-config.yaml` → Network-acct `-endpoints` VPC → `interfaceEndpoints.endpoints` (~L301).
  All PrivateLink-available in eu-west-2 (verified). `sts` deliberately dropped: task-role creds are
  agent-local, RDS IAM tokens are offline SigV4 — WP3 watches NFW drop logs for surprises.
- **FL-inbound architecture** — still open. FL clients dial the hub fl-server over gRPC+mTLS (L4
  passthrough; kits embed certs; NVFLARE ports 8002/8003). No IGW + VPC-BPA ⇒ no in-account public
  NLB. Options: (A) NLB in the central Ingress VPC (internet trusts, e.g. BDMS), (B) VPN-only
  (VPN firewall currently passes 80/443/ICMP only). Team direction: GSTT VPN grandfathered,
  non-VPN for other routes, don't break BDMS — realistically both.
- DNS zone move + SES identity verification queued behind the platform DNS decision (lza#33).

## Out-of-band resources already live in FLIPProduction (NOT Terraform-managed)

- TF state bucket **`flip-terraform-state-lza`** (versioned, SSE-KMS, PAB). Stays out-of-band
  (chicken-egg, matches legacy `create-backend.sh` practice).
- ECR **pull-through cache rules**, both validated + pull-tested:
  - `ghcr/` → `ghcr.io` (creds = read-only GHCR PAT in Secrets Manager `ecr-pullthroughcache/ghcr`).
    Registry for compose/TF: `893493035022.dkr.ecr.eu-west-2.amazonaws.com/ghcr/londonaicentre/`
    (composes `<registry><name>:<tag>` exactly like the GHCR prefix).
  - `ecr-public/` → `public.ecr.aws`, credential-less — used for the EFS-provision utility image
    (`…/ecr-public/aws-cli/aws-cli:2.22.35`). Eliminates the Docker Hub dependency.
  - Upstream fetch is ECR-service-side (no VPC egress). Mutable tags refresh ≤24h — hence #751
    immutable sha deploys; interim cache-bust = `aws ecr batch-delete-image`.
  - Recommendation: later TF-manage the two rules here (LZA-gated `aws_ecr_pull_through_cache_rule`
    + `terraform import '…ghcr[0]' ghcr` / `'…ecr_public[0]' ecr-public`); keep the PAT secret
    out-of-band. GHCR stays the canonical public registry — single CI push, open-source consumers
    unaffected.

## WP1 — env-gated TF (done on this branch)

Five commits (`9feccf73`…`41425e95`) on top of `origin/751-immutable-sha-deploys`. Design:

- `PROD=lza` → root `.env.lza-prod`, profile guard `LZA_AWS_PROFILE`, kit suffix `.lza-prod`
  (separate namespace — legacy prod kits never overwritten), `deploy-centralhub` ref `origin/main`.
- Two orthogonal axes: `TF_VAR_environment=prod` (LZA is prod-grade; RDS hardening on) +
  `TF_VAR_lza_managed_network=true` (platform-managed network). Never conflated.
- `network_lza.tf`: data lookups by Name tag (`lza_vpc_name`, default `AWSAccelerator-eu-west-2-prod`);
  matches ALL `-app-*`/`-data-*` subnets so the multi-AZ `-b` subnets auto-appear on the next plan.
  Placement: RDS instance → data subnets; ECS tasks / internal ALB / RDS Proxy / EFS mount targets /
  EC2 hosts → app subnets (need TGW → central endpoints).
- Gated OFF on LZA: VPC module, in-account VPC endpoints, DHCP options, `/flip/networking/*` SSM
  params, SG-drift CloudTrail stack, public FL NLB (+TG/DNS/SG/ECS `load_balancer` wiring — fl
  services still deploy, no inbound path yet). State-safety via module `create` flags + `moved`
  blocks (no address churn).
- `MANAGE_DNS=false` (no zone in the account yet): skips zone lookup, all records, both ACM certs;
  CloudFront on default domain + default viewer cert; CF→ALB `/api/*` leg plain HTTP over the
  private VPC-origin ENI (HTTPS listener needs an ISSUED cert); `local.ui_origin` feeds bucket CORS
  + Cognito URLs so sign-in/uploads work. All reverts by flipping the toggle + re-apply.
- Legacy no-op proven: `make -n` for `PROD=stag`/`PROD=true` byte-identical vs the base tip;
  `terraform validate` + `fmt` clean.

**Caveats:** subnet-ID sort order may re-plan bastion/Trust-EC2 when `-b` subnets land (stateless,
acceptable). Root-level `make new-trust PROD=lza` not wired (use `scripts/new_trust.py --env
lza-prod`); the AWS-provider side is consistent. `full-deploy*`, `make status`, `update_env.py`
(NatGatewayPublicIp null on LZA), `make destroy` untested against `PROD=lza`.

## `.env.lza-prod` (generated 2026-07-09, NOT in git)

Lives at the **main tree** repo root, mode 600, `.git/info/exclude`d there (this branch adds the
real `.gitignore` entry). Generated mechanically from local `.env.production`
(scratchpad script `gen_env_lza_prod.py`); regenerate the same way if lost. Never commit; never
paste values into a session transcript (enter secrets out-of-band).

- Overridden: state bucket, `DOCKER_REGISTRY` (ghcr/ cache), `AWS_PROFILE`, five `flip-lza-*`
  buckets (`model-files-uploads`, `fl-results`, `app-bundles`, `aicentre`, `ui`).
- Minted fresh (WP3 runs on fresh secrets; legacy **values** carried over only at WP4 so trust
  kits/encrypted data stay valid — never reuse the legacy secret resource): `INTERNAL_SERVICE_KEY`
  (+hash), `AES_KEY_BASE64`, `ADMIN_USER_PASSWORD`.
- Blanked `TODO(WP3)` (account-derived, post-apply): `DB_HOST`, `POSTGRES_SECRET_ARN`,
  `CENTRAL_HUB_API_URL` (CloudFront default domain), both Cognito IDs, `FLIP_BUCKET_NAME` (the
  legacy single-bucket split migration must never run against LZA).
- Added: `EFS_PROVISION_IMAGE` (ecr-public cache), `MANAGE_DNS=false`, commented `LZA_VPC_NAME`.

## WP3 — first bring-up checklist (online, blocked on multi-AZ for ALB/RDS)

1. `make create-backend PROD=lza` (idempotent) → `make init PROD=lza`.
2. `make plan PROD=lza` — first real evaluation of the tag-based data lookups.
3. `apply` — expect ALB + RDS subnet-group failures until `-b` subnets land; everything else should
   apply. Record SCP/permission failures → WP2.
4. Image pulls via `ghcr/` + the EFS-provision task via `ecr-public/` (exercises the LZA-gated
   `ecr:BatchImportUpstreamImage`/`ecr:CreateRepository` exec-role grant in `iam_ecs.tf`).
5. RDS Proxy master-secret retrieval (validates the app-subnet placement assumption).
6. Default-domain smoke: UI on `*.cloudfront.net`, `/api/*` over the HTTP origin leg, Cognito
   sign-in, presigned upload/download CORS.
7. `deploy-centralhub` / `deploy-ui PROD=lza` (`window.js` must carry the CloudFront domain).
8. Fix up auxiliary tooling as found (`check_status.py`, `update_env.py`, `full-deploy*`, `destroy`).
9. Watch Network Firewall drop logs — expect zero legitimate drops (validates dropping `sts`).
10. When the zone lands: `MANAGE_DNS=true` + plan/apply → certs/records/aliases/HTTPS origin leg.

## Later WPs (queued)

- **WP4** — S3 **audit first** (inventory every legacy bucket/prefix → keep-and-migrate /
  keep-until-teardown / drop), then copy-based re-runnable syncs with re-encryption; RDS
  dump/restore (carries trust registrations — reseeding wipes them); carry legacy secret **values**;
  Cognito users recreated (TOTP re-enrolment is user-visible — comms needed); EFS re-provision from
  kits; SES verify + production-access (lead time — start early).
- **WP5** — full e2e parity gate on LZA + sign-off, then DNS-only reversible cutover (post-24 Jul).
- **WP6** — decommission legacy after burn-in, separately approved.
- Possible follow-up issue: replace the EFS-provision Fargate task with Lambda+EFS.
