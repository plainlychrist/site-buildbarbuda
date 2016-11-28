# Writing Guidelines: https://docs.docker.com/engine/userguide/eng-image/dockerfile_best-practices/
# vim: set tabstop=4 shiftwidth=4 expandtab :

FROM drupal:8.2.3-fpm

MAINTAINER Jonah.Beckford@plainlychrist.org

WORKDIR /var/www/html

############# Versions

# https://hub.docker.com/_/nginx/ 1.11.5
ENV NGINX_VERSION 1.11.5-1~jessie
ENV DRUSH_MAJOR_VERSION 8
ENV VIDEO_EMBED_FIELD_VERSION 8.1
ENV SYMFONY_INTL_VERSION 3.1
ENV SYMFONY_FORM_VERSION 3.1
ENV DRUPAL_NAME_VERSION 8.1
ENV DRUPAL_ADDRESS_VERSION 8.1
ENV DRUPAL_WORKBENCH_MODERATION_VERSION 8.1
ENV DRUPAL_BACKUP_DB_VERSION 8.1
ENV DRUPAL_ADVAGG 8.2
ENV DRUPAL_BOOTSTRAP_VERSION 8.3
ENV MYSQL2SQLITE_VERSION 1b0b5d610c6090422625a2c58d2c23d2296eab3a
# This, as of 9/8/2016, is a dev dependency (https://packagist.drupal-composer.org/packages/drupal/security_review#dev-8.x-1.x), which needs 'git clone'
ENV DRUPAL_SECURITY_REVIEW_VERSION 8.1

# https://developers.google.com/speed/pagespeed/module/release_notes
ENV NPS_VERSION 1.11.33.4

########################
######## ROOT ##########
########################

############## APT

# Install gawk so mysql2sqlite does not Segfault on large bootstrap databases
# Install git so that Composer, when fetching dev dependencies, can do a 'git clone'
# Install a database client, which is used by 'drush up' and 'drush sql-dump'
#   mysql-client or sqlite3
# Install self-signed SSL (auto-generated) for HTTPS
# Install supervisor so we can run multiple processes in one container
RUN apt-get -y update
RUN apt-get -y install \
        gawk \
        git \
        mysql-client \
        sqlite3 \
        ssl-cert openssl-blacklist \
        supervisor

############## Nginx 1.11.5
# - skips installing nginx-module-*
# - skips remove /var/lib/apt/lists/*

RUN apt-key adv --keyserver hkp://pgp.mit.edu:80 --recv-keys 573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62 \
	&& echo "deb http://nginx.org/packages/mainline/debian/ jessie nginx" >> /etc/apt/sources.list \
	&& apt-get update \
	&& apt-get install --no-install-recommends --no-install-suggests -y \
						ca-certificates \
						nginx=${NGINX_VERSION} \
						gettext-base

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
  && ln -sf /dev/stderr /var/log/nginx/error.log

EXPOSE 80 443

# Install Google Page Speed Module for nginx
#    https://developers.google.com/speed/pagespeed/module/build_ngx_pagespeed_from_source
##########

RUN apt-get install --no-install-recommends --no-install-suggests -y build-essential zlib1g-dev libpcre3 libpcre3-dev unzip \
  && set -x \
  && cd \
  && NGINX_VERSION=$(nginx -v 2>&1 | sed 's#.*/##') \
  && PS_NGX_EXTRA_FLAGS=$(nginx -V 2>&1 | awk '/configure arguments:/{$1=""; $2=""; print}') \
  && curl -LO https://github.com/pagespeed/ngx_pagespeed/archive/release-${NPS_VERSION}-beta.zip \
  && unzip release-${NPS_VERSION}-beta.zip  \
  && cd ngx_pagespeed-release-${NPS_VERSION}-beta/  \
  && curl -LO https://dl.google.com/dl/page-speed/psol/${NPS_VERSION}.tar.gz  \
  && tar -xzvf ${NPS_VERSION}.tar.gz  \
  && cd  \
  && curl -LO http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz  \
  && tar -xvzf nginx-${NGINX_VERSION}.tar.gz  \
  && cd nginx-${NGINX_VERSION}/  \
  && echo ./configure --add-dynamic-module=$HOME/ngx_pagespeed-release-${NPS_VERSION}-beta $PS_NGX_EXTRA_FLAGS > /tmp/runit  \
  && sh /tmp/runit  \
  && rm /tmp/runit \
  && make \
  && install -pv ./objs/ngx_pagespeed.so /etc/nginx/modules/  \
  && cd \
  && rm -rf release-${NPS_VERSION}-beta.zip ngx_pagespeed-release-${NPS_VERSION}-beta/ nginx-${NGINX_VERSION}.tar.gz nginx-${NGINX_VERSION}/ \
  && apt-get remove -y build-essential zlib1g-dev libpcre3-dev unzip

# Clean up space and unneeded packages
##########

RUN apt-get autoremove -y && \
        apt-get clean && \
        rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Get rid of PHP extensions we don't need
