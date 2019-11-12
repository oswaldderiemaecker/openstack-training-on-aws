#!/bin/bash

set -e

. keystonerc_myuser
openstack keypair delete myuser-key
openstack flavor delete myflavor
openstack image delete cirros-0.3.5
openstack server delete mywebinstance
openstack security group delete web-ssh
openstack volume delete mytestvolume1
openstack volume delete mynewtestvolume1-from-snapshot
openstack volume snapshot delete mytestvolume1-snapshot
. keystonerc_admin
openstack project delete myproject
openstack user delete myuser
