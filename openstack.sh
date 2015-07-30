#!/bin/bash
#original here:
#https://github.com/dcnoye/misc/blob/master/openstack.sh
#http://git.fibernetoffice.com/dcn113/openstack/blob/master/openstack.sh

#setup swap - primarily for low ram test boxes
#can be removed

do_swap(){
    fallocate -l 4G /swapfile 
    chmod 600 /swapfile
    mkswap /swapfile;swapon /swapfile
    echo "/swapfile    none    swap    sw    0    0" >> /etc/fstab
}

get_ip() {
    dev=$1
    if [ -n "$dev" ]; then
        ip a show dev $dev 2>/dev/null | awk -F'[ /]' '/inet /{print $6}'
    fi
}
#comment out if you have over 4G ram
do_swap

#adjust dev as needed
CONTROLLER_IP=$(get_ip eth0)

#change with: openssl rand -hex 10
#look to autogenerate token below
ADMIN_TOKEN=8cfab25b26bb7c41759
SERVICE_PWD=letmein123
ADMIN_PWD=not4anyone
META_PWD=break4ever


PRIMARY_NODE_IP=$(get_ip eth1)
#SECONDARY_NODE_IP=10.17.100.12
#TERTIARY_NODE_IP=10.17.100.13

DB_PASS=fiberNet
USER_PWD=not4you22

#install ntp
# NTP is critical, openstack will not work without this.!
yum -y install ntp
yum -y install vim
systemctl enable ntpd.service
systemctl start ntpd.service

#openstack repos
# fiber should setup a mirror if they are doing a lot of installs
yum -y install yum-plugin-priorities
yum -y install epel-release
yum -y install http://rdo.fedorapeople.org/openstack-kilo/rdo-release-kilo.rpm
yum -y upgrade
yum -y install openstack-selinux

#loosen things up
systemctl stop firewalld.service
systemctl disable firewalld.service
sed -i 's/enforcing/disabled/g' /etc/selinux/config

#install database server for HA
#not the only option, however it’s well documented, so that’s why it’s being used
yum -y install  mariadb-galera-server xinetd rsync MySQL-python

#TODO: Look to optimize mariadb


#edit /etc/my.cnf.d/galera.cnf
#TODO: change to cat >> /etc/my.cnf.d/server.cnf << EOF

#Bootstrapping the cluster is a bit of a manual process. On the initial node, variable wsrep_cluster_address should be set to the value: gcomm://.
#The gcomm:// tells the node it can bootstrap without any cluster to connect to. 
#Setting that and starting up the first node should result in a cluster with a wsrep_cluster_conf_id of 1.
# After this single-node cluster is started, variable wsrep_cluster_address should be updated to the list of all nodes in the cluster.
sed -i.bak "150i\\
[mysqld]\n\
skip-name-resolve=1\n\
binlog_format=ROW\n\
default-storage-engine=innodb\n\
innodb_autoinc_lock_mode=2\n\
innodb_locks_unsafe_for_binlog=1\n\
max_connections=2048\n\
query_cache_size=0\n\
query_cache_type=0\n\
wsrep_provider=/usr/lib64/galera/libgalera_smm.so\n\
wsrep_cluster_name=’galera_cluster’\n\
wsrep_cluster_address=gcomm://\n\
#
#wsrep_cluster_address="gcomm://10.17.100.11,10.17.100.12,10.17.100.13"
#wsrep_cluster_address=””gcomm://$PRIMARY_NODE_IP, $SECONDARY_NODE_IP, $TERTIARY_NODE_IP””\n\
wsrep_slave_threads=1\n\
wsrep_certify_nonPK=1\n\
wsrep_max_ws_rows=131072\n\
wsrep_max_ws_size=1073741824\n\
wsrep_debug=0\n\
wsrep_convert_LOCK_to_trx=0\n\
wsrep_retry_autocommit=1\n\
wsrep_auto_increment_control=1\n\
wsrep_drupal_282555_workaround=0\n\
wsrep_causal_reads=0\n\
wsrep_notify_cmd=\n\
wsrep_sst_method=rsync\n\
" /etc/my.cnf.d/galera.cnf

