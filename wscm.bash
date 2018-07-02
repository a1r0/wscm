#!/bin/bash

# Author: Trader418 - https://trader418.me - https://github.com/trader418
# License: MIT
# Version: 0
# Not ready for production - Work In Progress
function usage {
  printf "\nUsage:   wscm.bash [--setup] [--help] [--create domain.com] [--create-wordpress domain.com] \n"
  printf "
-h     |  --help                          You're looking at it!
-s     |  --setup                         Setup the initial stack
-c     |  --create domain.com             Create a site
-cw    |  --create-wordpress domain.com   Create a WordPress site
-d     |  --delete domain.com             Delete a site and the associated database
-b     |  --backup domain.com             Backup a site + MySQL database to /opt/backup
-php72 |  --php72  domain.com             Change site to PHP 7.2
-php71 |  --php71  domain.com             Change site to PHP 7.1
-php70 |  --php70  domain.com             Change site to PHP 7.0
"
  exit
}

function backup {
  if [ ! -d "/var/www/$site" ]; then
    echo "error, site not found!"
    exit
  fi
  if [ ! -d "/opt/backup/$site" ]; then
    mkdir -p /opt/backup/$site
  fi
  date=$(date +"%d-%b-%Y")
  source /var/www/$site/db.bash
  mysqldump --user=$dbuser --password=$dbpass --host=localhost $dbname > /opt/backup/$site/$dbname-$date.sql
  zip -r /opt/backup/$site/$site-$date.zip /var/www/$site/public_html
}

function setup {
  if [ -d "/var/www/" ]; then
    echo "Error You have already ran setup"
    exit
  fi
  mkdir /var/www/
  mkdir -p /opt/php/sources
  mkdir /opt/php/7.2
  mkdir /opt/php/7.1
  mkdir /opt/php/7.0
  mkdir /opt/php/5.6
  os=$(gawk -F= '/^NAME/{print $2}' /etc/os-release)
  os=${os/ /.}
  if [ $os = "\"Ubuntu\"" ]
    then
    echo "OS detected as Ubuntu."
	setupUbuntu
  fi
  if [ $os = "\"CentOS.Linux\"" ]
    then
    echo "OS detected as CentOS."
	setupCentos
  fi
  ln -s /opt/php/7.2/bin/php /usr/bin/php 
  wget -O /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && chmod +x /usr/local/bin/wp
  echo "Please register with Lets Encrypt for SSL..."
  certbot register
  echo "Finished, now you can create sites with --create domain.com"
  exit
}

function setupCentos {
  echo "Running yum update"
  yum update -y
  echo "Installing Packages... This may take a few minutes depending on your system."
  yum install wget -y
  yum install epel-release -y
  yum install nginx -y
  yum install zip -y
  yum groupinstall -y 'Development Tools'
  yum install libcurl-devel libxslt-devel glibc-utils.x86_64 libxslt libtool-ltdl-devel aspell-devel freetype-devel libpng-devel libjpeg-devel openssl-devel bzip2-devel libxml2-devel -y
  compilePHP
  echo "Confiugring Nginx..."
  mkdir /etc/nginx/common
  echo "
          location ~ \.php$ {
                include fastcgi.conf;
                fastcgi_pass unix:/run/php7.1-fpm.sock;
        }
  " >> /etc/nginx/common/php7.1.conf
  echo "
          location ~ \.php$ {
                include fastcgi.conf;
                fastcgi_pass unix:/run/php7.2-fpm.sock;
        }
  " >> /etc/nginx/common/php7.2.conf
  echo "
          location ~ \.php$ {
                include fastcgi.conf;
                fastcgi_pass unix:/run/php7.0-fpm.sock;
        }
  " >> /etc/nginx/common/php7.0.conf
  mkdir /etc/nginx/sites-available/
  mkdir /etc/nginx/sites-enabled/
  sed -i s/'include\ \/etc\/nginx\/conf\.d\/\*\.conf\;'/'include\ \/etc\/nginx\/sites\-enabled\/\*\;'/g /etc/nginx/nginx.conf
  systemctl start nginx
  systemctl enable nginx
  echo "# MariaDB 10.2 CentOS repository list - created 2018-04-07 14:49 UTC
# http://downloads.mariadb.org/mariadb/repositories/
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.2/centos7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1" >> /etc/yum.repos.d/MariaDB.repo
  yum install MariaDB-server MariaDB-client -y
  systemctl start mariadb
  systemctl enable mariadb
  password="$(< /dev/urandom tr -dc a-z | head -c${1:-15};echo;)"
  echo "rootpass=$password" >> /etc/mysql-nginx.bash
  mysql_secure_installation <<EOF

  y
  $password
  $password
  y
  y
  y
  y
EOF
  yum install certbot-nginx -y
  echo "...Complete"
}

