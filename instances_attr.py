#!/usr/bin/python

# Script to list some instance's attributes

import os
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
    for server in nc.servers.list(search_opts={'all_tenants':1}, detailed=True):
        print server.id, server.name, server.status, server.addresses

if __name__ == '__main__':
    main()

