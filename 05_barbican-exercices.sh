#!/bin/bash

set -e

. keystonerc_admin

openstack volume type create LUKS
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
cinder encryption-type-create --cipher aes-xts-plain64 --key_size 256 --control_location front-end LUKS nova.volume.encryptors.luks.LuksEncryptor

. keystonerc_admin
openstack volume create --size 1 --type LUKS mycryptovolume
openstack volume show mycryptovolume

openstack security group create --description "Allow ssh Encrypted" web-ssh-enc
openstack security group rule create --protocol tcp --ingress --dst-port 22 web-ssh-enc
openstack security group rule create --protocol tcp --ingress --dst-port 80 web-ssh-enc
openstack security group rule list web-ssh-enc

ssh-keygen -f ~/.ssh/admin-key
openstack keypair create --public-key ~/.ssh/admin-key.pub admin-key
openstack keypair list

openstack server create --flavor m1.tiny --image cirros --security-group web-ssh-enc --key-name admin-key --nic net-id=$NIC myencryptedinstance

sleep 20

openstack server list
openstack volume list
ROUTER=$(ip netns ls | grep router | awk {'print $1'})
IP=$(openstack server list --name myencryptedinstance -f value -c Networks | awk -F"public=" '/public=/{print $2}')
openstack server add volume myencryptedinstance mycryptovolume --device /dev/vdc
ip netns exec $ROUTER ssh -i .ssh/admin-key cirros@$IP 'sudo /sbin/fdisk -l'
openstack server delete myencryptedinstance
openstack security group delete web-ssh-enc
openstack volume delete mycryptovolume
