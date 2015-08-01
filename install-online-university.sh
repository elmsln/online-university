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

#READ THIS >>> 
#This assumes that you have httpd installed.
rpm --nosignature -i https://repo.varnish-cache.org/redhat/varnish-3.0.el6.rpm
yum install varnish -y

sed -i 's/VARNISH_LISTEN_PORT=6081/VARNISH_LISTEN_PORT=80/g' /etc/sysconfig/varnish
sed -i 's/Listen 80/Listen 8080/g' /etc/httpd/conf/httpd.conf
cat /dev/null > /etc/varnish/default.vcl

cat << EOF > /etc/varnish/default.vcl
backend default {
.host = "127.0.0.1";
.port = "8080";
.connect_timeout = 600s;
.first_byte_timeout = 600s;
.between_bytes_timeout = 600s;
.max_connections = 800;
}

# allow purge requests from localhost -djb44
acl purge {
  "localhost";
  "127.0.0.1";
}

sub vcl_recv {

#purge
  if (req.request == "PURGE") {
  if (!client.ip ~ purge) {
  error 405 "Not allowed.";
  }
  return (lookup);
  }


# Now we use the different backends based on the uri of the site. Again, this is
# not needed if you're running a single site on a server
#if (req.http.host ~ "sitea.com$") {
#  set req.backend = sitea;
#} else if (req.http.host ~ "siteb.com$") {
#set req.backend = siteb;
#} else {
# Use the default backend for all other requests
set req.backend = default;
#}

  # Add a unique header containing the client address
  remove req.http.X-Forwarded-For;
  set    req.http.X-Forwarded-For = client.ip;

  # Get rid of progress.js query params
  if (req.url ~ "^/misc/progress\.js\?[0-9]+$") {
    set req.url = "/misc/progress.js";
  }

  # Pipe these paths directly to Apache for streaming.
  if (req.url ~ "^/admin/content/backup_migrate/export") {
    return (pipe);
 }

# If global redirect is on
# if (req.url ~ "node\?page=[0-9]+$") {
#  set req.url = regsub(req.url, "node(\?page=[0-9]+$)", "\1");
#  return (lookup);
# }

# Do not cache these paths.
  if (req.url ~ "^/status\.php$" ||
      req.url ~ "^/update\.php" ||
      req.url ~ "^/install\.php" ||
      req.url ~ "^/admin" ||
      req.url ~ "^/admin/.*$" ||
      req.url ~ "^/user" ||
      req.url ~ "^/user/.*$" ||
      req.url ~ "^/users/.*$" ||
      req.url ~ "^/info/.*$" ||
      req.url ~ "^/flag/.*$" ||
      req.url ~ "^.*/ajax/.*$" ||
      req.url ~ "^.*/ahah/.*$") {
      return (pass);
  }

  # Do not allow outside access to cron.php or install.php
  if (req.url ~ "^/(cron|install)\.php$" && !client.ip ~ internal) {
    # Have Varnish throw the error directly.
    error 404 "Page not found.";
    # Use a custom error page that you've defined in Drupal at the path "404".
    # set req.url = "/404";
  }

  # Always cache the following file types for all users.
  if (req.url ~ "(?i)\.(png|gif|jpeg|jpg|ico|swf|css|js|html|htm)(\?[a-z0-9]+)?$") {
    unset req.http.Cookie;
  }

  # Remove all cookies that Drupal doesn't need to know about. ANY remaining
  # cookie will cause the request to pass-through to Apache. For the most part
  # we always set the NO_CACHE cookie after any POST request, disabling the
  # Varnish cache temporarily. The session cookie allows all authenticated users
  # to pass through as long as they're logged in.
  ## See: http://drupal.stackexchange.com/questions/53467/varnish-problem-user-log...  # 1. Append a semi-colon to the front of the cookie string.
  # 2. Remove all spaces that appear after semi-colons.
  # 3. Match the cookies we want to keep, adding the space we removed
  # previously, back. (\1) is first matching group in the regsuball.
  # 4. Remove all other cookies, identifying them by the fact that they have
  # no space after the preceding semi-colon.
  # 5. Remove all spaces and semi-colons from the beginning and end of the
  # cookie string.
  if (req.http.Cookie) {
    set req.http.Cookie = ";" + req.http.Cookie;
    set req.http.Cookie = regsuball(req.http.Cookie, "; +", ";");
    set req.http.Cookie = regsuball(req.http.Cookie, ";(S{1,2}ESS[a-z0-9]+|NO_CACHE)=", "; \1=");
    set req.http.Cookie = regsuball(req.http.Cookie, ";[^ ][^;]*", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "^[; ]+|[; ]+$", "");

    if (req.http.Cookie == "") {
      # If there are no remaining cookies, remove the cookie header. If there
      # aren't any cookie headers, Varnish's default behavior will be to cache
      # the page.
      unset req.http.Cookie;
    }
    else {
      # If there is any cookies left (a session or NO_CACHE cookie), do not
      # cache the page. Pass it on to Apache directly.
      return (pass);
    }
  }

    # Remove the "has_js" cookie
    set req.http.Cookie = regsuball(req.http.Cookie, "has_js=[^;]+(; )?", "");

    # Remove the "Drupal.toolbar.collapsed" cookie
    set req.http.Cookie = regsuball(req.http.Cookie, "Drupal.toolbar.collapsed=[^;]+(; )?", "");

    # Remove any Google Analytics based cookies
    set req.http.Cookie = regsuball(req.http.Cookie, "__utm.=[^;]+(; )?", "");

    # Remove the Quant Capital cookies (added by some plugin, all __qca)
    set req.http.Cookie = regsuball(req.http.Cookie, "__qc.=[^;]+(; )?", "");

    # Are there cookies left with only spaces or that are empty?
    if (req.http.cookie ~ "^ *$") {
        unset req.http.cookie;
    }

    # Cache static content unique to the theme (so no user uploaded images)
    if (req.url ~ "^/themes/" && req.url ~ ".(css|js|png|gif|jp(e)?g)") {
        unset req.http.cookie;
    }
}


sub vcl_hit {
  if (req.request == "PURGE") {
    purge;
    error 200 "Purged.";
  }
}

sub vcl_miss {
        if (req.request == "PURGE") {
                purge;
                error 200 "Purged.";
        }
}
EOF

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
