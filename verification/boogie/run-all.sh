#!/bin/sh
# Run every Boogie model; full output per run in logs/, one summary line each here.
cd "$(dirname "$0")"
run() { name=$1; shift; sh run.sh "$@" > "logs/$name.txt" 2>&1; printf '%-32s %s\n' "$name" "$(tail -1 logs/$name.txt | sed 's/Boogie program verifier finished with //')"; }
M=models
run 00-smoke                      $M/00-smoke.bpl
run 01-skip-reparse-tag-spaces    $M/prelude.bpl $M/01-skip-reparse-tag-spaces.bpl
run 02-direct-start-tag-name      $M/prelude.bpl $M/02-direct-start-tag-name.bpl
for c in A-before-fix B-after-fix C-contract-as-written; do
  run 03-$c $M/prelude.bpl $M/01-skip-reparse-tag-spaces.bpl $M/02-direct-start-tag-name.bpl $M/03-direct-start-tag-attributes.bpl $M/config-$c.bpl
done
for c in UA-before-fix UB-after-fix UC-contract-as-written; do
  run 04-$c $M/04-append-decoded-utf16.bpl $M/config-$c.bpl
done
