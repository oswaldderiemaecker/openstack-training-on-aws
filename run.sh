#!/bin/bash
# Configure Hosts with Management and Provider interface

set -e

PUBLIC_IP="172.31.32.6"
MANAGEMENT_IP="172.31.32.6"
PROVIDER_IP="172.31.33.218"
PROVIDER_INTERFACE_NAME="ens7"
OVERLAY_INTERFACE_IP_ADDRESS=$MANAGEMENT_IP

echo "$MANAGEMENT_IP controller.example.com controller
$MANAGEMENT_IP compute.example.com compute
$MANAGEMENT_IP network.example.com network" >> /etc/hosts
setenforce 0 ; sed -i 's/=enforcing/=disabled/g' /etc/sysconfig/selinux
getenforce
yum update -y
ping -c 4 www.google.com
ping -c 4 controller
yum install chrony -y
cat /etc/chrony.conf
systemctl enable chronyd.service
systemctl start chronyd.service
yum install ntpdate -y
ntpdate -u 0.europe.pool.ntp.org
yum install centos-release-openstack-rocky -y
yum update -y
yum install python-openstackclient openstack-selinux -y
yum install mariadb mariadb-server python2-PyMySQL -y
echo '
[mysqld]
bind-address = controller
default-storage-engine = innodb
innodb_file_per_table
max_connections = 4096
collation-server = utf8_general_ci
character-set-server = utf8
' > /etc/my.cnf.d/openstack.cnf
systemctl enable mariadb.service
systemctl start mariadb.service
systemctl status mariadb.service
mysql_secure_installation
yum install rabbitmq-server -y
systemctl enable rabbitmq-server.service
systemctl start rabbitmq-server.service
systemctl status rabbitmq-server.service
rabbitmqctl add_user openstack rootroot
rabbitmqctl set_permissions openstack ".*" ".*" ".*"
yum install memcached python-memcached -y
systemctl enable memcached.service
systemctl start memcached.service
systemctl status memcached.service


# Keystone
mysql -u root -prootroot -e "CREATE DATABASE keystone; GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY 'rootroot'; GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY 'rootroot';"
yum install openstack-keystone httpd mod_wsgi -y

echo '
[DEFAULT]
[database]
connection = mysql+pymysql://keystone:rootroot@controller.example.com/keystone

[token]
provider = fernet
'> /etc/keystone/keystone.conf
su -s /bin/sh -c "keystone-manage db_sync" keystone
keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
keystone-manage bootstrap --bootstrap-password rootroot --bootstrap-admin-url http://controller.example.com:5000/v3/ \
                          --bootstrap-internal-url http://controller.example.com:5000/v3/ \
                          --bootstrap-public-url http://controller.example.com:5000/v3/ \
                          --bootstrap-region-id RegionOne
sed -i 's/#ServerName www.example.com:80/ServerName controller/g' /etc/httpd/conf/httpd.conf
ln -s /usr/share/keystone/wsgi-keystone.conf /etc/httpd/conf.d/
setenforce 0 ; sed -i 's/=enforcing/=disabled/g' /etc/sysconfig/selinux
getenforce
systemctl enable httpd.service
systemctl start httpd.service
systemctl status httpd.service

cd
echo "
unset OS_SERVICE_TOKEN
    export OS_USERNAME=admin
    export OS_PASSWORD=rootroot
    export OS_AUTH_URL=http://controller.example.com:5000/v3
    export PS1='[\u@\h \W(keystone_admin)]\$ '

export OS_TENANT_NAME=admin
export OS_REGION_NAME=RegionOne
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_IDENTITY_API_VERSION=3" > keystonerc_admin

. keystonerc_admin
openstack project create --domain default --description "Service Project" services
openstack project create --domain default --description "Demo Project" demo
openstack user create --domain default --password rootroot demo # to-check
openstack role create user
openstack role add --project demo --user demo user

# Glance

