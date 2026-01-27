#!/bin/bash
# convert json file to easier-to-read TSV
# ROW starts row
# IR is initial.regs <name> <val>
# IM is initial.mem <addr> <val>
# EXEC -> do exec code here
# FR is final.regs <name> <val>
# FM is final.mem <addr> <val>
file=$1
tsv=${file}.tsv
if [ -e $tsv ]; then
    exit 0
fi
jq -r '
.[] |
  (["ROW", .name] | @tsv),
  (.initial.regs | to_entries[] | ["IR", .key, .value] | @tsv),
  (.initial.ram  | .[] | ["IM", .[0], .[1]] | @tsv),
  (["EXEC"] | @tsv),
  (.final.regs   | to_entries[] | ["FR", .key, .value] | @tsv),
  (.final.ram    | .[] | ["FM", .[0], .[1]] | @tsv)
' $file > $tsv
