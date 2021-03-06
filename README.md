    ***********************************************************
    ** PRE RELEASE SOFTWARE - DO NOT USE UNLESS YOU IS CRAZY **
    ***********************************************************
    
    If you still want to use this, please contact neil@cazcade.com

easydeploy
==========

A set of scripts that allow incredibly easy deployment and running of apps using Docker and supervisord

## 0. Intro


### Highlights

#### Add modules to your Dockerfiles

    MOD newrelic-sysmond  7fab41848a24fdcdf3c6868cf94fb17f457684387a8

#### Set up an Ubuntu host with supervisord running a Docker instance containing your app

    ezd -e dev deploy 88.37.2.89

#### Re-image and upgrade multiple machines 

    ezd -e dev upgrade

#### Re-buid and deploy your app 

    ezd -e dev rebuild-app

#### Built in (bit torrent) large file syncing

    /var/easydeploy/share/sync/global

### Philosophy

Tools to help you, not a straight jacket to trap you - that's why Easydeploy **IS NOT A PaaS** it's a DevOps tool.

Convention over configuration.

For small deployments - there are many more people needing to do 5-100 cloud server deploys than there are people doing 10,000 server deploys. So we optimize for samller deployments.


## 1. Creating a Project

At present easydeploy only supports Ubuntu/Docker combination.

### The Configuration file ezd/etc/ezd.sh

** Beware this is likely to change as we switch over to using Fig **

This file should contain the following:

    export DOCKER_COMMANDS=
    export DOCKER_ARGS=
    export EASYDEPLOY_PORTS=
    export EASYDEPLOY_EXTERNAL_PORTS=
    export EASYDEPLOY_PROCESS_NUMBER=
    export EASYDEPLOY_PACKAGES=

All variables are optional and *must* be exported (all the scripts rely on that).

EASYDEPLOY_PORTS should be a space separated list of ports that should be mapped on the docker instance(s) so a value of "80 8080" translates to `-p 80:80 -p 8080:8080`

EASYDEPLOY_EXTERNAL_PORTS should be a space separated list of ports that should be open on the *host* machine.

EASYDEPLOY_PROCESS_NUMBER (misnamed) is the number of instances that should be run on each host.

DOCKER_ARGS (misnamed) is a set of options that are passed to docker before the name of the instance to run. Here you can do your own port mapping like "-p 80:8080" - but don't forget to expose the ports using EASYDEPLOY_EXTERNAL_PORTS

EASYDEPLOY_PACKAGES is a space seperated list of (apt-get) packages to deploy prior to the running of the install script.

EASYDEPLOY_STATE can be 'stateless' or 'stateful' the default behaviour is stateful, stateful services destroy all traces of their state on restarts using dockers `--rm=true` and by running `docker rm $(docker -q -a)` in the update.sh script.

EASYDEPLOY_UPDATE_CRON should be a cron pattern that will be used to run the update.sh script which updates your application on a regular basis set this to 'none' (the default) if you don't want the script run.

### The Dockerfile

This should be a normal Dockerfile however the following *easydeploy* extensions are supported:

#### MOD


    MOD <module-name> <arg>*

This will look for the script that provides  `<module-name>` passing it the arguments supplied. The result of the script execution will end up in the Dockerfile.

You can add your own modules by placing them in the directory ~/.edmods on the machine from which you deploy. The file should be a bash shell script compatible with the host OS (Ubuntu) called <module-name> and should output (to stdout) valid Dockerfile syntax.

## 2. Deployment

### Deployment configuration files ezd/deploy/conf.sh and ezd/deploy/<env>/conf.sh

Again all variables should be exported, and here are the variables:

    #Specific
    export COMPONENT=logstash

    #Common
    export PROVIDER=do
    export USERNAME=root

    #Provider specific
    export DO_BASE_IMAGE=2158507
    export DO_KEYS=93676
    export DO_IMAGE_SIZE=62
    export DO_REGION=4

    #Loadbalancers Only
    export LB_TARGET_COMPONENT=api

    #Scaling
    export MIN_INSTANCES=2
    export MAX_INSTANCES=2

### Deploying

    ezd -e <environment> deploy <ip-or-hostname>

The first time the script is run it will create the easydeploy ssh keys and tell you the public key. 

Once the keys are created this command will deploy your application to the hostname supplied - run it within a docker container and keep it running using supervisord

#### Blue/Green Deploys

    ezd -m blue -e prod update
    ezd -m green -e prod update
    
The -m option allows the adding of an additional modifier which will affect hostnames but not image names. Allowing multiple environments at the same deploy stage. This is typically to be used for blue/green deployments.

#### File uploads

The contents of ~/.ezd/upload/share/ will be pushed to the directory /var/eadydeploy/share/deployer/ on the remote machine during a deploy and before the installation scripts are run.

The contents of ~/.ezd/upload/bootstrap_sync/ will be pushed to the directory /var/eadydeploy/share/sync/global on the remote machine during a deploy and before the installation scripts are run. * NB: This ensures any core files that are used by the syncing process are their before syncing starts. *


## 3. Runtime

### The host

As part of the deployment process a user called 'easydeploy' will be created on the host system. In the `/home/easydeploy` directory will be a bin directory containing scripts used by the easydeploy runtime.

#### run-docker.sh

This is the script that is run by supervisord which then builds and runs your docker container, this script should be run by the easydeploy user.

#### update.sh

TODO:


## 4. Cloud Functions