#start database server
#when clustering db use below instead to start db
#sudo -u mysql /usr/libexec/mysqld --wsrep-cluster-address='gcomm://' &

systemctl enable mariadb.service
systemctl start mariadb.service

#automated install of mysql
#TODO: double check - this needs more, eg drop test db etc


mysql -e "UPDATE mysql.user SET Password = PASSWORD('$DB_PASS') WHERE User = 'root'"
mysql -e "FLUSH PRIVILEGES"

#create databases
echo 'starting DB configuration'
mysql -u root -p"$DB_PASS"<<EOF
CREATE DATABASE nova;
CREATE DATABASE cinder;
CREATE DATABASE glance;
CREATE DATABASE keystone;
CREATE DATABASE neutron;
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '$SERVICE_PWD';
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY '$SERVICE_PWD';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '$SERVICE_PWD';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '$SERVICE_PWD';
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY '$SERVICE_PWD';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY '$SERVICE_PWD';
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' IDENTIFIED BY '$SERVICE_PWD';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '$SERVICE_PWD';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '$SERVICE_PWD';
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY '$SERVICE_PWD';
FLUSH PRIVILEGES;
EOF

#install messaging service
#TODO: make HA
#rabbitmqctl change_password openstack RABBIT_PASS

yum -y install rabbitmq-server
systemctl enable rabbitmq-server.service
systemctl start rabbitmq-server.service

#install keystone
#yum -y install openstack-keystone python-keystoneclient python-openstackclient memcached python-memcached httpd mod_wsgi
yum -y install openstack-keystone httpd mod_wsgi python-openstackclient memcached python-memcached
#edit /etc/keystone.conf

sed -i.bak "s/#admin_token = ADMIN/admin_token = $ADMIN_TOKEN/g" /etc/keystone/keystone.conf

sed -i "/\[database\]/a \
connection = mysql://keystone:$SERVICE_PWD@$CONTROLLER_IP/keystone" /etc/keystone/keystone.conf

sed -i.bak "s/#servers = localhost:11211/servers = localhost:11211/g" /etc/keystone/keystone.conf

sed -i.bak "s/#provider = keystone.token.providers.uuid.Provider/provider = keystone.token.providers.uuid.Provider/g" /etc/keystone/keystone.conf

sed -i.bak "s/#keystone.token.persistence.backends.sql.Token/keystone.token.persistence.backends.sql.Token/g" /etc/keystone/keystone.conf

sed -i.bak "s/#driver = keystone.contrib.revoke.backends.sql.Revoke/driver = keystone.contrib.revoke.backends.sql.Revoke/g" /etc/keystone/keystone.conf

#sed -i.bak "s/#verbose = True/verbose = True/g" /etc/keystone/keystone.conf


#finish keystone setup
#keystone-manage pki_setup --keystone-user keystone --keystone-group keystone
#chown -R keystone:keystone /var/log/keystone
#chown -R keystone:keystone /etc/keystone/ssl
#chmod -R o-rwx /etc/keystone/ssl


su -s /bin/sh -c "keystone-manage db_sync" keystone


#set hostname
sed -i.bak "s/#ServerName www.example.com:80/ServerName $(hostname -f)/g" /etc/httpd/conf/httpd.conf

#add config
cat >/etc/httpd/conf.d/wsgi-keystone.conf <<EOL
Listen 5000
Listen 35357
<VirtualHost *:5000>
    WSGIDaemonProcess keystone-public processes=5 threads=1 user=keystone group=keystone display-name=%{GROUP}
    WSGIProcessGroup keystone-public
    WSGIScriptAlias / /var/www/cgi-bin/keystone/main
    WSGIApplicationGroup %{GLOBAL}
    WSGIPassAuthorization On
    LogLevel info
    ErrorLogFormat "%{cu}t %M"
    ErrorLog /var/log/httpd/keystone-error.log
    CustomLog /var/log/httpd/keystone-access.log combined
