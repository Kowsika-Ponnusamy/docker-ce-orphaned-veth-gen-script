#!/usr/bin/env bash

RED=$(tput setaf 1)
NC=$(tput sgr0)


read -p "Will remove all containers from docker (y/n)?" choice
case "$choice" in 
  y|Y|yes|YES|Yes ) echo "";;
  * ) exit 1;;
esac
echo
echo "it may take some time. You may take a cup of caffe"
echo
echo
echo
docker pull ubuntu > /dev/null
service docker restart

while : ; do
    # create dummy containers
    echo 'creating images'
    for i in {1..64} ; do
        docker run -d -t --entrypoint /bin/bash $(docker images | grep -i ubuntu | head -n1 | awk '{print $3}') > /dev/null
    done
    
    echo "${RED}chaos monkey start${NC}"
    # simulate unstable environment or oom killer or whatever. Just make containerd process unstable
    while : ; do
        pgrep -lfa docker-container | grep -e "/var/run/docker/libcontainerd/containerd" | cut -f1 -d " " | \
            xargs -n1 -I PID bash -c "echo killing pid: PID; kill -15 PID " > /dev/null
        sleep 1
    done &
    CHAOS_MONKEY_PID=$!
    sleep 1
    # remove all containers with simulated oom killer on containerd proc
    docker ps -a | cut -f1 -d " " | grep -v CONTAINER | xargs -n1 docker rm --force > /dev/null

    # kill chaos monkey
    while ps -p $CHAOS_MONKEY_PID; do
        kill -9 $CHAOS_MONKEY_PID
        sleep 1
    done
    jobs
    echo "${RED} chaos stop ${NC}"
    # remove all containers
    docker ps -a | cut -f1 -d " " | grep -v CONTAINER | xargs -n1 docker rm --force > /dev/null
    sleep 1
    # just for sure
    docker ps -a | cut -f1 -d " " | grep -v CONTAINER | xargs -n1 docker rm --force > /dev/null

    # check if we still have orphaned interfaces
    ls /sys/class/net | grep veth && break
done

set -x
ls /sys/class/net | grep veth
docker ps -a

