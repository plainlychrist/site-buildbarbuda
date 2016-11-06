#!/bin/bash
# vim: set tabstop=2 shiftwidth=2 expandtab smartindent:

DEFAULT_SETTINGS=/var/www/html/sites/default/default.settings.php
SERVICES=/var/www/html/sites/default/services.yml
SETTINGS=/var/www/html/sites/default/settings.php
STORAGE_CONFIG=/var/lib/site/storage-config

function restore_data {
  local RESTORE_URL="$1"
  echo "Restoring data from ${RESTORE_URL} ..."

  BOOTSTRAP_DIR=/var/lib/site/bootstrap/active
  install -d ${BOOTSTRAP_DIR}

  # Download (or copy if file://) the data as *.sql.txt
  curl --include --progress-bar "${RESTORE_URL}/latest.txt" > ${BOOTSTRAP_DIR}/latest.txt
  BOOTSTRAP_LATEST=$(< ${BOOTSTRAP_DIR}/latest.txt)
  curl --include --progress-bar "${RESTORE_URL}/${BOOTSTRAP_LATEST}.plain-dump.sql.txt" > ${BOOTSTRAP_DIR}/plain-dump.sql.txt
  curl --include --progress-bar "${RESTORE_URL}/${BOOTSTRAP_LATEST}.sanitized-dump.sql.txt" > ${BOOTSTRAP_DIR}/sanitized-dump.sql.txt
  curl --include --progress-bar "${RESTORE_URL}/${BOOTSTRAP_LATEST}.sanitized-restore.sql.txt" > ${BOOTSTRAP_DIR}/sanitized-restore.sql.txt
  curl --include --progress-bar "${RESTORE_URL}/${BOOTSTRAP_LATEST}.sites-default-files.tar.xz" > ${BOOTSTRAP_DIR}/sites-default-files.tar.xz
  curl --include --progress-bar "${RESTORE_URL}/${BOOTSTRAP_LATEST}.flysystem-main.tar.xz" > ${BOOTSTRAP_DIR}/flysystem-main.tar.xz

  # Copy or convert the downloaded file to *.sql
  if [[ $USE_SQLITE -eq 1 ]]; then
    # SQLite needs to be converted from MySQL
    gawk -f ~drupaladmin/bin/mysql2sqlite ${BOOTSTRAP_DIR}/plain-dump.sql.txt > ${BOOTSTRAP_DIR}/plain-dump.sql
    gawk -f ~drupaladmin/bin/mysql2sqlite ${BOOTSTRAP_DIR}/sanitized-dump.sql.txt > ${BOOTSTRAP_DIR}/sanitized-dump.sql
    install ${BOOTSTRAP_DIR}/sanitized-restore.sql.txt ${BOOTSTRAP_DIR}/sanitized-restore.sql
    # make sure we have at least an empty SQLite database
    install -d "${SQLITE_DIR}" # create parent directories as root if not present
    install -d -o drupaladmin -g www-data -m 775 "${SQLITE_DIR}" # fix SQLSTATE[HY000]: General error: 14 unable to open database file: http://www.php.net/manual/en/ref.pdo-sqlite.php#57356
    touch "${SQLITE_LOCATION}"
    chown drupaladmin:www-data "${SQLITE_LOCATION}"
  else
    install ${BOOTSTRAP_DIR}/plain-dump.sql.txt ${BOOTSTRAP_DIR}/plain-dump.sql
    install ${BOOTSTRAP_DIR}/sanitized-dump.sql.txt ${BOOTSTRAP_DIR}/sanitized-dump.sql
    install ${BOOTSTRAP_DIR}/sanitized-restore.sql.txt ${BOOTSTRAP_DIR}/sanitized-restore.sql
  fi

  # Restore the database ('drush sql-query' has problems restoring SQLite, at minimum, so use sql-connect)
  $(drush sql-connect --db-url="${DB_URL}") < ${BOOTSTRAP_DIR}/plain-dump.sql
  $(drush sql-connect --db-url="${DB_URL}") < ${BOOTSTRAP_DIR}/sanitized-dump.sql
  $(drush sql-connect --db-url="${DB_URL}") < ${BOOTSTRAP_DIR}/sanitized-restore.sql

  # Restore any files to sites/default/files
  install -d /var/www/html/sites/default/files
  tar --extract --xz --directory /var/www/html/sites/default/files \
    --exclude "*.php" \
    --exclude ".htaccess" \
    --file ${BOOTSTRAP_DIR}/sites-default-files.tar.xz
  tar --extract --xz --directory /var/www/flysystem \
    --exclude "*.php" \
    --exclude ".htaccess" \
    --file ${BOOTSTRAP_DIR}/flysystem-main.tar.xz
}