mysql -u root -prootroot -e "CREATE DATABASE glance; GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY 'rootroot'; GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY 'rootroot';"
openstack user create --domain default --password rootroot glance
openstack role add --project services --user glance admin
openstack service create --name glance --description "OpenStack Image" image
openstack endpoint create --region RegionOne image public http://controller.example.com:9292
openstack endpoint create --region RegionOne image internal http://controller.example.com:9292
openstack endpoint create --region RegionOne image admin http://controller.example.com:9292
yum install openstack-glance -y
echo '
[database]
connection = mysql+pymysql://glance:rootroot@controller.example.com/glance

[glance_store]
stores = file,http,swift
default_store = file
filesystem_store_datadir = /var/lib/glance/images/
os_region_name=RegionOne

[keystone_authtoken]
www_authenticate_uri  = http://controller:5000
auth_uri = http://controller:5000
auth_url = http://controller:5000
memcached_servers = controller:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = services
username = glance
password = rootroot

[oslo_policy]
policy_file = /etc/glance/policy.json

[paste_deploy]
flavor = keystone
' > /etc/glance/glance-api.conf

echo '
[database]
connection = mysql+pymysql://glance:rootroot@controller.example.com/glance

[keystone_authtoken]
www_authenticate_uri = http://controller:5000
auth_uri = http://controller:5000
auth_url = http://controller:5000
memcached_servers = controller:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = services
username = glances
password = rootroot

[paste_deploy]
flavor = keystone
' > /etc/glance/glance-registry.conf

mkdir -p /var/lib/glance/images/
mkdir -p /var/lib/glance/image-cache
chown -R glance:glance /var/lib/glance/images
chown -R glance:glance /var/lib/glance/image-cache

export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
su -s /bin/sh -c "glance-manage db_sync" glance

systemctl enable openstack-glance-api.service openstack-glance-registry.service
systemctl start openstack-glance-api.service openstack-glance-registry.service
systemctl status openstack-glance-api.service openstack-glance-registry.service

sudo yum -y install wget
wget http://download.cirros-cloud.net/0.4.0/cirros-0.4.0-x86_64-disk.img
openstack image create "cirros" --file cirros-0.4.0-x86_64-disk.img --disk-format qcow2 --container-format bare --public
openstack image list

# Nova

mysql -u root -prootroot -e "CREATE DATABASE nova_api; CREATE DATABASE nova; CREATE DATABASE nova_cell0; CREATE DATABASE placement;"
mysql -u root -prootroot -e "GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY 'rootroot'; GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY 'rootroot';"
mysql -u root -prootroot -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY 'rootroot'; GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY 'rootroot';"
mysql -u root -prootroot -e "GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'localhost' IDENTIFIED BY 'rootroot'; GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%' IDENTIFIED BY 'rootroot';"
mysql -u root -prootroot -e "GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'localhost' IDENTIFIED BY 'rootroot'; GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'%' IDENTIFIED BY 'rootroot';"

. keystonerc_admin

openstack user create --domain default --password rootroot nova
openstack role add --project services --user nova admin
openstack service create --name nova --description "OpenStack Compute" compute
openstack endpoint create --region RegionOne compute public http://controller:8774/v2.1
openstack endpoint create --region RegionOne compute internal http://controller:8774/v2.1
openstack endpoint create --region RegionOne compute admin http://controller:8774/v2.1
openstack user create --domain default --password rootroot placement
openstack role add --project services --user placement admin
openstack service create --name placement --description "Placement API" placement
openstack endpoint create --region RegionOne placement public http://controller.example.com:8778
openstack endpoint create --region RegionOne placement internal http://controller.example.com:8778
openstack endpoint create --region RegionOne placement admin http://controller.example.com:8778
yum install openstack-nova-api openstack-nova-conductor openstack-nova-console openstack-nova-novncproxy openstack-nova-scheduler openstack-nova-placement-api -y
echo "
[DEFAULT]
my_ip = $MANAGEMENT_IP
enabled_apis = osapi_compute,metadata
transport_url=rabbit://openstack:rootroot@controller.example.com:5672/
use_neutron = true
firewall_driver = nova.virt.firewall.NoopFirewallDriver

