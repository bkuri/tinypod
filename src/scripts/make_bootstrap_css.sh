#!/bin/bash

bname=`basename "$1" .less`
~/node_modules/less/bin/lessc -O2 -x less/bootstrap/$bname.less > ../assets/css/$bname.min.css
