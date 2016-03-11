#!/bin/bash

# Script to make automatic snapshots
# The script is executed in the controller
# Sergio Cuellar
# March 2016
# Ver 0.3
# There is an issue freezing the instance [1], it's paused after the process ends.
# So for now, the freezing isn't going to be used.
# http://docs.openstack.org/openstack-ops/content/snapshots.html

source /usr/local/etc/bsfl

LOG_ENABLED=y
POOL=cinder-volumes

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
            echo ${POOL}/volume-$(echo $LINE | cut -d':' -f2 | tr -d " ")
        done <<< "$VOLUMES"
    fi
}

get_instance_name () {
    UUID=$1
    nova show $UUID | grep "\<name\>" | awk '{print $4}'
}

get_snapshot_id () {
    SNAPNAME=$1
    nova image-show $SNAPNAME | grep "\<id\>" | cut -d\| -f3 | sed 's/^[ \t]*//;s/[ \t]*$//'
}

record_snapshot_registry () {
    UUID=$1
    SNAPNAME=$2
    REGISTRY_FILE=/var/log/snapshots/snapshot_registry.txt
    if [ ! -f $REGISTRY_FILE ]; then
        touch $REGISTRY_FILE
    fi
    D=`date +%d-%b-%y`
    echo "$D|$UUID|$SNAPNAME" >> $REGISTRY_FILE
}

usage () {
    echo "Usage: $0 -T <Tenant> [-a] [-U <Instance UUID>] [-t] [-f <File with UUIDs>]" 
    echo "-T : Tenant where the instance resides"
    echo "-a : all instances"
    echo "-U : UUID of the single instance to snapshot"
    echo "-t : Test the instance with a script defined in"
    echo "     /tmp/test_instance_id.txt file"
    echo "-c : Check in all instances if qemu agent is installed and exits"
    echo "-f : Make snapshot of instances defined in a file"
    exit 1
}

check_for_qemuagent () {
    UUID_FILE="/tmp/test_instance_id.txt"
    generate_UUID_file $UUID_FILE

    if [ -f /tmp/uuids_no_qemu_agent.txt ]; then
        rm /tmp/uuids_no_qemu_agent.txt
    fi

    for UUID in `cat $UUID_FILE`; do
        INSTANCE_NAME=`get_instance_name $UUID`
        COMPUTE=`get_compute_host $UUID`
        ssh $COMPUTE "virsh qemu-agent-command  $UUID '{\"execute\":\"guest-fsfreeze-status\"}' &>/dev/null"
        if [ $? -ne 0 ]; then
            msg_error "$INSTANCE_NAME ($UUID)"
            echo "$UUID|$INSTANCE_NAME" >> /tmp/uuids_no_qemu_agent.txt
        else
            msg_ok "$INSTANCE_NAME ($UUID)"
        fi
    done
    rm $UUID_FILE
    exit 1
}


LOG_FILE="/var/log/snapshots/snapshots_`date +%y-%m-%d_%H:%M:%S`.log"

if [ $EUID -ne 0 ]; then
    msg_error "Script must be run as root"
    exit 1
fi

if [ ! -d /var/log/snapshots ]; then
    mkdir /var/log/snapshots
fi

TENANT=Soriana
ALLINSTANCES=false
TEST=false
CHECK=false
FILE=false
ONEUUID=false

NUMARGS=$#
if [ $NUMARGS -eq 0 ]; then
    usage
fi

msg "Loading credentials"

source /root/admin_creds

msg "Set Tenant Name"
export OS_TENANT_NAME=$TENANT
export OS_PROJECT_NAME=$TENANT

while getopts :T:f:tcaU:h OPT; do
    case $OPT in
        T)
            TENANT=$OPTARG
            ;;
        a)
            ALLINSTANCES=true
            ;;
        U)
            ONEUUID=true
            ID=$OPTARG
            ;;
        t)
            TEST=true
            ;;
        f)
            FILE=true
            UUID_FILE=$OPTARG
            ;;
        c)
            CHECK=true
            check_for_qemuagent
            ;;
        h)
            usage
            ;; 
        \?)
            echo "Option -$OPTARG not allowed."
            usage
            ;;
        :)
            echo "Option -$OPTARG requires an argument" >&2
            usage
            ;;
    esac
done
shift $((OPTIND-1))


if [ "$TEST" == "true" ]; then
    UUID_FILE="/tmp/test_instance_id.txt"
    if [ ! -f $UUID_FILE ]; then
        msg_error "$UUID_FILE does not exist"
        exit 2
    fi
fi

if [ "$FILE" == "false" ]; then
    UUID_FILE=$(mktemp)
fi

