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
import sys
import MySQLdb
import datetime
import calendar
from datetime import date
from dateutil.rrule import rrule, MONTHLY

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
    #
    # Nova API is not finding a lot flavors, so the results are wrong
    """
    for server in nc.servers.list(detailed=True):
        flavor_id = server.flavor['id']
        try:
            flavor = nc.flavors.find(id=flavor_id)
            total_vcpus += flavor.vcpus
            total_ram += flavor.ram
            total_disk += flavor.disk
        except(BaseException) as detail:
            #continue
            print detail
    """

    connection = MySQLdb.connect (host = "localhost", user = "root", passwd = "XXXXXXXXXXXXXX", db = "nova")
    today = datetime.date.today()
    first = today.replace(day=1)
    lastMonth = first - datetime.timedelta(days=1)
    year = lastMonth.year
    month = lastMonth.month

    a = date(year, month, 1)
    b = lastMonth

    tenant = os.environ['OS_TENANT_NAME']


    # Better query the nova database
    for dt in rrule(MONTHLY, dtstart=a, until=b):
        the_date = dt.strftime("%Y-%m-%d")

        cursor = connection.cursor ()
        cursor.execute ("SELECT x.name AS tenant, COUNT(x.name) AS qty, SUM(x.vcpus) AS vcpus, SUM(ROUND(x.memory_mb/1024)) AS mem, SUM(x.root_gb) AS hd FROM (SELECT t.name, i.uuid, i.display_name, i.created_at, i.terminated_at, DATEDIFF(LAST_DAY('" + the_date + "'), i.created_at) AS days, i.vcpus, i.memory_mb, i.root_gb FROM keystone.project t JOIN nova.instances i ON t.id=i.project_id WHERE (t.name LIKE '" + tenant + "') AND i.deleted=0 AND YEAR(i.created_at)=YEAR('" + the_date + "') AND MONTH(i.created_at)=MONTH('" + the_date + "') UNION DISTINCT SELECT t.name, i.uuid, i.display_name, i.created_at, i.terminated_at, DAY(LAST_DAY('" + the_date + "')) AS days, i.vcpus, i.memory_mb, i.root_gb FROM keystone.project t JOIN nova.instances i ON t.id=i.project_id WHERE (t.name LIKE '" + tenant + "') AND i.deleted=0 AND i.created_at<='" + the_date + "' UNION DISTINCT SELECT t.name, i.uuid, i.display_name, i.created_at, i.terminated_at, DATEDIFF(i.terminated_at, i.created_at) + 1 AS days, i.vcpus, i.memory_mb, i.root_gb FROM keystone.project t JOIN nova.instances i ON t.id=i.project_id WHERE (t.name LIKE '" + tenant + "') AND i.deleted=1 AND i.terminated_at IS NOT NULL AND YEAR(i.created_at)=YEAR('" + the_date + "') AND MONTH(i.created_at)=MONTH('" + the_date + "') AND YEAR(i.updated_at)=YEAR('" + the_date + "') AND MONTH(i.updated_at)=MONTH('" + the_date + "') UNION DISTINCT SELECT t.name, i.uuid, i.display_name, i.created_at, i.terminated_at, DAY(LAST_DAY('" + the_date + "')) AS days, i.vcpus, i.memory_mb, i.root_gb FROM keystone.project t JOIN nova.instances i ON t.id=i.project_id WHERE (t.name LIKE '" + tenant + "') AND i.deleted=1 AND i.created_at<='" + the_date + "' AND i.terminated_at>=LAST_DAY('" + the_date + "')) AS x GROUP BY x.name;")
        data = cursor.fetchall ()

        for row in data:
            total_vcpus = total_vcpus + row[2]
            total_ram   = total_ram + row[3]
            total_disk  = total_disk + row[4]

        cursor.close ()

        connection.close ()

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