</VirtualHost>
<VirtualHost *:35357>
    WSGIDaemonProcess keystone-admin processes=5 threads=1 user=keystone group=keystone display-name=%{GROUP}
    WSGIProcessGroup keystone-admin
WSGIScriptAlias / /var/www/cgi-bin/keystone/admin
    WSGIApplicationGroup %{GLOBAL}
    WSGIPassAuthorization On
    LogLevel info
    ErrorLogFormat "%{cu}t %M"
    ErrorLog /var/log/httpd/keystone-error.log
    CustomLog /var/log/httpd/keystone-access.log combined
</VirtualHost>
EOL

mkdir -p /var/www/cgi-bin/keystone


curl http://git.openstack.org/cgit/openstack/keystone/plain/httpd/keystone.py?h=stable/kilo \
  | tee /var/www/cgi-bin/keystone/main /var/www/cgi-bin/keystone/admin


chown -R keystone:keystone /var/www/cgi-bin/keystone
chmod 755 /var/www/cgi-bin/keystone/*

systemctl enable httpd.service memcached.service
systemctl start httpd.service memcached.service

#openstack yum package for keystone doesn't fully work yet
#start keystone
#systemctl enable openstack-keystone.service
#systemctl start openstack-keystone.service

  
#create users and projects(tenants)
#967c28d6a6389011776d

export OS_TOKEN=$ADMIN_TOKEN
export OS_URL=http://$CONTROLLER_IP:35357/v2.0
openstack project create --description "Admin Project" admin
openstack user create admin --password $ADMIN_PWD
openstack role create admin
openstack role add --project admin --user admin admin
openstack role create _member_
openstack role add --project admin --user admin _member_ 
openstack project create --description "Webdev Project" webdev
openstack user create webdev --password $USER_PWD
openstack role add --project webdev --user webdev _member_
openstack project create --description "Service Project" service


openstack service create --name keystone --description "OpenStack Identity" identity

openstack endpoint create \
  --publicurl http://$CONTROLLER_IP:5000/v2.0 \
  --internalurl http://$CONTROLLER_IP:5000/v2.0 \
  --adminurl http://$CONTROLLER_IP:35357/v2.0 \
  --region FiberNet \
  identity


#create credentials file
#needed for when you want to run command line commands
echo "export OS_PROJECT_DOMAIN_ID=default" > auth
echo "export OS_USER_DOMAIN_ID=default" >> auth
echo "export OS_PROJECT_NAME=admin" >> auth
echo "export OS_TENANT_NAME=admin" >> auth
echo "export OS_USERNAME=admin" >> auth
echo "export OS_PASSWORD=$ADMIN_PWD" >> auth
echo “export OS_AUTH_URL=http://$CONTROLLER_IP:35357/v3” >> auth
source auth

#create keystone entries for glance
#openstack user create glance --password  letmein123fiberNetrules123$
openstack user create glance --password $SERVICE_PWD
openstack role add --project service --user glance  admin
openstack service create --name glance --description "OpenStack Image service" image

openstack endpoint create \
  --publicurl http://$CONTROLLER_IP:9292 \
  --internalurl http://$CONTROLLER_IP:9292 \
  --adminurl http://$CONTROLLER_IP:9292 \
  --region FiberNet \
  image

#install glance
yum -y install openstack-glance python-glanceclient


#edit /etc/glance/glance-api.conf
sed -i.bak "/\[database\]/a \
connection = mysql://glance:$SERVICE_PWD@$CONTROLLER_IP/glance" /etc/glance/glance-api.conf

sed -i "/\[keystone_authtoken\]/a \
auth_uri = http://$CONTROLLER_IP:5000/v2.0\n\
identity_uri = http://$CONTROLLER_IP:35357\n\
admin_tenant_name = service\n\
admin_user = glance\n\
admin_password = $SERVICE_PWD" /etc/glance/glance-api.conf

sed -i "/\[paste_deploy\]/a \
flavor = keystone" /etc/glance/glance-api.conf

sed -i "/\[glance_store\]/a \
default_store = file\n\
filesystem_store_datadir = /var/lib/glance/images/" /etc/glance/glance-api.conf

#edit /etc/glance/glance-registry.conf
sed -i.bak "/\[database\]/a \
connection = mysql://glance:$SERVICE_PWD@$CONTROLLER_IP/glance" /etc/glance/glance-registry.conf

sed -i "/\[keystone_authtoken\]/a \
auth_uri = http://$CONTROLLER_IP:5000/v2.0\n\
identity_uri = http://$CONTROLLER_IP:35357\n\
admin_tenant_name = service\n\
admin_user = glance\n\
admin_password = $SERVICE_PWD" /etc/glance/glance-registry.conf

sed -i "/\[paste_deploy\]/a \
flavor = keystone" /etc/glance/glance-registry.conf

#start glance
su -s /bin/sh -c "glance-manage db_sync" glance
systemctl enable openstack-glance-api.service openstack-glance-registry.service
systemctl start openstack-glance-api.service openstack-glance-registry.service

#upload the cirros image to glance
yum -y install wget
wget http://download.cirros-cloud.net/0.3.3/cirros-0.3.3-x86_64-disk.img
#wget http://cdn.download.cirros-cloud.net/0.3.3/cirros-0.3.3-x86_64-disk.img
glance image-create --name "cirros-0.3.3-x86_64" --file cirros-0.3.3-x86_64-disk.img \
  --disk-format qcow2 --container-format bare --progress
  
#create the keystone entries for nova
#openstack user create nova --password letmein123fiberNetrules123$
openstack user create nova --password $SERVICE_PWD
openstack role add --project service --user nova admin
openstack service create --name nova --description "OpenStack Compute" compute

openstack endpoint create \
  --publicurl http://$CONTROLLER_IP:8774/v2/%\(tenant_id\)s \
  --internalurl http://$CONTROLLER_IP:8774/v2/%\(tenant_id\)s \
  --adminurl http://$CONTROLLER_IP:8774/v2/%\(tenant_id\)s \
  --region FiberNet \
  compute

#install the nova controller components
yum -y install openstack-nova-api openstack-nova-cert openstack-nova-conductor \
  openstack-nova-console openstack-nova-novncproxy openstack-nova-scheduler \
  python-novaclient

#edit /etc/nova/nova.conf
sed -i.bak "/\[database\]/a \
connection = mysql://nova:$SERVICE_PWD@$CONTROLLER_IP/nova" /etc/nova/nova.conf

sed -i "/\[DEFAULT\]/a \
rpc_backend = rabbit\n\
rabbit_host = $CONTROLLER_IP\n\
auth_strategy = keystone\n\
my_ip = $CONTROLLER_IP\n\
vncserver_listen = $CONTROLLER_IP\n\
vncserver_proxyclient_address = $CONTROLLER_IP\n\
network_api_class = nova.network.neutronv2.api.API\n\
security_group_api = neutron\n\
linuxnet_interface_driver = nova.network.linux_net.LinuxOVSInterfaceDriver\n\
firewall_driver = nova.virt.firewall.NoopFirewallDriver" /etc/nova/nova.conf

sed -i "/\[keystone_authtoken\]/i \
[database]\nconnection = mysql://nova:$SERVICE_PWD@$CONTROLLER_IP/nova" /etc/nova/nova.conf

sed -i "/\[keystone_authtoken\]/a \
auth_uri = http://$CONTROLLER_IP:5000/v2.0\n\
identity_uri = http://$CONTROLLER_IP:35357\n\
admin_tenant_name = service\n\
admin_user = nova\n\
admin_password = $SERVICE_PWD" /etc/nova/nova.conf

sed -i "/\[glance\]/a host = $CONTROLLER_IP" /etc/nova/nova.conf

sed -i "/\[neutron\]/a \
url = http://$CONTROLLER_IP:9696\n\
auth_strategy = keystone\n\
admin_auth_url = http://$CONTROLLER_IP:35357/v2.0\n\
admin_tenant_name = service\n\
admin_username = neutron\n\
admin_password = $SERVICE_PWD\n\
service_metadata_proxy = True\n\
metadata_proxy_shared_secret = $META_PWD" /etc/nova/nova.conf

#start nova
su -s /bin/sh -c "nova-manage db sync" nova

systemctl enable openstack-nova-api.service openstack-nova-cert.service \
  openstack-nova-consoleauth.service openstack-nova-scheduler.service \
  openstack-nova-conductor.service openstack-nova-novncproxy.service
systemctl start openstack-nova-api.service openstack-nova-cert.service \
  openstack-nova-consoleauth.service openstack-nova-scheduler.service \
  openstack-nova-conductor.service openstack-nova-novncproxy.service

#create keystone entries for neutron
#openstack user create neutron  --password letmein123fiberNetrules123$
openstack user create neutron  --password $SERVICE_PWD
openstack role add --project service --user neutron admin
openstack service create --name neutron --description "OpenStack Networking" network
openstack endpoint create \
  --publicurl http://$CONTROLLER_IP:9696 \
  --adminurl http://$CONTROLLER_IP:9696 \
  --internalurl http://$CONTROLLER_IP:9696 \
  --region FiberNet \
  network
#install neutron
yum -y install openstack-neutron openstack-neutron-ml2 python-neutronclient which

#edit /etc/neutron/neutron.conf
sed -i.bak "/\[database\]/a \
connection = mysql://neutron:$SERVICE_PWD@$CONTROLLER_IP/neutron" /etc/neutron/neutron.conf

SERVICE_TENANT_ID=$(openstack project list | awk '/ service / {print $2}')

sed -i '0,/\[DEFAULT\]/s//\[DEFAULT\]\
rpc_backend = rabbit\
rabbit_host = '"$CONTROLLER_IP"'\
auth_strategy = keystone\
core_plugin = ml2\
service_plugins = router\
allow_overlapping_ips = True\
notify_nova_on_port_status_changes = True\
notify_nova_on_port_data_changes = True\
nova_url = http:\/\/'"$CONTROLLER_IP"':8774\/v2\
nova_admin_auth_url = http:\/\/'"$CONTROLLER_IP"':35357\/v2.0\
nova_region_name = FiberNet\
nova_admin_username = nova\
nova_admin_tenant_id = '"$SERVICE_TENANT_ID"'\
nova_admin_password = '"$SERVICE_PWD"'/' /etc/neutron/neutron.conf

sed -i "/\[keystone_authtoken\]/a \
auth_uri = http://$CONTROLLER_IP:5000/v2.0\n\
identity_uri = http://$CONTROLLER_IP:35357\n\
admin_tenant_name = service\n\
admin_user = neutron\n\
admin_password = $SERVICE_PWD" /etc/neutron/neutron.conf

#edit /etc/neutron/plugins/ml2/ml2_conf.ini
sed -i "/\[ml2\]/a \
type_drivers = flat,gre\n\
tenant_network_types = gre\n\
mechanism_drivers = openvswitch" /etc/neutron/plugins/ml2/ml2_conf.ini

sed -i "/\[ml2_type_gre\]/a \
tunnel_id_ranges = 1:1000" /etc/neutron/plugins/ml2/ml2_conf.ini

sed -i "/\[securitygroup\]/a \
enable_security_group = True\n\
enable_ipset = True\n\
firewall_driver = neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver" /etc/neutron/plugins/ml2/ml2_conf.ini

#start neutron
ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf \
  --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade kilo" neutron
systemctl restart openstack-nova-api.service openstack-nova-scheduler.service \
  openstack-nova-conductor.service
systemctl enable neutron-server.service
systemctl start neutron-server.service

#install dashboard
#TODO: put on dedicated server
yum -y install openstack-dashboard httpd mod_wsgi memcached python-memcached

#edit /etc/openstack-dashboard/local_settings
sed -i.bak "s/ALLOWED_HOSTS = \['horizon.example.com', 'localhost'\]/ALLOWED_HOSTS = ['*']/" /etc/openstack-dashboard/local_settings
sed -i 's/OPENSTACK_HOST = "127.0.0.1"/OPENSTACK_HOST = "'"$CONTROLLER_IP"'"/' /etc/openstack-dashboard/local_settings
sed -i "s/WEBROOT = '\/dashboard\/'/WEBROOT = '\/'/" /etc/openstack-dashboard/local_settings


#drop the /dashboard from the url
sed -i.bak 's/WSGIScriptAlias \/dashboard/WSGIScriptAlias \//' /etc/httpd/conf.d/openstack-dashboard.conf  


#start dashboard
setsebool -P httpd_can_network_connect on
chown -R apache:apache /usr/share/openstack-dashboard/static

systemctl restart memcached.service
sleep 10
systemctl restart httpd.service

#create keystone entries for cinder
#TODO: needs custom config for dell equallogic
#openstack user create cinder  --password letmein123fiberNetrules123$ 
openstack user create cinder --password $SERVICE_PWD
openstack role add --project service --user cinder admin
openstack service create  --name cinder --description "OpenStack Block Storage" volume
openstack service create  --name cinderv2 --description "OpenStack Block Storage" volumev2

openstack endpoint create \
  --publicurl http://$CONTROLLER_IP:8776/v2/%\(tenant_id\)s \
  --internalurl http://$CONTROLLER_IP:8776/v2/%\(tenant_id\)s \
  --adminurl http://$CONTROLLER_IP:8776/v2/%\(tenant_id\)s \
  --region FiberNet \
  volume
openstack endpoint create \
  --publicurl http://$CONTROLLER_IP:8776/v2/%\(tenant_id\)s \
  --internalurl http://$CONTROLLER_IP:8776/v2/%\(tenant_id\)s \
  --adminurl http://$CONTROLLER_IP:8776/v2/%\(tenant_id\)s \
  --region FiberNet \
  volumev2


#install cinder controller
yum -y install openstack-cinder python-cinderclient python-oslo-db


#edit /etc/cinder/cinder.conf
sed -i.bak "/\[database\]/a connection = mysql://cinder:$SERVICE_PWD@$CONTROLLER_IP/cinder" /etc/cinder/cinder.conf

sed -i "/\[DEFAULT\]/a \
rpc_backend = rabbit\n\
rabbit_host = $CONTROLLER_IP\n\
auth_strategy = keystone\n\
my_ip = $CONTROLLER_IP" /etc/cinder/cinder.conf

sed -i "/\[keystone_authtoken\]/a \
auth_uri = http://$CONTROLLER_IP:5000/v2.0\n\
identity_uri = http://$CONTROLLER_IP:35357\n\
admin_tenant_name = service\n\
admin_user = cinder\n\
admin_password = $SERVICE_PWD" /etc/cinder/cinder.conf

#start cinder controller
su -s /bin/sh -c "cinder-manage db sync" cinder
systemctl enable openstack-cinder-api.service openstack-cinder-scheduler.service
systemctl start openstack-cinder-api.service openstack-cinder-scheduler.service



#openstack user create swift  --password letmein123fiberNetrules123$
openstack user create swift  --password $SERVICE_PWD
openstack role add --project service --user swift admin
openstack service create --name swift --description "OpenStack Object Storage" object-store
openstack endpoint create \
  --publicurl http://$CONTROLLER_IP:8080 \
  --adminurl http://$CONTROLLER_IP:8080 \
  --internalurl http://$CONTROLLER_IP:8080 \
  --region FiberNet \
  object-store
#install swift



###############################################################################
# All done!
###############################################################################


cat <<CONCLUSION
Openstack controller node is now installed. 
visit http://$CONTROLLER_IP/ 
use $ADMIN_PWD for admin password
CONCLUSION

