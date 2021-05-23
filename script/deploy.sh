#! /bin/bash

set -ex

# build site into output/
BRIDGETOWN_ENV=production yarn deploy

# switch to deploy branch
git checkout deploy

# delete old release; recursively copy all files from output/
rm -rf ./docs
cp -R ./output/ ./docs/
git checkout docs/CNAME docs/.nojekyll

# commit and push to deploy branch
git add -A
git commit -m "Update build"
git push origin HEAD

# switch back
git checkout main
