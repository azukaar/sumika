#!/bin/bash

echo " ---- Build Sumika ----"

rm -rf build

go build -o build/sumika server/*.go
if [ $? -ne 0 ]; then
    exit 1
fi

echo " ---- Build complete, copy assets ----"

chmod +x build/sumika

cp -r server/assets build/assets
echo '{' > build/meta.json
# cat package.json | grep -E '"version"' >> build/meta.json
echo '  "buildDate": "'`date`'",' >> build/meta.json
echo '  "built from": "'`hostname`'"' >> build/meta.json
echo '}' >> build/meta.json

echo " ---- copy complete ----"