##########

# We won't use: PostgreSQL (comes from Drupal Dockerfile)
RUN rm -f /usr/local/etc/php/conf.d/docker-php-ext-pdo_pgsql.ini

########################
###### DRUPALADMIN #####
########################

# POSIX permissions: https://www.drupal.org/node/244924
# Keep uid and gid stable across all Docker containers by setting to 200
RUN addgroup --system  --gid 200 drupaladmin
RUN adduser --system  --uid 200 --ingroup drupaladmin --shell /bin/false drupaladmin

# Give it the permissions it needs
RUN chown -R drupaladmin \
        /var/www/html/composer.json \
        /var/www/html/composer.lock \
        /var/www/html/modules \
        /var/www/html/profiles \
        /var/www/html/themes \
        /var/www/html/vendor
RUN chmod o+w \
        /var/www/html/modules \
        /var/www/html/profiles \
        /var/www/html/themes \
        /var/www/html/vendor

# Switch to drupaladmin
USER drupaladmin

############# Composer

# Install Composer with the phar file.
RUN install -d ~/bin
RUN curl -fsSL "https://getcomposer.org/installer" | php -- --install-dir ~/bin --filename=composer && \
        chmod +x ~/bin/composer

# Choose where to install packages from
RUN \
        ~/bin/composer config repositories.drupal composer https://packagist.drupal-composer.org && \
        ~/bin/composer config minimum-stability dev

############# Drush

# Install Drush with Composer: http://www.whaaat.com/installing-drush-8-using-composer
RUN ~/bin/composer global require \
        drush/drush:${DRUSH_MAJOR_VERSION}.*
RUN ln -s ~/.composer/vendor/bin/drush ~/bin/

# Test your install.
RUN ~/bin/drush core-status

# Modules
#   To mitigate docker build running out of memory, we split up the composer require commands
#########

# Video embedding (https://www.drupal.org/project/video_embed_field)
# config_installer: Because of bug https://www.drupal.org/node/1613424, we need this custom install profile
RUN ~/bin/drush dl config_installer
RUN ~/bin/composer require "drupal/video_embed_field ~${VIDEO_EMBED_FIELD_VERSION}"

# Install symfony/intl: commerceguys/addressing suggests installing symfony/intl (to use it as the source of country data)
# Install symfony/form: commerceguys/addressing suggests installing symfony/form (to generate Symfony address forms)
# Install name and address fields
RUN ~/bin/composer require "symfony/intl ~${SYMFONY_INTL_VERSION}" "symfony/form ~${SYMFONY_FORM_VERSION}" \
    "drupal/name ~${DRUPAL_NAME_VERSION}" "drupal/address ~${DRUPAL_ADDRESS_VERSION}"

# Install Backup and Migrate
# Install Advanced CSS/JS Aggregation
# Install security review
# Install workbench moderation
RUN ~/bin/composer require \
        "drupal/backup_db ~${DRUPAL_BACKUP_DB_VERSION}" \
        "drupal/advagg ~${DRUPAL_ADVAGG}" && \
    ~/bin/composer require \
        "drupal/security_review ~${DRUPAL_SECURITY_REVIEW_VERSION}" \
        "drupal/workbench_moderation ~${DRUPAL_WORKBENCH_MODERATION_VERSION}"

# Install Bootstrap base theme
RUN ~/bin/composer require \
        "drupal/bootstrap ~${DRUPAL_BOOTSTRAP_VERSION}"

# Install mysql2sqlite
RUN curl "https://raw.githubusercontent.com/dumblob/mysql2sqlite/${MYSQL2SQLITE_VERSION}/mysql2sqlite" > ~/bin/mysql2sqlite && \
        chmod +x ~/bin/mysql2sqlite

# Clean up drupaladmin
##########

RUN ~/bin/composer clear-cache

########################
######## ROOT ##########
########################

USER root

# Configuration
#########

COPY filesystem/etc/ /etc/
COPY filesystem/usr/local/etc/ /usr/local/etc/
RUN rm -f /usr/local/etc/php-fpm.d/zz-docker.conf

# Initial configuration for the 'all' site ...

COPY filesystem/var/www/html/sites/all/modules/ /var/www/html/sites/all/modules
RUN chown -R www-data:www-data /var/www/html/sites/all/modules

# Snippets used to build the settings.php and .htacess
COPY settings/ /var/lib/site/settings

# Installation
############

COPY filesystem/var/lib/site/ /var/lib/site/
RUN chmod 500 /var/lib/site/bin/*.sh && \
  chown www-data /var/lib/site/bin/sanitized-backup.sh && \
  install -o drupaladmin -g www-data -m 750 -d /var/www/html/sites/default && \
  install -o drupaladmin -g www-data -m 770 -d /var/www/private && \
  chown -R drupaladmin:www-data /var/lib/site/storage-config/active

ENTRYPOINT ["/var/lib/site/bin/entry.sh"]
