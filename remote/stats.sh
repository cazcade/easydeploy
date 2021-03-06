#!/bin/bash -eux

. /home/easydeploy/bin/env.sh

if [[ -f /home/easydeploy/project/ezd/etc/datadog-api-key.txt ]]
then
    DDOG=$( </home/easydeploy/project/ezd/etc/datadog-api-key.txt)
    DDOG=
fi
if [[ -f /home/easydeploy/project/ezd/etc/stathat-user.txt ]]
then
    STATHAT=$(< /home/easydeploy/project/ezd/etc/stathat-user.txt)
else
    STATHAT=
fi

if [[ -f /home/easydeploy/project/ezd/etc/librato-cred.txt ]]
then
    LIBRATO=$(< /home/easydeploy/project/ezd/etc/librato-cred.txt)
else
    LIBRATO=
fi

if [[ -f /home/easydeploy/project/ezd/etc/hg-key.txt ]]
then
    HG=$(< /home/easydeploy/project/ezd/etc/hg-key.txt)
else
    HG=
fi

if dig +short metrics.${PROJECT}.${DEPLOY_ENV}.comp.ezd
then
    STATSD=metrics.${PROJECT}.${DEPLOY_ENV}.comp.ezd
else
    STATSD=
fi


function sendVal() {
    [[ -z $HG ]] || echo "${HG}.${1}.${HOST} $2" | nc carbon.hostedgraphite.com 2003
    [[ -z $HG ]] ||  echo "${HG}.${1}.${IP} $2" | nc carbon.hostedgraphite.com 2003
    [[ -z $STATSD ]] || echo -n "sys.ezd.{$1}.${IP}:$2|g" | nc $STATSD 8125
    [[ -z $LIBRATO ]] || curl -u ${LIBRATO} -d "measure_time=$(date +%s)&source=${HOST}&gauges[0][name]=${1}-agg&gauges[0][value]=${2}&gauges[1][name]=${1}&gauges[1][value]=${2}&gauges[1][source]=${IP}" -X POST https://metrics-api.librato.com/v1/metrics

    [[ -z $STATHAT ]] || curl -d "stat=${1}~${HOST},${IP}&email=${STATHAT}&value=${2}" http://api.stathat.com/ez
    
    if [[ ${DEPLOY_ENV} != "prod" ]]
    then
        [[ -z ${DDOG} ]]  || curl  -X POST -H "Content-type: application/json" -d "{ \"series\" : [{\"metric\":\"ezd.${1}\", \"points\":[[$(date +%s), $2]], \"type\":\"gauge\", \"host\":\"${HOST}-${IP}\", \"tags\":[\"environment:${DEPLOY_ENV}\",\"component:${COMPONENT}\", \"project:${PROJECT}\"]} ] }" "https://app.datadoghq.com/api/v1/series?api_key=${DDOG}"
    fi

}

function sendCount() {
    [[ -z $HG ]] || echo "${HG}.${1}.${HOST} $2" | nc carbon.hostedgraphite.com 2003
    [[ -z $HG ]] || echo "${HG}.${1}.${IP} $2" | nc carbon.hostedgraphite.com 2003
    [[ -z $STATSD ]] || echo -n "sys.ezd.{$1}.${IP}:$2|c" | nc $STATSD 8125

    [[ -z $LIBRATO ]] || curl -u ${LIBRATO} -d "measure_time=$(date +%s)&source=${HOST}&counters[0][name]=${1}-agg&counters[0][value]=${2}&counters[1][name]=${1}&counters[1][value]=${2}&counters[1][source]=${IP}" -X POST https://metrics-api.librato.com/v1/metrics

    [[ -z ${STATHAT} ]] || curl -d "stat=${1}~${HOST},${IP}&email=${STATHAT}&value=${2}" http://api.stathat.com/ez

}


function reportLoad() {
    sendVal "load"  `uptime | awk '{ print $10}' | cut -f1 -d,`
}

function reportDiskUsage() {
    usage=$(df -m / | tail -1 | awk '{$1=$1}1' OFS=',' | cut -d, -f 5 | tr -d '%')
    sendVal "disk_usage_slash" ${usage}
}

function reportMemory() {
    memtotal=`free -m | grep 'Mem' | tr -s ' ' | cut -d ' ' -f 2`
    memfree=`free -m | grep 'buffers/cache' | tr -s ' ' | cut -d ' ' -f 4`
    let "memused=memtotal-memfree"
    let "memusedper=100-memfree*100/memtotal"
    sendVal "memtotal" ${memtotal}
    sendVal "memfree" ${memfree}
    sendVal "memused" ${memused}
    sendVal "memusedper" ${memusedper}
}

function reportProcesses() {
    sendVal "procs" $(ps aux | wc -l)
}

function reportDstat() {
    IFS=,
    read -r cpu_usr cpu_sys cpu_idl cpu_wait hiq siq disk_read disk_write net_recv net_send page_in page_out sysint syscsw
    sendVal "cpu_usr" ${cpu_usr}
    sendVal "cpu_sys" ${cpu_sys}
    sendVal "cpu_idl" ${cpu_idl}
    sendVal "cpu_wait" ${cpu_wait}
    sendVal "disk_read" ${disk_write}
    sendVal "net_recv" ${net_recv}
    sendVal "net_send" ${net_send}
    sendVal "page_out" ${page_out}
    sendVal "page_in" ${page_in}
}

function report() {
    reportLoad
    reportMemory
    reportDiskUsage
    reportProcesses
    tail -1 < /tmp/dstat.csv | reportDstat
}

while :
do
    dstat --output /tmp/dstat.csv 60 1
    report
done