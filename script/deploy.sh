#! /bin/bash

set -ex

# build site into output/
BRIDGETOWN_ENV=production yarn build

# switch to deploy branch
git checkout deploy

# delete old release; recursively copy all files from output/
rm -rf ./site
cp -R ./output/ ./site/

# commit and push to deploy branch
git add -A
git commit -m "Update build"
git push origin HEAD

# switch back
git checkout main
