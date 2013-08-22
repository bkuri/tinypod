#!/bin/bash

bname=`basename "$1" .js`
~/node_modules/uglify-js/bin/uglifyjs -o ../assets/js/$bname.min.js $1
