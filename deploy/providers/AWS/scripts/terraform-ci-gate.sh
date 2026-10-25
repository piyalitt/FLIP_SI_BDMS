#!/usr/bin/env bash
#
# Copyright (c) 2026 Guy's and St Thomas' NHS Foundation Trust & King's College London
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#     http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Decide whether a Terraform CI job (plan, apply, drift) can talk to AWS.
#
# Those jobs assume an OIDC role from a GitHub *environment* variable and pass
# AWS_REGION to configure-aws-credentials, which treats an empty region as
# "Input required and not supplied: aws-region". A fork of this repository has
# the workflows and none of the environment: the first scheduled drift run, and
# every develop push that touches the stack, fails there before the missing role
# is even mentioned. A permanently red nightly is how a real failure comes to be
# ignored, so an environment that was never seeded skips the AWS steps and says
# so, instead of failing inside the action.
#
# "Never seeded" is all three of these being blank, not the role alone:
#
#   * ROLE_ARN            — TF_PLAN_ROLE_ARN (plan, drift) or TF_APPLY_ROLE_ARN
#   * TF_HUB              — the estate selector; compose-ci-env.sh has no default
#   * STATE_BUCKET        — FLIP_TFSTATE_BUCKET_NAME
#
# A role that has been deleted while the hub or the state bucket is still set is
# a broken seeded environment. That fails the job, with the missing variable
# named. Skipping it would turn a wiped role into a green apply that applied
# nothing.
#
# A set role with a blank AWS_REGION still runs. The workflows pass eu-west-2,
# the region this stack is written for (site.yml, update_ssm_ssh_config.py,
# reconcile_ci_env.py --region). This script only warns; the expression
# `vars.AWS_REGION || 'eu-west-2'` in the workflows is what the action receives,
# and .github/tests/workflows/test_terraform_ci_unconfigured.py pins the two
# together. An action input cannot call this script.
#
# Outputs (GITHUB_OUTPUT):
#   run=true|false
#
# Exit 0 when the job should continue or when it should skip. Exit 1 only for
# the half-configured case above.

set -euo pipefail

# The region this stack is written for. Kept in step with the workflow
# expressions; the test named above fails if they diverge.
DEFAULT_AWS_REGION="eu-west-2"

ROLE_ARN="${ROLE_ARN:-}"
AWS_REGION="${AWS_REGION:-}"
TF_HUB="${TF_HUB:-}"
STATE_BUCKET="${STATE_BUCKET:-}"
ROLE_VAR="${ROLE_VAR:-the OIDC role ARN}"

# Blank means empty or whitespace. The value itself is never rewritten: the
# workflows pass vars straight through to the action, and this script only
# decides.
is_blank() {
    [[ -z "${1//[[:space:]]/}" ]]
}

emit() {
    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
        printf '%s\n' "$1" >>"${GITHUB_OUTPUT}"
    fi
}

if is_blank "${ROLE_ARN}" && is_blank "${TF_HUB}" && is_blank "${STATE_BUCKET}"; then
    emit "run=false"
    echo "::warning title=Terraform CI is not configured::${ROLE_VAR}, TF_HUB and FLIP_TFSTATE_BUCKET_NAME are unset, so this job skipped AWS. Seed the GitHub environment to enable it (deploy/providers/AWS/README.md). AWS_REGION for this stack is ${DEFAULT_AWS_REGION}."
    if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
        cat >>"${GITHUB_STEP_SUMMARY}" <<EOF
### Terraform CI is not configured

This job did not call AWS. \`${ROLE_VAR}\`, \`TF_HUB\` and \`FLIP_TFSTATE_BUCKET_NAME\` are all unset on its GitHub environment, so there is no OIDC role to assume and no estate to select.

That is expected for a repository that has not been seeded. A fork does not inherit \`aws-stag\` / \`aws-prod\` from upstream. The job stays green instead of failing in \`configure-aws-credentials\` with \`Input required and not supplied: aws-region\`.

To run plan, apply and drift against an account this repository owns, seed the environment with \`deploy/providers/AWS/scripts/setup-github-environments.sh\`. See \`deploy/providers/AWS/README.md\`, "Terraform CI". \`AWS_REGION\` for this stack is \`${DEFAULT_AWS_REGION}\`.
EOF
    fi
    exit 0
fi

if is_blank "${ROLE_ARN}"; then
    emit "run=false"
    echo "::error title=Terraform CI role is unset::${ROLE_VAR} is empty, but TF_HUB or FLIP_TFSTATE_BUCKET_NAME is set. This environment is half-configured, so the job fails rather than skipping. Set ${ROLE_VAR} from the CI bootstrap module on this GitHub environment."
    exit 1
fi

emit "run=true"
if is_blank "${AWS_REGION}"; then
    echo "::warning title=AWS_REGION is unset::Using ${DEFAULT_AWS_REGION}, the region this stack is written for. Set AWS_REGION on the GitHub environment to make that choice explicit."
fi
exit 0
