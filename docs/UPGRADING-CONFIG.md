Your typical workflow would be:

1. Run either:
    * `site-web` with [the RUNNING instructions](../RUNNING.md)
    * `site-ec2-linux-desktop` with [Docker Compose for site-ec2-linux-desktop](https://github.com/plainlychrist/applications/tree/master/site/site-ec2-linux-desktop)
2. Do all your configuration changes by logging into your newly running website and going to `https://your_web_site/admin/config`
3. Regardless of how your website was started, you must go into your `site-web` directory (where you can do `git` commands). Verify by running `git remote -v` and make sure you see `https://github.com/plainlychrist/site-web.git`
4. Copy your new configuration with either:
    * `docker cp site-web:/var/lib/site/storage-config/active/ filesystem/var/lib/site/storage-config/` if you originally ran `site-web`
    * `docker cp siteec2linuxdesktop_web_1:/var/lib/site/storage-config/active/ filesystem/var/lib/site/storage-config/` if you originally ran [Docker Compose for site-ec2-linux-desktop](https://github.com/plainlychrist/applications/tree/master/site/site-ec2-linux-desktop)
5. Verify your changes with `git status` and `git diff`
6. Commit your changes with `git add filesystem/var/lib/site/storage-config/active` and `git commit`
7. Push it into your Git repository with `git push`
8. Ask a committer, like jonah.beckford@plainlychrist.org for plainlychrist.org, to "pull" your changes.
