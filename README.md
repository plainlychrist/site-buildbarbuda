# What is plainlychrist/site-web?

`site-web` is the website for PlainlyChrist.org. The website is a [Drupal 8](https://www.drupal.org/) content management system (CMS). CMS's, like `site-web`, allow many different people to edit the content on a website.

# Design Principles

The main design principle for PlainlyChrist.org is to be transparent.

* **Open-source**: All the logic (the code and configuration) is fully open-source, with a truly unrestrictive license (Apache v2.0). That means you don't have to pay anybody or sign contracts to examine what we are doing.
* **Open-data**: All the content (the text and the links) is fully open data. That means you don't have to pay anybody or sign contracts to see what information we use.
* **Reproducible**: Anybody with a modern computer can create a full copy of the existing website. That means if you dislike what PlainlyChrist.org is doing, you have the freedom to start your own I-Want-Something-Better-Than-PlainlyChrist.org.

# Running

## Linux on Amazon EC2

These instructions are for Amazon Linux only. Your mileage may vary if you launched with any other Linux distribution (RedHat, etc.).

First, follow the **eight (8)** instructions on the [Amazon EC2 Container Service "Installing Docker"](http://docs.aws.amazon.com/AmazonECS/latest/developerguide/docker-basics.html#install_docker) section.

Then do these steps:
```bash
docker rm -f site-web # this is fine if this fails
docker run -d -p 80:80 --name site-web --env WEB_ADMIN_PASSWORD=...make...up...a...password personal/site-web --trust-this-ec2-host
docker logs --follow site-web
```

## Linking Active Configuration To Git Workspace

Similar instructions as `Linux on Amazon EC2`, and replace the `run` line with the following lines:

```bash
git clone https://github.com/plainlychrist/site-web.git # skip this if you already have the source code
cd site-web
docker run -d -p 80:80 --name site-web -v $PWD/storage-config:/var/lib/site/storage-config --env WEB_ADMIN_PASSWORD=...make...up...a...password personal/site-web
```
