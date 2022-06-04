#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

echo "ATTENTION! LEMP must be installed to run this script correctly! If you use immers.cloud preinstalled image - ignore this message."
echo "Install selections:"
echo "[0]: PHPMyAdmin
[1]: WordPress
[2]: Laravel 8
[3]: Yii2 Basic
[4]: Yii2 Advanced"
if [ -z ${id_mode+x} ];
then
    echo -n "Which one are you want to setup?: [0-4] "
    read id_mode
fi

case $id_mode in
    0) #LEMP_PMA
#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi


if [ -z ${user_mysql_root+x} ];
then
    echo -n "Enter new mysql username: "
    read user_mysql_root
fi

if [ -z ${pwd_mysql_root+x} ];
then
    echo -n "Enter new mysql user password: "
    read pwd_mysql_root
fi

user_mysql_exists="$(mysql -sse "SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user = '$user_mysql_root')")"

if [ "$user_mysql_exists" != 1 ];
then
mysql << EOF
CREATE USER '${user_mysql_root}'@'localhost' IDENTIFIED BY '${pwd_mysql_root}';
GRANT ALL PRIVILEGES ON *.* to '${user_mysql_root}'@'localhost';
FLUSH PRIVILEGES;
EOF
service mysql restart
else
    echo "Alert!: User exists. Ignoring mysql request."
fi

