#!/bin/bash

set -euf -o pipefail

set -x

if ! apt-get install man-db -y; then
  apt-get update
  # man-db: who doesn't like man?
  # vim: you need an editor
  # ruby2.1: needed for 'sass'
  # ack-grep: searching a lot of source code (HTML, JS, CSS) is much easier with ack
  # wget: downloading made easy
  apt-get install man-db vim ruby2.1 ack-grep wget -y
fi

cd /var/www/html

# Adjust read-only permissions
chmod u+w composer.json composer.lock
chown drupaladmin /home/drupaladmin composer.json composer.lock
find /var/www/html/vendor -print0 | xargs -0 chmod u+w
find /var/www/html/vendor -print0 | xargs -0 chown drupaladmin
find /var/www/html/modules -print0 | xargs -0 chmod u+w
find /var/www/html/modules -print0 | xargs -0 chown drupaladmin
chmod -R a+w /var/www/html/sites/all/themes/directjude
install -o drupaladmin -g drupaladmin -d modules/custom
find /var/lib/site/storage-config/active/ -name '*.yml' -print0 | xargs -0 chmod 644
find /var/lib/site/storage-config/active/ -name '*.yml' -print0 | xargs -0 chown drupaladmin:www-data

# Adjust history permissions
if [[ -e /root/.bash_history ]]; then
  chown root:root /root/.bash_history
fi
if [[ -e /home/drupaladmin/.bash_history ]]; then
  chown drupaladmin:drupaladmin /home/drupaladmin/.bash_history
fi

# Other perms
chown drupaladmin:drupaladmin /home/drupaladmin /home/drupaladmin/.vimrc /var/www/html/sites/settings.local.php

# Install Drupal Console
runuser -s /bin/bash -c '/home/drupaladmin/bin/composer require drupal/console:~1.0 drupal/devel:~1.2 drupal/masquerade:~2.0 --prefer-dist --optimize-autoloader' drupaladmin

cd /home/drupaladmin

# Install Drupal Console Launcher
if [[ ! -e bin/drupal ]]; then
  curl https://drupalconsole.com/installer -L -o bin/drupal.phar
  chmod +x bin/drupal.phar
  chown drupaladmin bin/drupal.phar
  mv bin/drupal.phar bin/drupal
fi

# Just use Drupal Console to install (easier than composer( ...
cd /var/www/html

# Enable development settings
if ! tail -n1 sites/default/settings.php | grep -q settings.local.php; then
  echo "include \$app_root . '/' . \$site_path . '/settings.local.php';" >> sites/default/settings.php
fi

# Install Devel
runuser -s /bin/bash -c '/home/drupaladmin/bin/drush en devel -y' drupaladmin
runuser -s /bin/bash -c '/home/drupaladmin/bin/drush en kint -y' drupaladmin
runuser -s /bin/bash -c '/home/drupaladmin/bin/drush en masquerade -y' drupaladmin
