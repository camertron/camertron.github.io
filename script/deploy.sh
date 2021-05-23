#! /bin/bash

set -e

yarn build
git checkout deploy
cp -R output/ ./
git add -A
git commit -m "Update build"
git push origin deploy
