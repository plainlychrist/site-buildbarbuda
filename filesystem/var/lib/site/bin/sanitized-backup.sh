#!/bin/bash
# vim: set tabstop=2 shiftwidth=2 expandtab smartindent:
set -euo pipefail

# global variables
DRUSH=~drupaladmin/bin/drush
DT=$(/bin/date --utc +%Y-%m-%d.%H-%M-%S)
STRUCTURE_TABLES_LIST=backup_db,batch,cache_bootstrap,cache_config,cache_container,cache_data,cache_default,cache_discovery,cache_dynamic_page_cache,cache_entity,cache_flysystem,cache_menu,cache_render,cache_toolbar,cachetags,flood,history,queue,semaphore,sessions,watchdog

# skip users_field_data because it has identifiable information in it
# skip site_phase[12] because it is used only for signalling multiple machines in the Drupal installation
SKIP_TABLES_LIST=users_field_data,site_phase1,site_phase2

# relative paths
echo "Moving into /var/www/html directory ..."
cd /var/www/html
REL_PUBLIC_BACKUPS=sites/default/files/public-backups

# Make sure we are not leaking data by *not* backing up if the table structure has not been vetted.
# diff --unchanged-line-format= --old-line-format= --new-line-format='%5dn: %L' ...:
#   We make sure that the database does not contain any new tables that we don't already know about, and does not contain any differences with tables we do know about
#   We skip any tables that we know about, but are not yet in the database (why? b/c the cache tables are created on-demand)
# diff --line-format='%L' /dev/null ...:
#   If there is anything new or different from above, then print it and set the exit code to non-zero
DUMP_EXTRA='--no-data --no-create-db --skip-create-options --skip-lock-tables --compact'
DUMP_CMP=/var/lib/site/resources/sanitized-backup/database_structure.txt
echo "Comparing ${DUMP_CMP} against the output of the following to see if there are new or different tables: ${DRUSH} sql-dump --extra='${DUMP_EXTRA}'"
set +o pipefail
${DRUSH} sql-dump --extra="${DUMP_EXTRA}" | /usr/bin/diff --unchanged-line-format= --old-line-format= --new-line-format='%5dn: %L' ${DUMP_CMP} - | diff --line-format='%L' /dev/null - || exit 1
set -o pipefail

# Do the backup of the majority of tables
DATA_EXTRA='--skip-comments'
echo Creating ${REL_PUBLIC_BACKUPS}/${DT}.plain-dump.sql.txt.gz ...
${DRUSH} sql-dump --extra="${DATA_EXTRA}" --ordered-dump --structure-tables-list=${STRUCTURE_TABLES_LIST} --skip-tables-list=${SKIP_TABLES_LIST} --result-file=${REL_PUBLIC_BACKUPS}/${DT}.plain-dump.sql.txt
gzip ${REL_PUBLIC_BACKUPS}/${DT}.plain-dump.sql.txt

# SECFIX.1: sql-dump --tables-list=xxx, if xxx does not exist, will dump all the tables. So we create uniquely named tables so no race condition attacks
SANTBL_UFD="san_$(echo $$ $(/bin/hostname) $(/bin/date +%s.%N) | /usr/bin/sha224sum | /usr/bin/awk '{print $1}')"
SANITIZED_TABLES_LIST="${SANTBL_UFD}"
function cleanup_sanitized {
    ${DRUSH} sql-query "DROP TABLE IF EXISTS ${SANTBL_UFD}"
}
trap cleanup_sanitized EXIT

# Create a sanitized table
echo "Sanitizing tables ..."
${DRUSH} sql-query "CREATE TABLE ${SANTBL_UFD} LIKE users_field_data"
${DRUSH} sql-query "INSERT INTO ${SANTBL_UFD}
    SELECT
        uid, langcode, NULL as preferred_langcode, NULL as preferred_admin_langcode,
	CASE WHEN name='' THEN '' ELSE SHA2(CONCAT(RAND(), name), 224) END as name,
	NULL as pass, NULL as mail,
	timezone, 0 as status,
	created, NULL as changed, created as access,
	NULL as login, NULL as init, default_langcode
    FROM users_field_data"

