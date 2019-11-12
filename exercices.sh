#!/bin/bash

set -e

systemctl restart openstack-cinder-api.service
systemctl restart openstack-cinder-scheduler.service
systemctl restart openstack-cinder-volume.service
systemctl restart openstack-cinder-backup.service

openstack compute service list
openstack network agent list
openstack hypervisor list
openstack volume service list
nova-status upgrade check
vgdisplay

sleep 60

. keystonerc_myuser
openstack volume create --size 1 mytestvolume1
openstack volume list
openstack volume delete mytestvolume1

. keystonerc_admin
openstack project create myproject
openstack project list
openstack user create --email oswald@continuous.lu --password demo --project myproject myuser
openstack role add --project myproject --user myuser member

echo "
unset OS_SERVICE_TOKEN
    export OS_USERNAME=myuser
    export OS_PASSWORD=demo
    export OS_AUTH_URL=http://controller.example.com:5000/v3
    export PS1='[\u@\h \W(keystone_myuser)]\$ '

export OS_TENANT_NAME=Default
export OS_REGION_NAME=RegionOne
export OS_PROJECT_NAME=myproject
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_IDENTITY_API_VERSION=3
" > keystonerc_myuser

. keystonerc_myuser
ssh-keygen -f ~/.ssh/myuser-key
nova keypair-add --pub-key ~/.ssh/myuser-key.pub myuser-key
nova keypair-list

. keystonerc_admin
openstack flavor create --id 3 --ram 512 --vcpus 1 --disk 1  myflavor

. keystonerc_myuser
openstack flavor list

. keystonerc_admin
wget http://download.cirros-cloud.net/0.3.5/cirros-0.3.5-x86_64-disk.img
openstack image create "cirros-0.3.5" --file cirros-0.3.5-x86_64-disk.img --disk-format qcow2 --container-format bare --public
openstack image list

. keystonerc_myuser

openstack security group list
openstack security group rule list default
openstack security group rule create --help
openstack security group create --description "Allow ssh" web-ssh
openstack security group rule create --protocol tcp --ingress --dst-port 22 web-ssh
openstack security group rule create --protocol tcp --ingress --dst-port 80 web-ssh
openstack security group rule list web-ssh

. keystonerc_myuser

openstack image list
openstack network list
NIC=$(openstack network list | grep public | awk '{print $2}')
openstack server create --flavor myflavor --image cirros-0.3.5 --security-group web-ssh --key-name myuser-key --nic net-id=$NIC mywebinstance

openstack server list

. keystonerc_myuser
openstack volume create --size 1 mytestvolume1
openstack volume list

. keystonerc_myuser
openstack server add volume --device /dev/vdb mywebinstance mytestvolume1
openstack server show mywebinstance
openstack volume list
openstack server remove volume mywebinstance mytestvolume1
openstack server show mywebinstance

. keystonerc_myuser
openstack server list
openstack server show mywebinstance
ip netns list
ROUTER=$(ip netns ls | grep router | awk {'print $1'})
ip netns exec $ROUTER ssh -i $HOME/.ssh/myuser-key cirros@10.0.30.20 touch testing.txt

. keystonerc_myuser
nova image-create mywebinstance mynewwebinstance-image
openstack image list
openstack network list
openstack server create --flavor myflavor --image mynewwebinstance-image --security-group web-ssh --key-name myuser-key --nic net-id=$NIC mywebinstance-from-new-image
openstack server list
ip netns list
ROUTER=$(ip netns ls | grep router | awk {'print $1'})
ip netns exec $ROUTER ssh -i $HOME/.ssh/myuser-key cirros@10.0.30.18 ls -l

. keystonerc_myuser
openstack volume list
openstack snapshot create --name mytestvolume1-snapshot mytestvolume1
openstack snapshot list
openstack volume create --size 1 --snapshot mytestvolume1-snapshot mynewtestvolume1-from-snapshot
openstack server add volume --device /dev/vdb mywebinstance-from-new-image mynewtestvolume1-from-snapshot
openstack server show mywebinstance-from-new-image
ip netns exec $ROUTER ssh -i $HOME/.ssh/myuser-key cirros@10.0.30.18 sudo fdisk -l
openstack server remove volume mywebinstance-from-new-image mynewtestvolume1-from-snapshot
openstack volume snapshot delete mytestvolume1-snapshot
openstack server remove volume mywebinstance-from-new-image  mynewtestvolume1-from-snapshot
openstack volume snapshot list
openstack volume snapshot delete mytestvolume1-snapshot
openstack server delete mywebinstance
openstack volume list
openstack volume delete mytestvolume1
openstack volume delete mynewtestvolume1-from-snapshot
