#!/bin/bash

bname=`basename "$1" .less`
~/node_modules/less/bin/lessc -O2 -x $bname.less > ../css/$bname.css
