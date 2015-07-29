#!/bin/bash
# a script to install server dependencies

# provide messaging colors for output to console
txtbld=$(tput bold)             # Bold
bldgrn=$(tput setaf 2) #  green
bldred=${txtbld}$(tput setaf 1) #  red
txtreset=$(tput sgr0)
elmslnecho(){
  echo "${bldgrn}$1${txtreset}"
}
elmslnwarn(){
  echo "${bldred}$1${txtreset}"
}
# Define seconds timestamp
timestamp(){
  date +"%s"
}
start="$(timestamp)"
# run the 1-line installer for elmsln
yes | yum -y install git && git clone https://github.com/elmsln/elmsln.git /var/www/elmsln && bash /var/www/elmsln/scripts/install/handsfree/centos/centos-install.sh $1 $2 $3 $4 $5 $6
cd $HOME && source .bashrc
# get things in place so that we can run mysql / php 5.5
rpm -Uvh http://download.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm
rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-6.rpm
yes | yum -y --enablerepo=remi install mysql mysql-server
/etc/init.d/mysqld restart
yes | yum -y --enablerepo=remi,remi-php55 install httpd php php-common
yes | yum -y --enablerepo=remi,remi-php55 install php-pecl-apc php-cli php-pear php-pdo php-mysqlnd php-pgsql php-pecl-mongo php-sqlite php-pecl-memcache php-pecl-memcached php-gd php-mbstring php-mcrypt php-xml
/etc/init.d/httpd restart
# clean up upload progress not being needed now
rm /etc/php.d/uploadprogress.ini
# optimize apc
echo "" >> /etc/php.d/apcu.ini
echo "apc.rfc1867=1" >> /etc/php.d/apcu.ini
echo "apc.rfc1867_prefix=upload_" >> /etc/php.d/apcu.ini
echo "apc.rfc1867_name=APC_UPLOAD_PROGRESS" >> /etc/php.d/apcu.ini
echo "apc.rfc1867_freq=0" >> /etc/php.d/apcu.ini
echo "apc.rfc1867_ttl=3600" >> /etc/php.d/apcu.ini
# optimize opcodecache for php 5.5
echo "opcache.memory_consumption=128" >> /etc/php.ini
echo "opcache.max_accelerated_files=10000" >> /etc/php.ini
echo "opcache.max_wasted_percentage=10" >> /etc/php.ini
echo "opcache.validate_timestamps=0" >> /etc/php.ini
echo "opcache.fast_shutdown=1" >> /etc/php.ini

# setup publicize for the homepage system to market this university
git clone --branch 7.x-1.x https://github.com/drupalprojects/publicize.git /var/www/html/publicize
cd /var/www/html/publicize
# remove everything except the make files from the repo
# we then clone it back into itself basically
rm -rf modules
rm -rf themes
rm -rf .git
find . -type f -not -name '*.make*' | xargs rm
# build off the make files
drush make local.make.example --y
# clean up make file now that we built
rm *.make*
# pull our newly created stuff into scope
source /var/www/elmsln/config/scripts/drush-create-site/config.cfg
drush si publicize -y --db-url=mysql://root@localhost/openulmus_org  --db-su=$dbsu --db-su-pw=$dbsupw --account-name=admin --account-mail=btopro@openulmus.org install_configure_form.update_status_module='array(FALSE,FALSE)' install_configure_form.site_default_country=US --y
drush en publicize_defaults --y
drush en publicize_content --y
cd sites/all/modules
# symlink ELMSLN to Publicize... this will allow insanity to ensure
# publicize will soon be able to act like an authority distribution of elmsln
# even though it's not actually running inside the elmsln deployment
ln -s /var/www/elmsln/config/shared/drupal-7.x/modules elmsln_config_modules
ln -s /var/www/elmsln/core/dslmcode/shared/drupal-7.x/modules/elmsln_contrib elmsln_modules
cd ../../..
# enable the connection credentials keychain from ELMSLN in publicize... oh no he didn't
drush en $1_$2_settings --y
# prime authority as if it is one
drush cook elmsln_authority_setup --y
# setup the ability for this to have its course nodes remote updated
drush en cis_course_authority --y
# account for STUPID caching issue of menu name
drush sqlq "UPDATE block SET title='<none>' WHERE module='menu_block'"

# establish domain file for this
touch /etc/httpd/conf.d/publicize.conf
echo "#ELMSLN domains.conf recommendations" >> /etc/httpd/conf.d/publicize.conf
echo "NameVirtualHost *:80" >> /etc/httpd/conf.d/publicize.conf
echo "<VirtualHost *:80>" >> /etc/httpd/conf.d/publicize.conf
echo "    DocumentRoot /var/www/html/publicize" >> /etc/httpd/conf.d/publicize.conf
echo "    ServerName online.YOURUNIT.edu" >> /etc/httpd/conf.d/publicize.conf
echo "    ServerAlias DATA.online.SERVICEYOURUNIT.edu" >> /etc/httpd/conf.d/publicize.conf
echo "</VirtualHost>" >> /etc/httpd/conf.d/publicize.conf
echo "<Directory /var/www/html/publicize>" >> /etc/httpd/conf.d/publicize.conf
echo "    AllowOverride all" >> /etc/httpd/conf.d/publicize.conf
echo "    Order allow,deny" >> /etc/httpd/conf.d/publicize.conf
echo "    allow from all" >> /etc/httpd/conf.d/publicize.conf
echo "</Directory>" >> /etc/httpd/conf.d/publicize.conf

# @todo figure out how to automatically install learning locker via this method

# @todo figure out how to automatically install piwik via this method

# clean up and enjoy!
sudo /etc/init.d/httpd restart
sudo /etc/init.d/mysqld restart

