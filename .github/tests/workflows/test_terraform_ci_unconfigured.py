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
"""An unseeded GitHub environment skips Terraform CI instead of failing in the AWS action.

``configure-aws-credentials`` requires ``aws-region``. An empty ``vars.AWS_REGION``
fails the step with ``Input required and not supplied: aws-region`` before the
missing role is reported, which is what a fork's nightly drift run does. The gate
step decides, and every later step in the same job has to honour ``run``. A step
added without that ``if`` calls AWS anyway and the red nightly comes back.

Job-level ``if`` cannot do this: it is evaluated before the environment loads, so
``vars.TF_PLAN_ROLE_ARN`` there is the repository variable, not the ``aws-stag``
one. Read as text, like the other workflow tests.

Usage:
    python3 .github/tests/workflows/test_terraform_ci_unconfigured.py
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path

WORKFLOWS = Path(__file__).resolve().parents[2] / "workflows"
REPO_ROOT = WORKFLOWS.parents[1]
GATE = "steps.tf-ci.outputs.run == 'true'"
REGION = "vars.AWS_REGION || 'eu-west-2'"
# setup-github-environments.sh harvests `KEY: ${{ vars.NAME }}` from
# terraform_plan.yml. The role ARN is written from IAM, not from the operator
# env file, so the gate must not use that shape for it.
# Same shape as the `grep -oE` in setup-github-environments.sh. Python has no
# POSIX classes, so this is `\s` rather than `[[:space:]]`; the two agree on
# the lines these workflows actually contain.
HARVEST = re.compile(
    r"^\s+[A-Z][A-Z0-9_]*:\s+\$\{\{\s*vars\.[A-Z0-9_]+",
    re.MULTILINE,
)

JOBS = (
    ("terraform_plan.yml", "plan", "TF_PLAN_ROLE_ARN"),
    ("terraform_apply.yml", "apply", "TF_APPLY_ROLE_ARN"),
    ("terraform_drift.yml", "drift", "TF_PLAN_ROLE_ARN"),
)


def job_body(workflow: str, job: str) -> str:
    text = (WORKFLOWS / workflow).read_text()
    block = re.search(rf"^  {job}:\n(?P<body>(?:    [^\n]*\n|\s*\n)*)", text, re.MULTILINE)
    assert block, f"{workflow}: no job '{job}'"
    return block["body"]


def steps(body: str) -> list[str]:
    parts = re.split(r"(?=^      - name: )", body, flags=re.MULTILINE)
    return [part for part in parts if part.startswith("      - name:")]


class TerraformCiUnconfigured(unittest.TestCase):
    def test_every_step_after_the_gate_is_conditional(self) -> None:
        for workflow, job, role in JOBS:
            with self.subTest(workflow=workflow):
                chunks = steps(job_body(workflow, job))
                gate_at = next(
                    (i for i, chunk in enumerate(chunks) if "id: tf-ci" in chunk),
                    None,
                )
                assert gate_at is not None, f"{workflow}:{job} has no tf-ci step"
                gate = chunks[gate_at]
                assert "terraform-ci-gate.sh" in gate, gate
                assert f"ROLE_VAR: {role}" in gate, gate
                assert f"vars['{role}']" in gate, gate
                # Bracket form, not `vars.NAME`, so the seeding script does not
                # harvest the role (or the gate's copies of TF_HUB / the bucket)
                # as an env-file input.
                assert HARVEST.search(gate) is None, gate
                assert HARVEST.search("          ROLE_ARN: ${{ vars." + role + " }}\n"), (
                    "the harvest regex stopped matching a dotted vars reference"
                )
                assert "name: Configure AWS credentials" in chunks[gate_at + 1]
                for chunk in chunks[gate_at + 1 :]:
                    name = chunk.splitlines()[0].strip()
                    assert GATE in chunk, f"{workflow}:{job} {name} does not check the gate"

    def test_region_falls_back_to_the_stack_default_and_only_there(self) -> None:
        script = (REPO_ROOT / "deploy/providers/AWS/scripts/terraform-ci-gate.sh").read_text()
        assert 'DEFAULT_AWS_REGION="eu-west-2"' in script
        for workflow, _, _ in JOBS:
            with self.subTest(workflow=workflow):
                text = (WORKFLOWS / workflow).read_text()
                assert f"aws-region: ${{{{ {REGION} }}}}" in text
                assert text.count(f"region=${{{{ {REGION} }}}}") >= 1
                assert f"AWS_REGION: ${{{{ {REGION} }}}}" in text
                # A bare `vars.AWS_REGION }}` is the input the action rejects
                # when the variable is unset. The fallback form does not match.
                assert "vars.AWS_REGION }}" not in text

    def test_the_drift_dispatch_is_not_gated_on_aws(self) -> None:
        """Production dispatch does not assume a role. The staging skip must not stop it."""
        body = job_body("terraform_drift.yml", "dispatch-prod")
        assert "tf-ci" not in body
        assert "needs:" not in body


if __name__ == "__main__":
    unittest.main()
