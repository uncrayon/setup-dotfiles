#!/usr/bin/env python3
"""PreToolUse guard for Bash: branch names, worktree paths, PR creation, pushes to master."""

import json
import os
import re
import shlex
import subprocess
import sys

BRANCH_RE = re.compile(r"^(feat|fix|chore|hotfix)/[a-z0-9]+(-[a-z0-9]+)*$")
PROTECTED = {"master", "main"}
SEPARATORS = {"&&", "||", ";", "|", "&", "\n", "(", ")"}
TEMPLATES = (".github/PULL_REQUEST_TEMPLATE.md", ".github/pull_request_template.md")


def git(cwd, *args):
    result = subprocess.run(["git", "-C", cwd, *args], capture_output=True, text=True)
    return result.stdout.strip() if result.returncode == 0 else None


def split_commands(command):
    lexer = shlex.shlex(command.replace("\n", " ; "), posix=True, punctuation_chars=";&|()")
    lexer.whitespace_split = True
    current = []
    for token in lexer:
        if token in SEPARATORS:
            if current:
                yield current
            current = []
        else:
            current.append(token)
    if current:
        yield current


def strip_env(argv):
    while argv and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", argv[0]):
        argv = argv[1:]
    return argv


def git_subcommand(argv, cwd):
    args = argv[1:]
    while args and args[0].startswith("-"):
        flag = args.pop(0)
        if flag in ("-C", "-c") and args:
            value = args.pop(0)
            if flag == "-C":
                cwd = os.path.join(cwd, os.path.expanduser(value))
    return (args[0], args[1:], cwd) if args else (None, [], cwd)


def check_branch(name):
    if not BRANCH_RE.match(name):
        return (
            f"Branch '{name}' must be feat/, fix/, chore/ or hotfix/ plus a kebab-case name "
            "(never claude/, codex/ or agent/)."
        )
    return None


def option_value(args, *flags):
    for i, arg in enumerate(args):
        for flag in flags:
            if arg == flag and i + 1 < len(args):
                return args[i + 1]
            if flag.startswith("--") and arg.startswith(flag + "="):
                return arg.split("=", 1)[1]
    return None


def new_branch_names(sub, args):
    if sub in ("checkout", "switch"):
        name = option_value(args, "-b", "-B", "-c", "-C", "--create", "--force-create")
        return [name] if name else []
    if sub == "branch":
        if any(a in ("-d", "-D", "--delete", "-m", "-M", "--move", "-l", "--list", "-a", "-r",
                     "--show-current", "--unset-upstream", "--contains", "--merged") or
               a.startswith(("--set-upstream-to", "-u", "--format", "--sort")) for a in args):
            return []
        positional = [a for a in args if not a.startswith("-")]
        return positional[:1]
    return []


def check_worktree(args, cwd):
    if not args or args[0] != "add":
        return None
    rest = args[1:]
    branch = option_value(rest, "-b", "-B")
    skip_next = {"-b", "-B", "--reason"}
    positional, i = [], 0
    while i < len(rest):
        if rest[i] in skip_next:
            i += 2
            continue
        if not rest[i].startswith("-"):
            positional.append(rest[i])
        i += 1
    if not positional:
        return None
    if branch:
        problem = check_branch(branch)
        if problem:
            return problem
    else:
        if len(positional) < 2 or git(cwd, "show-ref", "--verify", f"refs/heads/{positional[1]}") is None:
            return None
        branch = positional[1]
    common = git(cwd, "rev-parse", "--path-format=absolute", "--git-common-dir")
    if not common:
        return None
    repo_root = os.path.dirname(common.rstrip("/"))
    expected = os.path.join(os.path.dirname(repo_root), f"{os.path.basename(repo_root)}-{branch.replace('/', '-')}")
    actual = os.path.realpath(os.path.join(cwd, os.path.expanduser(positional[0])))
    if actual != os.path.realpath(expected):
        return f"Worktree for '{branch}' goes at {expected} (sibling of the repo), not {actual}."
    return None


def check_push(args, cwd):
    positional = [a for a in args if not a.startswith("-")]
    refspecs = positional[1:]
    for spec in refspecs:
        target = spec.lstrip("+").split(":")[-1].removeprefix("refs/heads/")
        if target in PROTECTED:
            return f"Never push to {target}: everything reaches it through a reviewed PR."
    if not refspecs:
        upstream = git(cwd, "rev-parse", "--abbrev-ref", "@{u}")
        current = git(cwd, "branch", "--show-current")
        if (upstream and upstream.split("/", 1)[-1] in PROTECTED) or current in PROTECTED:
            return (
                f"This push would update {upstream or current}. Unset the upstream "
                "(git branch --unset-upstream) and push with `-u origin <branch>`."
            )
    return None


def required_template_lines(template_text):
    return [
        re.sub(r"^- \[[xX ]\]", "- [ ]", line.rstrip())
        for line in template_text.splitlines()
        if line.lstrip().startswith(("#", "- ["))
    ]


def check_pr_create(args, cwd):
    problems = []
    if any(a in ("-d", "--draft") for a in args):
        problems.append("open it ready for review, not as a draft")
    body_file = option_value(args, "-F", "--body-file")
    root = git(cwd, "rev-parse", "--show-toplevel") or cwd
    template = next((os.path.join(root, t) for t in TEMPLATES if os.path.exists(os.path.join(root, t))), None)
    if template:
        if not body_file or body_file == "-":
            problems.append(f"pass the filled template with `--body-file <file>` ({template})")
        else:
            path = os.path.join(cwd, os.path.expanduser(body_file))
            body = open(path).read() if os.path.exists(path) else ""
            body_lines = {re.sub(r"^- \[[xX ]\]", "- [ ]", line.rstrip()) for line in body.splitlines()}
            missing = [line for line in required_template_lines(open(template).read()) if line not in body_lines]
            if missing:
                problems.append("keep every template heading and checkbox; missing: " + " | ".join(missing))
    return ("PR rules: " + "; ".join(problems) + ".") if problems else None


def check(command, cwd):
    for argv in split_commands(command):
        argv = strip_env(argv)
        if not argv:
            continue
        if argv[0] == "cd" and len(argv) > 1:
            cwd = os.path.join(cwd, os.path.expanduser(argv[1]))
        elif argv[0] == "git":
            sub, args, git_cwd = git_subcommand(argv, cwd)
            problem = None
            if sub in ("checkout", "switch", "branch"):
                problem = next(filter(None, map(check_branch, new_branch_names(sub, args))), None)
            elif sub == "worktree":
                problem = check_worktree(args, git_cwd)
            elif sub == "push":
                problem = check_push(args, git_cwd)
            if problem:
                return problem
        elif argv[0] == "gh" and argv[1:3] == ["pr", "create"]:
            problem = check_pr_create(argv[3:], cwd)
            if problem:
                return problem
    return None


def main():
    payload = json.load(sys.stdin)
    command = payload.get("tool_input", {}).get("command", "")
    try:
        reason = check(command, payload.get("cwd") or os.getcwd())
    except ValueError:
        return
    if reason:
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": reason,
            }
        }))


if __name__ == "__main__":
    main()
