#!/bin/bash
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

read -p "Input new username: " user_name
read -p "Input new password: " user_pass


cat << EOF >> /etc/ppp/chap-secrets
"${user_name}" l2tpserver "${user_pass}" *
EOF

systemctl enable xl2tpd
systemctl restart xl2tpd
