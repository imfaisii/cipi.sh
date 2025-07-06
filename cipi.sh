#!/bin/bash

#################################################### CONFIGURATION ###
BUILD=202412010
PASS=$(openssl rand -base64 32|sha256sum|base64|head -c 32| tr '[:upper:]' '[:lower:]')
DBPASS=$(openssl rand -base64 24|sha256sum|base64|head -c 32| tr '[:upper:]' '[:lower:]')
SERVERID=$(openssl rand -base64 12|sha256sum|base64|head -c 32| tr '[:upper:]' '[:lower:]')
REPO=andreapollastri/cipi
if [ -z "$1" ]; then
    BRANCH=latest
else
    BRANCH=$1
fi

# Detect Ubuntu version
UBUNTU_VERSION=$(lsb_release -rs)
UBUNTU_CODENAME=$(lsb_release -cs)

####################################################   CLI TOOLS   ###
reset=$(tput sgr0)
bold=$(tput bold)
underline=$(tput smul)
black=$(tput setaf 0)
white=$(tput setaf 7)
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
blue=$(tput setaf 4)
purple=$(tput setaf 5)
bgblack=$(tput setab 0)
bgwhite=$(tput setab 7)
bgred=$(tput setab 1)
bggreen=$(tput setab 2)
bgyellow=$(tput setab 4)
bgblue=$(tput setab 4)
bgpurple=$(tput setab 5)

#################################################### CIPI SETUP ######

# LOGO
clear
echo "${green}${bold}"
echo ""
echo " ██████ ██ ██████  ██" 
echo "██      ██ ██   ██ ██" 
echo "██      ██ ██████  ██" 
echo "██      ██ ██      ██" 
echo " ██████ ██ ██      ██" 
echo ""
echo "Installation has been started... Hold on!"
echo "Ubuntu Version: $UBUNTU_VERSION ($UBUNTU_CODENAME)"
echo "${reset}"
sleep 3s

# OS CHECK
clear
clear
echo "${bggreen}${black}${bold}"
echo "OS check..."
echo "Detected Ubuntu $UBUNTU_VERSION ($UBUNTU_CODENAME)"
echo "${reset}"
sleep 1s

ID=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"')
VERSION=$(grep -oP '(?<=^VERSION_ID=).+' /etc/os-release | tr -d '"')

# Check if Ubuntu version is supported
if [[ "$ID" != "ubuntu" ]]; then
    echo "${bgred}${white}${bold}"
    echo "This script is designed for Ubuntu only."
    echo "${reset}"
    exit 1
fi

# ROOT CHECK
clear
clear
echo "${bggreen}${black}${bold}"
echo "Permission check..."
echo "${reset}"
sleep 1s

if [ "$(id -u)" = "0" ]; then
    clear
else
    clear
    echo "${bgred}${white}${bold}"
    echo "You have to run Cipi as root. (In AWS use 'sudo -s')"
    echo "${reset}"
    exit 1
fi

# BASIC SETUP
clear
clear
echo "${bggreen}${black}${bold}"
echo "Base setup..."
echo "${reset}"
sleep 1s

# Update package lists and install essential packages
sudo apt-get update
sudo apt-get -y install software-properties-common curl wget nano vim rpl sed zip unzip openssl expect dirmngr apt-transport-https lsb-release ca-certificates dnsutils dos2unix zsh htop ffmpeg gnupg2

# GET IP
clear
clear
echo "${bggreen}${black}${bold}"
echo "Getting IP..."
echo "${reset}"
sleep 1s

