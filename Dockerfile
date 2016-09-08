# Writing Guidelines: https://docs.docker.com/engine/userguide/eng-image/dockerfile_best-practices/

FROM drupal:latest

MAINTAINER Jonah.Beckford@plainlychrist.org

############# Versions

ENV DRUSH_MAJOR_VERSION 8
ENV VIDEO_EMBED_FIELD_VERSION 8.1
ENV DRUPAL8_ZYMPHONIES_THEME_VERSION 8.1
ENV SYMFONY_INTL_VERSION 3.1
ENV SYMFONY_FORM_VERSION 3.1
ENV DRUPAL_NAME_VERSION 8.1
ENV DRUPAL_ADDRESS_VERSION 8.1
ENV DRUPAL_WORKBENCH_MODERATION_VERSION 8.1
# This, as of 9/8/2016, is a dev dependency (https://packagist.drupal-composer.org/packages/drupal/security_review#dev-8.x-1.x), which needs 'git clone'
ENV DRUPAL_SECURITY_REVIEW_VERSION 8.1

############## APT

# Install a database client, which is used by 'drush up' and 'drush sql-dump'
#   mysql-client or sqlite3
# Install git so that Composer, when fetching dev dependencies, can do a 'git clone'
RUN apt-get -y update && \
  apt-get -y install git && \
  apt-get -y install mysql-client && \
  apt-get -y install sqlite3

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

############# Composer

# Install Composer with the phar file.
RUN curl -fsSL "https://getcomposer.org/installer" | php -- --install-dir=/usr/local/bin --filename=composer && \
  chmod +x /usr/local/bin/composer

# Choose where to install packages from
RUN composer config repositories.drupal composer https://packagist.drupal-composer.org
RUN composer config minimum-stability dev

############# Drush

# Install Drush with Composer: http://www.whaaat.com/installing-drush-8-using-composer
RUN composer global require drush/drush:${DRUSH_MAJOR_VERSION}.*
RUN ln -s /root/.composer/vendor/bin/drush /usr/local/bin/

# Test your install.
RUN drush core-status

# Modules
#########

# Install symfony/polyfill-intl-icu suggests installing ext-intl (For best performance), and
# symfony/intl suggests installing ext-intl (to use the component with locales other than "en")
# NOTE: Can get this to install, but not important ... http://stackoverflow.com/questions/6727736/cant-get-to-install-intl-extension-for-php-on-debian
#RUN apt-get install -y php5-intl libicu-dev
#RUN pecl install intl
#RUN docker-php-ext-install intl

# Backup (https://www.drupal.org/project/backup_migrate and http://www.nodesquirrel.com/) "drupal/backup_migrate ~8.4"
# Video embedding (https://www.drupal.org/project/video_embed_field)
# Themes
# config_installer: Because of bug https://www.drupal.org/node/1613424, we need this custom install profile
RUN drush dl config_installer
RUN composer require "drupal/video_embed_field ~${VIDEO_EMBED_FIELD_VERSION}" && \
    composer require "drupal/drupal8_zymphonies_theme ~${DRUPAL8_ZYMPHONIES_THEME_VERSION}"

# Install symfony/intl: commerceguys/addressing suggests installing symfony/intl (to use it as the source of country data)
# Install symfony/form: commerceguys/addressing suggests installing symfony/form (to generate Symfony address forms)
# Install name and address fields
RUN composer require "symfony/intl ~${SYMFONY_INTL_VERSION}" "symfony/form ~${SYMFONY_FORM_VERSION}" \
    "drupal/name ~${DRUPAL_NAME_VERSION}" "drupal/address ~${DRUPAL_ADDRESS_VERSION}"

# Install workbench moderation
RUN composer require "drupal/workbench_moderation ~${DRUPAL_WORKBENCH_MODERATION_VERSION}"

# Install security review
RUN composer require "drupal/security_review ~${DRUPAL_SECURITY_REVIEW_VERSION}"

# Development (https://www.drupal.org/project/devel) ... SHOULD NOT BE INSTALLED IN PRODUCTION ... use entry.sh to install
##RUN drush dl devel

# Configuration
#########

# Initial configuration for the 'default' site. ...

COPY config/sites/default/ /var/lib/site/config/sites/default
RUN chown -R www-data:www-data /var/lib/site/config/sites/default/

# Clean up space and unneeded packages
##########

RUN apt-get autoremove && apt-get clean
RUN rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN composer clear-cache

# Installation
############

COPY scripts/entry.sh /var/lib/site/bin/entry.sh
RUN chmod 500 /var/lib/site/bin/entry.sh

ENTRYPOINT ["/var/lib/site/bin/entry.sh"]
