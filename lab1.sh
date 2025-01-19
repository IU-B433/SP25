#!/bin/bash
# update the apt package index
sudo apt update
# install Apache2, MySQL
sudo apt install apache2 net-tools mysql-server -y
# install PHP
sudo apt install php libapache2-mod-php php-mysql -y
# allow Apache2 through the firewall
sudo ufw allow in "Apache"
# enable the firewall
sudo ufw enable
