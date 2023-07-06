#!/bin/bash
rm -r exported log.txt
scriptDir=$(dirname "$(readlink -f "$0")")
id=$(basename "$scriptDir")
craftos -d "$scriptDir/../.." -i "$id" --headless
cat log.txt
for file in $(find "$(dirname $0)/exported" -type f -name "*.lua"); do
    echo "Processing file: $file"
    luamin -f "$file" > tmp
    mv tmp "$file"
done
cd exported
vfstool-rs -d . -cs -a ../project.sea
