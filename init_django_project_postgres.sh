#!/bin/bash
#------------------COLORS!!!-------------------
RED='\033[0;31m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
CLEAN='\033[0m'

env_location=~/django

cat << EOF

-----
This script will help you to fast configure Django virtual environment
And create your projects. He is also can generate nginx proxy config file! 
-----

EOF

function read_environment_exists {
[ ! -d "$env_location" ] && mkdir $env_location
env_list=($(ls $env_location/))
env_count=($(ls $env_location/ | wc -l))
if [[ $env_count>0 ]]
then
	echo -e "${ORANGE}[We found already created ${RED}$env_count${ORANGE} environments]:${CLEAN}"
	for (( i=0; i<env_count; i++))
	do
		echo "["$i"] " ${env_list[$i]}
	done
	echo "["$env_count"] Select this number to create new environment" 
	read -p "Select the number of environment: " env_select
	if [[ $env_select > $env_count ]] 
	then
		read_environment_new
		configure_env
	else
		env_location=$env_location/${env_list[$env_select]}
	fi
else 
	read_environment_new
	configure_env
fi
echo "Your environment location is: " $env_location
}

function read_environment_new {
read -p "Input new environment name: " env_name
env_location=$env_location"/"$env_name
}

function read_project_new {
echo -e ${ORANGE}"[Input parameters of new project, please]"${CLEAN}
read -p "Input new project name: " proj_name
proj_location=$env_location"/"$proj_name
}

function read_postgres_new {
read -p "Input new postgres database name: " db_name
read -p "Input new postgres database username: " db_user
read -p "Input new postgres database password: " db_pass
}

function configure_env {
echo -e "${GREEN}[Configurting environment]${CLEAN}"
virtualenv $env_location
source $env_location/bin/activate
pip install django gunicorn psycopg2
}

function configure_pgresql {
echo -e "${GREEN}[Configuring PostgreSQL]${CLEAN}"
sudo -u postgres -i psql -c "CREATE USER $db_user WITH PASSWORD '$db_pass';"
sudo -u postgres -i psql -c "CREATE DATABASE $db_name;"
sudo -u postgres -i psql -c "GRANT ALL PRIVILEGES ON DATABASE $db_name TO $db_user;"	
}

function configure_django {
echo -e "${GREEN}[Creating project]${CLEAN}"
cd $env_location
django-admin startproject $proj_name
cat << EOF > $proj_location/settings.py
STATIC_ROOT = "$env_location/static/"
DATABASES = {
	'default': {
			'ENGINE': 'django.db.backends.postgresql_psycopg2',
			'NAME': '$db_name',
			'USER': '$db_user',
			'PASSWORD': '$db_pass',
			'HOST': 'localhost',
			'PORT': '',
		}
	}
EOF
python3 $proj_location/manage.py migrate
}

function configure_gunicorn {
echo -e "${GREEN}[Configuring gunicorn]${CLEAN}"
cat << EOF > $env_location/gunicorn_config.py
command = '$env_location/bin/gunicorn'
pythonpath = '$proj_location'
bind = '127.0.0.1:8001'
workers = 3
EOF

cat << EOF > $proj_location/runproj.sh
#!/bin/bash
source $env_location/bin/activate
gunicorn -c gunicorn -c $env_location/gunicorn_config.py $proj_name.wsgi
deactivate
EOF
chmod +x $proj_location/runproj.sh
}

function configure_nginx {
echo -e "${GREEN}[Configurting nginx]${CLEAN}"
cat << EOF > $proj_location/nginx.conf
server {
	server_name localhost;

	 access_log off;

	location /static/ {
		alias $env_location/static/;
	}

	location / {
		proxy_pass http://127.0.0.1:8001;
		proxy_set_header X-Forwarded-Host \$server_name;
		proxy_set_header X-Real-IP \$remote_addr;
		add_header P3P 'CP=\"ALL DSP COR PSAa PSDa OUR NOR ONL UNI COM NAV\"';
	}
}
EOF
sudo ln -s $proj_location/nginx.conf /etc/nginx/sites-enabled/$proj_name
sudo rm /etc/nginx/sites-enabled/default
sudo service nginx restart
}
#---------Quiz about users variables-----------
	#TODO: Confirm\check that there is no environment exists
	#TODO: Confirm\check that there is no db or user exists
read_environment_exists
#read_environment_new
read_project_new
read_postgres_new

#-----------Configuring env section------------------
#configure_env
#-------Configuring PostgreSQL section---------------
configure_pgresql
#--------Django project creation section-------------
configure_django
#------------Gunicorn configuring section------------
configure_gunicorn
#---------------NGINX Configuring section------------
configure_nginx
#---------------------FIN?---------------------------
echo -e "${GREEN}[DONE!]${CLEAN}"
echo -e "${GREEN}[INFO]: ${ORANGE}Activate Django shell by command ${RED}source $env_location/bin/activate${CLEAN}"
echo -e "${GREEN}[INFO]: ${ORANGE}Edit your project nginx config here: $proj_location/nginx.conf${CLEAN}"
echo -e "${GREEN}[INFO]: ${ORANGE}You can run your app by launching ${RED}$proj_location/runproj.sh${CLEAN}"
exit 0
