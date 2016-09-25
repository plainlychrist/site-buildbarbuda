#!/bin/bash
# vim: set tabstop=2 shiftwidth=2 expandtab smartindent:
set -euo pipefail

# global variables
DRUSH=~drupaladmin/bin/drush
DT=$(date --utc +%Y-%m-%d.%H-%M-%S)
SKIP_TABLES_LIST=users_field_data
STRUCTURE_TABLES_LIST=backup_db,batch,cache_bootstrap,cache_config,cache_container,cache_data,cache_default,cache_discovery,cache_dynamic_page_cache,cache_entity,cache_flysystem,cache_menu,cache_render,cache_toolbar,cachetags,flood,history,queue,semaphore,sessions,watchdog

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

# Do the backup
echo Creating ${REL_PUBLIC_BACKUPS}/${DT}.sql.txt ...
${DRUSH} sql-dump --structure-tables-list=${STRUCTURE_TABLES_LIST} --skip-tables-list=${SKIP_TABLES_LIST} --result-file=${REL_PUBLIC_BACKUPS}/${DT}.sql.txt

# Update the reference atomically
echo ${DT} > ${REL_PUBLIC_BACKUPS}/latest.txt.tmp
mv ${REL_PUBLIC_BACKUPS}/latest.txt.tmp ${REL_PUBLIC_BACKUPS}/latest.txt
echo Updated ${REL_PUBLIC_BACKUPS}/latest.txt. Done