function setupUbuntu {
  echo "Adding user nginx"
  adduser --system --no-create-home --shell /bin/false --group --disabled-login nginx
  echo "Running apt-get update"
  apt-get update -y > /dev/null
  echo "Installing Packages... This may take a few minutes depending on your system."
  apt-get install libcurl4-openssl-dev pkg-config libssl-dev libxml2-dev libbz2-dev libjpeg-turbo8-dev libpng-dev libfreetype6-dev libxslt-dev build-essential autoconf libzip-dev bison zip -y
  apt-get install nginx -y > /dev/null
  sed -i s/user\ www\-data\;/user\ nginx\;/g /etc/nginx/nginx.conf
  compilePHP
  echo "Confiugring Nginx..."
  mkdir /etc/nginx/common
  echo "
          location ~ \.php$ {
              fastcgi_pass unix:/run/php7.2-fpm.sock;
              include snippets/fastcgi-php.conf;
              fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
          }
  " >> /etc/nginx/common/php7.2.conf
  echo "
          location ~ \.php$ {
              fastcgi_pass unix:/run/php7.1-fpm.sock;
              include snippets/fastcgi-php.conf;
              fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
          }
  " >> /etc/nginx/common/php7.1.conf
  echo "
          location ~ \.php$ {
              fastcgi_pass unix:/run/php7.0-fpm.sock;
              include snippets/fastcgi-php.conf;
              fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
          }
  " >> /etc/nginx/common/php7.0.conf
  apt-get install software-properties-common -y > /dev/null
  add-apt-repository ppa:certbot/certbot -y
  apt-get update -y > /dev/null
  apt-get install python-certbot-nginx -y > /dev/null
  crontab -l | { cat; echo "30 12 1 * * certbot renew"; } | crontab -
  systemctl start nginx
  systemctl enable nginx
  echo "Installing mysql"
  password="$(< /dev/urandom tr -dc a-z | head -c${1:-15};echo;)"
  echo "rootpass=$password" >> /etc/mysql-nginx.bash
  apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8 -y
  add-apt-repository 'deb [arch=amd64,i386,ppc64el] http://mirrors.coreix.net/mariadb/repo/10.2/ubuntu xenial main' -y
  apt update -y
  apt install mariadb-server -y
  mysql_secure_installation <<EOF

  y
  $password
  $password
  y
  y
  y
  y
EOF
  echo "...Complete"
}

