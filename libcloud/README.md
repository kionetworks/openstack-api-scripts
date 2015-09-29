# Libcloud

Apache Libcloud is a Python library which hides differences between different cloud provider APIs and allows you to manage different cloud resources through a unified and easy to use API.

https://libcloud.apache.org/

## One Interface To Rule Them All

* `images.py` lists all images in the tenant
* `flavors.py` lists all flavors in the tenant
* `networks.py` lists all networks in the tenant
* `create_instance.py` create an instance given the image id, flavor and network
