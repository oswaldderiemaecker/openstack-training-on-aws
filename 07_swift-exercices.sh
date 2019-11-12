#!/bin/bash

set -e

. keystonerc_admin
swift
swift post orders
swift list
swift help
swift stat
swift stat orders
swift stat -v
swift post orders -r ".r:*"
swift stat
swift stat orders
swift post orders -r "SoftwareTester:*"
swift stat orders
swift post order -w "SoftwareTester:developer1"
swift stat orders
swift post orders -w "SoftwareTester:developer1"
swift stat orders
swift delete order
swift list
swift post orders -w "SoftwareTester:developer1,Admin:*"
swift stat orders
swift list orders
swift upload orders /etc/hosts etc/hosts
ls -l /etc/hosts
swift upload orders /etc/hosts /etc/hosts
swift stat orders
swift stat orders etc/hosts
swift post orders etc/hosts -H "X-Delete-After:600"
swift stat orders etc/hosts
swift list orders
date +’%s’
swift post orders etc/hosts -H "X-Delete-At:1508085313"
swift stat orders etc/hosts
swift post orders etc/hosts -H "X-Remove-Delete-At:"
swift stat orders etc/hosts
swift list orders
swift upload orders /etc/hosts /etc/hosts
swift list orders
swift post orders -r "*:*"
swift post orders -r "SoftwareTester:developer1,Admin:*"
swift post orders -w "SoftwareTester:developer1,Admin:*"
swift stat orders etc/hosts
swift stat orders
swift post orders etc/hosts -H "X-Delete-After:1200"
date -s
swift stat orders etc/hosts
swift download orders etc/hosts -o myfile.txt
cat myfile.txt
swift post -m "web-listings: true orders"
openstack object create order /etc/group
openstack object create orders /etc/group
openstack object list orders
openstack object show orders /etc/group
openstack object store account show
openstack object create orders /etc/hosts
openstack object list orders
openstack object show orders /etc/hosts
openstack object store account show
openstack object delete orders /etc/hosts
openstack object store account show
