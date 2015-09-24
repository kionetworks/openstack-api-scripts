#!/bin/bash

# Script to make automatic snapshots
# The script is executed in the controller
# Sergio Cuellar
# Sep 2015
# Ver 0.1

source bsfl

LOG_ENABLED=y
TEST="y"

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

get_instance_name () {
    UUID=$1
    nova show $UUID | grep "\<name\>" | awk '{print $4}'
}

get_snapshot_id () {
    SNAPNAME=$1
    nova image-show $SNAPNAME | grep "\<id\>" | cut -d\| -f3 | sed 's/^[ \t]*//;s/[ \t]*$//'
}

record_snapshot_registry () {
    SNAPID=$1
    SNAPNAME=$2
    REGISTRY_FILE=/var/lib/nova/instances/snapshots_soriana/snapshot_registry.txt
    if [ ! -f $REGISTRY_FILE ]; then
        touch $REGISTRY_FILE
    fi
    echo "$SNAPID|$SNAPNAME" >> $REGISTRY_FILE
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

if [ "$TEST" == "y" ]; then
    UUID_FILE="test_instance_id.txt"
else
    UUID_FILE=$(mktemp)
fi

if [ "$TEST" != "y" ]; then
    cmd "generate_UUID_file $UUID_FILE" 
fi

if [ -f uuids_no_qemu_agent.txt ]; then
    rm uuids_no_qemu_agent.txt
fi

for UUID in `cat $UUID_FILE`; do
    INSTANCE_NAME=`get_instance_name $UUID`
    msg "Instance Name: $INSTANCE_NAME"
    msg "Get compute where $UUID is stored"
    COMPUTE=`get_compute_host $UUID`
    msg_ok "$COMPUTE for $UUID"
    msg "Status of QEMU agent for instance $UUID"
    ssh $COMPUTE "virsh qemu-agent-command  $UUID '{\"execute\":\"guest-fsfreeze-status\"}'"
    if [ $? -eq 0 ]; then
        msg_ok "QEMU agent installed"
        #TODO Make the snapshots
        msg "Freezing instance"
        ssh $COMPUTE "virsh qemu-agent-command $UUID '{\"execute\":\"guest-fsfreeze-freeze\"}'"
        if [ $? -eq 0 ]; then
            msg_ok "Instance is freezed"
            sleep 1
            msg "Get status of the instance"
            ssh $COMPUTE "virsh qemu-agent-command $UUID '{\"execute\":\"guest-fsfreeze-status\"}'"
            sleep 1
            msg "Get attached volumes"
            for VOL in `get_attached_volumes $UUID`; do
                msg "Create snap fo $VOL"
                SNAPNAME=`date +%Y-%m-%d_%H%M`
                ssh $COMPUTE "rbd snap create ${VOL}@${SNAPNAME} 2>/dev/null"
                if [ $? -eq 0 ]; then
                    msg_ok "Snap of $VOL created"
                    ssh $COMPUTE "rbd snap ls $VOL 2>/dev/null" 
                fi
                # Al ejecutar comandos de rbd se obtiene el siguiente mensaje
                #
                # 2015-09-22 11:32:45.793711 7f49875df840 -1 asok(0x35699e0) AdminSocketConfigObs::init: 
                # failed: AdminSocket::bind_and_listen: failed to bind the UNIX domain 
                # socket to '/var/run/ceph/rbd-client-107058.asok': (2) No such file or directory
                # 
                # Parece que no implica problema en la creación del snapshot de los vols
                # Por el momento se redirecciona el error a /dev/null
                if [ "$TEST" == "y" ]; then
                    # Delete snapshot
                    ssh $COMPUTE "rbd snap unprotect ${VOL}@${SNAPNAME} 2>/dev/null"
                    ssh $COMPUTE "rbd snap rm ${VOL}@${SNAPNAME} 2>/dev/null"
                fi
            done
            # Copy the disk file
            SNAPNAME=`date +%Y-%m-%d_%H%M`
            ssh $COMPUTE "ls /var/lib/nova/instances/$UUID/disk"
            if [ $? -eq 0 ]; then
                msg "/var/lib/nova/instances/$UUID/disk exists"
                msg "Creating the snapshot of disk"
                #ssh $COMPUTE "rsync -avzP /var/lib/nova/instances/$UUID/disk /var/lib/nova/instances/$UUID/disk_${SNAPNAME}"
                # --poll Report the snapshot progress and poll until image creation is complete.
                OS_TENANT_NAME=XXXXXXX nova image-create --poll $UUID ${INSTANCE_NAME}_SNAP_$SNAPNAME
                if [ $? -eq 0 ]; then
                    #msg_ok "/var/lib/nova/instances/$UUID/disk_${SNAPNAME} created"
                    msg_ok "Snapshot created"
                    OS_TENANT_NAME=XXXXXXX nova image-show ${INSTANCE_NAME}_SNAP_$SNAPNAME
                    if [ $? -eq 0 ]; then
                        msg_ok "Getting info of snapshot"
                        # Actualmente Glance está sobre /, por lo que crear los snapshots
                        # en esa ruta consumiría mucho espacio sobre ese file system.
                        # Una opción es configurar Glance para que utilice Ceph; otra opción es
                        # crear el directorio /var/lib/nova/instances/snapshots_soriana y una vez
                        # que se haya creado el snapshot a través de nova image-create, obtener el ID
                        # del snapshot, moverlo hacia el directorio mencionado y crear una liga 
                        # simbólica en /var/lib/glance/images
                        msg "Get Glance ID of the snapshot"
                        SNAP_ID=`OS_TENANT_NAME=XXXXXXX get_snapshot_id ${INSTANCE_NAME}_SNAP_$SNAPNAME`
                        msg_ok "Snap ID $SNAP_ID"
                        if [ -f /var/lib/glance/images/$SNAP_ID ]; then
                            msg "Moving Snapshot file to /var/lib/nova/instances/snapshots_soriana/" 
                            rsync --remove-source-files -avzP \
                                /var/lib/glance/images/$SNAP_ID /var/lib/nova/instances/snapshots_soriana/
                            if [ $? -eq 0 ]; then
                                msg_ok "Rsyncing completed"
                                msg "Creating symbolic link"
                                ln -s /var/lib/nova/instances/snapshots_soriana/$SNAP_ID /var/lib/glance/images/$SNAP_ID 
                                # Cuando se utiliza nova image-delete, el link simbólico es borrado y la info de 
                                # metadata también, por lo que ahora ya no es posible identificar, a qué máquina 
                                # le correspondía el archivo en /var/lib/nova/instances/snapshots_soriana/
                                # Es necesario crear una relación para no perder el control.
                                # Por el momento un archivo de texto, lo ideal sería una DB en sqlite
                                record_snapshot_registry $SNAP_ID ${INSTANCE_NAME}_SNAP_$SNAPNAME
                            else
                                msg_error "Error moving image to  /var/lib/nova/instances/snapshots_soriana/"
                            fi
                        fi
                    else
                        msg_error "Error getting info of snapshot"
                    fi

                else
                    msg_error "Cannot create the snapshot for ${INSTANCE_NAME}"
                fi
            else
                msg_info "/var/lib/nova/instances/$UUID/disk does not exist"
            fi
            msg "Unfreeze the instance"
            ssh $COMPUTE "virsh qemu-agent-command $UUID '{\"execute\":\"guest-fsfreeze-thaw\"}'"
            if [ $? -eq 0 ]; then
                msg_ok "Instance unfreezed"
                ssh $COMPUTE "virsh qemu-agent-command $UUID '{\"execute\":\"guest-fsfreeze-status\"}'"
            fi
        else
            msg_error "The instance could not be freezed"
            exit 2
        fi
    else
        msg_error "QEMU agent not installed for $UUID"
        echo "$UUID" >> uuids_no_qemu_agent.txt
    fi
done

if [ -f $UUID_FILE -a "$TEST" != "y" ]; then
    rm $UUID_FILE
fi

