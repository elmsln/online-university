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
echo "<VirtualHost *:80>" >> /etc/httpd/conf.d/publicize.conf
echo "    DocumentRoot /var/www/html/publicize" >> /etc/httpd/conf.d/publicize.conf
echo "    ServerName ${3}" >> /etc/httpd/conf.d/publicize.conf
echo "    ServerAlias www.${3}" >> /etc/httpd/conf.d/publicize.conf
echo "</VirtualHost>" >> /etc/httpd/conf.d/publicize.conf
echo "<Directory /var/www/html/publicize>" >> /etc/httpd/conf.d/publicize.conf
echo "    AllowOverride all" >> /etc/httpd/conf.d/publicize.conf
echo "    Order allow,deny" >> /etc/httpd/conf.d/publicize.conf
echo "    allow from all" >> /etc/httpd/conf.d/publicize.conf
echo "</Directory>" >> /etc/httpd/conf.d/publicize.conf

# clean up and enjoy!
sudo /etc/init.d/httpd restart
sudo /etc/init.d/mysqld restart

# clear caches and cron things
drush @elmsln cc all --y
drush @elmsln cron --y
# seed entity caches at least
drush @elmsln ecl --y
# same but for publicize
drush cc all --y
drush cron --y
# seed entity caches at least
drush ecl --y
# @todo enable bakery for SSO everywhere

# # @todo figure out how to automatically install learning locker via this method

# @todo figure out how to automatically install piwik via this method
