#!/bin/bash
set -e
cd $(dirname $0)
. ../../commands/common.sh
. ./do_common.sh
$tugboat droplets | grep "${DATACENTER}-${DEPLOY_ENV}-${PROJECT}-.* " |  cut -d":" -f2| tr -d ')' | cut -d, -f1 | tr -d ' '
