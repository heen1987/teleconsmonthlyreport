#!/usr/bin/env bash
set -euo pipefail

exec env LC_ALL="en_US.UTF-8" \
  /opt/homebrew/opt/postgresql@17/bin/postgres \
  -D /opt/homebrew/var/postgresql@17
