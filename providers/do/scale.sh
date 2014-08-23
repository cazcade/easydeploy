#!/bin/bash -x
#trap 'echo FAILED' ERR
cd $(dirname $0)
. ../../commands/common.sh
. ./do_common.sh

current=$(echo $(tugboat droplets | grep "^${MACHINE_NAME} " | wc -l))
export ids=( $(./list-machines-by-id.sh "^${MACHINE_NAME} " ) )
echo "Currently $current servers requested $1 servers running difference is $(($1 - $current))"

if [ $current -gt $1 ]
then
    seq 0 $(($current - $1 - 1))  | (while read i; do echo ${ids[$i]};done) | parallel "tugboat destroy -c -i {}"

elif [ $current -lt $1 ]
then
    image=$(tugboat info_image -n $(template_name) | grep ID: | cut -d: -f2  | tr -d ' ' | tail -1)
    for i in $(seq $current $(($1 - 1)) )
    do
        echo "Creating new ${MACHINE_NAME}"
        tugboat create --quiet --size=${DO_IMAGE_SIZE} --image=${image} --region=${DO_REGION}  --keys=${DO_KEYS} --private-networking  $MACHINE_NAME
    done
else
    echo "Nothing to do."
fi
true
