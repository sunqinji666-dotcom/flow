#!/bin/bash
set -e
cd "$(dirname "$0")/Flow"
echo "=== Flow Windows Build ==="
dotnet publish -c Release -r win-x64 --self-contained true \
  -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true \
  -o publish
echo "=== Done ==="
echo "Output: $(pwd)/publish/Flow.exe"
