#!/bin/bash

source /home/kftadmin/admin_creds

export OS_TENANT_NAME=admin

SAVEIFS=$IFS
IFS=$(echo -en "\n\b")

for TENANT in `keystone tenant-list | \
        grep -v + | \
        cut -d\| -f3 | \
        sed -e 's/^[ \t]*//' -e 's/[ \t]*$//' | \
        grep -v name`; do
    export OS_TENANT_NAME="$TENANT"
    export OS_PROJECT_NAME="$TENANT"
    /usr/local/bin/tenant_glance_images.py 2>/dev/null
done

IFS=$SAVEIFS

