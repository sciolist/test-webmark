FROM php:8-apache
WORKDIR /var/www/html
RUN apt-get update && apt-get install -y libpq-dev && docker-php-ext-install pdo pdo_pgsql
RUN mv $PHP_INI_DIR/php.ini-production $PHP_INI_DIR/php.ini && \
    ln -s /etc/apache2/mods-available/rewrite.conf /etc/apache2/mods-enabled/rewrite.conf && \
    ln -s /etc/apache2/mods-available/rewrite.load /etc/apache2/mods-enabled/rewrite.load && \
    echo "Listen 3000\nLoadModule rewrite_module modules/mod_rewrite.so" > /etc/apache2/ports.conf && \
    echo "<VirtualHost *:3000>\nDocumentRoot /var/www/html\n</VirtualHost>" > /etc/apache2/sites-enabled/000-default.conf
COPY . .