SALT_FILE=/var/lib/site/salt.txt

function generate_salt_file {
  if [[ -z "$HASH_SALT" ]]; then
    openssl rand -base64 64 | tr -d '\n' > $SALT_FILE
  else
    echo "$HASH_SALT" > $SALT_FILE
  fi
  chown drupaladmin:www-data $SALT_FILE
  chmod 440 $SALT_FILE
}

function generate_settings {
  # confer: https://api.drupal.org/api/drupal/sites%21default%21default.settings.php/8.1.x

  # https://www.drupal.org/node/1992030
  n_elements=${#TRUSTED_HOST_PATTERNS[@]}
  max_index=$((n_elements - 1))
  if [[ $n_elements -gt 0 ]]; then
    echo
    echo '# Installed by site-web entry-bootstrap.sh from "docker run ... -t ..."'
    echo '$settings["trusted_host_patterns"] = array('
    for ((i = 0; i <= max_index; i++)); do
      echo "'${TRUSTED_HOST_PATTERNS[i]}',"
    done
    echo ');'
  fi

  # core settings
  cat <<EOF
# private files. https://www.drupal.org/documentation/modules/file
# They are needed for drupal/backup_db
\$settings['file_private_path'] = '/var/www/private';

\$settings['update_free_access'] = FALSE;

\$settings['hash_salt'] = file_get_contents('${SALT_FILE}');

\$settings['container_yamls'][] = __DIR__ . '/services.yml';

\$settings['install_profile'] = 'standard';
EOF

  # flywheel for local + remote file access
  cat /var/lib/site/settings/flysystem-local.php

  # database configuration
  if [[ $USE_SQLITE -eq 1 ]]; then
    cat <<EOF
\$databases['default']['default'] = array(
  'driver' => 'sqlite',
  'namespace' => 'Drupal\\\\Core\\\\Database\\\\Driver\\\\sqlite',
  'database' => '$SQLITE_LOCATION',
);
EOF
  elif [[ $USE_MYSQL -eq 1 ]]; then
    cat <<EOF
\$databases['default']['default'] = array(
  'driver' => 'mysql',
  'namespace' => 'Drupal\\\\Core\\\\Database\\\\Driver\\\\mysql',
  'host' => '$MYSQL_HOST',
  'port' => '$MYSQL_PORT',
  'database' => '$MYSQL_DATABASE',
  'username' => '$MYSQL_USER',
  'password' => '$MYSQL_PASSWORD',
  'prefix' => '',
);
EOF
  else
    echo "Unsupported database selected: ${DB_URL}" >&2
    exit 1
  fi
}

function generate_settings_file_config {
  echo
  echo '# Installed by site-web entry-bootstrap.sh'
  echo "\$settings['bootstrap_config_storage'] = array('Drupal\Core\Config\BootstrapConfigStorageFactory', 'getFileStorage');"
  echo "\$config_directories = array(
     CONFIG_ACTIVE_DIRECTORY => '${STORAGE_CONFIG}/active/',
     CONFIG_STAGING_DIRECTORY => '${STORAGE_CONFIG}/staging/',
     CONFIG_SYNC_DIRECTORY => '${STORAGE_CONFIG}/sync/',
    );"
}

function generate_services_file_config {
  echo >> ${SERVICES}
  echo '# Installed by site-web entry-bootstrap.sh' >> ${SERVICES}
  echo 'services:' >> ${SERVICES}
  echo '  config.storage:' >> ${SERVICES}
  echo '    class: Drupal\Core\Config\CachedStorage' >> ${SERVICES}
  echo "    arguments: ['@config.storage.active', '@cache.config']" >> ${SERVICES}
  echo '  config.storage.active:' >> ${SERVICES}
  echo '    class: Drupal\Core\Config\FileStorage' >> ${SERVICES}
  echo '    factory: Drupal\Core\Config\FileStorageFactory::getActive' >> ${SERVICES}
}

# Use file-based configuration rather than database-base configuration
# https://www.drupal.org/node/2291587

# We always want to use file based configuration (we also need generate_settings_file_config later to enable it)
generate_services_file_config

HAVE_STORED_CONFIG=1
if [[ ! -e ${STORAGE_CONFIG}/active/system.site.yml ]]; then # there is no Docker mount to a 'git' workspace
  HAVE_STORED_CONFIG=0
  install -d ${STORAGE_CONFIG}
  install -o drupaladmin -d ${STORAGE_CONFIG}/staging # configs for manual import should never be modified by the running Drupal system
  install -o drupaladmin -g www-data -m 775 -d ${STORAGE_CONFIG}/active ${STORAGE_CONFIG}/sync
fi