curl https://files.phpmyadmin.net/phpMyAdmin/5.1.2/phpMyAdmin-5.1.2-all-languages.zip --output /tmp/pma.zip
unzip /tmp/pma.zip -d /tmp/
mkdir /var/www/phpmyadmin
mv -f /tmp/phpMyAdmin-5.1.2-all-languages/* /var/www/phpmyadmin/

touch /etc/nginx/sites-available/zpma.conf
cat << EOF > /etc/nginx/sites-available/zpma.conf
server {
    charset utf-8;
    client_max_body_size 128M;

    listen 80; ## listen for ipv4
    #listen [::]:80 default_server ipv6only=on; ## listen for ipv6

    server_name pma;
    root        /var/www/phpmyadmin;
    index       index.php;

    location / {
        # Redirect everything that isn't a real file to index.php
        try_files \$uri \$uri/ /index.php\$is_args\$args;
    }

    # uncomment to avoid processing of calls to non-existing static files by Yii
    #location ~ \.(js|css|png|jpg|gif|swf|ico|pdf|mov|fla|zip|rar)$ {
    #    try_files \$uri =404;
    #}
    #error_page 404 /404.html;

    # deny accessing php files for the /assets directory
    location ~ ^/assets/.*\.php$ {
        deny all;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_pass unix:/run/php/php8.1-fpm.sock;
        try_files \$uri =404;
    }

    location ~* /\. {
        deny all;
    }
}
EOF

rm /etc/nginx/sites-enabled/default
sudo ln -s /etc/nginx/sites-available/zpma.conf /etc/nginx/sites-enabled/
systemctl restart nginx

    ;;
    1) #LEMP_WP
#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

#mysql_secure_installation

if [ -z ${db_wp_name+x} ];
then
    echo -n "Enter new Wordpress Database name: "
    read db_wp_name
fi
if [ -z ${db_wp_username+x} ];
then
    echo -n "Enter new Wordpress Database username: "
    read db_wp_username
fi
db_wp_username=\'$db_wp_username\'
if [ -z ${db_wp_password+x} ]
then
echo -n "Enter new Wordpress Database password: "
read db_wp_password
fi
db_wp_password=\'$db_wp_password\'
db_wp_host='localhost'

if [ -z ${check_pma_install+x} ]
then
echo -n "Install PHPMyAdmin in http://<site>/phpmyadmin? [y/n]: "
read check_pma_install
fi

user_mysql_exists="$(mysql -sse "SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user = $db_wp_username)")"

if [ "$user_mysql_exists" != 1 ];
then
mysql << EOF
CREATE USER ${db_wp_username}@${db_wp_host} IDENTIFIED BY ${db_wp_password};
GRANT ALL PRIVILEGES ON ${db_wp_name}.* to ${db_wp_username}@${db_wp_host};
FLUSH PRIVILEGES;
EOF
else
    echo "Alert!: User exists. Ignoring mysql request."
fi
mysql << EOF
CREATE DATABASE IF NOT EXISTS ${db_wp_name};
EOF

mkdir /etc/ssl
mkdir /etc/ssl/certs

echo -n "Input Self-Signed certificate data, please:"
openssl req -x509 -nodes -days 365 -newkey rsa:2048  -keyout /etc/ssl/private/nginx-selfsigned.key -out /etc/ssl/certs/nginx-selfsigned.crt -subj "/C=/ST=/L=/O=/CN="
openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048

touch /etc/nginx/sites-available/wordpress
touch /etc/nginx/snippets/ssl-params.conf
touch /etc/nginx/snippets/self-signed.conf

cat << EOF > /etc/nginx/sites-available/wordpress
server {
    listen 80;
	listen [::]:80;
	listen 443 ssl;
	listen [::]:443 ssl http2;

	include snippets/self-signed.conf;
	include snippets/ssl-params.conf;

        root /var/www/wordpress/;
        index index.php;

        server_name localhost ;

	location = /favicon.ico { log_not_found off; access_log off; }
	location = /robots.txt { log_not_found off; access_log off; allow all; }

        location / {
            try_files \$uri \$uri/ /index.php\$is_args\$args;
        }

        location ~ .php$ {
                include snippets/fastcgi-php.conf;
                fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
        }
}
EOF

cat << EOF > /etc/nginx/snippets/self-signed.conf
ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;
EOF
cat << EOF > /etc/nginx/snippets/ssl-params.conf
ssl_protocols TLSv1.2;
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
add_header X-XSS-Protection "1; mode=block";
ssl_dhparam /etc/ssl/certs/dhparam.pem;
EOF

rm /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/wordpress
systemctl restart nginx

wget -O /tmp/wordpress.tar.gz https://wordpress.org/latest.tar.gz
tar -xzvf /tmp/wordpress.tar.gz -C /var/www

cat << EOF > /var/www/wordpress/wp-config.php
<?php
define( 'DB_NAME', '${db_wp_name}' );
define( 'DB_USER', ${db_wp_username} );
define( 'DB_PASSWORD', ${db_wp_password} );
define( 'DB_HOST', 'localhost' );
define( 'DB_CHARSET', 'utf8' );
define( 'DB_COLLATE', '' );
\$table_prefix = 'wp_';
if ( ! defined( 'ABSPATH' ) ) {
        define( 'ABSPATH', __DIR__ . '/' );
}
require_once ABSPATH . 'wp-settings.php';
EOF

if [ "$check_pma_install" == "y" ]
then
    curl https://files.phpmyadmin.net/phpMyAdmin/5.1.2/phpMyAdmin-5.1.2-all-languages.zip --output /tmp/pma.zip
    unzip /tmp/pma.zip -d /tmp/
    mkdir /var/www/wordpress/phpmyadmin
    mv -f /tmp/phpMyAdmin-5.1.2-all-languages/* /var/www/wordpress/phpmyadmin/
fi
    ;;
    2) #LEMP_L8
#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

composer create-project laravel/laravel /var/www/laravel

touch /etc/nginx/sites-available/laravel.conf
cat << EOF > /etc/nginx/sites-available/laravel.conf
server {
    listen 80;
    listen [::]:80;
    server_name laravel;
    root /var/www/laravel/public;

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";

    index index.php;

    charset utf-8;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    error_page 404 /index.php;

    location ~ \.php$ {
        fastcgi_pass unix:/run/php/php8.1-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
EOF

sudo chown www-data /var/www/laravel/storage/framework/sessions/
sudo chown www-data /var/www/laravel/storage/framework/views/
sudo chown www-data /var/www/laravel/storage/logs/

rm /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/laravel.conf /etc/nginx/sites-enabled/
systemctl restart nginx

    ;;
    3) #LEMP_Y2B
#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

composer create-project --prefer-dist yiisoft/yii2-app-basic /var/www/yii2basic


mkdir /var/www/yii2basic/log
chown www-data /var/www/yii2basic/log
touch /etc/nginx/sites-available/yii2basic.conf
cat << EOF > /etc/nginx/sites-available/yii2basic.conf
server {
    charset utf-8;
    client_max_body_size 128M;

    listen 80; ## listen for ipv4
    #listen [::]:80 default_server ipv6only=on; ## listen for ipv6

    server_name yii2basic;
    root        /var/www/yii2basic/web;
    index       index.php;

    access_log  /var/www/yii2basic/log/access.log;
    error_log   /var/www/yii2basic/log/error.log;

    location / {
        # Redirect everything that isn't a real file to index.php
        try_files \$uri \$uri/ /index.php\$is_args\$args;
    }

    # uncomment to avoid processing of calls to non-existing static files by Yii
    #location ~ \.(js|css|png|jpg|gif|swf|ico|pdf|mov|fla|zip|rar)$ {
    #    try_files \$uri =404;
    #}
    #error_page 404 /404.html;

    # deny accessing php files for the /assets directory
    location ~ ^/assets/.*\.php$ {
        deny all;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_pass unix:/run/php/php8.1-fpm.sock;
        try_files \$uri =404;
    }

    location ~* /\. {
        deny all;
    }
}
EOF
rm /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/yii2basic.conf /etc/nginx/sites-enabled/
systemctl restart nginx

    ;;
    4) #LEMP_Y2A
#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

composer create-project --prefer-dist yiisoft/yii2-app-advanced /var/www/yii-application
cd /var/www/yii-application
php init
mysql << EOF
	create database yii2advanced;
	exit;
EOF
php yii migrate

mkdir /var/www/yii-application/log
touch /var/www/yii-application/log/frontend-access.log
chown -R www-data /var/www/yii-application/log

touch /etc/nginx/sites-available/yii2adv.conf
cat << EOF > /etc/nginx/sites-available/yii2adv.conf
	server {
        charset utf-8;
        client_max_body_size 128M;

        listen 80; ## listen for ipv4
        #listen [::]:80 default_server ipv6only=on; ## listen for ipv6

        server_name frontend;
        root        /var/www/yii-application/frontend/web/;
        index       index.php;

        access_log  /var/www/yii-application/log/frontend-access.log;
        error_log   /var/www/yii-application/log/frontend-error.log;

        location / {
            # Redirect everything that isn't a real file to index.php
            try_files \$uri \$uri/ /index.php\$is_args\$args;
        }

        # uncomment to avoid processing of calls to non-existing static files by Yii
        #location ~ \.(js|css|png|jpg|gif|swf|ico|pdf|mov|fla|zip|rar)$ {
        #    try_files \$uri =404;
        #}
        #error_page 404 /404.html;

        # deny accessing php files for the /assets directory
        location ~ ^/assets/.*\.php$ {
            deny all;
        }

        location ~ \.php$ {
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            fastcgi_pass unix:/run/php/php8.1-fpm.sock;
            try_files \$uri =404;
        }

        location ~* /\. {
            deny all;
        }
    }

    server {
        charset utf-8;
        client_max_body_size 128M;

        listen 80; ## listen for ipv4
        #listen [::]:80 default_server ipv6only=on; ## listen for ipv6

        server_name backend;
        root        /var/www/yii-application/backend/web/;
        index       index.php;

        access_log  /var/www/yii-application/log/backend-access.log;
        error_log   /var/www/yii-application/log/backend-error.log;

        location / {
            # Redirect everything that isn't a real file to index.php
            try_files \$uri \$uri/ /index.php\$is_args$args;
        }

        # uncomment to avoid processing of calls to non-existing static files by Yii
        #location ~ \.(js|css|png|jpg|gif|swf|ico|pdf|mov|fla|zip|rar)$ {
        #    try_files \$uri =404;
        #}
        #error_page 404 /404.html;

        # deny accessing php files for the /assets directory
        location ~ ^/assets/.*\.php$ {
            deny all;
        }

        location ~ \.php$ {
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            fastcgi_pass unix:/run/php/php8.1-fpm.sock;
            try_files \$uri =404;
        }

        location ~* /\. {
            deny all;
        }
    }
EOF
rm /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/yii2adv.conf /etc/nginx/sites-enabled/
systemctl restart nginx

    ;;
esac

chown ubuntu:ubuntu /var/www/ -R
chmod 755 /var/www/ -R
