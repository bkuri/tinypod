#!/bin/bash

sudo touch /var/log/fsniper.log
fsniper --daemon fsniper.conf
