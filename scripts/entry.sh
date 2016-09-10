#!/bin/bash
# vim: set tabstop=2 shiftwidth=2 expandtab smartindent:
set -euo pipefail

usage()
{
  echo "Options: " >&2
    echo "-h                              Display this help" >&2
    echo "-t|--trust-host-pattern REGEX   Add a trusted host pattern, as per https://www.drupal.org/node/1992030. Can be repeated" >&2
    echo "--trust-this-ec2-host           Add the public DNS name of this EC2 host as a trusted host pattern, as per https://www.drupal.org/node/1992030" >&2
    echo "-m|--use-mysql                  Use MySQL. Expects MYSQL_DATABASE, MYSQL_USER and MYSQL_PASSWORD environment variables, with 'db' as the hostname" >&2
}

# process command line
TRUSTED_HOST_PATTERNS=()
USE_MYSQL=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 2
      ;;
    -m|--use-mysql)
      USE_MYSQL=1
      shift
      ;;
    -t|--trust-host-pattern)
      TRUSTED_HOST_PATTERNS+=( $2 )
      shift 2
      ;;
    --trust-this-ec2-host)
      PUBLIC_HOSTNAME="^$(curl -s http://169.254.169.254/latest/meta-data/public-hostname)$"
      TRUSTED_HOST_PATTERNS+=( ${PUBLIC_HOSTNAME} )
      shift
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

# Default database is SQLite (for development use)
USE_SQLITE=1
SQLITE_DIR=/var/lib/site/db/sqlite
SQLITE_LOCATION=${SQLITE_DIR}/.ht.sqlite
DB_URL=sqlite://${SQLITE_LOCATION}