[database]
connection=mysql+pymysql://nova:rootroot@controller.example.com/nova

[api_database]
connection=mysql+pymysql://nova:rootroot@controller.example.com/nova_api

[placement_database]
connection=mysql+pymysql://placement:rootroot@controller.example.com/placement

[api]
auth_strategy = keystone

[keystone_authtoken]
auth_url = http://controller:5000/v3
memcached_servers = controller:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = services
username = nova
password = rootroot

[vnc]
enabled = true
server_listen = \$my_ip
server_proxyclient_address = \$my_ip
novncproxy_base_url = http://controller:6080/vnc_auto.html

[glance]
api_servers = http://controller:9292

[oslo_concurrency]
lock_path = /var/lib/nova/tmp

[placement]
region_name = RegionOne
project_domain_name = Default
project_name = services
auth_type = password
user_domain_name = Default
auth_url = http://controller:5000/v3
username = placement
password = rootroot
" > /etc/nova/nova.conf

echo '
<Directory /usr/bin>
   <IfVersion >= 2.4>
      Require all granted
   </IfVersion>
   <IfVersion < 2.4>
      Order allow,deny
      Allow from all
   </IfVersion>
</Directory>
' >> /etc/httpd/conf.d/00-nova-placement-api.conf

systemctl restart httpd.service
chown nova:nova /usr/bin/nova-placement-api
chown nova:nova /var/log/nova/nova-placement-api.log
su -s /bin/sh -c "nova-manage api_db sync" nova
su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova
su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova
su -s /bin/sh -c "nova-manage db sync" nova
su -s /bin/sh -c "nova-manage cell_v2 list_cells" nova
nova-manage cell_v2 list_cells
systemctl enable openstack-nova-api.service openstack-nova-consoleauth openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service
systemctl start openstack-nova-api.service openstack-nova-consoleauth openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service
systemctl status openstack-nova-api.service openstack-nova-consoleauth openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service

yum install openstack-nova-compute -y

#egrep -c '(vmx|svm)' /proc/cpuinfo

echo '
[libvirt]
virt_type = qemu
' >> /etc/nova/nova.conf

systemctl enable libvirtd.service openstack-nova-compute.service
systemctl start libvirtd.service openstack-nova-compute.service
systemctl status libvirtd.service openstack-nova-compute.service

openstack compute service list --service nova-compute
su -s /bin/sh -c "nova-manage cell_v2 discover_hosts --verbose" nova
openstack hypervisor list
openstack compute service list

# Neutron

mysql -u root -prootroot -e "CREATE DATABASE neutron; GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY 'rootroot'; GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY 'rootroot';"
openstack user create --domain default --password rootroot neutron
openstack role add --project services --user neutron admin
openstack service create --name neutron --description "OpenStack Networking" network
openstack endpoint create --region RegionOne network public http://controller.example.com:9696
openstack endpoint create --region RegionOne network internal http://controller.example.com:9696
openstack endpoint create --region RegionOne network admin http://controller.example.com:9696

yum install openstack-neutron openstack-neutron-ml2 openstack-neutron-linuxbridge ebtables -y

echo '
[DEFAULT]
core_plugin = ml2
service_plugins = router
allow_overlapping_ips = true
transport_url=rabbit://openstack:rootroot@controller.example.com:5672/
auth_strategy = keystone
notify_nova_on_port_status_changes = true
notify_nova_on_port_data_changes = true

[database]
connection=mysql+pymysql://neutron:rootroot@controller.example.com/neutron

[keystone_authtoken]
www_authenticate_uri = http://controller:5000
auth_uri=http://controller:5000/
auth_type=password
auth_url=http://controller:5000
username=neutron
password=rootroot
user_domain_name=Default
project_name=services
project_domain_name=Default

[nova]
region_name=RegionOne
auth_url=http://controller:5000
auth_type=password
project_domain_name=Default
project_name=services
user_domain_name=Default
username=nova
password=rootroot

