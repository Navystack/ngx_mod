#!/bin/bash
chown --recursive --changes www-data:www-data /var/www/html/wp-content
find /var/www/html/wp-content -type f -exec chmod --changes 0664 {} \;
find /var/www/html/wp-content -type d -exec chmod --changes 0775 {} \;
nginx -g "daemon off;" &
php-fpm
