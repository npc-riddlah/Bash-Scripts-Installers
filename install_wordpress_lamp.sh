#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

#mysql_secure_installation

echo -n "Enter new Wordpress Database name: "
read db_wp_name
echo -n "Enter new Wordpress Database username: "
read db_wp_username
db_wp_username=\'$db_wp_username\'
echo -n "Enter new Wordpress Database password: "
read db_wp_password
db_wp_password=\'$db_wp_password\'

db_wp_host='localhost'

mysql << EOF
CREATE DATABASE $db_wp_name;
CREATE USER $db_wp_username@$db_wp_host IDENTIFIED BY $db_wp_password;
GRANT ALL PRIVILEGES ON $db_wp_name.* to $db_wp_username@$db_wp_host;
FLUSH PRIVILEGES;
EOF

mkdir /etc/ssl
mkdir /etc/ssl/certs

echo -n "Input Self-Signed certificate data, please:"
openssl req -x509 -nodes -days 365 -newkey rsa:2048  -keyout /etc/ssl/private/apache-selfsigned.key -out /etc/ssl/certs/apache-selfsigned.crt -subj "/C=/ST=/L=/O=/CN="
openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048

touch /etc/apache2/sites-available/wordpress.conf
touch /etc/apache2/conf-available/ssl-params.conf

echo "<VirtualHost *:80>
    DocumentRoot /var/www/wordpress
    <Directory /var/www/wordpress>
        Options FollowSymLinks
        AllowOverride Limit Options FileInfo
        DirectoryIndex index.php
        Require all granted
    </Directory>
    <Directory /var/www/wordpress/wp-content>
        Options FollowSymLinks
        Require all granted
    </Directory>
</VirtualHost>
<VirtualHost *:443>
    DocumentRoot /var/www/wordpress
    SSLEngine on
    SSLCertificateFile      /etc/ssl/certs/apache-selfsigned.crt
    SSLCertificateKeyFile /etc/ssl/private/apache-selfsigned.key
    <Directory /var/www/wordpress>
        Options FollowSymLinks
        AllowOverride Limit Options FileInfo
        DirectoryIndex index.php
        Require all granted
    </Directory>
    <Directory /var/www/wordpress/wp-content>
        Options FollowSymLinks
        Require all granted
    </Directory>
</VirtualHost>
" > /etc/apache2/sites-available/wordpress.conf

echo "SSLCipherSuite EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH
SSLProtocol All -SSLv2 -SSLv3
SSLHonorCipherOrder On
Header always set Strict-Transport-Security \"max-age=63072000; includeSubdomains\"
Header always set X-Frame-Options DENY
Header always set X-Content-Type-Options nosniff
SSLCompression off
SSLSessionTickets Off
SSLUseStapling on
SSLStaplingCache \"shmcb:logs/stapling-cache(150000)\"
SSLOpenSSLConfCmd DHParameters \"/etc/ssl/certs/dhparam.pem\"
" > /etc/apache2/conf-available/ssl-params.conf

a2enmod rewrite
sudo a2dissite 000-default
a2enmod ssl
a2enmod headers
a2enconf ssl-params
a2ensite wordpress
systemctl restart apache2

wget -O /tmp/wordpress.tar.gz https://wordpress.org/latest.tar.gz
tar -xzvf /tmp/wordpress.tar.gz -C /var/www
chown -R www-data.www-data /var/www/wordpress

echo "
<?php
define( 'DB_NAME', '"$db_wp_name"' );
define( 'DB_USER', "$db_wp_username" );
define( 'DB_PASSWORD', "$db_wp_password" );
define( 'DB_HOST', 'localhost' );
define( 'DB_CHARSET', 'utf8' );
define( 'DB_COLLATE', '' );
\$table_prefix = 'wp_';
if ( ! defined( 'ABSPATH' ) ) {
        define( 'ABSPATH', __DIR__ . '/' );
}
require_once ABSPATH . 'wp-settings.php';
" > /var/www/wordpress/wp-config.php
