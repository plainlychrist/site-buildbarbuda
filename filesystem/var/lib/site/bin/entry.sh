#!/bin/bash
# vim: set tabstop=2 shiftwidth=2 expandtab smartindent:
set -euo pipefail

function usage()
{
  echo "Options: " >&2
    echo "-h                              Display this help" >&2
    echo "--hash-salt SALT                Use the specified hash salt, which we recommend to be the same across machines behind the same Drupal load balancer. If not specified, each installation gets its own unique hash salt, which means CSRF tokens may not work without sticky sessions. A good way to generate a hash salt is: openssl rand -base64 64 | tr -d '\\n'" >&2
    echo "-t|--trust-host-pattern REGEX   Add a trusted host pattern, as per https://www.drupal.org/node/1992030. Can be repeated" >&2
    echo "--trust-this-host               Add the result of running 'hostname' as a trusted host pattern, as per https://www.drupal.org/node/1992030" >&2
    echo "--trust-this-ec2-host           Add the public DNS name of this EC2 host as a trusted host pattern, as per https://www.drupal.org/node/1992030" >&2
    echo "--trust-this-ec2-local-ipv4     Add the local IP4 address of this EC2 host, used by AWS ELB for health checks, as a trusted host pattern, as per https://www.drupal.org/node/1992030" >&2
    echo "-m|--use-mysql                  Use MySQL. Expects the MYSQL_PASSWORD environment variable to be set. MYSQL_DATABASE, MYSQL_USER, MYSQL_HOST and MYSQL_PORT are optional, and default to 'drupal', 'drupal', 'db' and '3306', respectively, for convenience with Docker links" >&2
    echo "-p|--use-postfix                Use Postfix with TLS and SASL security. Expects the POSTFIX_DOMAIN, POSTFIX_RELAY_HOST, POSTFIX_USER, POSTFIX_PASSWORD environment variables to be set. POSTFIX_RELAY_PORT, POSTFIX_SASL_SECURITY_OPTIONS, and POSTFIX_SASL_TLS_SECURITY_OPTIONS are optional, and default to 587, 'noanonymous,noplaintext' and 'noanonymous', respectively. Typically POSTFIX_DOMAIN is your email domain (the part after the @ in your email address), and POSTFIX_USER is the full email address of whoever is allowed to send out emails, and POSTFIX_RELAY_HOST is the name of your SMTP server" >&2
    echo "-b|--bootstrap WEBSITE_URL      Bootstrap the data from a live website. This will fetch the latest available snapshot of the data, and only a sanitized (the users are stripped of identifying information) version of that data. The WEBSITE_URL can be https://buildbarbuda.org; you MUST TRUST the site as the site will have the ability to install arbitrary code on your site. The bootstrapping will only occur if there is no data yet on your site. The live data is from a MySQL database, and is automatically converted to SQLite if you are not using MySQL yourself; that conversion is not perfect, so using MySQL is recommended" >&2
    echo "--no-op                         This option will be ignored, and is only needed as a placeholder for automated tools that call this script" >&2
    echo "--no-start                      Do not start the supervisor daemon. Useful for debugging instead the container" >&2
}

function drush()
{
  runuser -u drupaladmin -- /home/drupaladmin/bin/drush "$@"
}

# process command line
TRUSTED_HOST_PATTERNS=()
USE_MYSQL=0
USE_POSTFIX=0
BOOTSTRAP_URL=""
HASH_SALT=""
NO_START=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 2
      ;;
    --no-op)
      shift
      ;;
    -m|--use-mysql)
      USE_MYSQL=1
      shift
      ;;
    -p|--use-postfix)
      USE_POSTFIX=1
      shift
      ;;
    --hash-salt)
      HASH_SALT="$2"
      shift 2
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
    --trust-this-ec2-local-ipv4)
      LOCAL_IPV4="^$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4 | sed 's/[.]/\\./g')$"
      TRUSTED_HOST_PATTERNS+=( ${LOCAL_IPV4} )
      shift
      ;;
    --no-start)
      NO_START=1
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
else
  echo "Skipped bootstrapping because 'drush core-status drupal-settings-file' does not report MISSING"
fi

# http://www.postfix.org/SASL_README.html#client_sasl
echo Configuring postfix for emails ...
cp /etc/resolv.conf /var/spool/postfix/etc/resolv.conf
if [[ $USE_POSTFIX -eq 1 ]]; then
  POSTFIX_SASL_SECURITY_OPTIONS=${POSTFIX_SASL_SECURITY_OPTIONS:-noanonymous,noplaintext}
  POSTFIX_SASL_TLS_SECURITY_OPTIONS=${POSTFIX_SASL_TLS_SECURITY_OPTIONS:-noanonymous}
  POSTFIX_RELAY_PORT=${POSTFIX_RELAY_PORT:-587}
  postconf -e smtp_use_tls=yes
  postconf -e mydomain="${POSTFIX_DOMAIN}"
  postconf -e myorigin="${POSTFIX_DOMAIN}"
  postconf -e "relayhost=[${POSTFIX_RELAY_HOST}]:${POSTFIX_RELAY_PORT}"
  postconf -e smtp_sasl_auth_enable=yes
  postconf -e smtp_sasl_password_maps=hash:/etc/postfix/sasl_passwd
  postconf -e smtp_sasl_security_options="${POSTFIX_SASL_SECURITY_OPTIONS}"
  postconf -e smtp_sasl_tls_security_options="${POSTFIX_SASL_TLS_SECURITY_OPTIONS}"
  echo "[${POSTFIX_RELAY_HOST}]:${POSTFIX_RELAY_PORT} ${POSTFIX_USER}:${POSTFIX_PASSWORD}" > /etc/postfix/sasl_passwd
  postmap /etc/postfix/sasl_passwd
fi

# https://www.drupal.org/node/244924
echo Securing POSIX permissions for web account ...
set -x
chmod -R a-w /var/www/html
install -o drupaladmin -g www-data -m 755 -d /var/www/html/modules
install -o drupaladmin -g www-data -m 750 -d /var/www/html/sites/default/files/public-backups
chown -R drupaladmin:www-data /var/www/html/sites/default/files /var/lib/site/storage-config/sync /var/www/private
find /var/www/html/sites/default/files -type d -print0 | xargs -0 chmod 770
find /var/lib/site/storage-config/sync -type d -print0 | xargs -0 chmod 770
find /var/www/private -type d -print0 | xargs -0 chmod 770
chown -R www-data:drupaladmin /var/lib/site/storage-config/active # the update.php will try to chmod here, which means www-data needs to be owner
find /var/lib/site/storage-config/active -type d -print0 | xargs -0 chmod 770
find /var/lib/site/storage-config/active -type f -print0 | xargs -0 --no-run-if-empty chmod 664
set +x

# Applying security advisory: https://www.drupal.org/SA-CORE-2013-003
install -o drupaladmin -g www-data -m 444 /var/lib/site/settings/private.htaccess /var/www/private/.htaccess

if [[ $NO_START -eq 0 ]]; then
  # Launch Apache and cron, with a supervisor to manage the two processes
  echo Starting the supervisor in the foreground ...
  exec supervisord -c /etc/supervisor/conf.d/supervisord.conf
fi
