# wscm
Web Stack Config Manager

This script will install Nginx as a package and compile PHP 7.0, 7.1, 7.2 and 7.3 from github tags. 

This is a work in progress script and should not be used in production.
----

Supported OS's:

-Fresh install of CentOS 7 (Tested with SELinux disabled and firewalld allowed ports 80 and 443)

-Fresh install of Ubuntu 18.04

-Fresh install of Arch Linux

Any other OS's will not work.

Do not use this script on any OS if it is not a fresh install.
---

How to use this script?
---

First, Setup Nginx and PHP (This can take a long time depending on your server as this will compile 3 different versions of PHP as well as install many build dependencies):

>sudo ./wscm.bash -s

Second, add a site to host:

>sudo ./wscm.bash -c yourdomain.com

This will add a server block in nginx as well as create a MySQL database and setup your public root at /var/www/yourdomain.com/public_html.
The MySQL database details are found at /var/www/yourdomain.com/db.bash

How can I delete a domain?

>sudo ./wscm.bash -d yourdomain.com

How can I backup a domain + the MySQL database?:

>sudo ./wscm.bash -b yourdomain.com

This will backup the database as well as the public_html root to /opt/backup

Configuration locations:
---

Main NGINX Config: /etc/nginx/nginx.conf

NGINX Server Blocks: /etc/nginx/sites-enabled

PHP: /opt/php/VERSION/lib/php.ini
