#!/bin/bash

if [ "$EUID" -ne 0 ]
  then 
	#echo "Please run as root"
	dialog --infobox "Please run as root" 5 25 
	read await
	clear
  exit
fi

echo "ATTENTION! LAMP must be installed to run this script correctly! If you use immers.cloud preinstalled image - ignore this message."
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
#	exec 3>&1;
#	id_mode=$(dialog --title "LAMP Installation menu" --clear --menu "Which tool you wanna install?" 21 40 40 \
#	"0" "PHPMyAdmin"\
#	"1" "Wordpress"\
#	"2" "Laravel 8"\
#	"3" "Yii2 Basic"\
#	"4" "Yii2 Advanced"\
#	2>&1 1>&3)
#	exitcode=$?;
#	exec 3>&-;
#	if [ "$exitcode" != 0 ]
#	then
#		echo "Have a good day! Script stopped."
#		exit 0
#	fi
fi

case $id_mode in
    0) #LAMP_PMA
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

touch /etc/apache2/sites-available/zpma.conf
cat << EOF > /etc/apache2/sites-available/zpma.conf
        ServerName zpma
        Alias /phpmyadmin "/var/www/phpmyadmin"
        <Directory "/var/www/phpmyadmin">
                DirectoryIndex index.php
                AllowOverride All
                Options FollowSymlinks
                Require all granted
        </Directory>
EOF

ln -s /etc/apache2/sites-available/zpma.conf /etc/apache2/sites-enabled/
systemctl restart apache2

    ;;
    1) #LAMP_WP
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

user_mysql_exists="$(mysql -sse "SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user = $db_wp_username)")"

if [ "$user_mysql_exists" != 1 ];
then
mysql << EOF
CREATE USER ${db_wp_username}@${db_wp_host} IDENTIFIED BY ${db_wp_password};
GRANT ALL PRIVILEGES ON ${db_wp_name}.* to ${db_wp_username}@$db_wp_host;
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
openssl req -x509 -nodes -days 365 -newkey rsa:2048  -keyout /etc/ssl/private/apache-selfsigned.key -out /etc/ssl/certs/apache-selfsigned.crt -subj "/C=/ST=/L=/O=/CN="
openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048

touch /etc/apache2/sites-available/wordpress.conf
touch /etc/apache2/conf-available/ssl-params.conf

cat << EOF > /etc/apache2/sites-available/wordpress.conf
<VirtualHost *:80>
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
EOF

cat << EOF > /etc/apache2/conf-available/ssl-params.conf
SSLCipherSuite EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH
SSLProtocol All -SSLv2 -SSLv3
SSLHonorCipherOrder On
Header always set Strict-Transport-Security "max-age=63072000; includeSubdomains"
Header always set X-Frame-Options DENY
Header always set X-Content-Type-Options nosniff
SSLCompression off
SSLSessionTickets Off
SSLUseStapling on
SSLStaplingCache "shmcb:logs/stapling-cache(150000)"
SSLOpenSSLConfCmd DHParameters "/etc/ssl/certs/dhparam.pem"
EOF

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
    ;;
    2) #LAMP_L8
#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

composer create-project laravel/laravel /var/www/laravel

touch /etc/apache2/sites-available/laravel.conf
cat << EOF > /etc/apache2/sites-available/laravel.conf
<VirtualHost *:80>
    ServerName laravel
    DocumentRoot /var/www/laravel/public/

    <Directory /var/www/laravel/public/>
            Options Indexes FollowSymLinks MultiViews
            AllowOverride All
            Order allow,deny
            allow from all
            Require all granted
    </Directory>

    LogLevel debug
    ErrorLog /var/www/laravel/storage/logs/error.log
    CustomLog /var/www/laravel/storage/logs/access.log combined
</VirtualHost>
EOF

sudo chown www-data /var/www/laravel/storage/framework/sessions/
sudo chown www-data /var/www/laravel/storage/framework/views/
sudo chown www-data /var/www/laravel/storage/logs/

rm /etc/apache2/sites-enabled/000-default.conf
ln -s /etc/apache2/sites-available/laravel.conf /etc/apache2/sites-enabled/
systemctl restart apache2
    ;;
    3) #LAMP_Y2B
#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

composer create-project --prefer-dist yiisoft/yii2-app-basic /var/www/yii2basic

mkdir /var/www/yii2basic/log
chown www-data /var/www/yii2basic/log
touch /etc/apache2/sites-available/yii2basic.conf
cat << EOF > /etc/apache2/sites-available/yii2basic.conf
<VirtualHost *:80>
    ServerName mysite
    ServerAlias www.mysite
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/yii2basic/web
    ErrorLog /var/www/yii2basic/log/error.log
    CustomLog /var/www/yii2basic/log/access.log combined
	<Directory "/var/www/yii2basic/web">
		# use mod_rewrite for pretty URL support
		RewriteEngine on

		# if \$showScriptName is false in UrlManager, do not allow accessing URLs with script name
		RewriteRule ^index.php/ - [L,R=404]

		# If a directory or a file exists, use the request directly
		RewriteCond %{REQUEST_FILENAME} !-f
		RewriteCond %{REQUEST_FILENAME} !-d

		# Otherwise forward the request to index.php
		RewriteRule . index.php

		# ...other settings...
	</Directory>
</VirtualHost>
EOF
a2enmod rewrite
rm /etc/apache2/sites-enabled/000-default.conf
ln -s /etc/apache2/sites-available/yii2basic.conf /etc/apache2/sites-enabled/
systemctl restart apache2

    ;;
    4) #LAMP_Y2A
#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

composer create-project --prefer-dist yiisoft/yii2-app-advanced /var/www/yii-application
cd /var/www/yii-application
sudo php init
mysql << EOF
	create database yii2advanced;
	exit;
EOF
php yii migrate

mkdir /var/www/yii-application/log
touch /var/www/yii-application/log/frontend-access.log
chown -R www-data /var/www/yii-application/log
touch /etc/apache2/sites-available/yii2adv.conf
cat << EOF > /etc/apache2/sites-available/yii2adv.conf
	<VirtualHost *:80>
        ServerName frontend
        DocumentRoot "/var/www/yii-application/frontend/web/"

        <Directory "/var/www/yii-application/frontend/web/">
            # use mod_rewrite for pretty URL support
            RewriteEngine on
            # If a directory or a file exists, use the request directly
            RewriteCond %{REQUEST_FILENAME} !-f
            RewriteCond %{REQUEST_FILENAME} !-d
            # Otherwise forward the request to index.php
            RewriteRule . index.php

            # use index.php as index file
            DirectoryIndex index.php

            # ...other settings...
        </Directory>
    </VirtualHost>

    <VirtualHost *:80>
        ServerName backend
        DocumentRoot "/var/www/yii-application/backend/web/"

        <Directory "/var/www/yii-application/backend/web/">
            # use mod_rewrite for pretty URL support
            RewriteEngine on
            # If a directory or a file exists, use the request directly
            RewriteCond %{REQUEST_FILENAME} !-f
            RewriteCond %{REQUEST_FILENAME} !-d
            # Otherwise forward the request to index.php
            RewriteRule . index.php

            # use index.php as index file
            DirectoryIndex index.php

            # ...other settings...
        </Directory>
    </VirtualHost>
EOF
a2enmod rewrite
rm /etc/apache2/sites-enabled/000-default.conf
ln -s /etc/apache2/sites-available/yii2adv.conf /etc/apache2/sites-enabled/
systemctl restart apache2
    ;;
esac

chown ubuntu:ubuntu /var/www/ -R
chmod 755 /var/www/ -R
