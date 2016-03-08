#!/usr/bin/python

import os
import json
from pprint import pprint
from os import environ as env
import glanceclient.exc

from collections import Counter

import novaclient.v1_1.client as nvclient
import glanceclient.v2.client as glclient
import keystoneclient.v2_0.client as ksclient



def get_nova_credentials():
    cred = {}
    cred['username'] = os.environ['OS_USERNAME']
    cred['api_key'] = os.environ['OS_PASSWORD']
    cred['auth_url'] = os.environ['OS_AUTH_URL']
    cred['project_id'] = os.environ['OS_TENANT_NAME']
    return cred


def main():

    keystone = ksclient.Client(auth_url=env['OS_AUTH_URL'],
                               username=env['OS_USERNAME'],
                               password=env['OS_PASSWORD'],
                               tenant_name=env['OS_TENANT_NAME'])

    credentials = get_nova_credentials()
    glance_endpoint = keystone.service_catalog.url_for(service_type='image')

    nc = nvclient.Client(**credentials)
    gc = glclient.Client(glance_endpoint, token=keystone.auth_token)

    L = []

    for server in nc.servers.list(detailed=True):
        imagedata = server.image

        if imagedata:
            try:
                jsondata = json.dumps(imagedata['id'])
                image_id = jsondata.translate(None, '"')
            except ValueError:
                print "Decoding JSON has failed"
            try:
                imageinfo = gc.images.get(image_id)
            except glanceclient.exc.HTTPException:
                continue                                
            try:
                jsondata = json.dumps(imageinfo['name'])
                image_name = jsondata.translate(None, '"')
            except ValueError:
                print "Decoding JSON has failed"

            L.append(image_name)

    count = Counter(L)
    print "***** %s *****" % os.environ['OS_TENANT_NAME']
    for key, value in sorted(count.iteritems()):
        print "%s,%d" % (key, value)

if __name__ == '__main__':
    main()