If you are using a supported cloud provider (currently Digital Ocean only) then you also can do some more advanced functions.


### Create Image

    ezd -e <environment> image

Creates an image on the cloud provider specified by `${PROVIDER}` from the profile. Specifically it creates an appropriate instance, deploys to it and then snapshots it.


### Create Single Instance

     ezd -e <environment> create

Creates a single instance ignoring any scaling parameters set in the profile and deploys to it.

### Tail All Instances

     ezd -e <environment> tail

To use this you *must* have `multitail` installed (try Homebrew `brew install multitail` on Macs). This command will create a multitail session split for each server. Not suitable for large numbers of instances.


### Scale to N Instances

     ezd -e <environment>> scale [<N> | 'max' | 'min']

This will scale the number of instances to N, if the current number of instances is larger they will be destroyed if less then they will be created. The values max and min are synonyms for the MAX_INSTANCES and MIN_INSTANCES configuration values.


### List Instances

     ezd -e <environment> list

This will list all instances of the deployment profile, however the way the results are displayed are currently provider specific.

### Upgrade Machines

    ezd -e <environment> upgrade

This command will create a temporary machine, deploy to it, create a machine image and then use that image to re-image all the deployed servers that match the profile (on Digital Ocean we do that by matching the droplet name of ${DEPLOY_ENV}-${GIT_URL_USER}-${COMPONENT}).

Easydeploy will look for the variable PROVIDER in the profile file and use that to determine which scripts to run internally.

NB: We only support `export PROVIDER=do` at present.

### Rebuild Machines

    ezd -e <environment> rebuild

This is similar to Upgrade Machines, however instead it uses an existing machine image without creating a new one first.


### Wire Machines Together

    ezd -e <environment> wire

This tells each machine in this *profile* of all the machines in the *project/environment* of each others presence so that service discovery can then take place. This command knows nothing about your architecture and is simply telling each serf agent in this profile about the machines in this project/environment.

This command should not need to be run regularly as serf will self-heal itself. However it does need to be run after a scale operation at present.

## 5. Continuous Deployment

Continuous deployment is integral to easydeploy, it will assume that you're trying to do this if you're app has `export EASYDEPLOY_STATE="stateless"` set in the `ezd.sh`file. Stateless apps are always preferable as gradually accrued unwanted or unexpected state can be deleted at any time.

**TRY TO MAKE ALL YOUR APPS STATELESS, EXCEPT YOUR ACTUAL DATABASE**

Easydeploy manages CD in an incredibly simple manner, using supervisord and a simple shellscript.

HOW DO I REDEPLOY? 

    ezd -m blue -e prod rebuild-app


## 6. Shared Directories

### /var/easydeploy/container/XX -> /var/local

The  /var/easydeploy/container/XX directory where XX is the instance number of the docker container is mapped to the /var/easydeploy/local of each docker instance. Therefore it is not shared with other containers. This is most useful for seeing 'under the hood' of a running docker container by having access to it's files from the host.


### /var/easydeploy/share -> /var/share , /var/easydeploy/share

A directory shared between the host machine and all the docker containers on that machine. This is a quick way of passing files from the host to all containers or for files to be shared by containers within a host. It appears as both /var/share and /var/easydepoy/share in the container.  This directory has some very useful sub-directories listed below.

### /var/easydeploy/share/.config

Various configuration data usually one value per file. Files include

 * app_args - the additional arguments to be passed to the running container ${APP_ARGS}
 * component - the name of the application component placed on the machine ${COMPONENT}
 * edstate - whether this is a stateful or stateless app ${EASYDEPLOY_STATE}
 * branch - the git branch being used, usually master for prod/alt-prod environments or the name of the environment ${GIT_BRANCH}
 * deploy_env - the deployment envitonment (e.g. prod,dev,test) ${DEPLOY_ENV}
 * machines.txt a list of machines that were present at build time, usually used to get the serf nodes seeded.


### /var/easydeploy/share/.config/sync/discovery

This directory provides a nice and simple service discovery capability. The directory will be prepopulated on an install and then updated as members come and go. A file is created for each component in the environment in CSV format and as just a list of ip addresses in a .txt file. Also two files all.csv and all.txt contain all the machines in the environment.

### /var/easydeploy/share/sync

This directory is the parent directory for those synchronized using btsync. The various sub directories work with a subset of nodes, they are useful for sharing large (MB-GB)  binary objects between machines and containers.

#### /var/easydeploy/share/sync/global

**All** nodes in **all** environments, so don't put anything big in here :-) - you probably want to use `/var/easydeploy/sync/env` instead.

#### /var/easydeploy/share/sync/env

All nodes in the environment (i.e. dev, prod etc).

#### /var/easydeploy/share/sync/component

All nodes with the same component type and in the same environment (i.e. dev, prod etc).

### /var/easydeploy/share/tmp

This directory is the parent directory of the self deleting directories, anything placed within the following directories will be deleted according to the appropriate timescales:

* /var/easydeploy/share/tmp/hourly checked hourly, older than one hour deleted
* /var/easydeploy/share/tmp/daily checked daily, older than one day deleted
* /var/easydeploy/share/tmp/monthly checked daily, older than 31 days deleted

## A. Examples

Not yet, sorry.

#easydeploy is powered by#

![Powered by Docker](http://blog.docker.io/wp-content/uploads/2013/08/KuDr42X_ITXghJhSInDZekNEF0jLt3NeVxtRye3tqco.png)








