#!/usr/bin/python

from libcloud.compute.types import Provider
from libcloud.compute.providers import get_driver

import libcloud.security
libcloud.security.VERIFY_SSL_CERT = False

auth_username = 'admin'
auth_password = 'thepassword'
auth_url = 'http://172.18.0.10:5000'
project_name = 'admin'

provider = get_driver(Provider.OPENSTACK)
conn = provider(auth_username,
                auth_password,
                ex_force_auth_url=auth_url,
                ex_force_auth_version='2.0_password',
                ex_force_service_region='regionOne',
                ex_tenant_name=project_name)

flavors = conn.list_sizes()
print ("******** Flavor **********")
for flavor in flavors:
    print 'Name: %10s\tID: %40s\tRAM: %4s\tDisk: %5s\tVCPUS: %2s' % (flavor.name, flavor.id, flavor.ram, flavor.disk, flavor.vcpus)