if [[ $USE_MYSQL -eq 1 ]]; then
  DB_URL=mysql://${MYSQL_USER}:"${MYSQL_PASSWORD}"@db:3306/${MYSQL_DATABASE}
  USE_SQLITE=0

  echo Waiting for at most 30 seconds for MySQL to come alive ...
  php -r "
  for (\$i = 1; \$i <= 30; \$i++) {
    try {
        \$dbh = new PDO('mysql:host=db;port=3306;dbname=${MYSQL_DATABASE}', '${MYSQL_USER}', '${MYSQL_PASSWORD}', array( PDO::ATTR_PERSISTENT => false));
        if (\$dbh->query('SELECT 1')) { echo \"Connected to MySQL\n\"; exit; }
    } catch (PDOException \$e) {
        echo 'WARN: Retrying connection to MySQL: ', \$e->getMessage(), \"\n\";
        sleep(1);
    }
  }
  echo \"FATAL: Could not connect to MySQL\n\";
  "
fi

# Install drupal, specifically sites/default/settings.php
if drush core-status drupal-settings-file | grep MISSING; then

  echo Installing a starter site with Drush site-install, with email notification disabled ...

  echo Generating the global Drupal settings ...

  # https://www.drupal.org/node/1992030
  SETTINGS=/var/www/html/sites/default/default.settings.php
  n_elements=${#TRUSTED_HOST_PATTERNS[@]}
  max_index=$((n_elements - 1))
  if [[ $n_elements -gt 0 ]]; then
    echo >> ${SETTINGS}
    echo '# Installed by site-web entry.sh from "docker run ... -t ..."' >> ${SETTINGS}
    echo '$settings["trusted_host_patterns"] = array(' >> ${SETTINGS}
    for ((i = 0; i <= max_index; i++)); do
      echo "'${TRUSTED_HOST_PATTERNS[i]}'," >> ${SETTINGS}
    done
    echo ');' >> ${SETTINGS}
  fi

  # Use file-based configuration rather than database-base configuration
  # https://www.drupal.org/node/2291587

  STORAGE_CONFIG=/var/lib/site/storage-config
  HAVE_STORED_CONFIG=1
  if [[ ! -e ${STORAGE_CONFIG}/active/system.site.yml ]]; then # there is no Docker mount to a 'git' workspace
    HAVE_STORED_CONFIG=0
    install -d ${STORAGE_CONFIG}
    install -d ${STORAGE_CONFIG}/staging # configs for manual import should never be modified by the running Drupal system
    install -o www-data -m 755 -d ${STORAGE_CONFIG}/active ${STORAGE_CONFIG}/sync
  fi
  echo >> ${SETTINGS}
  echo '# Installed by site-web entry.sh' >> ${SETTINGS}
  echo "\$settings['bootstrap_config_storage'] = array('Drupal\Core\Config\BootstrapConfigStorageFactory', 'getFileStorage');" >> ${SETTINGS}
  echo "\$config_directories = array(
     CONFIG_ACTIVE_DIRECTORY => '${STORAGE_CONFIG}/active/',
     CONFIG_STAGING_DIRECTORY => '${STORAGE_CONFIG}/staging/',
     CONFIG_SYNC_DIRECTORY => '${STORAGE_CONFIG}/sync/',
    );" >> ${SETTINGS}

  SERVICES=/var/www/html/sites/default/services.yml
  echo >> ${SERVICES}
  echo '# Installed by site-web entry.sh' >> ${SERVICES}
  echo 'services:' >> ${SERVICES}
  echo '  config.storage:' >> ${SERVICES}
  echo '    class: Drupal\Core\Config\CachedStorage' >> ${SERVICES}
  echo "    arguments: ['@config.storage.active', '@cache.config']" >> ${SERVICES}
  echo '  config.storage.active:' >> ${SERVICES}
  echo '    class: Drupal\Core\Config\FileStorage' >> ${SERVICES}
  echo '    factory: Drupal\Core\Config\FileStorageFactory::getActive' >> ${SERVICES}

  if [[ $HAVE_STORED_CONFIG -eq 1 ]]; then
    echo Doing an already-active configuration site installation ...

    # TODO: do a database restore first ... the configuration refers to records in the database.
    # without a database with those records, the config_installer later will fail with Drupal\Core\Database\ConnectionNotDefinedException

    drush -y site-install --db-url="${DB_URL}" \
      --account-name=admin \
      --account-pass="${WEB_ADMIN_PASSWORD}" \
      config_installer install_configure_form.update_status_module='array(FALSE,FALSE)'

  else
    echo Doing a no-configuration site installation ...

    drush -y site-install --db-url="${DB_URL}" \
      --account-name=admin \
      --account-pass="${WEB_ADMIN_PASSWORD}" \
      --account-mail=no-reply@plainlychrist.org \
      --site-name="PlainlyChrist.org" \
      --site-mail=no-reply@plainlychrist.org \
      standard install_configure_form.update_status_module='array(FALSE,FALSE)'
  fi

  if [[ $USE_SQLITE -eq 1 ]]; then
    # Fix permissions as per https://api.drupal.org/api/drupal/core!INSTALL.sqlite.txt/8.1.x
    chown www-data "${SQLITE_DIR}" "${SQLITE_LOCATION}"
    chmod 600 "${SQLITE_LOCATION}"
  fi

  # Enable the modules that must be present, regardless of configuration.
  # Note that configuration in active/ will automatically enable any module it refers to, so
  # the modules listed below are only really relevant for a barebones no-configuration system.
  # Basically, Day 1 of the source code.

  echo Enabling the Security Review module ...
  drush -y pm-enable security_review

  echo Enabling the Update Manager module ...
  drush -y pm-enable update

  echo Securing POSIX permissions ...
  # https://www.drupal.org/node/244924
  find /var/www/html -type f -exec chmod a-w {} \;
  find /var/www/html -type d -exec chmod a-w {} \;
  chown -R www-data /var/www/html/sites/default/files
  find /var/www/html/sites/default/files -type d -exec chmod u+w {} \;
  chown -R www-data /var/lib/site/storage-config/active /var/lib/site/storage-config/sync
fi

# Then run CMD (apache2-foreground) from php:apache in https://hub.docker.com/_/php/
echo Starting the Apache server in foreground ...
exec apache2-foreground
