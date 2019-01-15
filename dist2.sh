#!/bin/bash

gmake dist-bzip2 >/dev/null 2>&1
file=`ls *.bz2`
typeset -i size=$1
typeset -i actualsize=$(wc -c <"$file")

while (( "$actualsize" > "$size" ))
do
 `gmake dist-bzip2>/dev/null 2>&1`
 actualsize=$(wc -c <"$file")
done

echo "Done." && ls -al $file
exit 0
