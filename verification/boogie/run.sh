#!/bin/sh
# Run Boogie with Z3 on the given .bpl files (Git Bash, Linux or macOS).
#   BOOGIE  Boogie executable  (default: boogie on PATH, else ~/.dotnet/tools/boogie)
#   Z3      Z3 executable      (default: Boogie looks for z3 on PATH)
# Boogie 3.5.x targets .NET 8; DOTNET_ROLL_FORWARD=Major lets it run on a newer runtime.
export DOTNET_ROLL_FORWARD=Major MSYS_NO_PATHCONV=1
BOOGIE=${BOOGIE:-$(command -v boogie || echo "$HOME/.dotnet/tools/boogie")}
set -- -timeLimit:60 "$@"
[ -n "$Z3" ] && set -- -proverOpt:PROVER_PATH="$Z3" "$@"
exec "$BOOGIE" "$@"
