#!/bin/bash

set -euf -o pipefail

set -x

if ! apt-get install man-db -y; then
  apt-get update
  apt-get install man-db vim -y
fi

cd /var/www/html

# Adjust read-only permissions
chmod u+w composer.json composer.lock
chown drupaladmin /home/drupaladmin composer.json composer.lock
find /var/www/html/vendor -print0 | xargs -0 chmod u+w
find /var/www/html/vendor -print0 | xargs -0 chown drupaladmin
find /var/www/html/modules -print0 | xargs -0 chmod u+w
find /var/www/html/modules -print0 | xargs -0 chown drupaladmin

# Adjust history permissions
chown root:root /root/.bash_history
chown drupaladmin:drupaladmin /home/drupaladmin/.bash_history

# Install Drupal Console
runuser -s /bin/bash -c '/home/drupaladmin/bin/composer require drupal/console:~1.0 --prefer-dist --optimize-autoloader' drupaladmin

cd /home/drupaladmin

# Install Drupal Console Launcher
if [[ ! -e bin/drupal ]]; then
  curl https://drupalconsole.com/installer -L -o bin/drupal.phar
  chmod +x bin/drupal.phar
  chown drupaladmin bin/drupal.phar
  mv bin/drupal.phar bin/drupal
fi
