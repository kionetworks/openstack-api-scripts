#!/usr/bin/python

from libcloud.compute.types import Provider
from libcloud.compute.providers import get_driver

import libcloud.security
libcloud.security.VERIFY_SSL_CERT = False

auth_username = 'admin'
auth_password = 'thepassword'
auth_url      = 'http://172.18.0.10:5000'
project_name  = 'Tecnologia'

provider = get_driver(Provider.OPENSTACK)
conn = provider(auth_username,
                auth_password,
                ex_force_auth_url=auth_url,
                ex_force_auth_version='2.0_password',
                ex_force_service_region='regionOne',
                ex_tenant_name=project_name)

instance_name = 'Ubuntu_by_libcloud'
# 7   Red
flavor_id = '7'
flavor = conn.ex_get_size(flavor_id)
# f5fc4336-8622-42f2-a1fc-cf46ff140686  Ubuntu-cfntools
image_id = 'f5fc4336-8622-42f2-a1fc-cf46ff140686'
image = conn.get_image(image_id)
password = 'yourpreferedpassword'
# 855cbb0a-a11a-497b-b90c-5b53c2b9f48d Management Network Tecnologia
net_id = '855cbb0a-a11a-497b-b90c-5b53c2b9f48d'

networks = conn.ex_list_networks()
for network in networks:
    if network.id == net_id:
        the_network = network


print('Checking for existing instance...')

instance_exists = False

for instance in conn.list_nodes():
    if instance.name == instance_name:
        testing_instance = instance
	instance_exists = True

if instance_exists:
   print('Instance ' + testing_instance.name + ' already exists. Skipping creation.')
else:
    testing_instance = conn.create_node(name=instance_name,
				image=image,
				size=flavor,
                                networks=[the_network],
				ex_admin_pass=password)
    conn.wait_until_running([testing_instance])

for instance in conn.list_nodes():
    if instance.name == instance_name:
        print(instance)

