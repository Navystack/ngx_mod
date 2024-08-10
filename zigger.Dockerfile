ARG NGINX_VERSION=1.26.0

FROM navystack/ngx_mod:${NGINX_VERSION} as zigger-downloader

RUN apt-get update && apt-get install git -y
RUN git clone --depth=1 https://github.com/ziggerFramework/zigger-source-2.4.git /usr/src/zigger
RUN mkdir -p /usr/src/zigger/data
RUN rm -rf /usr/src/zigger/.htaccess
RUN cat <<"EOF" > /usr/src/zigger/.htaccess
RewriteEngine On
RewriteRule ^\.well-known/.+ - [L]
RewriteRule ^install($|/.*) - [L]
RewriteRule ^manage$ manage/index.php [L]
RewriteRule ^manage/$ manage/index.php [L]
RewriteCond %{QUERY_STRING} ^(.*)$ [NC]
RewriteRule ^(.*)/([0-9]+)$ index.php?rewritepage=$1&mode=view&read=$2&%1 [L]
RewriteRule ^($|/.*) - [L]
RewriteRule ^(.*)/$ index.php?rewritepage=$1 [L]
RewriteCond %{REQUEST_URI} !(robots.txt|\.(?i:php|css|js|png|jpg|jpeg|gif|bmp|tiff|webp|woff|woff2|eot|svg))$ [NC]
RewriteCond %{QUERY_STRING} ^(.*)$ [NC]
RewriteRule ^(.*)$ index.php?rewritepage=$1&%1 [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule .? index.php?rewritepage=error/code404% [L]
EOF

RUN chown -R www-data:www-data /usr/src/zigger
RUN chmod -R 1707 /usr/src/zigger

FROM rockylinux:8 as final

RUN dnf -y install epel-release dnf-utils http://rpms.remirepo.net/enterprise/remi-release-8.rpm && \
    dnf -y module enable php:remi-8.2 && \
    dnf -y install procps vim php httpd php-bcmath php-cli php-common php-gd php-intl php-mbstring php-mysqlnd php-opcache php-pdo php-pear php-pecl-mcrypt php-soap php-xml && \
    dnf clean all && \
    sed -i 's+^post_max_size = 8M+post_max_size = 120M+g;s+^upload_max_filesize = 2M+upload_max_filesize = 100M+g;s+^short_open_tag = Off+short_open_tag = On+g;s+;mysqli.allow_local_infile = On+mysqli.allow_local_infile = On+g' /etc/php.ini && \
    sed -i 's+pid = /run/php-fpm/php-fpm.pid+pid = /run/httpd/php-fpm.pid+g' /etc/php-fpm.conf && \
    sed -i 's+listen = /run/php-fpm/www.sock+listen = 9000+g' /etc/php-fpm.d/www.conf && \
    sed -i 's+SetHandler "proxy:unix:/run/php-fpm/www.sock|fcgi://localhost"+SetHandler "proxy:fcgi://127.0.0.1:9000"+g' /etc/httpd/conf.d/php.conf && \
    sed -i 's+UserDir disabled+UserDir html+g;s+tory "/home/\*/public_html">+tory "/var/*/html">+g' /etc/httpd/conf.d/userdir.conf && \
    echo "alias ll='ls -l'" >> /etc/bashrc && \
    DOTHT_NUM=$(grep -n '^<Files ".ht' /etc/httpd/conf/httpd.conf | awk -F: '{print $1+1}') && \
    sed -i "${DOTHT_NUM}s+Require all denied+Require all granted+g;s+#ServerName www.example.com:80+ServerName localhost+g" /etc/httpd/conf/httpd.conf && \
    sed -i 's+Listen 80+Listen 8080+g' /etc/httpd/conf/httpd.conf && \
    sed -i 's+AllowOverride None+AllowOverride All+g' /etc/httpd/conf/httpd.conf && \
    ln -sf /dev/stdout /var/log/httpd/access_log && ln -s /dev/stderr /var/log/httpd/error_log

COPY --from=zigger-downloader --chown=www-data:www-data /usr/src/zigger /var/www/html
WORKDIR /var/www/html
EXPOSE 8080

ENTRYPOINT ["/bin/sh", "-c" , "/usr/sbin/php-fpm -D && /usr/sbin/httpd -D FOREGROUND"]