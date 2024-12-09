# Step 1: Use PHP 7.1 FPM as the base image
FROM php:7.1-fpm

# Step 2: Install system dependencies required for Laravel and Vue.js
RUN apt-get update && apt-get install -y \
    git \
    unzip \
    curl \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    nginx \
    nodejs \
    npm \
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install pdo pdo_mysql gd

# Step 3: Install Node.js 16.x and npm (newer version)
RUN curl -sL https://deb.nodesource.com/setup_16.x | bash - \
    && apt-get install -y nodejs

# Step 4: Downgrade Composer to version 2.2 LTS
RUN curl -sS https://getcomposer.org/installer | php -- --version=2.2.6
RUN mv composer.phar /usr/local/bin/composer

# Step 5: Set the working directory to /var/www
WORKDIR /var/www

# Step 6: Copy the application files into the container
COPY . .

# Step 7: Install PHP dependencies using Composer
RUN composer install --no-dev --optimize-autoloader

# Step 8: Install Node.js dependencies for Vue.js (frontend)
RUN npm install

# Step 9: Build Vue.js assets using Laravel Mix (production build)
RUN npm run production

# Step 10: Set proper permissions for Laravel storage and bootstrap/cache
RUN chown -R www-data:www-data /var/www/storage /var/www/bootstrap/cache

# Step 11: Copy Nginx configuration file for Laravel application
COPY ./deploy/nginx/default.conf /etc/nginx/sites-available/default

# Step 12: Expose port 8080 for Nginx and 9000 for PHP-FPM
EXPOSE 8080
EXPOSE 9000

# Step 13: Start PHP-FPM and Nginx directly without using the 'service' command
CMD ["sh", "-c", "php-fpm & nginx -g 'daemon off;'"]