# Do the backup of sanitized tables
echo Creating ${REL_PUBLIC_BACKUPS}/${DT}.sanitized-dump.sql.txt.gz ...
${DRUSH} sql-dump --extra="${DATA_EXTRA}" --ordered-dump --tables-list=${SANITIZED_TABLES_LIST} --result-file=${REL_PUBLIC_BACKUPS}/.${DT}.sanitized.sql.unknown
if [ "$(/bin/grep '^CREATE TABLE' ${REL_PUBLIC_BACKUPS}/.${DT}.sanitized.sql.unknown | /usr/bin/wc -l)" != "1" ]; then
  # another failsafe in case the SECFIX.1 fails ... we should only have one (1) table ... the sanitized table!
  echo "SECFIX.1"
  exit 1
else
  # The webserver will not serve files with a leading dot "." nor with unknown extensions, which we did on purpose to mitigate SECFIX.1
  gzip -c ${REL_PUBLIC_BACKUPS}/.${DT}.sanitized.sql.unknown > ${REL_PUBLIC_BACKUPS}/${DT}.sanitized-dump.sql.txt.gz
  rm -f ${REL_PUBLIC_BACKUPS}/.${DT}.sanitized.sql.unknown
fi

# Make sure the sanitized tables restore themselves
echo 'DROP TABLE IF EXISTS `users_field_data`;' > ${REL_PUBLIC_BACKUPS}/${DT}.sanitized-restore.sql.txt
echo 'ALTER TABLE `'"${SANTBL_UFD}"'` RENAME TO `users_field_data`;' >> ${REL_PUBLIC_BACKUPS}/${DT}.sanitized-restore.sql.txt
gzip ${REL_PUBLIC_BACKUPS}/${DT}.sanitized-restore.sql.txt

# Cleanup gracefully now that we are done (rather than hope that EXIT trap works)
cleanup_sanitized

# Make a backup of all the files
# - Don't need the js_ and css_ aggregations (https://www.keycdn.com/blog/speed-up-drupal/#css)
# - Don't need the php twig precompilations (https://www.drupal.org/docs/8/theming/twig/debugging-compiled-twig-templates)
# - Don't need to backup the backups
# - Don't need the .htaccess, which will be ignored anyway during restoration

echo Creating tar backup of public files at ${REL_PUBLIC_BACKUPS}/${DT}.sites-default-files.tar.xz ...
/bin/tar --create --xz --directory /var/www/html/sites/default/files --file ${REL_PUBLIC_BACKUPS}/${DT}.sites-default-files.tar.xz \
    --exclude="./js/js_*" \
    --exclude="./css/css_*" \
    --exclude="./php/twig/*" \
    --exclude="./public-backups/*" \
    --exclude ".htaccess" \
    .

echo Creating tar backup of flysystem files at ${REL_PUBLIC_BACKUPS}/${DT}.flysystem-main.tar.xz ...
/bin/tar --create --xz --directory /var/www/flysystem --file ${REL_PUBLIC_BACKUPS}/${DT}.flysystem-main.tar.xz \
    --exclude ".htaccess" \
    .

# Update the reference atomically
echo ${DT} > ${REL_PUBLIC_BACKUPS}/latest.txt.tmp
mv -f ${REL_PUBLIC_BACKUPS}/latest.txt.tmp ${REL_PUBLIC_BACKUPS}/latest.txt
echo Updated ${REL_PUBLIC_BACKUPS}/latest.txt. Done

# Remove older backups than 15 days ago
echo Removing much older backups ...
find /var/www/html/sites/default/files/public-backups -type f -mtime +15 -exec rm -vf {} +

echo Done
