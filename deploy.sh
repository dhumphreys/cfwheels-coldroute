#!/bin/bash

# remove the existing zip file
rm -f coldroute-0.0.1.zip
cd src

# load in the basic plugin files
zip ../coldroute-0.0.1.zip coldroute.cfc index.cfm

# add the core coldroute files
zip -r ../coldroute-0.0.1.zip lib/
