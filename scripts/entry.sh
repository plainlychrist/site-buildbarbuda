#!/bin/bash
# vim: set tabstop=2 shiftwidth=2 expandtab:
set -euo pipefail

usage()
{
  echo "Options: " >&2
    echo "-h   Display this help" >&2
    echo "-t   Add a trusted host pattern, as per https://www.drupal.org/node/1992030. Can be repeated" >&2
    echo "-m   Use MySQL. Expects MYSQL_DATABASE, MYSQL_USER and MYSQL_PASSWORD environment variables, with 'db' as the hostname" >&2
}

TRUSTED_HOST_PATTERNS=()
USE_MYSQL=0
while getopts "hmt:" opt; do
  case $opt in
    h)
      usage
      exit 0
      ;;
    t)
      TRUSTED_HOST_PATTERNS+=( $OPTARG )
      ;;
    m)
      USE_MYSQL=1
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      ;;
  esac
done
shift $((OPTIND-1))

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

    if test -e /var/lib/site/config/sites/default/sync; then

      install -m 666 /var/www/html/sites/default/default.settings.php /var/www/html/sites/default/settings.php
      echo "\$config_directories[CONFIG_SYNC_DIRECTORY] = '/var/lib/site/config/sites/default/sync';" >> /var/www/html/sites/default/settings.php
      drush -y site-install --db-url="${DB_URL}" \
        --account-name=admin \
        --account-pass="${WEB_ADMIN_PASSWORD}" \
        config_installer install_configure_form.update_status_module='array(FALSE,FALSE)' ;

    else
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

      echo Doing the site installation ...
      drush -y site-install --db-url="${DB_URL}" \
        --account-name=admin \
        --account-pass="${WEB_ADMIN_PASSWORD}" \
        --account-mail=no-reply@plainlychrist.org \
        --site-name="PlainlyChrist.org" \
        --site-mail=no-reply@plainlychrist.org \
        standard install_configure_form.update_status_module='array(FALSE,FALSE)'

      echo Securing POSIX permissions ...
      # https://www.drupal.org/node/244924
      find /var/www/html -type f -exec chmod a-w {} \;
      find /var/www/html -type d -exec chmod a-w {} \;
      chown -R www-data /var/www/html/sites/default/files
      find /var/www/html/sites/default/files -type d -exec chmod u+w {} \;

      if [[ $USE_SQLITE -eq 1 ]]; then
        # Fix permissions as per https://api.drupal.org/api/drupal/core!INSTALL.sqlite.txt/8.1.x
        chown www-data "${SQLITE_DIR}" "${SQLITE_LOCATION}"
        chmod 600 "${SQLITE_LOCATION}"
      fi

      echo Setting the default theme to Zymphonies ...
      drush -y pm-enable drupal8_zymphonies_theme
      drush -y cset system.theme default drupal8_zymphonies_theme

      echo Enabling the Security Review module ...
      drush -y pm-enable security_review

      echo Enabling the Update Manager module ...
      drush -y pm-enable update
    fi 
fi

# Then run CMD (apache2-foreground) from php:apache in https://hub.docker.com/_/php/
echo Starting the Apache server in foreground ...
exec apache2-foreground
