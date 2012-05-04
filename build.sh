#!/bin/bash

# set version
VERSION=0.3

# set file name
ZIPFILE=coldroute-$VERSION.zip

# remove the existing zip file
if [ ! -d build ]; then
    mkdir build
fi
rm -f build/$ZIPFILE
cd src

# load in the basic plugin files
zip ../build/$ZIPFILE coldroute.cfc index.cfm

# add the core coldroute files
zip -r ../build/$ZIPFILE lib/
