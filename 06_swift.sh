#!/bin/bash

set -e

MANAGEMENT_IP="172.31.32.98"

. keystonerc_admin

openstack user create --domain default --password-prompt swift
openstack role add --project service --user swift admin

openstack service create --name swift --description "OpenStack Object Storage" object-store
openstack endpoint create --region RegionOne object-store public http://controller:8080/v1/AUTH_%\(project_id\)s
openstack endpoint create --region RegionOne object-store internal http://controller:8080/v1/AUTH_%\(project_id\)s
openstack endpoint create --region RegionOne object-store admin http://controller:8080/v1

yum install openstack-swift-proxy python-swiftclient python-keystoneclient python-keystonemiddleware memcached -y

echo "
[DEFAULT]
bind_ip = $MANAGEMENT_IP
bind_port = 8080
swift_dir = /etc/swift
user = swift

[pipeline:main]
pipeline = catch_errors gatekeeper healthcheck proxy-logging cache listing_formats container_sync bulk ratelimit authtoken keystoneauth copy container-quotas account-quotas slo dlo versioned_writes symlink proxy-logging proxy-server

[app:proxy-server]
use = egg:swift#proxy
account_autocreate = True

[filter:tempauth]
use = egg:swift#tempauth
user_admin_admin = admin .admin .reseller_admin
user_test_tester = testing .admin
user_test2_tester2 = testing2 .admin
user_test_tester3 = testing3
user_test5_tester5 = testing5 service

[filter:authtoken]
paste.filter_factory = keystonemiddleware.auth_token:filter_factory
www_authenticate_uri = http://controller:5000
auth_url = http://controller:5000
memcached_servers = 127.0.0.1:11211
auth_type = password
project_domain_id = default
user_domain_id = default
project_name = service
username = swift
password = rootroot
delay_auth_decision = True

[filter:keystoneauth]
use = egg:swift#keystoneauth
operator_roles = admin,user

[filter:s3api]
use = egg:swift#s3api

[filter:s3token]
use = egg:swift#s3token
reseller_prefix = AUTH_
delay_auth_decision = False
auth_uri = http://keystonehost:35357/v3
http_timeout = 10.0

[filter:healthcheck]
use = egg:swift#healthcheck

[filter:cache]
use = egg:swift#memcache
memcache_servers = 127.0.0.1:11211

[filter:ratelimit]
use = egg:swift#ratelimit

[filter:read_only]
use = egg:swift#read_only

[filter:domain_remap]
use = egg:swift#domain_remap

[filter:catch_errors]
use = egg:swift#catch_errors

[filter:cname_lookup]
use = egg:swift#cname_lookup

[filter:staticweb]
use = egg:swift#staticweb

[filter:tempurl]
use = egg:swift#tempurl

[filter:formpost]
use = egg:swift#formpost

[filter:name_check]
use = egg:swift#name_check

[filter:list-endpoints]
use = egg:swift#list_endpoints

[filter:proxy-logging]
use = egg:swift#proxy_logging

[filter:bulk]
use = egg:swift#bulk

[filter:slo]
use = egg:swift#slo

[filter:dlo]
use = egg:swift#dlo

[filter:container-quotas]
use = egg:swift#container_quotas

[filter:account-quotas]
use = egg:swift#account_quotas

[filter:gatekeeper]
use = egg:swift#gatekeeper

[filter:container_sync]
use = egg:swift#container_sync

[filter:xprofile]
use = egg:swift#xprofile

[filter:versioned_writes]
use = egg:swift#versioned_writes

[filter:copy]
use = egg:swift#copy

[filter:keymaster]
use = egg:swift#keymaster
encryption_root_secret = changeme

[filter:kms_keymaster]
use = egg:swift#kms_keymaster

[filter:kmip_keymaster]
use = egg:swift#kmip_keymaster

[filter:encryption]
use = egg:swift#encryption

[filter:listing_formats]
use = egg:swift#listing_formats

[filter:symlink]
use = egg:swift#symlink
" > /etc/swift/proxy-server.conf

yum install xfsprogs rsync -y

mkfs.xfs /dev/nvme1n1
mkfs.xfs /dev/nvme2n1
mkfs.xfs /dev/nvme3n1

mkdir -p /srv/node/nvme1n1
mkdir -p /srv/node/nvme2n1
mkdir -p /srv/node/nvme3n1

echo '
/dev/nvme1n1 /srv/node/nvme1n1 xfs noatime,nodiratime,nobarrier,logbufs=8 0 2
/dev/nvme2n1 /srv/node/nvme2n1 xfs noatime,nodiratime,nobarrier,logbufs=8 0 2
/dev/nvme3n1 /srv/node/nvme3n1 xfs noatime,nodiratime,nobarrier,logbufs=8 0 2
' >> /etc/fstab

mount /srv/node/nvme1n1
mount /srv/node/nvme2n1
mount /srv/node/nvme3n1

echo "
gid = swift
log file = /var/log/rsyncd.log
pid file = /var/run/rsyncd.pid
address = $MANAGEMENT_IP

[account]
max connections = 2
path = /srv/node/
read only = False
lock file = /var/lock/account.lock

[container]
max connections = 2
path = /srv/node/
read only = False
lock file = /var/lock/container.lock

[object]
max connections = 2
path = /srv/node/
read only = False
lock file = /var/lock/object.lock
" > /etc/rsyncd.conf

systemctl enable rsyncd.service
systemctl start rsyncd.service

yum install openstack-swift-account openstack-swift-container openstack-swift-object -y