[oslo_concurrency]
lock_path = /var/lib/neutron/tmp
' > /etc/neutron/neutron.conf

echo '
[ml2]
type_drivers = flat,vlan,vxlan
tenant_network_types = vxlan
mechanism_drivers = linuxbridge,l2population
extension_drivers = port_security

[ml2_type_flat]
flat_networks = provider

[ml2_type_vxlan]
vni_ranges = 1:1000

[securitygroup]
enable_ipset = true
' > /etc/neutron/plugins/ml2/ml2_conf.ini

echo "
[linux_bridge]
physical_interface_mappings = provider:$PROVIDER_INTERFACE_NAME

[vxlan]
enable_vxlan = true
local_ip = $OVERLAY_INTERFACE_IP_ADDRESS
l2_population = true

[securitygroup]
enable_security_group = true
firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
" > /etc/neutron/plugins/ml2/linuxbridge_agent.ini

echo '
[DEFAULT]
interface_driver = linuxbridge
' > /etc/neutron/l3_agent.ini

echo '
[DEFAULT]
interface_driver = linuxbridge
dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq
enable_isolated_metadata = true
' > /etc/neutron/dhcp_agent.ini

echo '
[DEFAULT]
nova_metadata_host = controller
metadata_proxy_shared_secret = METADATA_SECRET
' > /etc/neutron/metadata_agent.ini

yum install openstack-neutron-linuxbridge ebtables ipset

echo '
[neutron]
url = http://controller:9696
auth_url = http://controller:5000
auth_type = password
project_domain_name = default
user_domain_name = default
region_name = RegionOne
project_name = services
username = neutron
password = rootroot
service_metadata_proxy = true
metadata_proxy_shared_secret = METADATA_SECRET
' >> /etc/nova/nova.conf

ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron
systemctl restart openstack-nova-api.service

systemctl enable neutron-server.service neutron-linuxbridge-agent.service neutron-l3-agent.service neutron-dhcp-agent.service neutron-metadata-agent.service
systemctl start neutron-server.service neutron-linuxbridge-agent.service neutron-l3-agent.service neutron-dhcp-agent.service neutron-metadata-agent.service
systemctl status neutron-server.service neutron-linuxbridge-agent.service neutron-l3-agent.service neutron-dhcp-agent.service neutron-metadata-agent.service

systemctl restart openstack-nova-api.service openstack-nova-consoleauth.service openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service
systemctl restart neutron-server.service
systemctl restart openstack-glance-api.service openstack-glance-registry.service
systemctl restart httpd.service memcached.service
systemctl restart rabbitmq-server.service

systemctl status openstack-nova-api.service
systemctl status openstack-nova-consoleauth.service
systemctl status openstack-nova-scheduler.service
systemctl status openstack-nova-conductor.service
systemctl status openstack-nova-novncproxy.service
systemctl status neutron-server.service
systemctl status neutron-linuxbridge-agent.service
systemctl status neutron-l3-agent.service
systemctl status neutron-dhcp-agent.service
systemctl status neutron-metadata-agent.service
systemctl status openstack-glance-api.service
systemctl status openstack-glance-registry.service
systemctl status httpd.service memcached.service
systemctl status rabbitmq-server.service

openstack network agent list
openstack compute service list
openstack network agent list
openstack hypervisor list

# Cinder

mysql -u root -prootroot -e "CREATE DATABASE cinder; GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY 'rootroot'; GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' IDENTIFIED BY 'rootroot';"

openstack user create --domain default --password rootroot cinder
openstack role add --project services --user cinder admin
openstack service create --name cinderv2 --description "OpenStack Block Storage" volumev2
openstack service create --name cinderv3 --description "OpenStack Block Storage" volumev3
openstack endpoint create --region RegionOne volumev2 public http://controller:8776/v2/%\(project_id\)s
openstack endpoint create --region RegionOne volumev2 internal http://controller:8776/v2/%\(project_id\)s
openstack endpoint create --region RegionOne volumev2 admin http://controller:8776/v2/%\(project_id\)s
openstack endpoint create --region RegionOne volumev3 public http://controller:8776/v3/%\(project_id\)s
openstack endpoint create --region RegionOne volumev3 internal http://controller:8776/v3/%\(project_id\)s
openstack endpoint create --region RegionOne volumev3 admin http://controller:8776/v3/%\(project_id\)s

