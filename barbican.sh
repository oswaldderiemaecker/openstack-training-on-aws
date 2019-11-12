#!/bin/bash

set -e

mysql -u root -prootroot -e "CREATE DATABASE barbican; GRANT ALL PRIVILEGES ON barbican.* TO 'barbican'@'localhost' IDENTIFIED BY 'rootroot'; GRANT ALL PRIVILEGES ON barbican.* TO 'barbican'@'%' IDENTIFIED BY 'rootroot';"

. keystonerc_admin

openstack user create --domain default --password rootroot barbican
openstack role add --project service --user barbican admin
openstack role create creator
openstack role add --project service --user barbican creator
openstack service create --name barbican --description "Key Manager" key-manager

openstack endpoint create --region RegionOne key-manager public http://controller:9311
openstack endpoint create --region RegionOne key-manager internal http://controller:9311
openstack endpoint create --region RegionOne key-manager admin http://controller:9311

yum install openstack-barbican-api

echo '
[DEFAULT]
sql_connection = mysql+pymysql://barbican:rootroot@controller/barbican
transport_url = rabbit://openstack:rootroot@controller

[keystone_authtoken]
www_authenticate_uri = http://controller:5000
auth_url = http://controller:5000
memcached_servers = controller:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = barbican
password = rootroot
' > /etc/barbican/barbican.conf

su -s /bin/sh -c "barbican-manage db upgrade" barbican

echo '
<VirtualHost [::1]:9311>
    ServerName controller

    ## Logging
    ErrorLog "/var/log/httpd/barbican_wsgi_main_error_ssl.log"
    LogLevel debug
    ServerSignature Off
    CustomLog "/var/log/httpd/barbican_wsgi_main_access_ssl.log" combined

    WSGIApplicationGroup %{GLOBAL}
    WSGIDaemonProcess barbican-api display-name=barbican-api group=barbican processes=2 threads=8 user=barbican
    WSGIProcessGroup barbican-api
    WSGIScriptAlias / "/usr/lib/python2.7/site-packages/barbican/api/app.wsgi"
    WSGIPassAuthorization On
</VirtualHost>
' >  /etc/httpd/conf.d/wsgi-barbican.conf

systemctl restart httpd.service

echo '
[key_manager]
backend = barbican
' >> /etc/cinder/cinder.conf

echo '
[key_manager]
backend = barbican
' >> /etc/nova/nova.conf

systemctl start openstack-barbican-api
systemctl restart openstack-nova-compute
