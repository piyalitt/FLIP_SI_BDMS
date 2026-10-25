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

# Black-box tests for scripts/terraform-ci-gate.sh — the step that keeps an
# unseeded GitHub environment from failing inside configure-aws-credentials.
#
# The decision under test is the one the workflows cannot express in a job-level
# `if`: environment variables are not loaded yet there. An environment with no
# role, no TF_HUB and no state bucket has never been seeded and must skip
# (exit 0, run=false). A role that has gone missing while the rest is still set
# must fail (exit 1). A set role runs, and a blank region only warns.
#
# Usage:
#     bash deploy/providers/AWS/scripts/tests/test_terraform_ci_gate.sh

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$(cd "${HERE}/.." && pwd)/terraform-ci-gate.sh"

TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "${TEST_ROOT}"' EXIT

PASS=0
FAIL=0

ok() {
    echo "   ✅ $1"
    PASS=$((PASS + 1))
}

no() {
    echo "   ❌ $1"
    shift
    for line in "$@"; do echo "      ${line}"; done
    FAIL=$((FAIL + 1))
}

# Run the gate. Positional args are the five inputs; empty string is a blank value.
# Sets RC, OUT, SUM, STDOUT.
run_gate() {
    local role="$1" region="$2" hub="$3" bucket="$4" role_var="$5"
    OUT="${TEST_ROOT}/out"
    SUM="${TEST_ROOT}/sum"
    : >"${OUT}"
    : >"${SUM}"
    RC=0
    STDOUT="$(
        ROLE_ARN="${role}" AWS_REGION="${region}" TF_HUB="${hub}" STATE_BUCKET="${bucket}" ROLE_VAR="${role_var}" \
            GITHUB_OUTPUT="${OUT}" GITHUB_STEP_SUMMARY="${SUM}" \
            "${SCRIPT}" 2>&1
    )" || RC=$?
}

echo "==== terraform-ci-gate.sh ===="

echo "-- never seeded: skip"
run_gate "" "" "" "" "TF_PLAN_ROLE_ARN"
[[ "${RC}" -eq 0 ]] && ok "exits 0" || no "exits 0" "rc=${RC}" "stdout: ${STDOUT}"
grep -qx 'run=false' "${OUT}" && ok "run=false" || no "run=false" "$(cat "${OUT}")"
grep -q 'title=Terraform CI is not configured' <<<"${STDOUT}" && ok "warns" || no "warns" "${STDOUT}"
grep -q 'TF_PLAN_ROLE_ARN' <<<"${STDOUT}" && ok "names the role variable" || no "names the role variable" "${STDOUT}"
grep -q 'eu-west-2' <<<"${STDOUT}" && ok "names the stack region" || no "names the stack region" "${STDOUT}"
grep -q '::error' <<<"${STDOUT}" && no "does not error" "${STDOUT}" || ok "does not error"
grep -q 'Terraform CI is not configured' "${SUM}" && ok "writes the job summary" || no "writes the job summary" "$(cat "${SUM}")"
grep -q 'setup-github-environments.sh' "${SUM}" && ok "summary points at the seeding script" || no "summary points at the seeding script" "$(cat "${SUM}")"

echo "-- whitespace-only inputs are blank"
run_gate "   " $'\t' "  " "" "TF_APPLY_ROLE_ARN"
[[ "${RC}" -eq 0 ]] && grep -qx 'run=false' "${OUT}" && ok "whitespace skips" || no "whitespace skips" "rc=${RC}" "$(cat "${OUT}")"
grep -q 'TF_APPLY_ROLE_ARN' <<<"${STDOUT}" && ok "apply role name is the one warned about" || no "apply role name is the one warned about" "${STDOUT}"

echo "-- a region on its own is still unconfigured"
run_gate "" "eu-west-2" "" "" "TF_PLAN_ROLE_ARN"
[[ "${RC}" -eq 0 ]] && grep -qx 'run=false' "${OUT}" && ok "region without a role still skips" || no "region without a role still skips" "rc=${RC}" "$(cat "${OUT}")" "${STDOUT}"

echo "-- half-configured: hub set, role missing"
run_gate "" "" "stag" "" "TF_PLAN_ROLE_ARN"
[[ "${RC}" -eq 1 ]] && ok "exits 1" || no "exits 1" "rc=${RC}" "${STDOUT}"
grep -qx 'run=false' "${OUT}" && ok "run=false so later steps stay skipped" || no "run=false so later steps stay skipped" "$(cat "${OUT}")"
grep -q 'title=Terraform CI role is unset' <<<"${STDOUT}" && ok "names the failure" || no "names the failure" "${STDOUT}"
grep -q 'Terraform CI is not configured' "${SUM}" && no "does not claim the environment was never seeded" "$(cat "${SUM}")" || ok "does not claim the environment was never seeded"

echo "-- half-configured: state bucket set, role missing"
run_gate "" "eu-west-2" "" "flip-terraform-state-stag" "TF_APPLY_ROLE_ARN"
[[ "${RC}" -eq 1 ]] && grep -q 'TF_APPLY_ROLE_ARN' <<<"${STDOUT}" && ok "bucket without a role fails and names the apply role" || no "bucket without a role fails and names the apply role" "rc=${RC}" "${STDOUT}"

echo "-- seeded: role and region set"
run_gate "arn:aws:iam::000000000000:role/plan" "eu-west-2" "stag" "flip-terraform-state-stag" "TF_PLAN_ROLE_ARN"
[[ "${RC}" -eq 0 ]] && grep -qx 'run=true' "${OUT}" && ok "run=true" || no "run=true" "rc=${RC}" "$(cat "${OUT}")" "${STDOUT}"
[[ -z "${STDOUT}" ]] && ok "no annotation when both are set" || no "no annotation when both are set" "${STDOUT}"
[[ ! -s "${SUM}" ]] && ok "no summary when the job will run" || no "no summary when the job will run" "$(cat "${SUM}")"

echo "-- seeded role, blank region: run and warn, do not invent a failure"
run_gate "arn:aws:iam::000000000000:role/plan" "" "stag" "flip-terraform-state-stag" "TF_PLAN_ROLE_ARN"
[[ "${RC}" -eq 0 ]] && grep -qx 'run=true' "${OUT}" && ok "still runs" || no "still runs" "rc=${RC}" "$(cat "${OUT}")"
grep -q 'title=AWS_REGION is unset' <<<"${STDOUT}" && grep -q 'eu-west-2' <<<"${STDOUT}" && ok "warns and names eu-west-2" || no "warns and names eu-west-2" "${STDOUT}"

echo "-- role alone is enough to run (TF_HUB stays the compose step's problem)"
run_gate "arn:aws:iam::000000000000:role/plan" "us-east-1" "" "" "TF_PLAN_ROLE_ARN"
[[ "${RC}" -eq 0 ]] && grep -qx 'run=true' "${OUT}" && ok "role without hub or bucket runs" || no "role without hub or bucket runs" "rc=${RC}" "$(cat "${OUT}")" "${STDOUT}"
grep -q 'AWS_REGION is unset' <<<"${STDOUT}" && no "a set region is not warned about" "${STDOUT}" || ok "a set region is not warned about"

echo ""
echo "${PASS} passed, ${FAIL} failed"
[[ "${FAIL}" -eq 0 ]]