function compilePHP {
  echo "Downloading PHP sources, this may take a few minutes depending on your network connection"
  cd /opt/php/sources
  git clone https://github.com/php/php-src.git
  cp /opt/php/sources/php-src /opt/php/sources/7.2 -R
  cp /opt/php/sources/php-src /opt/php/sources/7.1 -R
  cp /opt/php/sources/php-src /opt/php/sources/7.0 -R
  cd /opt/php/sources/7.2
  git checkout tags/php-7.2.7
  cd /opt/php/sources/7.1
  git checkout tags/php-7.1.19
  cd /opt/php/sources/7.0
  git checkout tags/php-7.0.30
  cd /opt/php/sources/7.2
  ./buildconf --force
  ./configure --prefix=/opt/php/7.2 --with-zlib-dir --with-freetype-dir --enable-mbstring --with-libxml-dir=/usr --enable-soap --enable-calendar --with-curl --with-zlib --with-gd --disable-rpath --enable-inline-optimization --with-bz2 --with-zlib --enable-sockets --enable-sysvsem --enable-sysvshm --enable-pcntl --enable-mbregex --enable-exif --enable-bcmath --with-mhash --enable-zip --with-pcre-regex --with-mysqli --with-pdo-mysql --with-mysqli --with-jpeg-dir=/usr --with-png-dir=/usr --with-openssl --with-fpm-user=www-data --with-fpm-group=www-data --with-libdir=/lib/x86_64-linux-gnu --enable-ftp --with-kerberos --with-gettext --with-xmlrpc --with-xsl --enable-opcache --enable-fpm
  make -j4
  make install
  cp /opt/php/sources/7.2/php.ini-production /opt/php/7.2/lib/php.ini
  cp /opt/php/7.2/etc/php-fpm.conf.default /opt/php/7.2/etc/php-fpm.conf
  cp /opt/php/7.2/etc/php-fpm.d/www.conf.default /opt/php/7.2/etc/php-fpm.d/www.conf
  echo "[Unit]
Description=The PHP 7.2 FastCGI Process Manager
After=network.target

[Service]
Type=simple
PIDFile=/opt/php/7.2/var/run/php-fpm.pid
ExecStart=/opt/php/7.2/sbin/php-fpm --nodaemonize --fpm-config /opt/php/7.2/etc/php-fpm.conf
ExecReload=/bin/kill -USR2 $MAINPID

[Install]
WantedBy=multi-user.target" >> /lib/systemd/system/php-7.2-fpm.service
  sed -i s/\;listen.owner\ \=\ www\-data/listen.owner\ \=\ nginx/g /opt/php/7.2/etc/php-fpm.d/www.conf
  sed -i s/\;listen.group\ \=\ www\-data/listen.group\ \=\ nginx/g /opt/php/7.2/etc/php-fpm.d/www.conf
  sed -i s/\;listen.mode\ \=\ 0660/listen.mode\ \=\ 0660/g /opt/php/7.2/etc/php-fpm.d/www.conf
  sed -i s/user\ \=\ www\-data/user\ \=\ nginx/g /opt/php/7.2/etc/php-fpm.d/www.conf
  sed -i s/group\ \=\ www\-data/group\ \=\ nginx/g /opt/php/7.2/etc/php-fpm.d/www.conf
  sed -i s/127.0.0.1\:9000/'\/run\/php7\.2\-fpm\.sock'/g /opt/php/7.2/etc/php-fpm.d/www.conf
  sed -i s/'\;pid\ \=\ run\/php\-fpm\.pid'/'pid\ \=\ run\/php\-fpm\-72\.pid'/g /opt/php/7.2/etc/php-fpm.conf
  systemctl start php-7.2-fpm.service
  systemctl enable php-7.2-fpm.service
  cd /opt/php/sources/7.1
  ./buildconf --force
  ./configure --prefix=/opt/php/7.1 --with-zlib-dir --with-freetype-dir --enable-mbstring --with-libxml-dir=/usr --enable-soap --enable-calendar --with-curl --with-zlib --with-gd --disable-rpath --enable-inline-optimization --with-bz2 --with-zlib --enable-sockets --enable-sysvsem --enable-sysvshm --enable-pcntl --enable-mbregex --enable-exif --enable-bcmath --with-mhash --enable-zip --with-pcre-regex --with-mysqli --with-pdo-mysql --with-mysqli --with-jpeg-dir=/usr --with-png-dir=/usr --with-openssl --with-fpm-user=www-data --with-fpm-group=www-data --with-libdir=/lib/x86_64-linux-gnu --enable-ftp --with-kerberos --with-gettext --with-xmlrpc --with-xsl --enable-opcache --enable-fpm
  make -j4
  make install
  cp /opt/php/sources/7.1/php.ini-production /opt/php/7.1/lib/php.ini
  cp /opt/php/7.1/etc/php-fpm.conf.default /opt/php/7.1/etc/php-fpm.conf
  cp /opt/php/7.1/etc/php-fpm.d/www.conf.default /opt/php/7.1/etc/php-fpm.d/www.conf
  echo "[Unit]
Description=The PHP 7.1 FastCGI Process Manager
After=network.target

[Service]
Type=simple
PIDFile=/opt/php/7.1/var/run/php-fpm.pid
ExecStart=/opt/php/7.1/sbin/php-fpm --nodaemonize --fpm-config /opt/php/7.1/etc/php-fpm.conf
ExecReload=/bin/kill -USR2 $MAINPID

[Install]
WantedBy=multi-user.target" >> /lib/systemd/system/php-7.1-fpm.service
  sed -i s/\;listen.owner\ \=\ www\-data/listen.owner\ \=\ nginx/g /opt/php/7.1/etc/php-fpm.d/www.conf
  sed -i s/\;listen.group\ \=\ www\-data/listen.group\ \=\ nginx/g /opt/php/7.1/etc/php-fpm.d/www.conf
  sed -i s/\;listen.mode\ \=\ 0660/listen.mode\ \=\ 0660/g /opt/php/7.1/etc/php-fpm.d/www.conf
  sed -i s/user\ \=\ www\-data/user\ \=\ nginx/g /opt/php/7.1/etc/php-fpm.d/www.conf
  sed -i s/group\ \=\ www\-data/group\ \=\ nginx/g /opt/php/7.1/etc/php-fpm.d/www.conf
  sed -i s/127.0.0.1\:9000/'\/run\/php7\.1\-fpm\.sock'/g /opt/php/7.1/etc/php-fpm.d/www.conf
  sed -i s/'\;pid\ \=\ run\/php\-fpm\.pid'/'pid\ \=\ run\/php\-fpm\-71\.pid'/g /opt/php/7.1/etc/php-fpm.conf
  systemctl start php-7.1-fpm.service
  systemctl enable php-7.1-fpm.service
  cd /opt/php/sources/7.0
  ./buildconf --force
  ./configure --prefix=/opt/php/7.0 --with-zlib-dir --with-freetype-dir --enable-mbstring --with-libxml-dir=/usr --enable-soap --enable-calendar --with-curl --with-zlib --with-gd --disable-rpath --enable-inline-optimization --with-bz2 --with-zlib --enable-sockets --enable-sysvsem --enable-sysvshm --enable-pcntl --enable-mbregex --enable-exif --enable-bcmath --with-mhash --enable-zip --with-pcre-regex --with-mysqli --with-pdo-mysql --with-mysqli --with-jpeg-dir=/usr --with-png-dir=/usr --with-openssl --with-fpm-user=www-data --with-fpm-group=www-data --with-libdir=/lib/x86_64-linux-gnu --enable-ftp --with-kerberos --with-gettext --with-xmlrpc --with-xsl --enable-opcache --enable-fpm
  make -j4
  make install
  cp /opt/php/sources/7.0/php.ini-production /opt/php/7.0/lib/php.ini
  cp /opt/php/7.0/etc/php-fpm.conf.default /opt/php/7.0/etc/php-fpm.conf
  cp /opt/php/7.0/etc/php-fpm.d/www.conf.default /opt/php/7.0/etc/php-fpm.d/www.conf
  echo "[Unit]
Description=The PHP 7.0 FastCGI Process Manager
After=network.target

[Service]
Type=simple
PIDFile=/opt/php/7.0/var/run/php-fpm.pid
ExecStart=/opt/php/7.0/sbin/php-fpm --nodaemonize --fpm-config /opt/php/7.0/etc/php-fpm.conf
ExecReload=/bin/kill -USR2 $MAINPID

[Install]
WantedBy=multi-user.target" >> /lib/systemd/system/php-7.0-fpm.service
  sed -i s/\;listen.owner\ \=\ www\-data/listen.owner\ \=\ nginx/g /opt/php/7.0/etc/php-fpm.d/www.conf
  sed -i s/\;listen.group\ \=\ www\-data/listen.group\ \=\ nginx/g /opt/php/7.0/etc/php-fpm.d/www.conf
  sed -i s/\;listen.mode\ \=\ 0660/listen.mode\ \=\ 0660/g /opt/php/7.0/etc/php-fpm.d/www.conf
  sed -i s/user\ \=\ www\-data/user\ \=\ nginx/g /opt/php/7.0/etc/php-fpm.d/www.conf
  sed -i s/group\ \=\ www\-data/group\ \=\ nginx/g /opt/php/7.0/etc/php-fpm.d/www.conf
  sed -i s/127.0.0.1\:9000/'\/run\/php7\.0\-fpm\.sock'/g /opt/php/7.0/etc/php-fpm.d/www.conf
  sed -i s/'\;pid\ \=\ run\/php\-fpm\.pid'/'pid\ \=\ run\/php\-fpm\-70\.pid'/g /opt/php/7.0/etc/php-fpm.conf
  systemctl start php-7.0-fpm.service
  systemctl enable php-7.0-fpm.service
}

