#! /bin/bash

set -ex

BRIDGETOWN_ENV=production yarn build
git checkout deploy
cp -R output/ ./
git add -A
git commit -m "Update build"
git push origin deploy
git checkout main
