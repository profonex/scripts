#!/bin/sh

read -p "Node Name: " nodename
read -p "Database Password: " dbasepass

apt-get update && apt-get upgrade -y --force-yes && apt-get install -y --force-yes git  && cd /usr/src && git clone https://github.com/fusionpbx/fusionpbx-install.sh.git && chmod 755 -R /usr/src/fusionpbx-install.sh && cd /usr/src/fusionpbx-install.sh/debian

sed "s@echo 'deb http://apt.postgresql.org/pub/repos/apt/ jessie-pgdg main' >> /etc/apt/sources.list.d/pgdg.list@#echo 'deb http://apt.postgresql.org/pub/repos/apt/ jessie-pgdg main' >> /etc/apt/sources.list.d/pgdg.list@g" -i /usr/src/fusionpbx-install.sh/debian/resources/postgres.sh
sed "s@wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -@#wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -@g" -i /usr/src/fusionpbx-install.sh/debian/resources/postgres.sh
sed "s@apt-get update && apt-get upgrade -y@#apt-get update && apt-get upgrade -yy@g" -i /usr/src/fusionpbx-install.sh/debian/resources/postgres.sh
sed "s@apt-get install -y --force-yes sudo postgresql@#apt-get install -y --force-yes sudo postgresql@g" -i /usr/src/fusionpbx-install.sh/debian/resources/postgres.sh

sed "s@#echo 'deb http://apt.postgresql.org/pub/repos/apt/ jessie-pgdg main'  >> /etc/apt/sources.list.d/postgresql.list@echo 'deb http://apt.postgresql.org/pub/repos/apt/ jessie-pgdg main'  >> /etc/apt/sources.list.d/postgresql.list@g" -i /usr/src/fusionpbx-install.sh/debian/resources/postgres.sh
sed "s@#echo 'deb http://packages.2ndquadrant.com/bdr/apt/ jessie-2ndquadrant main' >> /etc/apt/sources.list.d/2ndquadrant.list@echo 'deb http://packages.2ndquadrant.com/bdr/apt/ jessie-2ndquadrant main' >> /etc/apt/sources.list.d/2ndquadrant.list@g" -i /usr/src/fusionpbx-install.sh/debian/resources/postgres.sh
sed "s@#/usr/bin/wget --quiet -O - http://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc | apt-key add -@/usr/bin/wget --quiet -O - http://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc | apt-key add -@g" -i /usr/src/fusionpbx-install.sh/debian/resources/postgres.sh
sed "s@#/usr/bin/wget --quiet -O - http://packages.2ndquadrant.com/bdr/apt/AA7A6805.asc | apt-key add -@/usr/bin/wget --quiet -O - http://packages.2ndquadrant.com/bdr/apt/AA7A6805.asc | apt-key add -@g" -i /usr/src/fusionpbx-install.sh/debian/resources/postgres.sh
sed "s@#apt-get update && apt-get upgrade -y@apt-get update && apt-get upgrade -y@g" -i /usr/src/fusionpbx-install.sh/debian/resources/postgres.sh
sed "s@#apt-get install -y --force-yes sudo postgresql-bdr-9.4 postgresql-bdr-9.4-bdr-plugin postgresql-bdr-contrib-9.4@apt-get install -y --force-yes sudo postgresql-bdr-9.4 postgresql-bdr-9.4-bdr-plugin postgresql-bdr-contrib-9.4@g" -i /usr/src/fusionpbx-install.sh/debian/resources/postgres.sh

sed -i /etc/postgresql/9.4/main/postgresql.conf -e s:'snakeoil.key:snakeoil-postgres.key:'
cp /etc/ssl/private/ssl-cert-snakeoil.key /etc/ssl/private/ssl-cert-snakeoil-postgres.key
chown postgres:postgres /etc/ssl/private/ssl-cert-snakeoil-postgres.key
chmod 600 /etc/ssl/private/ssl-cert-snakeoil-postgres.key


cat >> /etc/postgresql/9.4/main/postgresql.conf << EOF
listen_addresses = '*'
shared_preload_libraries = 'bdr'
wal_level = 'logical'
track_commit_timestamp = on
max_connections = 200
max_wal_senders = 10
max_replication_slots = 10
# max_replication_slots maximum possible number is 48
# Make sure there are enough background worker slots for BDR to run
max_worker_processes = 20

# These aren't required, but are useful for diagnosing problems
#log_error_verbosity = verbose
#log_min_messages = debug1
#log_line_prefix = 'd=%d p=%p a=%a%q '

# Useful options for playing with conflicts
#bdr.default_apply_delay=2000   # milliseconds
#bdr.log_conflicts_to_table=on
#bdr.skip_ddl_replication = off
EOF


cat >> /etc/postgresql/9.4/main/pg_hba.conf << EOF
host     all     all     127.0.0.1/32     trust
hostssl     all     all     138.197.89.130/32     trust
hostssl     all     all     138.197.89.172/32     trust
hostssl     replication     postgres     138.197.89.130/32     trust
hostssl     replication     postgres     138.197.89.172/32     trust
EOF

systemctl daemon-reload
systemctl restart postgresql

su postgres
psql
ALTER USER fusionpbx WITH PASSWORD '$dbasepass';
ALTER USER freeswitch WITH PASSWORD '$dbasepass';

DROP DATABASE fusionpbx;
CREATE DATABASE fusionpbx;
DROP DATABSE freeswitch;
CREATE DATABASE freeswitch;

\c fusionpbx
CREATE EXTENSION btree_gist;
CREATE EXTENSION bdr;

SELECT bdr.bdr_group_join(
local_node_name := '$nodename',
node_external_dsn := 'host=138.197.89.172 port=5432 dbname=fusionpbx connect_timeout=10 keepalives_idle=5 keepalives_interval=1',
join_using_dsn := 'host=138.197.89.130 port=5432 dbname=fusionpbx connect_timeout=10 keepalives_idle=5 keepalives_interval=1');
SELECT bdr.bdr_node_join_wait_for_ready();

CREATE  EXTENSION pgcrypto;

\c freeswitch
create extension btree_gist;
create extension bdr;

SELECT bdr.bdr_group_join(
local_node_name := '$nodename',
node_external_dsn := 'host=138.197.89.172 port=5432 dbname=freeswitch connect_timeout=10 keepalives_idle=5 keepalives_interval=1',
join_using_dsn := 'host=138.197.89.130 port=5432 dbname=freeswitch connect_timeout=10 keepalives_idle=5 keepalives_interval=1');
SELECT bdr.bdr_node_join_wait_for_ready();

create extension pgcrypto;
\q
exit

cd /usr/src
git clone https://github.com/fusionpbx/fusionpbx-apps 
cp -R fusionpbx-apps/bdr /var/www/fusionpbx/app
chown -R www-data:www-data /var/www/fusionpbx/app/bdr

mkdir -p /etc/fusionpbx/resources/templates/
cp -R /var/www/fusionpbx/resources/templates/provision /etc/fusionpbx/resources/templates
chown -R www-data:www-data /etc/fusionpbx

