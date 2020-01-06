FROM php:7.4.1-apache
WORKDIR /var/www/html
RUN apt-get update && apt-get install -y libpq-dev && docker-php-ext-install pdo pdo_pgsql
RUN echo -e "\
ln -s /etc/apache2/mods-available/rewrite.conf /etc/apache2/mods-enabled/rewrite.conf;\n\
ln -s /etc/apache2/mods-available/rewrite.load /etc/apache2/mods-enabled/rewrite.load;\n\
echo \"Listen 3000\nLoadModule rewrite_module modules/mod_rewrite.so\" > /etc/apache2/ports.conf;\n\
echo \"<VirtualHost *:3000>\nDocumentRoot /var/www/html\n</VirtualHost>\" > /etc/apache2/sites-enabled/000-default.conf;\n\
" | bash
COPY . .
