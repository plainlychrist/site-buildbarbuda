
## Linux on Amazon EC2

These instructions are for Amazon Linux only. Your mileage may vary if you launched with any other Linux distribution (RedHat, etc.).

First, follow the **eight (8)** instructions on the [Amazon EC2 Container Service "Installing Docker"](http://docs.aws.amazon.com/AmazonECS/latest/developerguide/docker-basics.html#install_docker) section.

Then do these steps:
```bash
docker rm -f site-web # this is fine if this fails
docker run -d -p 80:80 --name site-web --env WEB_ADMIN_PASSWORD=...make...up...a...password personal/site-web --trust-this-ec2-host
docker logs --follow site-web
```

## Debugging a failed, stopped container

```bash
docker commit -m "Debugging" site-web plainlychrist/site-web:debugging && docker run -it --entrypoint '/bin/bash' plainlychrist/site-web:debugging --login
```