function createsite {
  if [ -d "/var/www/$site" ]; then
    echo "error! Site already exists at /var/www/$site"
    exit;
  fi
  if [ ! -d "/var/www/" ]; then
    echo "Error please run --setup first"
    exit
  fi
  mkdir /var/www/$site
  mkdir /var/www/$site/public_html
  echo "
  server {
          listen 80;
          server_name $site www.$site;
          root /var/www/$site/public_html;
          access_log /var/log/nginx/$site.access.log;
          error_log /var/log/nginx/$site.error.log;
          index index.php;

          location / {
                  try_files \$uri \$uri/ =404;
          }

          include /etc/nginx/common/php7.2.conf;

          location ~ /\.ht {
                  deny all;
          }
  }
  " >> /etc/nginx/sites-available/$site
  ln -s /etc/nginx/sites-available/$site /etc/nginx/sites-enabled/$site
  systemctl restart php-7.2-fpm.service
  systemctl restart nginx
  dbname="$(< /dev/urandom tr -dc a-z | head -c${1:-15};echo;)"
  dbuser="$(< /dev/urandom tr -dc a-z | head -c${1:-15};echo;)"
  dbpass="$(< /dev/urandom tr -dc a-z | head -c${1:-15};echo;)"
  echo "dbname=$dbname
dbuser=$dbuser
dbpass=$dbpass" >> /var/www/$site/db.bash
  source /etc/mysql-nginx.bash
  mysql -uroot -p${rootpass} -e "CREATE DATABASE ${dbname} /*\!40100 DEFAULT CHARACTER SET utf8 */;"
  mysql -uroot -p${rootpass} -e "CREATE USER ${dbuser}@localhost IDENTIFIED BY '${dbpass}';"
  mysql -uroot -p${rootpass} -e "GRANT ALL PRIVILEGES ON ${dbname}.* TO '${dbuser}'@'localhost';"
  mysql -uroot -p${rootpass} -e "FLUSH PRIVILEGES;"
  sudo certbot run -a webroot -i nginx -w /var/www/$site/public_html -d $site -d www.$site --redirect
}

