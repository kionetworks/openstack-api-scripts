#!/usr/bin/python

# Script to list some instance's attributes

import os
import json
from pprint import pprint
import novaclient.v1_1.client as nvclient

# Read from the env vars
# TODO parse arguments in command line
def get_nova_credentials():
    cred = {}
    cred['username']   = os.environ['OS_USERNAME']
    cred['api_key']    = os.environ['OS_PASSWORD']
    cred['auth_url']   = os.environ['OS_AUTH_URL']
    cred['project_id'] = os.environ['OS_TENANT_NAME']
    return cred

def main():

    credentials = get_nova_credentials()

    nc = nvclient.Client(**credentials)

    # List id, name and status from all servers from all tenants
    l = []
    for server in nc.servers.list(search_opts={'all_tenants':1}, detailed=True):
        json_str = json.dumps(server.addresses)
        data = json.loads(json_str)
        for key, value in data.iteritems() :
            if key in ('MONITOREO', 'vlan1007', 'BACKUP_NETWORK', 'vlan1009'):
                json_str2 = json.dumps(value)
                data2 = json_str2.translate(None, '"')
                data2 = data2.split(",")
                addr  = data2[2].split(":")
                l.append(addr[1])
        addresses = '|'.join(l)
        #print "%s,%s,%s,%s" % (server.id, server.name, server.status, addresses)
        print "%s,%s,%s" % (server.id, server.name, addresses)
        addresses = ''
        l = []

if __name__ == '__main__':
    main()


