#!/bin/bash
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

read -p "Input new Secret: " user_pass


cat << EOF > /etc/ipsec.secrets
%any %any : PSK "${user_pass}"
EOF

systemctl enable strongswan-starter
systemctl restart strongswan-starter
