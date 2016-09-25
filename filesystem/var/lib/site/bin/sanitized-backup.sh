#!/bin/bash
# vim: set tabstop=2 shiftwidth=2 expandtab smartindent:
set -euo pipefail

# global variables
DRUSH=~drupaladmin/bin/drush
DT=$(date --utc +%Y-%m-%d.%H-%M-%S)
SKIP_TABLES_LIST=users_field_data
STRUCTURE_TABLES_LIST=backup_db,batch,cache_bootstrap,cache_config,cache_container,cache_data,cache_default,cache_discovery,cache_dynamic_page_cache,cache_entity,cache_flysystem,cache_menu,cache_render,cache_toolbar,cachetags,flood,history,queue,semaphore,sessions,watchdog

# relative paths
cd /var/www/html
REL_PUBLIC_BACKUPS=sites/default/files/public-backups

# Make sure we are not leaking data by *not* backing up if the table structure has not been vetted
# diff is for visualizing; cmp is for exiting on differences
${DRUSH} sql-dump --extra="--no-data --no-create-db --skip-create-options --skip-lock-tables --compact" | /usr/bin/diff /var/lib/site/resources/sanitized-backup/database_structure.txt -
${DRUSH} sql-dump --extra="--no-data --no-create-db --skip-create-options --skip-lock-tables --compact" | /usr/bin/cmp /var/lib/site/resources/sanitized-backup/database_structure.txt || exit 1

# Do the backup
${DRUSH} sql-dump --structure-tables-list=${STRUCTURE_TABLES_LIST} --skip-tables-list=${SKIP_TABLES_LIST} --result-file=${REL_PUBLIC_BACKUPS}/${DT}.sql.txt

# Update the reference atomically
echo ${DT} > ${REL_PUBLIC_BACKUPS}/latest.txt.tmp
mv ${REL_PUBLIC_BACKUPS}/latest.txt.tmp ${REL_PUBLIC_BACKUPS}/latest.txt