function createwordpresssite {
  if [ "$adminemail" = "" ]; then
    echo "Admin email not set."
    exit;
  fi
  if [ -d "/var/www/$site" ]; then
    echo "error! Site already exists at /var/www/$site"
    exit;
  fi
  if [ ! -d "/var/www/" ]; then
    echo "Error please run --setup first"
    exit
  fi
  mkdir /var/www/$site
  mkdir /var/www/$site/public_html
  chown nginx:nginx /var/www/$site/public_html -R
  echo "
  server {
          listen 80;
          server_name $site www.$site;
          root /var/www/$site/public_html;
          access_log /var/log/nginx/$site.access.log;
          error_log /var/log/nginx/$site.error.log;
          index index.php;
 
          location / {
                  try_files \$uri \$uri/ /index.php\?\$args;
          }
 
          include /etc/nginx/common/php7.2.conf;
 
          location ~ /\.ht {
                  deny all;
          }
  }
  " >> /etc/nginx/sites-enabled/$site.conf
  systemctl restart nginx
  dbname="$(< /dev/urandom tr -dc a-z | head -c${1:-15};echo;)"
  dbuser="$(< /dev/urandom tr -dc a-z | head -c${1:-15};echo;)"
  dbpass="$(< /dev/urandom tr -dc a-z | head -c${1:-15};echo;)"
  wppass="$(< /dev/urandom tr -dc a-z | head -c${1:-15};echo;)"
  echo "dbname=$dbname
dbuser=$dbuser
dbpass=$dbpass" >> /var/www/$site/db.bash
  source /etc/mysql-nginx.bash
  mysql -uroot -p${rootpass} -e "CREATE DATABASE ${dbname} /*\!40100 DEFAULT CHARACTER SET utf8 */;"
  mysql -uroot -p${rootpass} -e "CREATE USER ${dbuser}@localhost IDENTIFIED BY '${dbpass}';"
  mysql -uroot -p${rootpass} -e "GRANT ALL PRIVILEGES ON ${dbname}.* TO '${dbuser}'@'localhost';"
  mysql -uroot -p${rootpass} -e "FLUSH PRIVILEGES;"
  certbot run -a webroot -i nginx -w /var/www/$site/public_html -d $site -d www.$site --redirect
  cd /var/www/$site/public_html
  /usr/local/bin/wp core download --allow-root
  /usr/local/bin/wp config create --dbname=$dbname --dbuser=$dbuser --dbpass=$dbpass --allow-root
  sed -i s/localhost/127\.0\.0\.1/g /var/www/$site/public_html/wp-config.php
  /usr/local/bin/wp core install --url=$site --title=ChangeMe! --admin_user=admin --admin_password=$wppass --admin_email=$adminemail --allow-root
  chown nginx:nginx /var/www/$site/public_html -R
  echo "finished, username: admin password: $wppass"
}