yum install openstack-cinder targetcli -y

echo "
[DEFAULT]
my_ip = $MANAGEMENT_IP
transport_url=rabbit://openstack:rootroot@controller.example.com:5672/
auth_strategy = keystone
enabled_backends = lvm

[database]
connection = mysql+pymysql://cinder:rootroot@controller.example.com/cinder

[keystone_authtoken]
www_authenticate_uri = http://controller:5000
auth_uri = http://controller:5000
auth_url = http://controller:5000
memcached_servers = 127.0.0.1:11211
auth_type = password
project_domain_id = default
user_domain_id = default
project_name = services
username = cinder
password = rootroot

[oslo_concurrency]
lock_path = /var/lib/cinder/tmp

[lvm]
iscsi_helper=lioadm
iscsi_ip_address=$MANAGEMENT_IP
volume_driver=cinder.volume.drivers.lvm.LVMVolumeDriver
volumes_dir=/var/lib/cinder/volumes
volume_backend_name=lvm
" > /etc/cinder/cinder.conf

su -s /bin/sh -c "cinder-manage db sync" cinder

echo '
[cinder]
os_region_name = RegionOne
' >> /etc/nova/nova.conf

systemctl restart openstack-nova-api.service
systemctl enable openstack-cinder-api.service openstack-cinder-scheduler.service
systemctl start openstack-cinder-api.service openstack-cinder-scheduler.service

yum install lvm2 device-mapper-persistent-data

systemctl enable lvm2-lvmetad.service
systemctl start lvm2-lvmetad.service

mkdir -p /var/lib/cinder/volumes
dd if=/dev/zero of=/var/lib/cinder/cinder-volumes bs=1G count=4
losetup /dev/loop0 /var/lib/cinder/cinder-volumes
pvcreate /dev/loop0
vgcreate "cinder-volumes" /dev/loop0
vgdisplay

echo "
[Unit]
    Description=Setup cinder-volume loop device
    DefaultDependencies=false
    Before=openstack-cinder-volume.service
    After=local-fs.target

    [Service]
    Type=oneshot
    ExecStart=/usr/bin/sh -c '/usr/sbin/losetup -j /var/lib/cinder/cinder-volumes | /usr/bin/grep /var/lib/cinder/cinder-volumes || /usr/sbin/losetup -f /var/lib/cinder/cinder-volumes'
    ExecStop=/usr/bin/sh -c '/usr/sbin/losetup -j /var/lib/cinder/cinder-volumes | /usr/bin/cut -d : -f 1 | /usr/bin/xargs /usr/sbin/losetup -d'
    TimeoutSec=60
    RemainAfterExit=yes

    [Install]
    RequiredBy=openstack-cinder-volume.service
" > /usr/lib/systemd/system/openstack-losetup.service

ln -s /usr/lib/systemd/system/openstack-losetup.service /etc/systemd/system/multi-user.target.wants/openstack-losetup.service

systemctl enable openstack-cinder-api.service
systemctl enable openstack-cinder-scheduler.service
systemctl enable openstack-cinder-volume.service
systemctl enable openstack-cinder-backup.service
systemctl restart openstack-losetup.service
systemctl restart openstack-cinder-api.service
systemctl restart openstack-cinder-scheduler.service
systemctl restart openstack-cinder-volume.service
systemctl restart openstack-cinder-backup.service
systemctl status openstack-cinder-api.service
systemctl status openstack-cinder-scheduler.service
systemctl status openstack-cinder-volume.service
systemctl status openstack-cinder-backup.service

# Horizon

yum install openstack-dashboard -y

