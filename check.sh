#!/usr/bin/env bash
# Fails if the repo contains likely secrets or work (Platzi) references. Run before every commit.
set -uo pipefail
cd "$(dirname "$0")"

WORK='platzi|radiance|class[-_ ]?director|kiwi|mf-b2b|sinapsis|eks-dev|kubeconfig'
SECRET='(^|[^a-z])(api[_-]?key|secret|token|password|authorization)["'"'"' ]*[:=] *["'"'"'][A-Za-z0-9_\-]{16,}|sk-[A-Za-z0-9]{20,}|gh[pousr]_[A-Za-z0-9]{30,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY'

status=0
if git grep --untracked -nIiE "$WORK" -- . ':!check.sh' ':!README.md' ':!sync.sh'; then
  echo "✗ work references found (above)"; status=1
fi
if git grep --untracked -nIiE "$SECRET" -- . ':!check.sh'; then
  echo "✗ possible secrets found (above)"; status=1
fi
[[ $status -eq 0 ]] && echo "✓ no secrets or work references"
exit $status
