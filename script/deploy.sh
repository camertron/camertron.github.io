#! /bin/bash

set -ex

BRIDGETOWN_ENV=production yarn build
git checkout deploy
git ls-files | xargs rm -f
git ls-tree --name-only -d -r HEAD | sort -r | xargs rmdir
git checkout .gitignore .nojekyll CNAME
cp -R output/ ./
exit 0
git add -A
git commit -m "Update build"
git push origin HEAD
git checkout main