echo "
[DEFAULT]
bind_ip = $MANAGEMENT_IP
bind_port = 6202
user = swift
swift_dir = /etc/swift
devices = /srv/node
mount_check = true

[pipeline:main]
pipeline = healthcheck recon account-server

[app:account-server]
use = egg:swift#account

[filter:healthcheck]
use = egg:swift#healthcheck

[filter:recon]
use = egg:swift#recon
recon_cache_path = /var/cache/swift

[account-replicator]

[account-auditor]

[account-reaper]

[filter:xprofile]
use = egg:swift#xprofile
" > /etc/swift/account-server.conf

echo "
[DEFAULT]
bind_ip = $MANAGEMENT_IP
bind_port = 6201
user = swift
swift_dir = /etc/swift
devices = /srv/node
mount_check = true

[pipeline:main]
pipeline = healthcheck recon container-server

[app:container-server]
use = egg:swift#container

[filter:healthcheck]
use = egg:swift#healthcheck

[filter:recon]
use = egg:swift#recon
recon_cache_path = /var/cache/swift

[container-replicator]

[container-updater]

[container-auditor]

[container-sync]

[filter:xprofile]
use = egg:swift#xprofile

[container-sharder]
" > /etc/swift/container-server.conf

echo "
[DEFAULT]
bind_ip = $MANAGEMENT_IP
bind_port = 6200
user = swift
swift_dir = /etc/swift
devices = /srv/node
mount_check = true

[pipeline:main]
pipeline = healthcheck recon object-server

[app:object-server]
use = egg:swift#object

[filter:healthcheck]
use = egg:swift#healthcheck

[filter:recon]
use = egg:swift#recon
recon_cache_path = /var/cache/swift
recon_lock_path = /var/lock

[object-replicator]

[object-reconstructor]

[object-updater]

[object-auditor]

[filter:xprofile]
use = egg:swift#xprofile
" > /etc/swift/object-server.conf

chown -R swift:swift /srv/node

mkdir -p /var/cache/swift
chown -R root:swift /var/cache/swift
chmod -R 775 /var/cache/swift

cd /etc/swift/

swift-ring-builder account.builder create 10 3 1

swift-ring-builder account.builder add --region 1 --zone 1 --ip $MANAGEMENT_IP --port 6202 --device nvme1n1 --weight 100
swift-ring-builder account.builder add --region 1 --zone 1 --ip $MANAGEMENT_IP --port 6202 --device nvme2n1 --weight 100
swift-ring-builder account.builder add --region 1 --zone 1 --ip $MANAGEMENT_IP --port 6202 --device nvme3n1 --weight 100

swift-ring-builder account.builder

swift-ring-builder account.builder rebalance

swift-ring-builder container.builder create 10 3 1

swift-ring-builder container.builder add --region 1 --zone 1 --ip $MANAGEMENT_IP --port 6201 --device nvme1n1 --weight 10
swift-ring-builder container.builder add --region 1 --zone 1 --ip $MANAGEMENT_IP --port 6201 --device nvme2n1 --weight 100
swift-ring-builder container.builder add --region 1 --zone 1 --ip $MANAGEMENT_IP --port 6201 --device nvme3n1 --weight 10

swift-ring-builder container.builder

swift-ring-builder container.builder rebalance

swift-ring-builder object.builder create 10 3 1

swift-ring-builder object.builder add --region 1 --zone 1 --ip $MANAGEMENT_IP --port 6200 --device nvme1n1 --weight 100
swift-ring-builder object.builder add --region 1 --zone 1 --ip $MANAGEMENT_IP --port 6200 --device nvme2n1 --weight 100
swift-ring-builder object.builder add --region 1 --zone 1 --ip $MANAGEMENT_IP --port 6200 --device nvme3n1 --weight 100

swift-ring-builder object.builder

swift-ring-builder object.builder rebalance

echo '
[swift-hash]

swift_hash_path_suffix = changemeHASH
swift_hash_path_prefix = changemeHASH

[storage-policy:0]
name = Policy-0
default = yes
aliases = yellow, orange

[swift-constraints]
' > /etc/swift/swift.conf

chown -R root:swift /etc/swift

systemctl enable openstack-swift-proxy.service memcached.service
systemctl start openstack-swift-proxy.service memcached.service

systemctl enable openstack-swift-account.service openstack-swift-account-auditor.service openstack-swift-account-reaper.service openstack-swift-account-replicator.service
systemctl start openstack-swift-account.service openstack-swift-account-auditor.service openstack-swift-account-reaper.service openstack-swift-account-replicator.service
systemctl enable openstack-swift-container.service openstack-swift-container-auditor.service openstack-swift-container-replicator.service openstack-swift-container-updater.service
systemctl start openstack-swift-container.service openstack-swift-container-auditor.service openstack-swift-container-replicator.service openstack-swift-container-updater.service
systemctl enable openstack-swift-object.service openstack-swift-object-auditor.service openstack-swift-object-replicator.service openstack-swift-object-updater.service
systemctl start openstack-swift-object.service openstack-swift-object-auditor.service openstack-swift-object-replicator.service openstack-swift-object-updater.service
systemctl restart httpd

systemctl status openstack-swift-account.service openstack-swift-account-auditor.service openstack-swift-account-reaper.service openstack-swift-account-replicator.service
systemctl status openstack-swift-container.service openstack-swift-container-auditor.service openstack-swift-container-replicator.service openstack-swift-container-updater.service
systemctl status openstack-swift-object.service openstack-swift-object-auditor.service openstack-swift-object-replicator.service openstack-swift-object-updater.service
