#!/bin/bash
shopt -s dotglob
export APP_ARGS=
#trap 'echo FAILED' ERR
cd $(dirname $0) &> /dev/null
. common.sh
export IP_ADDRESS=$1
echo "IP = $1"
set -eux

echo "************************** Public Key ****************************"
cat  ~/.ssh/easydeploy_id_rsa.pub
echo "******************************************************************"

if [[ -f .ssh/known_hosts ]]
then
    ssh-keygen -R ${IP_ADDRESS}
fi

rssh  ${USERNAME}@${IP_ADDRESS} "[ -d ~/.ssh ] || (echo | ssh-keygen -q -t rsa -N '' ) ; mkdir -p ~/remote/; mkdir -p ~/modules/ ; mkdir -p /var/easydeploy/share/sync/global/; [ -d ~/keys ] || mkdir ~/keys ;mkdir ~/project/ ; mkdir -p /var/easydeploy/share/deployer/"

sync ../remote/  ${USERNAME}@${IP_ADDRESS}:~/remote/

if [ -d ~/.ezd/modules/  ]
then
    sync ~/.ezd/modules/  ${USERNAME}@${IP_ADDRESS}:~/modules/
fi

if [ -f ~/.dockercfg  ]
then
    rscp ~/.dockercfg   ${USERNAME}@${IP_ADDRESS}:~/.dockercfg
fi

if [ -d ~/.ezd/bin/  ]
then
    sync ~/.ezd/bin/  ${USERNAME}@${IP_ADDRESS}:~/user-scripts/
fi

if [ -d ~/.ezd/etc/  ]
then
    sync ~/.ezd/etc/  ${USERNAME}@${IP_ADDRESS}:~/user-config/
fi

sync ${DIR}/*  ${USERNAME}@${IP_ADDRESS}:~/project/

rscp   ~/.ssh/easydeploy_* ${USERNAME}@${IP_ADDRESS}:~/.ssh/
rscp   ~/.ssh/id*.pub ${USERNAME}@${IP_ADDRESS}:~/keys

if [ ! -z "$PROVIDER" ]
then
    ../providers/${PROVIDER}/list-machines.sh > /tmp/ed-machine-list.txt
    rscp  /tmp/ed-machine-list.txt ${USERNAME}@${IP_ADDRESS}:~/machines.txt
fi
if [ -d ~/.ezd/project/${PROJECT}/upload/bootstrap_sync/ ]
then
    sync ~/.ezd/project/${PROJECT}/upload/bootstrap_sync/   ${USERNAME}@${IP_ADDRESS}:/var/easydeploy/share/sync/global/
fi
if [ -d ~/.ezd/project/${PROJECT}/upload/share/ ]
then
    sync ~/.ezd/project/${PROJECT}/upload/share/   ${USERNAME}@${IP_ADDRESS}:/var/easydeploy/share/deployer/
fi

rscp  ~/.ezd/serf_key ${USERNAME}@${IP_ADDRESS}:~/serf_key


rssh  ${USERNAME}@${IP_ADDRESS} "sudo cp -f ~/remote/*.sh /home/easydeploy/bin; [ -d ~/bin/ ] || mkdir ~/bin; cp -f ~/remote/bin/*; \
 ~/bin chmod 755 ~/bin/*; mv -f ~/remote/bashrc_profile ~/.bashrc_profile; sudo cp -f ~/.dockercfg /home/easydeploy/;\
[ -d /home/easydeploy/project/ezd/bin/ ] || mkdir -p /home/easydeploy/project/ezd/bin/;    \
[ -d /home/easydeploy/project/ezd/etc/ ] || mkdir -p /home/easydeploy/project/ezd/etc/; \
cp -rf ~/project/*  /home/easydeploy/project/ ; \
[ -d ~/user-scripts ] && sudo cp -rf ~/user-scripts/*  /home/easydeploy/project/ezd/bin/ ; \
[ -d ~/user-config ] && sudo cp -rf ~/user-config/*  /home/easydeploy/project/ezd/etc/ ; \
sudo chown easydeploy:easydeploy /home/easydeploy/.dockercfg ; \
sudo chown -R easydeploy:easydeploy /home/easydeploy/project ; \
sudo chmod 700 /home/easydeploy/.dockercfg ; \
sudo chmod 755 /home/easydeploy/bin/* ; \
sudo chmod 755 /home/easydeploy/project/ezd/bin/* ||: "