# Make a random salt for hardening against SQL injections
generate_salt_file

if [[ $HAVE_STORED_CONFIG -eq 1 ]]; then
  echo Detected we already have active configuration.

  # we only want one "winner" in a distributed Drupal cluster to do the database updates.
  DATABASE_WRITER=0
  if drush sql-query --db-url="${DB_URL}" 'CREATE TABLE site_phase1(id INT);'; then
    DATABASE_WRITER=1
    echo "Won the election to create the Drupal tables. We are the database creator."
  else
    echo "Could not create the table site_phase1. Another creator on a machine was elected to create the Drupal tables."
  fi

  if [[ $DATABASE_WRITER -eq 1 ]]; then
    # we need a database with records ... the config_installer later will fail with Drupal\Core\Database\ConnectionNotDefinedException
    echo Querying to see if we have any data in this site ...
    if ! drush sql-query --db-url="${DB_URL}" 'SELECT 1 FROM users'; then
      if [[ -z "${BOOTSTRAP_URL}" ]]; then
        # use the default bootstrap data
        restore_data "file:///var/lib/site/bootstrap/default"
      else
        restore_data "${BOOTSTRAP_URL}/sites/default/files/public-backups"
      fi
    else
      echo "  There is data in this site."
    fi
  fi

  echo Doing an already-active configuration site installation ...
  #echo TODO 1; export -f drush; export DB_URL WEB_ADMIN_PASSWORD; bash --login

  # Generate settings.php with proper permissions
  install -o drupaladmin -g www-data -m 640 /dev/null ${SETTINGS}
  echo '<?php' >> ${SETTINGS}
  generate_settings >> ${SETTINGS}
  generate_settings_file_config >> ${SETTINGS}

  if [[ $DATABASE_WRITER -eq 1 ]]; then
    # Verify settings are good (this is just visual)
    drush core-status

    # Unblock the admin account and rename to our admin user (for now, 'admin'). Then reset password
    drush sql-query "UPDATE users_field_data SET name='admin', status=1 WHERE uid=1;"
    drush user-password admin --password="${WEB_ADMIN_PASSWORD}"

    # Make sure all entities defined in configuration are present in database
    drush -y entity-updates

    # Reset drupal caches
    drush cache-rebuild

    # Say the winner (the "writer") is completed
    echo "Signaling to the election followers that we have finished creating the Drupal tables."
    drush sql-query --db-url="${DB_URL}" 'CREATE TABLE site_phase2(id INT);'
  else
    # Wait for the winner to complete
    echo "We'll wait until the elected database creator is complete ..."
    while true; do
      if drush sql-query --db-url="${DB_URL}" 'SELECT 1 FROM site_phase2;'; then
        echo "Finished waiting for the elected database creator to create the database"
        break
      else
        # Wait 5 seconds for retry
        sleep 5
      fi
    done

    # Verify settings are good (this is just visual)
    drush core-status
  fi
else
  echo Installing a no-config, no-data site with Drush site-install, with email notification disabled ...

  # site-install uses default.settings.php to generate settings.php
  generate_settings >> ${DEFAULT_SETTINGS}
  generate_settings_file_config >> ${DEFAULT_SETTINGS}

  # do the site-install, which generates settings.php and creates the database tables
  drush -y site-install --db-url="${DB_URL}" \
    --account-name=admin \
    --account-pass="${WEB_ADMIN_PASSWORD}" \
    --account-mail=no-reply@plainlychrist.org \
    --site-name="PlainlyChrist.org" \
    --site-mail=no-reply@plainlychrist.org \
    --verbose \
    standard install_configure_form.update_status_module='array(FALSE,FALSE)'
fi

if [[ $USE_SQLITE -eq 1 ]]; then
  # Fix permissions as per https://api.drupal.org/api/drupal/core!INSTALL.sqlite.txt/8.1.x
  chown drupaladmin:www-data "${SQLITE_DIR}" "${SQLITE_LOCATION}"
  chmod 660 "${SQLITE_LOCATION}"
fi

# Enable the modules that must be present, regardless of configuration.
# Note that configuration in active/ will automatically enable any module it refers to, so
# the modules listed below are only really relevant for a barebones no-configuration system.
# Basically, Day 1 of the source code.

echo Enabling the Security Review module ...
drush -y pm-enable security_review

echo Enabling the Update Manager module ...
drush -y pm-enable update

echo Enabling the Backup Database module ...
drush -y pm-enable backup_db

echo Enabling the Flysystem modules ...
drush -y pm-enable flysystem flysystem_s3

echo Enabling the Advanced CSS JS aggregation module ...
drush -y pm-enable advagg

echo Enabling the Loadbalancing cookie
drush -y pm-enable loadbalancing_cookie
