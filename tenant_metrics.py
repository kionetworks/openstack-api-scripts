#!/usr/bin/python

"""
To get the metrics of all tenants:

export OS_TENANT_NAME=admin
SAVEIFS=$IFS
IFS=$(echo -en "\n\b")
for TENANT in `keystone tenant-list | \
        grep -v + | \
        cut -d\| -f3 | \
        sed -e 's/^[ \t]*//' -e 's/[ \t]*$//' | \
        grep -v name`; do
    export OS_TENANT_NAME="$TENANT"
    tenant_metrics.py
done
IFS=$SAVEIFS
"""

# Script to list some instance's attributes

import os
import novaclient.v1_1.client as nvclient
from cinderclient.v2 import client as cclient

# Read from the env vars
# TODO parse arguments in command line


def get_nova_credentials():
    cred = {}
    cred['username'] = os.environ['OS_USERNAME']
    cred['api_key'] = os.environ['OS_PASSWORD']
    cred['auth_url'] = os.environ['OS_AUTH_URL']
    cred['project_id'] = os.environ['OS_TENANT_NAME']
    return cred


def main():

    credentials = get_nova_credentials()

    nc = nvclient.Client(**credentials)
    cc = cclient.Client(**credentials)

    total_vcpus = 0
    total_ram = 0
    total_disk = 0
    total_volumes = 0

    # List id, name and status from all servers from all tenants
    # Add search_opts={'all_tenants':1} to list method
    # if you want the metrics of all tenants that the user admin
    # has access.
    # List for specific tenant defined in OS_TENANT_NAME
    for server in nc.servers.list(detailed=True):
        flavor_id = server.flavor['id']
        try:
            flavor = nc.flavors.find(id=flavor_id)
            total_vcpus += flavor.vcpus
            total_ram += flavor.ram
            total_disk += flavor.disk
        except(BaseException):
            continue

    for volume in cc.volumes.list():
        try:
            total_volumes += volume.size
        except(BaseException):
            continue

    # print "Total VCPUs: %d\tTotal RAM MB: %d\tTotal Disk GB: %d\tTotal
    # Volumes GB: %d\t" % (total_vcpus, total_ram, total_disk, total_volumes)
    print "%s,%d,%d,%d,%d" % (os.environ['OS_TENANT_NAME'],
                             total_vcpus,
                             total_ram,
                             total_disk,
                             total_volumes)

if __name__ == '__main__':
    main()
