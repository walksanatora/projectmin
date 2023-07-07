#!/bin/bash
rm -r exported log.txt
scriptDir=$(dirname "$(readlink -f "$0")")
id=$(basename "$scriptDir")
craftos -d "$scriptDir/../.." -i "$id" --headless
cat log.txt
if command -q luamin;then
    for file in $(find "$(dirname $0)/exported" -type f -name "*.lua"); do
        echo "Processing file: $file"
        luamin -f "$file" > tmp
        mv tmp "$file"
    done
else
    echo "lua scripts not minified, install luamin to enable minification"
fi
cd exported
if command -q vfstool-rs; then
    echo "making lua Self-extracting archive"
    vfstool-rs -d . -cs -a ../project.sea
fi