IP=$(curl -s https://checkip.amazonaws.com)

# MOTD WELCOME MESSAGE
clear
echo "${bggreen}${black}${bold}"
echo "Motd settings..."
echo "${reset}"
sleep 1s

WELCOME=/etc/motd
sudo touch $WELCOME
sudo cat > "$WELCOME" <<EOF

 ██████ ██ ██████  ██ 
██      ██ ██   ██ ██ 
██      ██ ██████  ██ 
██      ██ ██      ██
 ██████ ██ ██      ██

With great power comes great responsibility...

EOF

# SWAP
clear
echo "${bggreen}${black}${bold}"
echo "Memory SWAP..."
echo "${reset}"
sleep 1s

sudo /bin/dd if=/dev/zero of=/var/swap.1 bs=1M count=1024
sudo /sbin/mkswap /var/swap.1
sudo /sbin/swapon /var/swap.1

# ALIAS
clear
echo "${bggreen}${black}${bold}"
echo "Custom CLI configuration..."
echo "${reset}"
sleep 1s

shopt -s expand_aliases
alias ll='ls -alF'

# CIPI DIRS
clear
echo "${bggreen}${black}${bold}"
echo "Cipi directories..."
echo "${reset}"
sleep 1s

sudo mkdir -p /etc/cipi/
sudo chmod o-r /etc/cipi
sudo mkdir -p /var/cipi/
sudo chmod o-r /var/cipi

# USER
clear
echo "${bggreen}${black}${bold}"
echo "Cipi root user..."
echo "${reset}"
sleep 1s

sudo pam-auth-update --package
sudo mount -o remount,rw /
sudo chmod 640 /etc/shadow
sudo useradd -m -s /bin/bash cipi
echo "cipi:$PASS"|sudo chpasswd
sudo usermod -aG sudo cipi

# NGINX
clear
echo "${bggreen}${black}${bold}"
echo "nginx setup..."
echo "${reset}"
sleep 1s

sudo apt-get -y install nginx-core
sudo systemctl start nginx.service
sudo rpl -i -w "http {" "http { limit_req_zone \$binary_remote_addr zone=one:10m rate=1r/s; fastcgi_read_timeout 300;" /etc/nginx/nginx.conf
sudo systemctl enable nginx.service

# FIREWALL
clear
echo "${bggreen}${black}${bold}"
echo "fail2ban setup..."
echo "${reset}"
sleep 1s

sudo apt-get -y install fail2ban
JAIL=/etc/fail2ban/jail.local
sudo rm -f $JAIL
sudo touch $JAIL
sudo cat > "$JAIL" <<EOF
[DEFAULT]
bantime = 3600
banaction = iptables-multiport
[sshd]
enabled = true
logpath  = /var/log/auth.log
EOF
sudo systemctl restart fail2ban
sudo ufw --force enable
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
sudo ufw allow "Nginx Full"

# PHP
clear
echo "${bggreen}${black}${bold}"
echo "PHP setup..."
echo "${reset}"
sleep 1s

# Add Ondřej Surý's PPA for PHP
sudo add-apt-repository -y ppa:ondrej/php
sudo apt-get update

# Function to install PHP version with all extensions
install_php_version() {
    local version=$1
    echo "Installing PHP $version..."
    
    sudo apt-get -y install php$version-fpm
    sudo apt-get -y install php$version-common
    sudo apt-get -y install php$version-curl
    sudo apt-get -y install php$version-openssl
    sudo apt-get -y install php$version-bcmath
    sudo apt-get -y install php$version-mbstring
    sudo apt-get -y install php$version-tokenizer
    sudo apt-get -y install php$version-mysql
    sudo apt-get -y install php$version-sqlite3
    sudo apt-get -y install php$version-pgsql
    sudo apt-get -y install php$version-redis
    sudo apt-get -y install php$version-memcached
    sudo apt-get -y install php$version-json
    sudo apt-get -y install php$version-zip
    sudo apt-get -y install php$version-xml
    sudo apt-get -y install php$version-soap
    sudo apt-get -y install php$version-gd
    sudo apt-get -y install php$version-imagick
    sudo apt-get -y install php$version-fileinfo
    sudo apt-get -y install php$version-imap
    sudo apt-get -y install php$version-cli
    
    # Create PHP configuration
    PHPINI=/etc/php/$version/fpm/conf.d/cipi.ini
    sudo touch $PHPINI
    sudo cat > "$PHPINI" <<EOF
memory_limit = 256M
upload_max_filesize = 256M
post_max_size = 256M
max_execution_time = 180
max_input_time = 180
EOF
    sudo systemctl restart php$version-fpm
}

# Install PHP versions (7.4 is EOL but keeping for compatibility)
install_php_version "7.4"
install_php_version "8.0"
install_php_version "8.1"
install_php_version "8.2"
install_php_version "8.3"
install_php_version "8.4"

# PHP EXTRA
sudo apt-get -y install php-dev php-pear

# PHP CLI - Set default to PHP 8.4
clear
echo "${bggreen}${black}${bold}"
echo "PHP CLI configuration..."
echo "${reset}"
sleep 1s

sudo update-alternatives --set php /usr/bin/php8.4

# COMPOSER
clear
echo "${bggreen}${black}${bold}"
echo "Composer setup..."
echo "${reset}"
sleep 1s

php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php composer-setup.php --no-interaction
php -r "unlink('composer-setup.php');"
mv composer.phar /usr/local/bin/composer
composer config --global repo.packagist composer https://packagist.org --no-interaction

# GIT
clear
echo "${bggreen}${black}${bold}"
echo "GIT setup..."
echo "${reset}"
sleep 1s

sudo apt-get -y install git
sudo ssh-keygen -t rsa -C "git@github.com" -f /etc/cipi/github -q -P ""

# SUPERVISOR
clear
echo "${bggreen}${black}${bold}"
echo "Supervisor setup..."
echo "${reset}"
sleep 1s

sudo apt-get -y install supervisor
service supervisor restart

# DEFAULT VHOST
clear
echo "${bggreen}${black}${bold}"
echo "Default vhost..."
echo "${reset}"
sleep 1s

NGINX=/etc/nginx/sites-available/default
if test -f "$NGINX"; then
    sudo rm -f $NGINX
fi
sudo touch $NGINX
sudo cat > "$NGINX" <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    root /var/www/html/public;
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Content-Type-Options "nosniff";
    client_body_timeout 10s;
    client_header_timeout 10s;
    client_max_body_size 256M;
    index index.html index.php;
    charset utf-8;
    server_tokens off;
    location / {
        try_files   \$uri     \$uri/  /index.php?\$query_string;
    }
    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }
    error_page 404 /index.php;
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.4-fpm.sock;
    }
    location ~ /\.(?!well-known).* {
        deny all;
    }
}
EOF
sudo mkdir -p /etc/nginx/cipi/
sudo systemctl restart nginx.service

