#!/bin/bash
# vim: set tabstop=2 shiftwidth=2 expandtab smartindent:

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

# private files. https://www.drupal.org/documentation/modules/file
# They are needed for drupal/backup_db
echo "\$settings['file_private_path'] = '/var/www/private';" >> ${SETTINGS}

# flywheel for local + remote file access
cat /var/lib/site/settings/flysystem-local.php >> ${SETTINGS}

# Use file-based configuration rather than database-base configuration
# https://www.drupal.org/node/2291587

STORAGE_CONFIG=/var/lib/site/storage-config
HAVE_STORED_CONFIG=1
if [[ ! -e ${STORAGE_CONFIG}/active/system.site.yml ]]; then # there is no Docker mount to a 'git' workspace
  HAVE_STORED_CONFIG=0
  install -d ${STORAGE_CONFIG}
  install -o drupaladmin -d ${STORAGE_CONFIG}/staging # configs for manual import should never be modified by the running Drupal system
  install -o drupaladmin -g www-data -m 775 -d ${STORAGE_CONFIG}/active ${STORAGE_CONFIG}/sync
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
    --verbose \
    config_installer install_configure_form.update_status_module='array(FALSE,FALSE)'

else
  echo Doing a no-configuration site installation ...

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
