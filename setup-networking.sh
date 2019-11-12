#!/bin/bash

set -e

. keystonerc_admin

openstack flavor create --id 0 --ram 512   --vcpus 1 --disk 1  m1.tiny
openstack flavor create --id 1 --ram 1024  --vcpus 1 --disk 1  m1.small
openstack flavor create --id 2 --ram 2048  --vcpus 1 --disk 1  m1.large

neutron net-create public --shared --router:external=True --provider:network_type=vxlan --provider:segmentation_id=96
neutron subnet-create --name public_subnet --enable-dhcp --allocation-pool start=192.168.178.100,end=192.168.178.150 public 192.168.178.0/24

echo "
unset OS_SERVICE_TOKEN
    export OS_USERNAME=demo
    export OS_PASSWORD=rootroot
    export OS_AUTH_URL=http://controller.example.com:5000/v3
    export PS1='[\u@\h \W(keystone_demo)]\$ '

export OS_TENANT_NAME=Default
export OS_REGION_NAME=RegionOne
export OS_PROJECT_NAME=demo
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_IDENTITY_API_VERSION=3
" > keystonerc_demo

. keystonerc_demo

neutron net-create private
neutron subnet-create --name private_subnet --dns-nameserver 8.8.8.8 --dns-nameserver 8.8.4.4 --allocation-pool start=10.0.30.10,end=10.0.30.254 private 10.0.30.0/24

neutron router-create extrouter
neutron router-gateway-set extrouter public
neutron router-interface-add extrouter private_subnet

systemctl restart openstack-nova-api.service openstack-nova-consoleauth.service openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service
systemctl restart neutron-server.service
systemctl restart openstack-glance-api.service openstack-glance-registry.service
systemctl restart httpd.service memcached.service
systemctl restart rabbitmq-server.service
systemctl restart openstack-losetup.service
systemctl restart openstack-cinder-api.service
systemctl restart openstack-cinder-scheduler.service
systemctl restart openstack-cinder-volume.service
systemctl restart openstack-cinder-backup.service

systemctl status openstack-nova-api.service
systemctl status openstack-nova-consoleauth.service
systemctl status openstack-nova-scheduler.service
systemctl status openstack-nova-conductor.service
systemctl status openstack-nova-novncproxy.service
systemctl status neutron-server.service
systemctl status neutron-metadata-agent.service
systemctl status openstack-glance-api.service
systemctl status openstack-glance-registry.service
systemctl status httpd.service memcached.service
systemctl status rabbitmq-server.service
systemctl status openstack-losetup.service
systemctl status openstack-cinder-api.service
systemctl status openstack-cinder-scheduler.service
systemctl status openstack-cinder-volume.service
systemctl status openstack-cinder-backup.service

systemctl enable neutron-server.service
systemctl enable neutron-linuxbridge-agent.service
systemctl enable neutron-l3-agent.service
systemctl enable neutron-dhcp-agent.service
systemctl enable neutron-metadata-agent.service

systemctl restart neutron-server.service
systemctl restart neutron-linuxbridge-agent.service
systemctl restart neutron-l3-agent.service
systemctl restart neutron-dhcp-agent.service
systemctl restart neutron-metadata-agent.service

systemctl status neutron-server.service
systemctl status neutron-linuxbridge-agent.service
systemctl status neutron-l3-agent.service
systemctl status neutron-dhcp-agent.service
systemctl status neutron-metadata-agent.service

systemctl enable openstack-nova-compute.service
systemctl enable libvirtd.service openstack-nova-compute.service

systemctl restart openstack-nova-compute.service
systemctl restart libvirtd.service openstack-nova-compute.service

systemctl status openstack-nova-compute.service
systemctl status libvirtd.service openstack-nova-compute.service

. keystonerc_admin

openstack compute service list
openstack network agent list
openstack hypervisor list
openstack network list --external
openstack network list
openstack router list
openstack router show extrouter
openstack volume service list
nova-status upgrade check
vgdisplay
