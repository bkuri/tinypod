#!/bin/bash

bname=`basename "$1" .handlebars`
handlebars $1 -o -m -f ../assets/js/templates/$bname.js
