#!/bin/bash

# Solicitar el nombre del dominio y la contraseña al usuario
read -p "Por favor, introduce el nombre de tu dominio (ejemplo: midominio): " dominio
read -s -p "Por favor, introduce la contraseña para el administrador LDAP: " contrasena
echo

# Convertir el dominio en formato LDAP
dominio_ldap=$(echo "$dominio" | sed 's/\./,dc=/g')

# Actualizar el sistema
sudo apt-get update
sudo apt-get upgrade -y

# === Instalación y configuración de OpenLDAP ===
sudo apt-get install -y slapd ldap-utils

sudo dpkg-reconfigure slapd

# Configurar OpenLDAP
cat <<EOF | sudo tee /etc/ldap/ldap.conf
BASE    dc=$dominio_ldap
URI     ldap://localhost
EOF

# Crear entradas iniciales para la base LDAP
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

# Añadir entradas a la base LDAP
sudo ldapadd -x -D cn=admin,dc=$dominio_ldap -w "$contrasena" -f base.ldif

# Verificar configuración
sudo ldapsearch -x -LLL -b dc=$dominio_ldap

# === Instalación y configuración de phpLDAPadmin ===
sudo apt-get install -y phpldapadmin

# Configurar phpLDAPadmin
sudo sed -i "s/\$servers->setValue('server','host','127.0.0.1');/\$servers->setValue('server','host','localhost');/" /etc/phpldapadmin/config.php
sudo sed -i "s/\$servers->setValue('server','base',array('dc=example,dc=com'));/\$servers->setValue('server','base',array('dc=$dominio_ldap'));/g" /etc/phpldapadmin/config.php
sudo sed -i "s/\$servers->setValue('login','bind_id','cn=admin,dc=example,dc=com');/\$servers->setValue('login','bind_id','cn=admin,dc=$dominio_ldap');/" /etc/phpldapadmin/config.php

# Reiniciar Apache
sudo systemctl restart apache2

echo "Instalación y configuración completadas para el dominio $dominio."
echo "Puedes acceder a phpLDAPadmin en http://localhost/phpldapadmin"
