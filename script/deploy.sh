#! /bin/bash

set -e

BRIDGETOWN_ENV=production yarn build
git checkout deploy
cp -R output/ ./
git add -A
git commit -m "Update build"
git push origin deploy
