# Make the changes

Your typical workflow would be:

1. Get the latest public Docker image with `docker pull plainlychrist/site-web:unstable`
2. Run `site-ec2-linux-desktop` with [Docker Compose for site-ec2-linux-desktop](https://github.com/plainlychrist/applications/tree/master/site/site-ec2-linux-desktop)
3. Log into your newly running website. Do whatever web site content changes you want (if any).
4. Run any pending upgrades (usually from a Drupal security update that was autobuilt on GitHub) by going to https://your_new_site/update.php
5. Run the **security review checklist** by going to https://your_new_site/admin/reports/security-review and clicking `Run > Run checklist`
6. [Upgrade the configuration](../UPGRADING-CONFIG.md), but stop at the `git commit` step
7. Go into your `site-web` directory (where you can do `git` commands). Verify by running `git remote -v` and make sure you see `https://github.com/plainlychrist/site-web.git`
8. Run `docker exec -it siteec2linuxdesktop_web_1 /home/drupaladmin/bin/drush cr`. Then run `docker exec -it siteec2linuxdesktop_web_1 runuser -u www-data /var/lib/site/bin/sanitized-backup.sh`. **If it fails** with a bunch of SQL statements after `Comparing /var/lib/site/resources/sanitized-backup/database_structure.txt against the output` or does not say `COMPLETE: Done`, then you must:
    * Decide whether the database changes (you may have had an Drupal security update, or you may have installed a new module) are what you wanted. If they are not, **start over**.
    * Copy the *drush* command it gave you. We'll assume it was `/home/drupaladmin/bin/drush sql-dump --extra='--no-data --no-create-db --skip-create-options --skip-lock-tables --compact'` below. Change it below if it is different.
    * Run:
        ```
        docker exec -it siteec2linuxdesktop_web_1 /home/drupaladmin/bin/drush sql-dump --extra='--no-data --no-create-db --skip-create-options --skip-lock-tables --compact' | bash -c 'tr -d $"\r"' > filesystem/var/lib/site/resources/sanitized-backup/database_structure.txt

        docker cp filesystem/var/lib/site/resources/sanitized-backup/database_structure.txt siteec2linuxdesktop_web_1:/var/lib/site/resources/sanitized-backup/database_structure.txt
        ```
    * Go back and re-run this step (`sanitized-backup.sh`), and make sure it doesn't fail.
9. Run the following to make a new bootstrap database template from the sanitized backup:
    ```
    (cd filesystem/var/lib/site/bootstrap/default && BURL=https://localhost/sites/default/files/public-backups/ && curl -k -s -o /tmp/latest.txt $BURL/latest.txt && LTT=$(< /tmp/latest.txt) && B=2010-01-01.00-00-000 && echo $B > latest.txt && curl -k -s -o $B.plain-dump.sql.txt $BURL/$LTT.plain-dump.sql.txt && curl -k -s -o $B.sanitized-dump.sql.txt $BURL/$LTT.sanitized-dump.sql.txt && curl -k -s -o $B.sanitized-restore.sql.txt $BURL/$LTT.sanitized-restore.sql.txt && curl -k -s -o $B.sites-default-files.tar.xz $BURL/$LTT.sites-default-files.tar.xz)
    ```
10. Rebuild the Docker image on your machine with `docker build -t plainlychrist/site-web:unstable .`

# Test the changes

1. Re-run `site-ec2-linux-desktop` with [Docker Compose for site-ec2-linux-desktop](https://github.com/plainlychrist/applications/tree/master/site/site-ec2-linux-desktop)
2. Log into your newly running website. All your changes should be there. If not, **start all over again**.
3. Run `site-web` with [the RUNNING instructions](../RUNNING.md)
4. Log into your newly running website. All your changes should be there. If not, **start all over again**.

# Send the changes for review

1. Since you are satisfied, go into your `site-web` directory (where you can do `git` commands). Verify by running `git remote -v` and make sure you see `https://github.com/plainlychrist/site-web.git`
2. Check all your changes with `git status` and `git diff`
3. Commit your changes with `git add filesystem/var/lib/site` and `git commit`
4. Push it into your Git repository with `git push`
5. Ask a committer, like jonah.beckford@plainlychrist.org for plainlychrist.org, to "pull" your changes.
