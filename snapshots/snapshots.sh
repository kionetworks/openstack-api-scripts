#!/bin/bash

# Script to make automatic snapshots
# The script is executed in the controller
# Sergio Cuellar
# Sep 2015
# Ver 0.1

source bsfl

LOG_ENABLED=y

generate_UUID_file () {
    nova list --all-tenants | grep  Running | cut -d\| -f2 | sed 's/^[ \t]*//;s/[ \t]*$//' > $1
}

get_compute_host () {
    UUID=$1
    nova show $UUID | grep OS-EXT-AZ:availability_zone | cut -d\| -f3 | sed 's/^[ \t]*//;s/[ \t]*$//'
}

get_attached_volumes () {
    UUID=$1
    VOL_FILES=$2
    VM=$(nova show $UUID)
    VOLUMES=$(echo "$VM" | grep "os-extended-volumes:volumes_attached" | cut -d'|' -f3 | tr -d "[]{}\"" |  sed 's/^[ \t]*//;s/[ \t]*$//' |awk -F',' '{for (i=1;i<=NF;i++) print $i}')
    if [ ! -z "$VOLUMES" ]; then
        while IFS= read -r LINE; do
            echo volumes/volume-$(echo $LINE | cut -d':' -f2 | tr -d " ")
        done <<< "$VOLUMES"
    fi
}

if [ ! -d snapshots_logs ]; then
    mkdir snapshots_logs
fi

LOG_FILE="snapshots_logs/snapshots_`date +%y-%m-%d_%H:%M:%S`.log"

if [ $EUID -ne 0 ]; then
    msg_error "Script must be run as root"
    exit 1
fi

msg "Loading credentials"

source /root/admin_creds

msg "Set Tenant Name"
cmd "export OS_TENANT_NAME=XXXXXXX"

msg "Generate temp file with all UUIDs of running instances"

UUID_FILE=$(mktemp)
VOLUMES_FILE=$(mktemp)

cmd "generate_UUID_file $UUID_FILE $VOLUMES_FILE"

if [ -f uuids_no_qemu_agent.txt ]; then
    rm uuids_no_qemu_agent.txt
fi

for UUID in `cat $UUID_FILE`; do
    echo "$UUID"
    msg "Get compute where $UUID is stored"
    COMPUTE=`get_compute_host $UUID`
    msg_ok "$COMPUTE for $UUID"
    msg "Get attached volumes"
    get_attached_volumes $UUID
    msg "Status of QEMU agent for instance $UUID"
    ssh $COMPUTE "virsh qemu-agent-command  $UUID '{\"execute\":\"guest-fsfreeze-status\"}'"
    if [ $? -eq 0 ]; then
        msg_ok "QEMU agent installed"
        #TODO Make the snapshots
    else
        msg_error "QEMU agent not installed for $UUID"
        echo "$UUID" >> uuids_no_qemu_agent.txt
    fi
done

if [ -f $UUID_FILE ]; then
    rm $UUID_FILE
fi

if [ -f $VOLUMES_FILE ]; then
    rm $VOLUMES_FILE
fi
