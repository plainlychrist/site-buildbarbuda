
## Linux on Amazon EC2

These instructions are for Amazon Linux only. Your mileage may vary if you launched with any other Linux distribution (RedHat, etc.).

First, follow the **eight (8)** instructions on the [Amazon EC2 Container Service "Installing Docker"](http://docs.aws.amazon.com/AmazonECS/latest/developerguide/docker-basics.html#install_docker) section.

Then do these steps:
```bash
sudo touch ~/site.drupaladmin.history ~/site.root.history
docker rm -f site-buildbarbuda # this is fine if this fails
docker run -d -p 443:443 --name site-buildbarbuda --env WEB_ADMIN_PASSWORD=...make...up...a...password -v ~/site.root.history:/root/.bash_history -v ~/site.drupaladmin.history:/home/drupaladmin/.bash_history plainlychrist/site-buildbarbuda:unstable --trust-this-ec2-host --trust-this-ec2-local-ipv4
docker logs --follow site-buildbarbuda
```

## Windows 10 Professional or Enterprise 64-bit

**These instructions will NOT work on Windows 10 Home, or earlier versions of Windows.**

* Download and install https://download.docker.com/win/stable/InstallDocker.msi
* Open `Power Shell` and run the following:

```bash
touch $HOME/site.drupaladmin.history $HOME/site.root.history
docker rm -f site-buildbarbuda # this is fine if this fails
docker run -d -p 443:443 --name site-buildbarbuda --env WEB_ADMIN_PASSWORD=...make...up...a...password -v $HOME/plainlychrist.site.root.history:/root/.bash_history -v $HOME/plainlychrist.site.drupaladmin.history:/home/drupaladmin/.bash_history plainlychrist/site-buildbarbuda:unstable
docker logs --follow site-buildbarbuda
```

You will see your site on https://localhost

### Downloading the source code

* Download and install https://desktop.github.com/
* Open `GitHub Desktop` Windows app, and *Clone* the "URL" repository `https://github.com/plainlychrist/site-buildbarbuda.git` into your `Documents` directory

### Changing the styling

*NOTE: You will need a Linux machine to build code changes, except for theme (styling) changes*

One terminal for running the website:

```bash
cd $HOME/Documents/site-buildbarbuda
docker rm -f site-buildbarbuda
docker run -p 443:443 --name site-buildbarbuda --env WEB_ADMIN_PASSWORD=...make...up...a...password -v $HOME/plainlychrist.site.history:/root/.bash_history -v $HOME\Documents\site-buildbarbuda\filesystem\var\www\html\sites\all\themes:/var/www/html/sites/all/themes plainlychrist/site-buildbarbuda:unstable
```

Another terminal for automatically recompiling the CSS files:

```bash
cd $HOME/Documents/site-buildbarbuda
docker exec site-buildbarbuda bash -c 'cd /tmp && chmod -R a+w /var/www/html/sites/all/themes/directjude && sass --default-encoding UTF-8 --debug-info --watch /var/www/html/sites/all/themes/directjude/sass/style.scss:/var/www/html/sites/all/themes/directjude/css/style.css'
```

## Accessing the Linux website container

*This assumes that your container has been started with a `docker run ...` command*

```
docker cp filesystem-dev/root site-buildbarbuda:/
docker cp filesystem-dev/home site-buildbarbuda:/
docker cp filesystem-dev/var site-buildbarbuda:/
docker exec -it site-buildbarbuda /root/dev.sh

docker exec -it site-buildbarbuda env - TERM=xterm-color /sbin/runuser -l -s /bin/bash drupaladmin

cd /var/www/html

# Then you can do 'drush' or 'drupal' commands ... like the following:
drupal module:install group
drush status
```

## Debugging a failed, stopped container

```bash
docker commit -m "Debugging" site-buildbarbuda plainlychrist/site-buildbarbuda:debugging && docker run -it --entrypoint '/bin/bash' plainlychrist/site-buildbarbuda:debugging --login
```
