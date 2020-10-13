# OpenStack Train on AWS (Training)

![](https://github.com/oswaldderiemaecker/openstack-training-on-aws/blob/master/screenshots/neutron.png)

Use the [AWS CloudFormation template](OpenStack-allinone.yml) to create an OpenStack Base install Stack.

For simplicity we will use the password **rootroot** for all passwords.

This is a **"all in one"** installation where everything is on the Controller.

It is recommended to make snapshots often so you can go back if any goes wrong.

The purpose of this training is to learn by installing all core OpenStack services from Scratch and practicing using the Labs (not included in this repository)

Follow the instructions steps by steps.

# 1 Base Installation

## 1.1 Installation of base system on the VMs

Get [CentOs 7](https://www.centos.org/download/) and install it, configure the network and base settings to suite your
configuration.

## 1.2 Configure Hosts and the Hostname

Get your IP address:

```bash
ip addr list
```

On the controller Node:
```bash
echo '172.31.32.70 controller.example.com controller
172.31.32.70 compute.example.com compute
172.31.32.70 network.example.com network' >> /etc/hosts
```

The interface are set as:

* 1st Interface: Public
* 2nd Interface: Management (172.31.32.70)
* 3rd Interface: Provider

## 1.3 Stop and disable firewalld & NetworkManager Service

**On all Nodes**

```bash
systemctl stop firewalld
systemctl disable firewalld
systemctl stop NetworkManager
systemctl disable NetworkManager
```

Disable SELinux using below command:

```bash
setenforce 0 ; sed -i 's/=enforcing/=disabled/g' /etc/sysconfig/selinux
getenforce
```

## 1.4 Update the repo

```bash
yum update -y
```

## 1.5 Verify connectivity

**On the controller Node:**

```bash
ping -c 4 www.google.com
ping -c 4 controller
```

## 1.6 Network Time Protocol (NTP) Setup

**On the Controller Node:**

```bash
yum install chrony -y
```

Edit the /etc/chrony.conf file and configure the server:

```
server 0.centos.pool.ntp.org iburst
server 1.centos.pool.ntp.org iburst
server 2.centos.pool.ntp.org iburst
server 3.centos.pool.ntp.org iburst
```

Start the NTP service and configure it to start when the system boots:

```bash
systemctl enable chronyd.service
systemctl start chronyd.service
```

Update the hour:

```bash
yum install ntpdate -y
ntpdate -u 0.europe.pool.ntp.org
```

## 1.7 Set OpenStack Train Repository

**On all Nodes install:**

```bash
yum install centos-release-openstack-train -y
yum update -y
yum install python-openstackclient openstack-selinux -y
```

## 1.8 Install MariaDB

**On Controller node**

```bash
yum install mariadb mariadb-server python2-PyMySQL -y
```

Create and edit the /etc/my.cnf.d/openstack.cnf file

```
[mysqld]
bind-address = controller
default-storage-engine = innodb
innodb_file_per_table
max_connections = 4096
collation-server = utf8_general_ci
character-set-server = utf8
```

Start the database service and configure it to start when the system boots:

```bash
systemctl enable mariadb.service
systemctl start mariadb.service
systemctl status mariadb.service
```

Secure the database service by running the mysql_secure_installation script.

```bash
mysql_secure_installation
```

**Use : rootroot as password.**

## 1.10 RabbitMQ message queue Setup

**On Controller node**

```bash
yum install rabbitmq-server -y
```

Start the message queue service and configure it to start when the system boots:

```bash
systemctl enable rabbitmq-server.service
systemctl start rabbitmq-server.service
systemctl status rabbitmq-server.service
```

Adding the openstack user:

```bash
rabbitmqctl add_user openstack rootroot
```

Permit configuration, write, and read access for the openstack user:

```bash
rabbitmqctl set_permissions openstack ".*" ".*" ".*"
```

## 1.10 Memcached setup

**On Controller node**

```bash
yum install memcached python-memcached -y
```

Start the Memcached service and configure it to start when the system boots:

```bash
systemctl enable memcached.service
systemctl start memcached.service
systemctl status memcached.service
```

# 2 Services Configurations

https://docs.openstack.org/install-guide/openstack-services.html#minimal-deployment-for-rocky

## 2.1.1 Installing Keystone

**On Controller node**

Connect to mysql

```bash
mysql -u root -p
```

And run the following SQL

```
CREATE DATABASE keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY 'rootroot';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY 'rootroot';
```

Install KeyStone:

```bash
yum install openstack-keystone httpd mod_wsgi -y
```

Edit the /etc/keystone/keystone.conf file and replace with the following:

```
[DEFAULT]
[database]
connection = mysql+pymysql://keystone:rootroot@controller.example.com/keystone

[token]
provider = fernet
```

Populate the Identity service database:

```bash
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
su -s /bin/sh -c "keystone-manage db_sync" keystone
```

Initialize Fernet key repositories:

```bash
keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
```

Bootstrap the Identity service:

```bash
keystone-manage bootstrap --bootstrap-password rootroot --bootstrap-admin-url http://controller.example.com:5000/v3/ \
                          --bootstrap-internal-url http://controller.example.com:5000/v3/ \
                          --bootstrap-public-url http://controller.example.com:5000/v3/ \
                          --bootstrap-region-id RegionOne
```

Configure the Apache HTTP server:

Edit the /etc/httpd/conf/httpd.conf file and configure the ServerName option to reference the controller node IP:

```
ServerName controller
```

Create a link to the /usr/share/keystone/wsgi-keystone.conf file:

```bash
ln -s /usr/share/keystone/wsgi-keystone.conf /etc/httpd/conf.d/
```

Disable SELinux again using below command:

```bash
setenforce 0 ; sed -i 's/=enforcing/=disabled/g' /etc/sysconfig/selinux
getenforce
```

Start the Apache HTTP service and configure it to start when the system boots:

```bash
systemctl enable httpd.service
systemctl start httpd.service
systemctl status httpd.service
```

Configure the administrative account by creating a keystonerc_admin file

```
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
export OS_IDENTITY_API_VERSION=3
```

## 2.1.2 Create a domain, projects, users, and roles

**On Controller node**

Set the environment:

```bash
. keystonerc_admin
```

Create the service project:

```bash
openstack project create --domain default --description "Service Project" service
```

Create the demo project:

```bash
openstack project create --domain default --description "Demo Project" demo
```

Create the demo user:

```bash
openstack user create --domain default --password-prompt demo
```

Create the user role:

```bash
openstack role create user
```

Add the user role to the demo project and user:

```bash
openstack role add --project demo --user demo user
```

## 2.1.3 Verify operation of the Identity service

Unset the temporary OS_AUTH_URL and OS_PASSWORD environment variable:

```bash
unset OS_AUTH_URL OS_PASSWORD
```

As the admin user, request an authentication token:

```bash
openstack --os-auth-url http://controller.example.com:5000/v3 --os-project-domain-name Default --os-user-domain-name Default --os-project-name admin --os-username admin token issue
```

As the demo user, request an authentication token:

```bash
openstack --os-auth-url http://controller.example.com:5000/v3 --os-project-domain-name Default --os-user-domain-name Default --os-project-name demo --os-username demo token issue
```

## 2.2.1 Image (glance) service install and configure

**On Controller node**

Use the database access client to connect to the database server as the root user:

```bash
mysql -u root -p
```

```
CREATE DATABASE glance;
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY 'rootroot';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY 'rootroot';
```

Create the glance user:

```bash
openstack user create --domain default --password-prompt glance
```

Add the admin role to the glance user and service project:

```bash
openstack role add --project service --user glance admin
```

Create the glance service entity:

```bash
openstack service create --name glance --description "OpenStack Image" image
```

Create the Image service API endpoints:

```bash
openstack endpoint create --region RegionOne image public http://controller.example.com:9292
openstack endpoint create --region RegionOne image internal http://controller.example.com:9292
openstack endpoint create --region RegionOne image admin http://controller.example.com:9292
```

Install the packages:

```bash
yum install openstack-glance -y
```

Edit the /etc/glance/glance-api.conf file and replace with the following actions:

```
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
project_name = service
username = glance
password = rootroot

[oslo_policy]
policy_file = /etc/glance/policy.json

[paste_deploy]
flavor = keystone
```

Edit the /etc/glance/glance-registry.conf file and replace with the following actions:

```
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
project_name = service
username = glance
password = rootroot

[paste_deploy]
flavor = keystone
```

Create the image cache folder:

```bash
mkdir -p /var/lib/glance/images/
mkdir -p /var/lib/glance/image-cache
chown -R glance:glance /var/lib/glance/images
chown -R glance:glance /var/lib/glance/image-cache
```

Populate the Image service database:

```bash
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
su -s /bin/sh -c "glance-manage db_sync" glance
```

Start the Image services and configure them to start when the system boots:

```bash
systemctl enable openstack-glance-api.service openstack-glance-registry.service
systemctl start openstack-glance-api.service openstack-glance-registry.service
```

Verify the Glance Service is running:

```bash
systemctl status openstack-glance-api.service openstack-glance-registry.service
```

Now download the cirros source image:

```bash
sudo yum -y install wget
wget http://download.cirros-cloud.net/0.4.0/cirros-0.4.0-x86_64-disk.img
```

Upload the image to the Image service using the QCOW2 disk format, bare container format, and public visibility so all projects can access it:

```bash
openstack image create "cirros" --file cirros-0.4.0-x86_64-disk.img --disk-format qcow2 --container-format bare --public
```

Confirm upload of the image and validate attributes:

```bash
openstack image list
```

## 2.2.2 Compute (nova) service install and configure

### 2.2.2.1 Install and configure controller

Before you install and configure the Compute service, you must create databases, service credentials,
and API endpoints.

Use the database access client to connect to the database server as the root user:

```bash
mysql -u root -p
```

Create the nova_api and nova databases:

```bash
CREATE DATABASE nova_api;
CREATE DATABASE nova;
CREATE DATABASE nova_cell0;
CREATE DATABASE placement;
```

Grant proper access to the databases:

```bash
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY 'rootroot';
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY 'rootroot';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY 'rootroot';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY 'rootroot';
GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'localhost' IDENTIFIED BY 'rootroot';
GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%' IDENTIFIED BY 'rootroot';
GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'localhost' IDENTIFIED BY 'rootroot';
GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'%' IDENTIFIED BY 'rootroot';
```
Source the admin credentials to gain access to admin-only CLI commands:

```bash
. keystonerc_admin
```

Create the nova user:

```bash
openstack user create --domain default --password-prompt nova
```

Add the admin role to the nova user:

```bash
openstack role add --project service --user nova admin
```

Create the nova service entity:

```bash
openstack service create --name nova --description "OpenStack Compute" compute
```

Create the Nova Compute service API endpoints:

```bash
openstack endpoint create --region RegionOne compute public http://controller:8774/v2.1
openstack endpoint create --region RegionOne compute internal http://controller:8774/v2.1
openstack endpoint create --region RegionOne compute admin http://controller:8774/v2.1
```

Create the nova placement user:

```bash
openstack user create --domain default --password-prompt placement
```

Add the admin role to the nova placement user:

```bash
openstack role add --project service --user placement admin
```

Create the nova placement service entity:

```bash
openstack service create --name placement --description "Placement API" placement
```

Create the Nova Placement service API endpoints:

```bash
openstack endpoint create --region RegionOne placement public http://controller.example.com:8778
openstack endpoint create --region RegionOne placement internal http://controller.example.com:8778
openstack endpoint create --region RegionOne placement admin http://controller.example.com:8778
```

Install the packages:

```bash
yum install openstack-nova-api openstack-nova-conductor openstack-nova-console openstack-nova-novncproxy openstack-nova-scheduler openstack-nova-placement-api -y
```

Edit the /etc/nova/nova.conf file and replace with the following actions:

```bash
[DEFAULT]
my_ip = 172.31.32.70
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
project_name = service
username = nova
password = rootroot

[glance]
api_servers = http://controller:9292

[oslo_concurrency]
lock_path = /var/lib/nova/tmp

[placement]
region_name = RegionOne
project_domain_name = Default
project_name = service
auth_type = password
user_domain_name = Default
auth_url = http://controller:5000/v3
username = placement
password = rootroot
```

**Ensure you changed the my_ip variable with your local IP:**

```bash
[DEFAULT]
my_ip = 172.31.32.70
...
```

Due to a packaging bug, you must enable access to the Placement API by adding the following configuration to /etc/httpd/conf.d/00-nova-placement-api.conf:

```bash
<Directory /usr/bin>
   <IfVersion >= 2.4>
      Require all granted
   </IfVersion>
   <IfVersion < 2.4>
      Order allow,deny
      Allow from all
   </IfVersion>
</Directory>
```

Restart apache:

```bash
systemctl restart httpd.service
```

```bash
yum install -y openstack-placement-api
mkdir /etc/placement/
```

Edit the /etc/placement/placement.conf file and complete the following actions:

```bash
[DEFAULT]

[placement_database]
connection = mysql+pymysql://placement:rootroot@controller/placement

[api]
auth_strategy = keystone

[keystone_authtoken]
auth_url = http://controller:5000/v3
memcached_servers = controller:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = placement
password = rootroot
```

Populate the placement database:

```bash
su -s /bin/sh -c "placement-manage db sync" placement
```

Populate the Compute databases:

Populate the nova-api and placement databases:
```bash
su -s /bin/sh -c "nova-manage api_db sync" nova
```

Register the cell0 database:

```bash
su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova
```

Create the cell1 cell:

```bash
su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova
```

Populate the nova database:

```bash
su -s /bin/sh -c "nova-manage db sync" nova
```

Verify nova cell0 and cell1 are registered correctly:

```bash
su -s /bin/sh -c "nova-manage cell_v2 list_cells" nova
```

Verify nova cell0 and cell1 are registered correctly:

```bash
nova-manage cell_v2 list_cells
```

Start the Compute service and configure them to start when the system boots:

```bash
systemctl enable openstack-nova-api.service openstack-nova-consoleauth openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service
systemctl start openstack-nova-api.service openstack-nova-consoleauth openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service
systemctl status openstack-nova-api.service openstack-nova-consoleauth openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service
```

### 2.2.2.2 Install and configure compute node

```bash
yum install openstack-nova-compute -y
```

Edit the /etc/nova/nova.conf file and complete the following actions:

```bash
[DEFAULT]
my_ip = 172.31.32.70
enabled_apis = osapi_compute,metadata
use_neutron = true
firewall_driver = nova.virt.firewall.NoopFirewallDriver

[api]
auth_strategy = keystone

[keystone_authtoken]
auth_url = http://controller:5000/v3
memcached_servers = controller:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = nova
password = rootroot

[vnc]
enabled = true
server_listen = $my_ip
server_proxyclient_address = $my_ip
novncproxy_base_url = http://3.229.11.186:6080/vnc_auto.html
vncserver_proxyclient_address=3.229.11.186

[glance]
api_servers = http://controller:9292

[oslo_concurrency]
lock_path = /var/lib/nova/tmp

[placement]
region_name = RegionOne
project_domain_name = Default
project_name = service
auth_type = password
user_domain_name = Default
auth_url = http://controller:5000/v3
username = placement
password = rootroot
```

**replace the 3.229.11.186 ip of the VNC to your public IP**

```bash
novncproxy_base_url = http://3.229.11.186:6080/vnc_auto.html
vncserver_proxyclient_address=3.229.11.186
...
```

Finalize installation:

```bash
egrep -c '(vmx|svm)' /proc/cpuinfo
```

If this command returns a value of one or greater, your compute node supports hardware acceleration which typically requires no additional configuration.

If this command returns a value of zero, your compute node does not support hardware acceleration and you must configure libvirt to use QEMU instead of KVM.

Edit the [libvirt] section in the /etc/nova/nova.conf file as follows:

```bash
[libvirt]
virt_type = qemu
```

Start the Compute service including its dependencies and configure them to start automatically when the system boots:

```bash
systemctl enable libvirtd.service openstack-nova-compute.service
systemctl start libvirtd.service openstack-nova-compute.service
systemctl status libvirtd.service openstack-nova-compute.service
```

Source the admin credentials to enable admin-only CLI commands, then confirm there are compute hosts in the database:

```bash
openstack compute service list --service nova-compute
```

Discover Compute Host:

```bash
su -s /bin/sh -c "nova-manage cell_v2 discover_hosts --verbose" nova
```

Check discovered Hypervisor:

```bash
openstack hypervisor list
```

On the Controller Node Verify operation of the Compute service:

```bash
openstack compute service list
+----+------------------+------------+----------+---------+-------+----------------------------+
| ID | Binary           | Host       | Zone     | Status  | State | Updated At                 |
+----+------------------+------------+----------+---------+-------+----------------------------+
|  1 | nova-conductor   | controller | internal | enabled | up    | 2017-11-04T10:10:18.000000 |
|  2 | nova-consoleauth | controller | internal | enabled | up    | 2017-11-04T10:10:17.000000 |
|  3 | nova-scheduler   | controller | internal | enabled | up    | 2017-11-04T10:10:17.000000 |
|  6 | nova-compute     | controller | nova     | enabled | up    | 2017-11-04T10:10:20.000000 |
+----+------------------+------------+----------+---------+-------+----------------------------+
```

## 2.3.1 Networking (neutron) service install and setup

On the controller node.

Use the database access client to connect to the database server as the root user:

```bash
mysql -u root -p
```

Create the neutron database:

```bash
CREATE DATABASE neutron;
```

Grant proper access to the neutron database:

```bash
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY 'rootroot';
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY 'rootroot';
```

Create the neutron user:

```bash
openstack user create --domain default --password-prompt neutron
```

Add the admin role to the neutron user:

```bash
openstack role add --project service --user neutron admin
```

Create the neutron service entity:

```bash
openstack service create --name neutron --description "OpenStack Networking" network
```

Create the Networking service API endpoints:

```bash
openstack endpoint create --region RegionOne network public http://controller.example.com:9696
openstack endpoint create --region RegionOne network internal http://controller.example.com:9696
openstack endpoint create --region RegionOne network admin http://controller.example.com:9696
```

## 2.3.2 Configure Neutron the Networking Self-service networks

Install the components:

```bash
yum install openstack-neutron openstack-neutron-ml2 openstack-neutron-linuxbridge ebtables -y
```

Configure the server component

Edit the /etc/neutron/neutron.conf file and replace with the following actions:

```bash
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
project_name=service
project_domain_name=Default

[nova]
region_name=RegionOne
auth_url=http://controller:5000
auth_type=password
project_domain_name=Default
project_name=service
user_domain_name=Default
username=nova
password=rootroot

[oslo_concurrency]
lock_path = /var/lib/neutron/tmp
```

Configure the Modular Layer 2 (ML2) plug-in:

Edit the /etc/neutron/plugins/ml2/ml2_conf.ini file and complete the following actions:

```bash
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
```

Configure the Linux bridge agent:

Edit the /etc/neutron/plugins/ml2/linuxbridge_agent.ini file and complete the following actions:

```bash
[linux_bridge]
physical_interface_mappings = provider:PROVIDER_INTERFACE_NAME

[vxlan]
enable_vxlan = true
local_ip = OVERLAY_INTERFACE_IP_ADDRESS
l2_population = true

[securitygroup]
enable_security_group = true
firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
```

Replace **PROVIDER_INTERFACE_NAME** with the name of the underlying provider physical network interface.

Replace **OVERLAY_INTERFACE_IP_ADDRESS** with the IP address of the underlying physical network interface that handles overlay networks. The example architecture uses the management interface to tunnel traffic to the other nodes. Therefore, replace **OVERLAY_INTERFACE_IP_ADDRESS** with the management IP address of the controller node. See Host networking for more information.

Ensure your Linux operating system kernel supports network bridge filters by verifying all the following sysctl values are set to 1:

```bash
net.bridge.bridge-nf-call-iptables
net.bridge.bridge-nf-call-ip6tables
```

To enable networking bridge support, typically the **br_netfilter** kernel module needs to be loaded. Check your operating system’s documentation for additional details on enabling this module.

```bash
modprobe br_netfilter
lsmod | grep br_netfilter
sysctl net.bridge.bridge-nf-call-iptables
sysctl net.bridge.bridge-nf-call-ip6tables
```

Configure the layer-3 agent:

Edit the /etc/neutron/l3_agent.ini file and complete the following actions:

```bash
[DEFAULT]
interface_driver = linuxbridge
```

Configure the DHCP agent:

Edit the /etc/neutron/dhcp_agent.ini file and complete the following actions:

```bash
[DEFAULT]
interface_driver = linuxbridge
dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq
enable_isolated_metadata = true
```

Configure the metadata agent:

Edit the /etc/neutron/metadata_agent.ini file and complete the following actions:

```bash
[DEFAULT]
nova_metadata_host = controller
metadata_proxy_shared_secret = METADATA_SECRET
```

Replace METADATA_SECRET with a suitable secret for the metadata proxy.

**Install and configure compute node:**

```bash
yum install openstack-neutron-linuxbridge ebtables ipset
```

Edit the /etc/neutron/neutron.conf file and complete the following actions:

```bash
[DEFAULT]
auth_strategy = keystone
transport_url=rabbit://openstack:rootroot@controller.example.com:5672/

[keystone_authtoken]
www_authenticate_uri = http://controller:5000
auth_uri=http://controller:5000/
auth_type=password
auth_url=http://controller:5000
username=neutron
password=rootroot
user_domain_name=Default
project_name=service
project_domain_name=Default

[oslo_concurrency]
lock_path = /var/lib/neutron/tmp
```

Configure the Compute service to use the Networking service:

Edit the /etc/nova/nova.conf file and add our neutron service information:

```bash
[neutron]
url = http://controller:9696
auth_url = http://controller:5000
auth_type = password
project_domain_name = default
user_domain_name = default
region_name = RegionOne
project_name = service
username = neutron
password = rootroot
service_metadata_proxy = true
metadata_proxy_shared_secret = METADATA_SECRET
```

The Networking service initialization scripts expect a symbolic link /etc/neutron/plugin.ini pointing to the ML2 plug-in configuration file, /etc/neutron/plugins/ml2/ml2_conf.ini. If this symbolic link does not exist, create it using the following command:

```bash
ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
```

Populate the database:

```bash
su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron
```

Restart the Compute API service:

```bash
systemctl restart openstack-nova-api.service
```

Start the Networking services and configure them to start when the system boots.

```bash
systemctl enable neutron-server.service neutron-linuxbridge-agent.service neutron-l3-agent.service neutron-dhcp-agent.service neutron-metadata-agent.service
systemctl start neutron-server.service neutron-linuxbridge-agent.service neutron-l3-agent.service neutron-dhcp-agent.service neutron-metadata-agent.service
systemctl status neutron-server.service neutron-linuxbridge-agent.service neutron-l3-agent.service neutron-dhcp-agent.service neutron-metadata-agent.service
```

```bash
systemctl restart openstack-nova-api.service openstack-nova-consoleauth.service openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service
systemctl restart neutron-server.service
systemctl restart openstack-glance-api.service openstack-glance-registry.service
systemctl restart httpd.service memcached.service
systemctl restart rabbitmq-server.service
```

Verify all is running fine:

```bash
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
```

Ensure all network agent are running:

```bash
openstack network agent list
+--------------------------------------+--------------------+---------------------------------------------+-------------------+-------+-------+---------------------------+
| ID                                   | Agent Type         | Host                                        | Availability Zone | Alive | State | Binary                    |
+--------------------------------------+--------------------+---------------------------------------------+-------------------+-------+-------+---------------------------+
| 0089b0c1-fbd8-4744-b90e-12954d3195d8 | Metadata agent     | ip-172-31-33-205.us-west-1.compute.internal | None              | :-)   | UP    | neutron-metadata-agent    |
| 27d1b65d-109a-4f57-99f8-eef44e6e1500 | Linux bridge agent | ip-172-31-33-205.us-west-1.compute.internal | None              | :-)   | UP    | neutron-linuxbridge-agent |
| bffbab15-a0c2-402a-9227-81bb6120e821 | L3 agent           | ip-172-31-33-205.us-west-1.compute.internal | nova              | :-)   | UP    | neutron-l3-agent          |
| c52da533-3f3b-4eeb-b2cb-578166a83b20 | DHCP agent         | ip-172-31-33-205.us-west-1.compute.internal | nova              | :-)   | UP    | neutron-dhcp-agent        |
+--------------------------------------+--------------------+---------------------------------------------+-------------------+-------+-------+---------------------------+
```

Ensure all services and agents are running fine:

```bash
. keystonerc_admin
openstack compute service list
+----+------------------+------------+----------+---------+-------+----------------------------+
| ID | Binary           | Host       | Zone     | Status  | State | Updated At                 |
+----+------------------+------------+----------+---------+-------+----------------------------+
|  1 | nova-conductor   | controller | internal | enabled | up    | 2017-11-04T11:09:50.000000 |
|  2 | nova-consoleauth | controller | internal | enabled | up    | 2017-11-04T11:09:40.000000 |
|  3 | nova-scheduler   | controller | internal | enabled | up    | 2017-11-04T11:09:41.000000 |
|  6 | nova-compute     | controller | nova     | enabled | up    | 2017-11-04T11:09:46.000000 |
+----+------------------+------------+----------+---------+-------+----------------------------+

openstack network agent list
+--------------------------------------+--------------------+---------------------------------------------+-------------------+-------+-------+---------------------------+
| ID                                   | Agent Type         | Host                                        | Availability Zone | Alive | State | Binary                    |
+--------------------------------------+--------------------+---------------------------------------------+-------------------+-------+-------+---------------------------+
| 0089b0c1-fbd8-4744-b90e-12954d3195d8 | Metadata agent     | ip-172-31-33-205.us-west-1.compute.internal | None              | :-)   | UP    | neutron-metadata-agent    |
| 27d1b65d-109a-4f57-99f8-eef44e6e1500 | Linux bridge agent | ip-172-31-33-205.us-west-1.compute.internal | None              | :-)   | UP    | neutron-linuxbridge-agent |
| bffbab15-a0c2-402a-9227-81bb6120e821 | L3 agent           | ip-172-31-33-205.us-west-1.compute.internal | nova              | :-)   | UP    | neutron-l3-agent          |
| c52da533-3f3b-4eeb-b2cb-578166a83b20 | DHCP agent         | ip-172-31-33-205.us-west-1.compute.internal | nova              | :-)   | UP    | neutron-dhcp-agent        |
+--------------------------------------+--------------------+---------------------------------------------+-------------------+-------+-------+---------------------------+

openstack hypervisor list
+----+-----------------------------+-----------------+--------------+-------+
| ID | Hypervisor Hostname         | Hypervisor Type | Host IP      | State |
+----+-----------------------------+-----------------+--------------+-------+
|  2 | ip-172-31-27-1.ec2.internal | QEMU            | 172.31.27.1  | up    |
+----+-----------------------------+-----------------+--------------+-------+
```

## 2.7 Dashboard install and configure

Install the packages:

```bash
yum install openstack-dashboard -y
```

Edit the /etc/openstack-dashboard/local_settings file and replace with the following actions:

```bash
# -*- coding: utf-8 -*-
OPENSTACK_HOST = "controller"
WEBROOT = '/dashboard'
ALLOWED_HOSTS = ['*']

SESSION_ENGINE = 'django.contrib.sessions.backends.cache'

CACHES = {
    'default': {
         'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache',
         'LOCATION': '127.0.0.1:11211',
    }
}

OPENSTACK_KEYSTONE_URL = "http://%s:5000/v3" % OPENSTACK_HOST
OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = True

OPENSTACK_API_VERSIONS = {
    "identity": 3,
    "image": 2,
    "volume": 2,
}

OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = "Default"
OPENSTACK_KEYSTONE_DEFAULT_ROLE = "user"

OPENSTACK_NEUTRON_NETWORK = {
    'enable_router': True,
    'enable_quotas': False,
    'enable_distributed_router': False,
    'enable_ha_router': False,
    'enable_lb': False,
    'enable_firewall': True,
    'enable_vpn': False,
    'enable_fip_topology_check': False,
}
```

Add the following line to /etc/httpd/conf.d/openstack-dashboard.conf if not included.

```bash
WSGIApplicationGroup %{GLOBAL}
```

Restart the web server and session storage service:

```bash
systemctl restart httpd.service memcached.service
systemctl status httpd.service memcached.service
```

Fix a permission:

```bash
chown apache:apache /usr/share/openstack-dashboard/openstack_dashboard/local/.secret_key_store
```

Verify operation of the dashboard.

```bash
http://<PUBLIC_IP>/dashboard
```

## 2.2.2 Cinder service install and configure on Controller node

**On Controller node**

Use the database access client to connect to the database server as the root user:

```bash
mysql -u root -p
```

```
CREATE DATABASE cinder;
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY 'rootroot';
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' IDENTIFIED BY 'rootroot';
```

Create the cinder user:

```bash
openstack user create --domain default --password-prompt cinder
```

Add the admin role to the glance user and service project:

```bash
openstack role add --project service --user cinder admin
```

Create the glance service entity:

```bash
openstack service create --name cinderv2 --description "OpenStack Block Storage" volumev2
openstack service create --name cinderv3 --description "OpenStack Block Storage" volumev3
```

Create the Image service API endpoints:

```bash
openstack endpoint create --region RegionOne volumev2 public http://controller:8776/v2/%\(project_id\)s
openstack endpoint create --region RegionOne volumev2 internal http://controller:8776/v2/%\(project_id\)s
openstack endpoint create --region RegionOne volumev2 admin http://controller:8776/v2/%\(project_id\)s
openstack endpoint create --region RegionOne volumev3 public http://controller:8776/v3/%\(project_id\)s
openstack endpoint create --region RegionOne volumev3 internal http://controller:8776/v3/%\(project_id\)s
openstack endpoint create --region RegionOne volumev3 admin http://controller:8776/v3/%\(project_id\)s
```

Install the packages:

```bash
yum install openstack-cinder targetcli -y
```

Edit the /etc/cinder/cinder.conf file and replace with the following actions:

```bash
[DEFAULT]
my_ip = 172.31.32.70
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
project_name = service
username = cinder
password = rootroot

[oslo_concurrency]
lock_path = /var/lib/cinder/tmp

[lvm]
volume_driver = cinder.volume.drivers.lvm.LVMVolumeDriver
volume_group = cinder-volumes
target_protocol = iscsi
target_helper = lioadm
```

Populate the Block Storage database:

```bash
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
su -s /bin/sh -c "cinder-manage db sync" cinder
```

Configure Compute to use Block Storage:

Edit the /etc/nova/nova.conf file and add the following to it:

```bash
[cinder]
os_region_name = RegionOne
```

Restart the Compute API service:
```bash
systemctl restart openstack-nova-api.service
```

Start the Block Storage service and configure them to start when the system boots:
```bash
systemctl enable openstack-cinder-api.service openstack-cinder-scheduler.service
systemctl start openstack-cinder-api.service openstack-cinder-scheduler.service
```

Install and configure a storage node:

Install the LVM packages:

```bash
yum install lvm2 device-mapper-persistent-data
```

Start the LVM metadata service and configure it to start when the system boots:

```bash
systemctl enable lvm2-lvmetad.service
systemctl start lvm2-lvmetad.service
```

Create the volume folder:

```bash
mkdir -p /var/lib/cinder/volumes
```

Lets create the LVM Volume.

Verify the disk is attached:

```bash
fdisk -l
Disk /dev/sdb: 10.7 GB, 10737418240 bytes, 20971520 sectors
Units = sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
```

Create the LVM volume (using loop for testing purpose, should use lvm partition):

```bash
dd if=/dev/zero of=/var/lib/cinder/cinder-volumes bs=1G count=4
losetup /dev/loop0 /var/lib/cinder/cinder-volumes
pvcreate /dev/loop0
vgcreate "cinder-volumes" /dev/loop0
vgdisplay
```

Create a systemd unit file /usr/lib/systemd/system/openstack-losetup.service to mount our loop device:

```bash
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
```

Enable the service at boot:

```bash
ln -s /usr/lib/systemd/system/openstack-losetup.service /etc/systemd/system/multi-user.target.wants/openstack-losetup.service
```

Restart the service:

```bash
systemctl enable openstack-cinder-api.service
systemctl enable openstack-cinder-scheduler.service
systemctl enable openstack-cinder-volume.service
systemctl enable openstack-cinder-backup.service
systemctl restart openstack-losetup.service
systemctl restart openstack-cinder-api.service
systemctl restart openstack-cinder-scheduler.service
systemctl restart openstack-cinder-volume.service
systemctl restart openstack-cinder-backup.service
```

Verify the service:

```bash
systemctl status openstack-cinder-api.service
systemctl status openstack-cinder-scheduler.service
systemctl status openstack-cinder-volume.service
systemctl status openstack-cinder-backup.service
```

Restart the services:

```bash
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
```

Verify all is running fine:

```bash
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
```

**Neutron:**

Ensure the services are enabled:

```bash
systemctl enable neutron-server.service
systemctl enable neutron-linuxbridge-agent.service
systemctl enable neutron-l3-agent.service
systemctl enable neutron-dhcp-agent.service
systemctl enable neutron-metadata-agent.service
```

Restart the services:

```bash
systemctl restart neutron-server.service
systemctl restart neutron-linuxbridge-agent.service
systemctl restart neutron-l3-agent.service
systemctl restart neutron-dhcp-agent.service
systemctl restart neutron-metadata-agent.service
```

Verify all is running fine:

```bash
systemctl status neutron-server.service
systemctl status neutron-linuxbridge-agent.service
systemctl status neutron-l3-agent.service
systemctl status neutron-dhcp-agent.service
systemctl status neutron-metadata-agent.service
```

**Nova Compute:**

Ensure the services are enabled:

```bash
systemctl enable openstack-nova-compute.service
systemctl enable libvirtd.service openstack-nova-compute.service
```

Restart the services:

```bash
systemctl restart openstack-nova-compute.service
systemctl restart libvirtd.service openstack-nova-compute.service
```

Verify all is running fine:

```bash
systemctl status openstack-nova-compute.service
systemctl status libvirtd.service openstack-nova-compute.service
```

Checks on the controller:

```bash
openstack compute service list
+----+------------------+------------+----------+---------+-------+----------------------------+
| ID | Binary           | Host       | Zone     | Status  | State | Updated At                 |
+----+------------------+------------+----------+---------+-------+----------------------------+
|  1 | nova-consoleauth | controller | internal | enabled | up    | 2017-10-26T17:21:04.000000 |
|  2 | nova-conductor   | controller | internal | enabled | up    | 2017-10-26T17:21:09.000000 |
|  3 | nova-scheduler   | controller | internal | enabled | up    | 2017-10-26T17:21:04.000000 |
|  6 | nova-compute     | compute    | nova     | enabled | up    | 2017-10-26T17:21:03.000000 |
+----+------------------+------------+----------+---------+-------+----------------------------+

openstack network agent list
+--------------------------------------+--------------------+---------------------------------------------+-------------------+-------+-------+---------------------------+
| ID                                   | Agent Type         | Host                                        | Availability Zone | Alive | State | Binary                    |
+--------------------------------------+--------------------+---------------------------------------------+-------------------+-------+-------+---------------------------+
| 0089b0c1-fbd8-4744-b90e-12954d3195d8 | Metadata agent     | ip-172-31-33-205.us-west-1.compute.internal | None              | :-)   | UP    | neutron-metadata-agent    |
| 27d1b65d-109a-4f57-99f8-eef44e6e1500 | Linux bridge agent | ip-172-31-33-205.us-west-1.compute.internal | None              | :-)   | UP    | neutron-linuxbridge-agent |
| bffbab15-a0c2-402a-9227-81bb6120e821 | L3 agent           | ip-172-31-33-205.us-west-1.compute.internal | nova              | :-)   | UP    | neutron-l3-agent          |
| c52da533-3f3b-4eeb-b2cb-578166a83b20 | DHCP agent         | ip-172-31-33-205.us-west-1.compute.internal | nova              | :-)   | UP    | neutron-dhcp-agent        |
+--------------------------------------+--------------------+---------------------------------------------+-------------------+-------+-------+---------------------------+

openstack hypervisor list
+----+-----------------------------+-----------------+--------------+-------+
| ID | Hypervisor Hostname         | Hypervisor Type | Host IP      | State |
+----+-----------------------------+-----------------+--------------+-------+
|  2 | ip-172-31-27-1.ec2.internal | QEMU            | 172.31.27.1  | up    |
+----+-----------------------------+-----------------+--------------+-------+
```

Networking:

```bash
openstack network list --external
+--------------------------------------+--------+--------------------------------------+
| ID                                   | Name   | Subnets                              |
+--------------------------------------+--------+--------------------------------------+
| 13eaf423-1901-4176-a184-e69a48f87586 | public | 89203467-67c0-42e4-ba55-f64387ea5ad4 |
+--------------------------------------+--------+--------------------------------------+

openstack network list
+--------------------------------------+---------+--------------------------------------+
| ID                                   | Name    | Subnets                              |
+--------------------------------------+---------+--------------------------------------+
| 13eaf423-1901-4176-a184-e69a48f87586 | public  | 89203467-67c0-42e4-ba55-f64387ea5ad4 |
| d1617aa6-1645-4a11-bbfe-dbf0e299f6c7 | private | f11e2036-7191-492d-a677-89a1ed647185 |
+--------------------------------------+---------+--------------------------------------+

openstack router list
+--------------------------------------+-----------+--------+-------+-------------+-------+----------------------------------+
| ID                                   | Name      | Status | State | Distributed | HA    | Project                          |
+--------------------------------------+-----------+--------+-------+-------------+-------+----------------------------------+
| 1c531ca9-3fbc-4e6a-94c0-1d61ccda3cd6 | extrouter | ACTIVE | UP    | False       | False | 133d12787b254e4e8422c1db84700c65 |
+--------------------------------------+-----------+--------+-------+-------------+-------+----------------------------------+

openstack router show extrouter
+-------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| Field                   | Value                                                                                                                                                                                     |
+-------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| admin_state_up          | UP                                                                                                                                                                                        |
| availability_zone_hints |                                                                                                                                                                                           |
| availability_zones      | nova                                                                                                                                                                                      |
| created_at              | 2017-11-04T22:31:07Z                                                                                                                                                                      |
| description             |                                                                                                                                                                                           |
| distributed             | False                                                                                                                                                                                     |
| external_gateway_info   | {"network_id": "849eb0f2-4a9f-4127-b7d9-0a01e6759e35", "enable_snat": true, "external_fixed_ips": [{"subnet_id": "7a7b25e5-1a02-42d9-ab73-a454a5abc9fa", "ip_address": "172.31.18.104"}]} |
| flavor_id               | None                                                                                                                                                                                      |
| ha                      | False                                                                                                                                                                                     |
| id                      | 1c531ca9-3fbc-4e6a-94c0-1d61ccda3cd6                                                                                                                                                      |
| name                    | extrouter                                                                                                                                                                                 |
| project_id              | 133d12787b254e4e8422c1db84700c65                                                                                                                                                          |
| revision_number         | 3                                                                                                                                                                                         |
| routes                  |                                                                                                                                                                                           |
| status                  | ACTIVE                                                                                                                                                                                    |
| tags                    |                                                                                                                                                                                           |
| updated_at              | 2017-11-04T22:31:14Z                                                                                                                                                                      |
+-------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
```

Block Storage:

```bash
openstack volume service list
+------------------+----------------+------+---------+-------+----------------------------+
| Binary           | Host           | Zone | Status  | State | Updated At                 |
+------------------+----------------+------+---------+-------+----------------------------+
| cinder-backup    | controller     | nova | enabled | up    | 2017-10-28T13:12:12.000000 |
| cinder-scheduler | controller     | nova | enabled | up    | 2017-10-28T13:12:53.000000 |
| cinder-volume    | controller@lvm | nova | enabled | up    | 2017-10-28T13:12:49.000000 |
+------------------+----------------+------+---------+-------+----------------------------+
```

## 2.8 Finalize the configuration of OpenStack

Create Flavors:

```bash
openstack flavor create --id 0 --ram 512   --vcpus 1 --disk 1  m1.tiny
openstack flavor create --id 1 --ram 1024  --vcpus 1 --disk 1  m1.small
openstack flavor create --id 2 --ram 2048  --vcpus 1 --disk 1  m1.large
```
## 2.8.1 Do the network Configuration:

Create Public Floating Network (All Tenants)

This is the virtual network that OpenStack will bridge to the outside world. You will assign public IPs to your instances from this network.

```bash
. keystonerc_admin
neutron net-create public --shared --router:external=True --provider:network_type=vxlan --provider:segmentation_id=96
neutron subnet-create --name public_subnet --enable-dhcp --allocation-pool start=192.168.178.100,end=192.168.178.150 public 192.168.178.0/24
```

Ensure to update the IPs for the allocation-pool and netmask with your local IPs.

Setup Tenant Network/Subnet

This is the private network your instances will attach to. Instances will be issued IPs from this private IP subnet.

```bash
. keystonerc_demo
neutron net-create private
neutron subnet-create --name private_subnet --dns-nameserver 8.8.8.8 --dns-nameserver 8.8.4.4 --allocation-pool start=10.0.30.10,end=10.0.30.254 private 10.0.30.0/24
```

Create an External Router to Attach to floating IP Network

This router will attach to your private subnet and route to the public network, which is where your floating IPs are located.

```bash
neutron router-create extrouter
neutron router-gateway-set extrouter public
neutron router-interface-add extrouter private_subnet
```

OpenStack Ports:

OpenStack Service      Port
Nova-api               8773 (for EC2 API)
                       8774 (for openstack API)
                       8775 (metadata port)
                       3333 (when accessing S3 API)
nova-novncproxy        6080
                       5800/5900 (VNC)
cinder                 8776
glance                 9191 (glance registry)
                       9292 (glance api)
keystone               5000 (public port)
                       35357 (admin port)
http                   80
Mysql                  3306
AMQP                   5672

Update the hours on the Nodes:

```bash
yum install ntpdate
ntpdate -u 0.europe.pool.ntp.org
```
