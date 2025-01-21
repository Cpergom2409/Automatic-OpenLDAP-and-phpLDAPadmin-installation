#!/bin/bash

# Prompt the user for the domain name and admin password
read -p "Please enter your domain name (e.g., mydomain): " dominio
read -s -p "Please enter the admin password for LDAP: " contrasena
echo

# Convert the domain to LDAP format
dominio_ldap=$(echo "$dominio" | sed 's/\./,dc=/g')

# Update the system
sudo apt-get update
sudo apt-get upgrade -y

# === OpenLDAP Installation and Configuration ===
sudo apt-get install -y slapd ldap-utils

sudo dpkg-reconfigure slapd

# Configure OpenLDAP
cat <<EOF | sudo tee /etc/ldap/ldap.conf
BASE    dc=$dominio_ldap
URI     ldap://localhost
EOF

# Create initial entries for the LDAP base
cat <<EOF | sudo tee base.ldif
dn: dc=$dominio_ldap
objectClass: top
objectClass: dcObject
objectClass: organization
o: $(echo "$dominio" | awk -F. '{print toupper($1) " Organization"}')
dc: $(echo "$dominio" | awk -F. '{print $1}')

dn: cn=admin,dc=$dominio_ldap
objectClass: simpleSecurityObject
objectClass: organizationalRole
cn: admin
description: LDAP administrator
userPassword: $(slappasswd -s $contrasena)
EOF

# Add entries to the LDAP base
sudo ldapadd -x -D cn=admin,dc=$dominio_ldap -w "$contrasena" -f base.ldif

# Verify the configuration
sudo ldapsearch -x -LLL -b dc=$dominio_ldap

# === phpLDAPadmin Installation and Configuration ===
sudo apt-get install -y phpldapadmin

# Configure phpLDAPadmin
sudo sed -i "s/\$servers->setValue('server','host','127.0.0.1');/\$servers->setValue('server','host','localhost');/" /etc/phpldapadmin/config.php
sudo sed -i "s/\$servers->setValue('server','base',array('dc=example,dc=com'));/\$servers->setValue('server','base',array('dc=$dominio_ldap'));/g" /etc/phpldapadmin/config.php
sudo sed -i "s/\$servers->setValue('login','bind_id','cn=admin,dc=example,dc=com');/\$servers->setValue('login','bind_id','cn=admin,dc=$dominio_ldap');/" /etc/phpldapadmin/config.php

# Restart Apache
sudo systemctl restart apache2

echo "Installation and configuration completed for domain $dominio."
echo "You can access phpLDAPadmin at http://localhost/phpldapadmin"
