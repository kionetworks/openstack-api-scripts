#!/usr/bin/python

# Script to list the available flavors

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

    for flavor in nc.flavors.list(is_public=None):
        print flavor.id, flavor.name, flavor.ram, flavor.disk


if __name__ == '__main__':
    main()

