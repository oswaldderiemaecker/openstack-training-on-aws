#!/bin/bash

# TODO: Refactor - Quick script
# Old-Public-IP New-Public-IP
# Old-Local-IP New-Local-IP
# ./ip-change.sh 34.224.228.250 34.227.89.179 172.31.36.180 172.31.35.124

sed -i s/$1/$2/ /etc/nova/nova.conf
sed -i s/$3/$4/ /etc/hosts
sed -i s/$3/$4/ /etc/nova/nova.conf
sed -i s/$3/$4/ /etc/neutron/plugins/ml2/linuxbridge_agent.ini
sed -i s/$3/$4/ /etc/cinder/cinder.conf


echo "Stopping Services"
systemctl stop --force openstack-nova-api.service openstack-nova-consoleauth.service openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service
sleep 2
systemctl stop --force neutron-server.service
sleep 2
systemctl stop --force openstack-glance-api.service openstack-glance-registry.service
systemctl stop --force httpd.service memcached.service
systemctl stop --force rabbitmq-server.service
systemctl stop --force openstack-losetup.service
systemctl stop --force openstack-cinder-api.service
systemctl stop --force openstack-cinder-scheduler.service
systemctl stop --force openstack-cinder-volume.service
systemctl stop --force openstack-cinder-backup.service
sleep 2
systemctl stop --force openstack-nova-compute.service
systemctl stop --force libvirtd.service openstack-nova-compute.service
sleep 2
systemctl stop --force neutron-server.service
systemctl stop --force neutron-linuxbridge-agent.service
systemctl stop --force neutron-l3-agent.service
systemctl stop --force neutron-dhcp-agent.service
systemctl stop --force neutron-metadata-agent.service
killall dnsmasq
systemctl stop --force openstack-heat-api.service openstack-heat-api-cfn.service openstack-heat-engine.service

echo "Starting Services"
systemctl restart mariadb.service
systemctl restart httpd.service memcached.service
systemctl restart rabbitmq-server.service
sleep 3
rabbitmqctl add_user openstack rootroot
rabbitmqctl set_permissions openstack ".*" ".*" ".*"
rabbitmqctl list_users

systemctl restart openstack-nova-api.service openstack-nova-consoleauth.service

# nova-manage cell_v2 delete_cell --force --cell_uuid 393d2a35-24d3-4e20-a6f0-5b7bbd017637
su -s /bin/sh -c "nova-manage cell_v2 discover_hosts --verbose" nova
su -s /bin/sh -c "nova-manage cell_v2 list_cells" nova

systemctl restart openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service
sleep 2
echo "Starting Neutron"
systemctl restart neutron-server.service
sleep 2
echo "Starting Glance"
systemctl restart openstack-glance-api.service openstack-glance-registry.service
echo "Starting Cinder"
systemctl restart openstack-losetup.service
systemctl restart openstack-cinder-api.service
systemctl restart openstack-cinder-scheduler.service
systemctl restart openstack-cinder-volume.service
systemctl restart openstack-cinder-backup.service
sleep 2
echo "Starting Nova Compute"
systemctl restart openstack-nova-compute.service
systemctl restart libvirtd.service openstack-nova-compute.service
sleep 2
echo "Starting LinuxBridge"
systemctl restart neutron-server.service
systemctl restart neutron-linuxbridge-agent.service
systemctl restart neutron-l3-agent.service
systemctl restart neutron-dhcp-agent.service
systemctl restart neutron-metadata-agent.service
echo "Starting Heat"
systemctl restart openstack-heat-api.service   openstack-heat-api-cfn.service openstack-heat-engine.service

systemctl status openstack-nova-api.service
systemctl status openstack-nova-consoleauth.service
systemctl status openstack-nova-scheduler.service
systemctl status openstack-nova-conductor.service
systemctl status openstack-nova-novncproxy.service
sleep 3
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
systemctl status openstack-nova-compute.service
systemctl status libvirtd.service openstack-nova-compute.service
sleep 3
systemctl status neutron-server.service
systemctl status neutron-linuxbridge-agent.service
systemctl status neutron-l3-agent.service
systemctl status neutron-dhcp-agent.service
systemctl status neutron-metadata-agent.service
sleep 3
systemctl status openstack-heat-api.service   openstack-heat-api-cfn.service openstack-heat-engine.service

su -s /bin/sh -c "nova-manage cell_v2 discover_hosts --verbose" nova
su -s /bin/sh -c "nova-manage cell_v2 list_cells" nova

. keystonerc_admin
openstack compute service list
openstack network agent list
openstack hypervisor list
