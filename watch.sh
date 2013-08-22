#!/bin/zsh

#adb connect nexus7
adb forward tcp:9222 localabstract:chrome_devtools_remote

export TINYPOD_TMP=/tmp/tinypod_build
mkdir -p $TINYPOD_TMP

#sudo mount -o bind $DROPBOX/Projects/TinyTinyPodcasts/public $DROPBOX/Apps/Pancake.io
hawkeye -v
