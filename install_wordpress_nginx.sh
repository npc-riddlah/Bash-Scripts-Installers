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
openssl req -x509 -nodes -days 365 -newkey rsa:2048  -keyout /etc/ssl/private/nginx-selfsigned.key -out /etc/ssl/certs/nginx-selfsigned.crt -subj "/C=/ST=/L=/O=/CN="
openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048

touch /etc/nginx/sites-available/wordpress
touch /etc/nginx/snippets/ssl-params.conf
touch /etc/nginx/snippets/self-signed.conf

echo "
server {
        listen 80;
	listen [::]:80;
	listen 443 ssl;
	listen [::]:443 ssl http2;

	include snippets/self-signed.conf;
	include snippets/ssl-params.conf;

        root /var/www/wordpress;

        index index.php;

        server_name _ ;

	location = /favicon.ico { log_not_found off; access_log off; }
	location = /robots.txt { log_not_found off; access_log off; allow all; }
	location ~* \.(css|gif|ico|jpeg|jpg|js|png)$ {
        	expires max;
        	log_not_found off;
    	}

        location / {
		try_files \$uri \$uri/ /index.php\$is_args\$args;
        }

        location ~ \.php$ {
                include snippets/fastcgi-php.conf;
                fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;
        }
}
" > /etc/nginx/sites-available/wordpress

echo "ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;
" > /etc/nginx/snippets/self-signed.conf

echo "ssl_protocols TLSv1.2;
ssl_prefer_server_ciphers on;
ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384;
ssl_ecdh_curve secp384r1;
ssl_session_timeout  10m;
ssl_session_cache shared:SSL:10m;
ssl_session_tickets off;
ssl_stapling on;
ssl_stapling_verify on;
resolver 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 5s;
add_header X-Frame-Options DENY;
add_header X-Content-Type-Options nosniff;
add_header X-XSS-Protection \"1; mode=block\";
ssl_dhparam /etc/ssl/certs/dhparam.pem;
" > /etc/nginx/snippets/ssl-params.conf

rm /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/wordpress
systemctl restart nginx

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