function deletesite {
  if [ ! -d "/var/www/$site" ]; then
    echo "error! Site does not exist"
    exit;
  fi
  if [ ! -d "/var/www/" ]; then
    echo "Error please run --setup first"
    exit
  fi
  rm -rf /etc/nginx/sites-available/$site 
  rm -rf /etc/nginx/sites-enabled/$site
  systemctl restart php-7.2-fpm.service
  systemctl restart nginx
  source /var/www/$site/db.bash
  source /etc/mysql-nginx.bash
  mysql -uroot -p${rootpass} -e "DROP USER '${dbuser}'@'localhost';"
  mysql -uroot -p${rootpass} -e "DROP DATABASE ${dbname};"
  rm -rf /var/www/$site
  echo "site removed"
}

function updatePHP72 {
    if [ ! -f /etc/nginx/sites-available/$site ]; then
      echo "Site not found. Please first create the site with ./wscm -c $site"
	  exit
    fi
    sed -i "/\/etc\/nginx\/common\//c\include /etc/nginx/common/php7.2.conf;" /etc/nginx/sites-available/$site
    systemctl reload nginx
}
function updatePHP71 {
    if [ ! -f /etc/nginx/sites-available/$site ]; then
      echo "Site not found. Please first create the site with ./wscm -c $site"
	  exit
    fi
    sed -i "/\/etc\/nginx\/common\//c\include /etc/nginx/common/php7.1.conf;" /etc/nginx/sites-available/$site
    systemctl reload nginx
}
function updatePHP70 {
    if [ ! -f /etc/nginx/sites-available/$site ]; then
      echo "Site not found. Please first create the site with ./wscm -c $site"
	  exit
    fi
    sed -i "/\/etc\/nginx\/common\//c\include /etc/nginx/common/php7.0.conf;" /etc/nginx/sites-available/$site
    systemctl reload nginx
}

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root, eg: sudo wscm.bash"
   exit 1
fi

if [ "$1" == "" ]
  then usage
fi

while [ "$1" != "" ]; do
    case $1 in
        -h  | --help )            usage
                                  exit
                                  ;;
        -s  | --setup )           setup
                                  exit
                                  ;;
        -c  | --create )          shift
                                  site=$1
                                  shift
                                  createsite
                                  ;;
		-cw  | --create-wordpress ) shift
                                  site=$1
                                  shift
                                  adminemail=$1
                                  shift
                                  createwordpresssite
                                  ;;
        -d  | --delete )          shift
                                  site=$1
                                  shift
                                  deletesite
                                  ;;
        -b  | --backup )          shift
                                  site=$1
                                  shift
                                  backup
                                  ;;
        -php72  | --php72 )       shift
                                  site=$1
                                  shift
                                  updatePHP72
                                  ;;
        -php71  | --php71 )       shift
                                  site=$1
                                  shift
                                  updatePHP71
                                  ;;
        -php70  | --php70 )       shift
                                  site=$1
                                  shift
                                  updatePHP70
                                  ;;
        * )                       usage
                                  exit 1
    esac
    shift
done
