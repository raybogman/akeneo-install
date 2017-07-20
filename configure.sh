#!/usr/bin/env bash
localedef -c -f UTF-8 -i en_US en_US.UTF-8
export DEBIAN_FRONTEND=noninteractive

WWW_USER=${WWW_USER-"www-data"}
WWW_GROUP=${WWW_GROUP-"www-data"}
UPLOAD_LIMIT=${UPLOAD_LIMIT-"256"}

# configure php cli
sed -i -e "s/;date.timezone\s=/date.timezone = UTC/g" /etc/php/7.0/cli/php.ini
sed -i -e "s/short_open_tag\s=\s*.*/short_open_tag = Off/g" /etc/php/7.0/cli/php.ini
sed -i -e "s/memory_limit\s=\s.*/memory_limit = -1/g" /etc/php/7.0/cli/php.ini
sed -i -e "s/max_execution_time\s=\s.*/max_execution_time = 0/g" /etc/php/7.0/cli/php.ini

# configure php fpm
sed -i -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" /etc/php/7.0/fpm/php.ini
sed -i -e "s/;date.timezone\s=/date.timezone = UTC/g" /etc/php/7.0/fpm/php.ini
sed -i -e "s/short_open_tag\s=\s*.*/short_open_tag = Off/g" /etc/php/7.0/fpm/php.ini

sed -i -e "s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 1G/g" /etc/php/7.0/fpm/php.ini
sed -i -e "s/memory_limit\s=\s.*/memory_limit = -1/g" /etc/php/7.0/fpm/php.ini
sed -i -e "s/post_max_size\s*=\s*8M/post_max_size = 1G/g" /etc/php/7.0/fpm/php.ini
sed -i -e "s/max_execution_time\s=\s.*/max_execution_time = 300/g" /etc/php/7.0/fpm/php.ini

# php-fpm config
sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php/7.0/fpm/php-fpm.conf
sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" /etc/php/7.0/fpm/pool.d/www.conf
sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" /etc/php/7.0/fpm/pool.d/www.conf
sed -i -e "s/listen\s=\s\/run\/php\/php7.0-fpm.sock/listen = \/var\/run\/php-fpm.sock/g" /etc/php/7.0/fpm/pool.d/www.conf

# Fix old style for comments
find /etc/php/7.0/cli/conf.d/ -name "*.ini" -exec sed -i -re 's/^(\s*)#(.*)/\1;\2/g' {} \;

# Configure nginx
rm /etc/nginx/sites-enabled/default
rm -rf /var/www

cp nginx.conf /etc/nginx
cp bap.conf /etc/nginx/sites-enabled

/usr/sbin/service nginx restart

# Create data folder
mkdir -p /srv/app-data
mkdir -p /var/www

mkdir -p /var/run/php
ln -s /usr/sbin/php-fpm7.0 /usr/sbin/php-fpm

chown ${WWW_USER}:${WWW_GROUP} /srv/app-data
chown ${WWW_USER}:${WWW_GROUP} /var/www

/usr/sbin/service php7.0-fpm restart

#cron let's Encrypt
(crontab -l 2>/dev/null; echo "30 2 * * 1 /usr/bin/letsencrypt renew >> /var/log/le-renew.log") | crontab -
(crontab -l 2>/dev/null; echo "35 2 * * 1 /bin/systemctl reload nginx") | crontab -

#download Akeneo

#sample
wget http://download.akeneo.com/pim-community-standard-v1.7-latest-icecat.tar.gz
#clean
#wget http://download.akeneo.com/pim-community-standard-v1.7-latest.tar.gz

tar -xvzf pim-community-standard-v1.7-latest-icecat.tar.gz -C /var/www
rm pim-community-standard*

mv /var/www/pim-community-standard/* /var/www
rm -rf /var/www/pim-community-standard

cd /var/www
composer.phar install --optimize-autoloader --prefer-dist
php app/console cache:clear --env=prod
php app/console pim:install --env=prod

chown -R www-data:www-data /var/www

#apt-get -qq clean
#rm -rf /var/lib/apt/lists/*
