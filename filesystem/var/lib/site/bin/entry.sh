#!/bin/bash
# vim: set tabstop=2 shiftwidth=2 expandtab smartindent:
set -euo pipefail

function usage()
{
  echo "Options: " >&2
    echo "-h                              Display this help" >&2
    echo "-t|--trust-host-pattern REGEX   Add a trusted host pattern, as per https://www.drupal.org/node/1992030. Can be repeated" >&2
    echo "--trust-this-host               Add the result of running 'hostname' as a trusted host pattern, as per https://www.drupal.org/node/1992030" >&2
    echo "--trust-this-ec2-host           Add the public DNS name of this EC2 host as a trusted host pattern, as per https://www.drupal.org/node/1992030" >&2
    echo "-m|--use-mysql                  Use MySQL. Expects the MYSQL_PASSWORD environment variable to be set. MYSQL_DATABASE, MYSQL_USER, MYSQL_HOST and MYSQL_PORT are optional, and default to 'drupal', 'drupal', 'db' and '3306', respectively, for convenience with Docker links" >&2
    echo "-b|--bootstrap WEBSITE_URL      Bootstrap the data from a live website. This will fetch the latest available snapshot of the data, and only a sanitized (the users are stripped of identifying information) version of that data. The WEBSITE_URL can be https://plainlychrist.org; you MUST TRUST the site as the site will have the ability to install arbitrary code on your site. The bootstrapping will only occur if there is no data yet on your site. The live data is from a MySQL database, and is automatically converted to SQLite if you are not using MySQL yourself; that conversion is not perfect, so using MySQL is recommended" >&2
}

function drush()
{
  runuser -u drupaladmin -- /home/drupaladmin/bin/drush "$@"
}

# process command line
TRUSTED_HOST_PATTERNS=()
USE_MYSQL=0
BOOTSTRAP_URL=""
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
    -b|--bootstrap)
      BOOTSTRAP_URL="$2"
      shift 2
      ;;
    -t|--trust-host-pattern)
      TRUSTED_HOST_PATTERNS+=( $2 )
      shift 2
      ;;
    --trust-this-host)
      TRUSTED_HOST_PATTERNS+=( "^$(hostname)$" )
      shift
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
  # supply defaults
  MYSQL_DATABASE=${MYSQL_DATABASE:-drupal}
  MYSQL_HOST=${MYSQL_HOST:-db}
  MYSQL_PORT=${MYSQL_PORT:-3306}
  MYSQL_USER=${MYSQL_USER:-drupal}
  DB_URL="mysql://${MYSQL_USER}:${MYSQL_PASSWORD}@${MYSQL_HOST}:${MYSQL_PORT}/${MYSQL_DATABASE}"
  echo   "mysql://${MYSQL_USER}:.................@${MYSQL_HOST}:${MYSQL_PORT}/${MYSQL_DATABASE}"
  USE_SQLITE=0

  echo Waiting for at most 30 seconds for MySQL to come alive ...
  php -r "
  for (\$i = 1; \$i <= 30; \$i++) {
    try {
        \$dbh = new PDO('mysql:host=${MYSQL_HOST};port=${MYSQL_PORT};dbname=${MYSQL_DATABASE}', '${MYSQL_USER}', '${MYSQL_PASSWORD}', array( PDO::ATTR_PERSISTENT => false));
        if (\$dbh->query('SELECT 1')) { echo \"Connected to MySQL\n\"; exit; }
    } catch (PDOException \$e) {
        echo 'WARN: Retrying connection to MySQL: ', \$e->getMessage(), \"\n\";
        sleep(1);
    }
  }
  echo \"FATAL: Could not connect to MySQL\n\";
  "

elif [[ $USE_SQLITE -eq 1 ]]; then
  install -o drupaladmin -g www-data -m 770 -d ${SQLITE_DIR}
fi

# Install drupal, specifically sites/default/settings.php
if drush core-status drupal-settings-file | grep MISSING; then
  source /var/lib/site/bin/entry-bootstrap.sh
fi

# https://www.drupal.org/node/244924
echo Securing POSIX permissions for web account ...
find /var/www/html -type f -exec chmod a-w {} \;
find /var/www/html -type d -exec chmod a-w {} \;
install -o drupaladmin -g www-data -m 755 -d /var/www/html/modules
install -o drupaladmin -g www-data -m 750 -d /var/www/html/sites/default/files/public-backups
chown -R drupaladmin:www-data /var/www/html/sites/default/files /var/lib/site/storage-config/active /var/lib/site/storage-config/sync
find /var/www/html/sites/default/files -type d -exec chmod 770 {} \;
find /var/lib/site/storage-config/active -type d -exec chmod 770 {} \;
find /var/lib/site/storage-config/active -type f -exec chmod 664 {} \;
find /var/lib/site/storage-config/sync -type d -exec chmod 770 {} \;

# Applying security advisory: https://www.drupal.org/SA-CORE-2013-003
install -o drupaladmin -g www-data -m 444 /var/lib/site/settings/private.htaccess /var/www/flysystem/.htaccess
install -o drupaladmin -g www-data -m 444 /var/lib/site/settings/private.htaccess /var/www/private/.htaccess

# Launch Apache and cron, with a supervisor to manage the two processes
echo Starting the supervisor in the foreground ...
exec supervisord -c /etc/supervisor/conf.d/supervisord.conf
