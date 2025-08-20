#!/bin/bash

echo " ---- Build Sumika ----"

# Ensure device metadata script dependencies are ready
if [ ! -d "device-metadata-script/node_modules" ]; then
    echo " ---- Installing device metadata script dependencies ----"
    cd device-metadata-script
    npm install
    cd ..
    echo " ---- Device metadata dependencies installed ----"
fi

rm -rf build

go build -o build/sumika server/*.go
if [ $? -ne 0 ]; then
    exit 1
fi

echo " ---- Build complete, copy assets ----"

chmod +x build/sumika

cp -r server/assets build/assets
cp -r device-metadata-script build/device-metadata-script
echo '{' > build/meta.json
# cat package.json | grep -E '"version"' >> build/meta.json
echo '  "buildDate": "'`date`'",' >> build/meta.json
echo '  "built from": "'`hostname`'"' >> build/meta.json
echo '}' >> build/meta.json

echo " ---- copy complete ----"