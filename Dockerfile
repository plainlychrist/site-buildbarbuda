# Writing Guidelines: https://docs.docker.com/engine/userguide/eng-image/dockerfile_best-practices/
# vim: set tabstop=4 shiftwidth=4 expandtab :

FROM drupal:latest

MAINTAINER Jonah.Beckford@plainlychrist.org

############# Versions

ENV DRUSH_MAJOR_VERSION 8
ENV DRUSH_CONFIG_EXTRA_FULL_VERSION 8.0.x-dev
ENV VIDEO_EMBED_FIELD_VERSION 8.1
ENV DRUPAL8_ZYMPHONIES_THEME_VERSION 8.1
ENV SYMFONY_INTL_VERSION 3.1
ENV SYMFONY_FORM_VERSION 3.1
ENV DRUPAL_NAME_VERSION 8.1
ENV DRUPAL_ADDRESS_VERSION 8.1
ENV DRUPAL_WORKBENCH_MODERATION_VERSION 8.1
ENV DRUPAL_BACKUP_DB_VERSION 8.1
ENV DRUPAL_FLYSYSTEM_VERSION 8.1
ENV DRUPAL_FLYSYSTEM_S3_VERSION 8.1
ENV MYSQL2SQLITE_VERSION 1b0b5d610c6090422625a2c58d2c23d2296eab3a
# This, as of 9/8/2016, is a dev dependency (https://packagist.drupal-composer.org/packages/drupal/security_review#dev-8.x-1.x), which needs 'git clone'
ENV DRUPAL_SECURITY_REVIEW_VERSION 8.1

########################
######## ROOT ##########
########################

############## APT

# Install a database client, which is used by 'drush up' and 'drush sql-dump'
#   mysql-client or sqlite3
# Install git so that Composer, when fetching dev dependencies, can do a 'git clone'
# Install supervisor so we can run multiple processes in one container
RUN apt-get -y update
RUN apt-get -y install \
        git \
        mysql-client \
        sqlite3 \
        supervisor

############## Apache

# Rarely does someone's machine have a `hostname` that has a reverse DNS-able entry in /etc/hosts.
# so we force the ServerName to be localhost, and use 'docker run .... -p 8080:80' networking to
# let us access the site.
# Doing this trick in Apache comes from http://askubuntu.com/questions/329323/problem-with-restarting-apache2
RUN echo 'ServerName localhost' > /etc/apache2/conf-available/ServerName.conf && \
        a2enconf ServerName

############# PHP extensions

# Install bcmath, needed by address
RUN docker-php-ext-install bcmath

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
        drush/drush:${DRUSH_MAJOR_VERSION}.* \
        drush/config-extra:${DRUSH_CONFIG_EXTRA_FULL_VERSION}
RUN ln -s ~/.composer/vendor/bin/drush ~/bin/

# Test your install.
RUN ~/bin/drush core-status

# Modules
#########

# Video embedding (https://www.drupal.org/project/video_embed_field)
# Themes
# config_installer: Because of bug https://www.drupal.org/node/1613424, we need this custom install profile
RUN ~/bin/drush dl config_installer
RUN ~/bin/composer require "drupal/video_embed_field ~${VIDEO_EMBED_FIELD_VERSION}" && \
        ~/bin/composer require "drupal/drupal8_zymphonies_theme ~${DRUPAL8_ZYMPHONIES_THEME_VERSION}"

# Install symfony/intl: commerceguys/addressing suggests installing symfony/intl (to use it as the source of country data)
# Install symfony/form: commerceguys/addressing suggests installing symfony/form (to generate Symfony address forms)
# Install name and address fields
RUN ~/bin/composer require "symfony/intl ~${SYMFONY_INTL_VERSION}" "symfony/form ~${SYMFONY_FORM_VERSION}" \
    "drupal/name ~${DRUPAL_NAME_VERSION}" "drupal/address ~${DRUPAL_ADDRESS_VERSION}"

# Install workbench moderation
# Install flysystem so we can run across multiple machines
# Install security review
# Install Backup and Migrate
RUN ~/bin/composer require \
        "drupal/backup_db ~${DRUPAL_BACKUP_DB_VERSION}" \
        "drupal/flysystem ~${DRUPAL_FLYSYSTEM_VERSION}" \
        "drupal/flysystem_s3 ~${DRUPAL_FLYSYSTEM_S3_VERSION}" \
        "drupal/security_review ~${DRUPAL_SECURITY_REVIEW_VERSION}" \
        "drupal/workbench_moderation ~${DRUPAL_WORKBENCH_MODERATION_VERSION}"

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

# Clean up space and unneeded packages
##########

RUN apt-get autoremove && \
        apt-get clean && \
        rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Configuration
#########

# Initial configuration for the 'default' site. ...

COPY config/sites/default/ /var/lib/site/config/sites/default
RUN chown -R www-data:www-data /var/lib/site/config/sites/default/

# Supervisor daemon to run multiple processes
COPY filesystem/etc/ /etc/

# Snippets used to build the settings.php and .htacess
COPY settings/ /var/lib/site/settings

# Installation
############

COPY filesystem/var/lib/site/ /var/lib/site/
RUN chmod 500 /var/lib/site/bin/*.sh && \
  install -o drupaladmin -g www-data -m 770 -d /var/www/flysystem && \
  install -o drupaladmin -g www-data -m 750 -d /var/www/html/sites/default && \
  install -o drupaladmin -g www-data -m 770 -d /var/www/private && \
  chown -R drupaladmin:www-data /var/lib/site/storage-config/active

ENTRYPOINT ["/var/lib/site/bin/entry.sh"]
