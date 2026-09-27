import importlib.util
from datetime import datetime, timezone
import json
from pathlib import Path
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("deploy", Path(__file__).with_name("deploy-parallel.py"))
deploy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(deploy)
credentials = json.dumps({"AccessKeyId": "test", "SecretAccessKey": "test", "SessionToken": "test"})
cases = [
    ([" M src/app/page.tsx"], "Commit or stash"),
    (["", "feature/unapproved"], "Only main"),
    (["", "main", "someone/another-repo"], "Unexpected repository"),
    (["", "main", "fennelouski/Fonsters", credentials, '{"Account":"000000000000"}'], "Unexpected AWS account"),
]
for results, message in cases:
    with patch.object(deploy, "output", side_effect=results), patch.object(deploy.subprocess, "run") as run, patch("sys.argv", ["deploy-parallel.py"]), patch.object(deploy, "check_parallel_window"):

        try:
            deploy.main()
        except RuntimeError as error:
            assert message in str(error)
        else:
            raise AssertionError("Unsafe deployment was not blocked")
        run.assert_not_called()
print("Deployment guards passed: dirty source, branch, repository and AWS account.")

# The last second of the parallel window is allowed; the cutoff itself is not.
deploy.check_parallel_window(datetime(2026, 10, 22, 6, 59, 59, tzinfo=timezone.utc))
for now in [datetime(2026, 10, 22, 7, tzinfo=timezone.utc), datetime(2027, 1, 1, tzinfo=timezone.utc)]:
    try:
        deploy.check_parallel_window(now)
    except RuntimeError as error:
        assert "cutoff reached" in str(error)
    else:
        raise AssertionError("Dual deployment was permitted after the cutoff")
print("Parallel deployment cutoff boundary passed.")

with patch.object(deploy, "output", side_effect=["", "main", "fennelouski/Fonsters", credentials, '{"Account":"074861507225"}']), patch.object(deploy.subprocess, "run") as run, patch.object(deploy, "check_parallel_window") as cutoff, patch("sys.argv", ["deploy-parallel.py", "--aws-only"]):
    deploy.main()
    cutoff.assert_not_called()
    commands = [call.args[0] for call in run.call_args_list]
    assert all(command[0] != "git" for command in commands)
    assert ["npm", "run", "deploy:aws"] in commands
    assert any("smoke-aws.mjs" in " ".join(command) for command in commands)
print("AWS-only path passed: checks and deployment run without a GitHub push.")
