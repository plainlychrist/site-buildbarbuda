
## Linux on Amazon EC2

These instructions are for Amazon Linux only. Your mileage may vary if you launched with any other Linux distribution (RedHat, etc.).

First, follow the **eight (8)** instructions on the [Amazon EC2 Container Service "Installing Docker"](http://docs.aws.amazon.com/AmazonECS/latest/developerguide/docker-basics.html#install_docker) section.

Then do these steps:
```bash
docker rm -f site-web # this is fine if this fails
docker run -d -p 443:443 --name site-web --env WEB_ADMIN_PASSWORD=...make...up...a...password -v ~/site.history:/root/.bash_history plainlychrist/site-web:unstable --trust-this-ec2-host --trust-this-ec2-local-ipv4
docker logs --follow site-web
```

## Debugging a failed, stopped container

```bash
docker commit -m "Debugging" site-web plainlychrist/site-web:debugging && docker run -it --entrypoint '/bin/bash' plainlychrist/site-web:debugging --login
```
