
## Linux on Amazon EC2

These instructions are for Amazon Linux only. Your mileage may vary if you launched with any other Linux distribution (RedHat, etc.).

First, follow the **eight (8)** instructions on the [Amazon EC2 Container Service "Installing Docker"](http://docs.aws.amazon.com/AmazonECS/latest/developerguide/docker-basics.html#install_docker) section.

Then do these steps:
```bash
docker rm -f site-buildbarbuda # this is fine if this fails
docker run -d -p 443:443 --name site-buildbarbuda --env WEB_ADMIN_PASSWORD=...make...up...a...password -v ~/site.history:/root/.bash_history plainlychrist/site-buildbarbuda:unstable --trust-this-ec2-host --trust-this-ec2-local-ipv4
docker logs --follow site-buildbarbuda
```

## Windows 10 Professional or Enterprise 64-bit

These instructions will not work on Windows 10 Home, or earlier versions of Windows.

* Download and install https://download.docker.com/win/stable/InstallDocker.msi
* Download and install https://desktop.github.com/
* Open `GitHub` desktop app, and add a new Repository `https://github.com/plainlychrist/site-buildbarbuda.git` into your `Documents` directory
* Open `Git Shell` and run the following:

```bash
cd $HOME/Documents
git clone https://github.com/plainlychrist/site-buildbarbuda.git
docker rm -f site-buildbarbuda
docker run -p 443:443 --name site-buildbarbuda --env WEB_ADMIN_PASSWORD=...make...up...a...password -v $HOME /plainlychrist.site.history:/root/.bash_history plainlychrist/site-buildbarbuda:unstable
```

You will see your site on https://localhost

### Changing the styling

*NOTE: You will need a Linux machine to build code changes, except for theme (styling) changes*

One terminal for running the website:

```bash
cd $HOME/Documents/site-buildbarbuda
docker rm -f site-buildbarbuda
docker run -p 443:443 --name site-buildbarbuda --env WEB_ADMIN_PASSWORD=...make...up...a...password -v $HOME /plainlychrist.site.history:/root/.bash_history -v $HOME\Documents\site-buildbarbuda\filesystem\var\www\html\sites\all\themes:/var/www/html/sites/all/themes plainlychrist/site-buildbarbuda:unstable
```

Another website for automatically recompiling the CSS files:

```bash
cd $HOME/Documents/site-buildbarbuda
docker exec site-buildbarbuda bash -c 'cd /tmp && chmod -R a+w /var/www/html/sites/all/themes/directjude && s
ass --default-encoding UTF-8 --debug-info --watch /var/www/html/sites/all/themes/directjude/sass/style.scss:/var/www/html/sites/all/themes/dir
ectjude/css/style.css'
```

## Debugging a failed, stopped container

```bash
docker commit -m "Debugging" site-buildbarbuda plainlychrist/site-buildbarbuda:debugging && docker run -it --entrypoint '/bin/bash' plainlychrist/site-buildbarbuda:debugging --login
```