# MYSQL
clear
echo "${bggreen}${black}${bold}"
echo "MySQL setup..."
echo "${reset}"
sleep 1s

sudo apt-get install -y mysql-server
SECURE_MYSQL=$(expect -c "
set timeout 10
spawn mysql_secure_installation
expect \"Press y|Y for Yes, any other key for No:\"
send \"n\r\"
expect \"New password:\"
send \"$DBPASS\r\"
expect \"Re-enter new password:\"
send \"$DBPASS\r\"
expect \"Remove anonymous users? (Press y|Y for Yes, any other key for No)\"
send \"y\r\"
expect \"Disallow root login remotely? (Press y|Y for Yes, any other key for No)\"
send \"n\r\"
expect \"Remove test database and access to it? (Press y|Y for Yes, any other key for No)\"
send \"y\r\"
expect \"Reload privilege tables now? (Press y|Y for Yes, any other key for No) \"
send \"y\r\"
expect eof
")
echo "$SECURE_MYSQL"
/usr/bin/mysql -u root -p$DBPASS <<EOF
use mysql;
CREATE USER 'cipi'@'%' IDENTIFIED WITH mysql_native_password BY '$DBPASS';
GRANT ALL PRIVILEGES ON *.* TO 'cipi'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

# REDIS
clear
echo "${bggreen}${black}${bold}"
echo "Redis setup..."
echo "${reset}"
sleep 1s

sudo apt install -y redis-server
sudo rpl -i -w "supervised no" "supervised systemd" /etc/redis/redis.conf
sudo systemctl restart redis.service

# LET'S ENCRYPT
clear
echo "${bggreen}${black}${bold}"
echo "Let's Encrypt setup..."
echo "${reset}"
sleep 1s

sudo apt-get install -y certbot
sudo apt-get install -y python3-certbot-nginx

# NODE
clear
echo "${bggreen}${black}${bold}"
echo "Node/npm setup..."
echo "${reset}"
sleep 1s

# Install Node.js 20.x (LTS)
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x $UBUNTU_CODENAME main" | sudo tee /etc/apt/sources.list.d/nodesource.list
sudo apt-get update
sudo apt -y install nodejs
sudo apt -y install npm

# PANEL INSTALLATION
clear
echo "${bggreen}${black}${bold}"
echo "Panel installation..."
echo "${reset}"
sleep 1s

/usr/bin/mysql -u root -p$DBPASS <<EOF
CREATE DATABASE IF NOT EXISTS cipi;
EOF
clear
sudo rm -rf /var/www/html
cd /var/www && git clone https://github.com/$REPO.git html
cd /var/www/html && git pull
cd /var/www/html && git checkout $BRANCH
cd /var/www/html && git pull
cd /var/www/html && sudo rm -f .env
cd /var/www/html && sudo cp .env.example .env
cd /var/www/html && php artisan key:generate
sudo rpl -i -w "DB_USERNAME=dbuser" "DB_USERNAME=cipi" /var/www/html/.env
sudo rpl -i -w "DB_PASSWORD=dbpass" "DB_PASSWORD=$DBPASS" /var/www/html/.env
sudo rpl -i -w "DB_DATABASE=dbname" "DB_DATABASE=cipi" /var/www/html/.env
sudo rpl -i -w "APP_URL=http://localhost" "APP_URL=http://$IP" /var/www/html/.env
sudo rpl -i -w "APP_ENV=local" "APP_ENV=production" /var/www/html/.env
sudo rpl -i -w "CIPISERVERID" $SERVERID /var/www/html/database/seeders/DatabaseSeeder.php
sudo rpl -i -w "CIPIIP" $IP /var/www/html/database/seeders/DatabaseSeeder.php
sudo rpl -i -w "CIPIPASS" $PASS /var/www/html/database/seeders/DatabaseSeeder.php
sudo rpl -i -w "CIPIDB" $DBPASS /var/www/html/database/seeders/DatabaseSeeder.php
sudo chmod -R o+w /var/www/html/storage
sudo chmod -R 777 /var/www/html/storage
sudo chmod -R o+w /var/www/html/bootstrap/cache
sudo chmod -R 777 /var/www/html/bootstrap/cache
cd /var/www/html && composer update --no-interaction
cd /var/www/html && php artisan key:generate
cd /var/www/html && php artisan cache:clear
cd /var/www/html && php artisan storage:link
cd /var/www/html && php artisan view:cache
cd /var/www/html && php artisan cipi:activesetupcount
CIPIBULD=/var/www/html/public/build_$SERVERID.php
sudo touch $CIPIBULD
sudo cat > $CIPIBULD <<EOF
$BUILD
EOF
CIPIPING=/var/www/html/public/ping_$SERVERID.php
sudo touch $CIPIPING
sudo cat > $CIPIPING <<EOF
Up
EOF
PUBKEYGH=/var/www/html/public/ghkey_$SERVERID.php
sudo touch $PUBKEYGH
sudo cat > $PUBKEYGH <<EOF
<?php
echo exec("cat /etc/cipi/github.pub");
EOF
cd /var/www/html && php artisan migrate --seed --force
cd /var/www/html && php artisan config:cache
sudo chmod -R o+w /var/www/html/storage
sudo chmod -R 775 /var/www/html/storage
sudo chmod -R o+w /var/www/html/bootstrap/cache
sudo chmod -R 775 /var/www/html/bootstrap/cache
sudo chown -R www-data:cipi /var/www/html

# LAST STEPS
clear
echo "${bggreen}${black}${bold}"
echo "Last steps..."
echo "${reset}"
sleep 1s

sudo chown www-data:cipi -R /var/www/html
sudo chmod -R 750 /var/www/html
sudo echo 'DefaultStartLimitIntervalSec=1s' >> /usr/lib/systemd/system/user@.service
sudo echo 'DefaultStartLimitBurst=50' >> /usr/lib/systemd/system/user@.service
sudo echo 'StartLimitBurst=0' >> /usr/lib/systemd/system/user@.service
sudo systemctl daemon-reload

TASK=/etc/cron.d/cipi.crontab
touch $TASK
cat > "$TASK" <<EOF
10 4 * * 7 certbot renew --nginx --non-interactive --post-hook "systemctl restart nginx.service"
20 4 * * 7 apt-get -y update
40 4 * * 7 DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical sudo apt-get -q -y -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" dist-upgrade
20 5 * * 7 apt-get clean && apt-get autoclean
50 5 * * * echo 3 > /proc/sys/vm/drop_caches && swapoff -a && swapon -a
* * * * * cd /var/www/html && php artisan schedule:run >> /dev/null 2>&1
5 2 * * * cd /var/www/html/utility/cipi-update && sh run.sh >> /dev/null 2>&1
EOF
crontab $TASK
sudo systemctl restart nginx.service
sudo rpl -i -w "#PasswordAuthentication" "PasswordAuthentication" /etc/ssh/sshd_config
sudo rpl -i -w "# PasswordAuthentication" "PasswordAuthentication" /etc/ssh/sshd_config
sudo rpl -i -w "PasswordAuthentication no" "PasswordAuthentication yes" /etc/ssh/sshd_config
sudo rpl -i -w "PermitRootLogin yes" "PermitRootLogin no" /etc/ssh/sshd_config
sudo service sshd restart
TASK=/etc/supervisor/conf.d/cipi.conf
touch $TASK
cat > "$TASK" <<EOF
[program:cipi-worker]
process_name=%(program_name)s_%(process_num)02d
command=php /var/www/html/artisan queue:work --sleep=3 --tries=3 --max-time=3600
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
user=cipi
numprocs=8
redirect_stderr=true
stdout_logfile=/var/www/worker.log
stopwaitsecs=3600
EOF
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl start all
sudo service supervisor restart

# COMPLETE
clear
echo "${bggreen}${black}${bold}"
echo "Cipi installation has been completed..."
echo "${reset}"
sleep 1s

# SETUP COMPLETE MESSAGE
clear
echo "***********************************************************"
echo "                    SETUP COMPLETE"
echo "***********************************************************"
echo ""
echo " Ubuntu Version: $UBUNTU_VERSION ($UBUNTU_CODENAME)"
echo " PHP Versions: 7.4, 8.0, 8.1, 8.2, 8.3, 8.4 (Default: 8.4)"
echo " Node.js Version: $(node --version)"
echo ""
echo " SSH root user: cipi"
echo " SSH root pass: $PASS"
echo " MySQL root user: cipi"
echo " MySQL root pass: $DBPASS"
echo ""
echo " To manage your server visit: http://$IP"
echo " and click on 'dashboard' button."
echo " Default credentials are: administrator / 12345678"
echo ""
echo "***********************************************************"
echo "          DO NOT LOSE AND KEEP SAFE THIS DATA"
echo "***********************************************************"