if [ "$TEST" == "false" ]; then
    if [ "$ALLINSTANCES" == "true" ]; then
        cmd "generate_UUID_file $UUID_FILE"
    fi
    if [ "$ALLINSTANCES" == "false" ] && [ "$ONEUUID" == true ]; then
        UUID_FILE="/tmp/UUID.txt"
        echo "$ID" > $UUID_FILE
    fi
fi

for UUID in `cat $UUID_FILE`; do
    INSTANCE_NAME=`get_instance_name $UUID`
    msg "Instance Name: $INSTANCE_NAME"
    msg "Get compute where $UUID is stored"
    COMPUTE=`get_compute_host $UUID`
    msg_ok "$COMPUTE for $UUID"
    # Uncomment the following lines if the instance has an ephemeral disk in RBD 
    #
    #msg "Create snap for the volume of the OS disk"
    #SNAPNAME=`date +%Y-%b-%d_%H%M`
    #cmd "rbd snap create ephemeral-vms/${UUID}_disk@${SNAPNAME} 2>/dev/null"
    #if [ $? -eq 0 ]; then
    #    msg_ok "Snap of $VOL created"
    #    cmd "rbd snap ls ephemeral-vms/${UUID}_disk 2>/dev/null"
    #    record_snapshot_registry $UUID ephemeral-vms/${UUID}_disk
    #fi
    # End of uncomment
    msg "Get attached volumes"
    for VOL in `get_attached_volumes $UUID`; do
        msg "Create snap for $VOL"
        SNAPNAME=`date +%Y-%b-%d_%H%M`
        cmd "rbd snap create ${VOL}@${SNAPNAME} 2>/dev/null"
        if [ $? -eq 0 ]; then
            msg_ok "Snap of $VOL created"
            cmd "rbd snap ls $VOL 2>/dev/null" 
            record_snapshot_registry $UUID ${VOL}@${SNAPNAME}
        fi
        # Al ejecutar comandos de rbd se obtiene el siguiente mensaje
        #
        # 2015-09-22 11:32:45.793711 7f49875df840 -1 asok(0x35699e0) AdminSocketConfigObs::init: 
        # failed: AdminSocket::bind_and_listen: failed to bind the UNIX domain 
        # socket to '/var/run/ceph/rbd-client-107058.asok': (2) No such file or directory
        # 
        # Parece que no implica problema en la creación del snapshot de los vols
        # Por el momento se redirecciona el error a /dev/null
        if [ "$TEST" == "true" ]; then
            # Delete snapshot
            msg_info "Deleting volume snapshots"
            cmd "rbd snap unprotect ${VOL}@${SNAPNAME} 2>/dev/null"
            cmd "rbd snap rm ${VOL}@${SNAPNAME} 2>/dev/null"
        fi
    done
    # Copy the disk file
    SNAPNAME=`date +%Y-%b-%d_%H%M`
    ssh $COMPUTE "ls /var/lib/nova/instances/$UUID/disk"
    if [ $? -eq 0 ]; then
        msg "/var/lib/nova/instances/$UUID/disk exists"
        msg "Creating the snapshot of disk"
        # --poll Report the snapshot progress and poll until image creation is complete.
        #OS_TENANT_NAME=$TENANT nova image-create --poll $UUID ${INSTANCE_NAME}_SNAP_$SNAPNAME
        ssh $COMPUTE "qemu-img convert -O qcow2 -f qcow2 /var/lib/nova/instances/$UUID/disk /var/lib/nova/instances/snapshots/${UUID}_disk-${SNAPNAME}"
        if [ $? -eq 0 ]; then
            msg_ok "Snapshot created"
            #OS_TENANT_NAME=$TENANT nova image-show ${INSTANCE_NAME}_SNAP_$SNAPNAME
            ssh $COMPUTE "ls -lh /var/lib/nova/instances/snapshots/${UUID}_disk-${SNAPNAME}"
            #if [ $? -eq 0 ]; then
            #    msg_ok "Getting info of snapshot"
            #    msg "Get Glance ID of the snapshot"
            #    SNAP_ID=`OS_TENANT_NAME=$TENANT get_snapshot_id ${INSTANCE_NAME}_SNAP_$SNAPNAME`
            #    msg_ok "Snap ID $SNAP_ID"
            #else
            #    msg_error "Error getting info of snapshot"
            #fi

        else
            msg_error "Cannot create the snapshot for ${INSTANCE_NAME}"
        fi
    else
        msg_info "/var/lib/nova/instances/$UUID/disk does not exist"
        msg_info "The instance has only volumes"
    fi
done

if [ -f $UUID_FILE ] && [ "$TEST" == "false" ] && [ "$FILE" == "false" ]; then
    rm $UUID_FILE
fi

