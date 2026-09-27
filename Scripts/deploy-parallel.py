#!/usr/bin/env python3
"""Deploy the current committed revision from this computer to Vercel and AWS."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import subprocess


def output(args, **kwargs):
    return subprocess.check_output(args, text=True, **kwargs).strip()


def check_parallel_window(now):
    if now >= datetime(2026, 10, 22, 7, tzinfo=timezone.utc):
        raise RuntimeError("Parallel deployment cutoff reached. Verify the recorded cutover and use the AWS-only release path; resolve any migration exception before releasing.")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--profile", default=os.environ.get("AWS_PROFILE", "fishbowl-head"))
    args = parser.parse_args()
    check_parallel_window(datetime.now(timezone.utc))
    os.chdir(Path(__file__).resolve().parent.parent)
    if output(["git", "status", "--porcelain"]):
        raise RuntimeError("Commit or stash local changes first so both hosts receive the same revision.")
    branch = output(["git", "branch", "--show-current"])
    if branch not in ("main", "codex/aws-parallel"):
        raise RuntimeError("Only main and codex/aws-parallel are enabled for the parallel stage.")
    repo = output(["gh", "repo", "view", "--json", "nameWithOwner", "--jq", ".nameWithOwner"])
    if repo != "fennelouski/Fonsters":
        raise RuntimeError("Unexpected repository; refusing to deploy.")
    credentials = json.loads(output(["aws", "configure", "export-credentials", "--profile", args.profile, "--format", "process"]))
    env = dict(os.environ)
    env.pop("AWS_PROFILE", None)
    env.update(AWS_ACCESS_KEY_ID=credentials["AccessKeyId"],
               AWS_SECRET_ACCESS_KEY=credentials["SecretAccessKey"],
               AWS_SESSION_TOKEN=credentials["SessionToken"],
               AWS_REGION="us-west-2", AWS_DEFAULT_REGION="us-west-2")
    identity = json.loads(output(["aws", "sts", "get-caller-identity", "--output", "json"], env=env))
    if identity["Account"] != "074861507225":
        raise RuntimeError("Unexpected AWS account; refusing to deploy.")
    subprocess.run(["npm", "ci"], check=True)
    subprocess.run(["npm", "run", "test:aws"], check=True)
    subprocess.run(["npm", "run", "lint"], check=True)
    subprocess.run(["git", "-c", "credential.helper=", "-c", "credential.helper=!gh auth git-credential",
                    "push", "origin", f"HEAD:refs/heads/{branch}"], check=True)
    print("GitHub push completed. Vercel builds independently; now deploying the same revision to AWS.", flush=True)
    subprocess.run(["npm", "run", "deploy:aws"], env=env, check=True)
    subprocess.run(["npx", "sst", "shell", "--stage", "parallel", "--", "node", "scripts/smoke-aws.mjs"], env=env, check=True)
    print("AWS deployment and live checks passed. Check Vercel's commit status for its independent build result.")


if __name__ == "__main__":
    main()
