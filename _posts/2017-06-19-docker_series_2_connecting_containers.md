---
layout: post
title: Docker basics - finding an image and running a container
---

---
## Introduction

This is the second post of the *Docker Basics* series. Last time, we talked about what are *images* and *containers* and how to use them to achieve a simple use case - run a Scala REPL. If you haven't read that yet and you're interested, you can see it [here](/docker-series-1-image-and-container) :)  You should also start with that post if you haven't yet installed Docker, as in this post I assume you have it done.

We'll consider a scenario where we have **two containers** and we want them to talk to each other. The first use case that came to my mind when thinking about two cooperating containers is an **application-database** relation. Therefore, we're going to create the following containers:
* One containing a MySQL RDBMS with a simple database and a simple table
* One that runs a single Python script that is supposed to fetch and print the data from the database

Very simple and illustrates the point. Let's get going then!

---
## Docker networking to tie them together

Linking containers together in the past was done with the [--link flag](https://docs.docker.com/engine/userguide/networking/default_network/dockerlinks/). That method, however, is deprecated and should not be used. The reason I'm mentioning it is because there are quite a lot of tutorials out there that still base on that method - you should know they're not up to date.

The proper method of linking containers together is with the use of the new [networking feature](https://docs.docker.com/engine/userguide/networking/).

Let's bring up our Docker console and run the `docker network ls` command. You should see something like this:

```
NETWORK ID      NAME    DRIVER  SCOPE
9872c9881f6e    bridge  bridge  local
6fc119c0ceda    host    host    local
c3fdf8d5c56e    none    null    local
```

There are the networks that are available by default:
* **bridge** default network all containers connect to if you don't specify the network yourself
* **none** connect to a container-specific network stack that lacks a network interface
* **host** connects to the host's network stack - there will be no isolation between host machine and the container, as far as network is concerned

If you need to know the details of a network, you can use the `docker network inspect <name>` command.

The recommended way to control which containers can communicate with each other is to use [user-defined networks](https://docs.docker.com/engine/userguide/networking/#user-defined-networks), which are simply networks that we create ourselves.

Let's create one with `docker network create my-network` and `docker network ls` to see it on the list:

```
NETWORK ID      NAME        DRIVER  SCOPE
9872c9881f6e    bridge      bridge  local
6fc119c0ceda    host        host    local
c3fdf8d5c56e    none        null    local
19671b2b8b20    my-network  bridge  local
```

Our user-defined network is up and ready to be used, so let's create a MySQL database container now.

---
## MySQL container

If you remember from the [previous post](/docker-series-1-image-and-container), in order to spin up a container, we first need an image. In this case, we'll use the default [mysql](https://hub.docker.com/_/mysql/) image. Let's pull it first with `docker pull mysql`.

Once we have it, let's start a mysql server instance with the following command:
`docker run -d --name mysql-server --network my-network -e MYSQL_ROOT_PASSWORD=secret mysql`

Let's break it down into pieces:
* **-d** makes the container run in background, as detached
* **--name** gives a specific name, which will be important in the next part
* **--network** defines the network the container should connect to
* **-e** sets and environment variable - in this case we define the password to be used

Quite simple. Our MySQL server should be up and running, which we can check with a `docker ps` command.

Let's now try to connect to our database server in order to create a database, a simple table and add some simple data. This will actually be the first demonstration that our network connect the two containers together as we need to start a separate container to connect to the existing server.

The command to do that is as follows (quite a long one):
`docker run -it --rm --network my-network mysql sh -c 'exec mysql -h"mysql-server" -P"3306" -uroot -p"secret"'`

If everything is fine, we should see the following:

```
mysql: [Warning] Using a password on the command line interface can be insecure.
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 3
Server version: 5.7.18 MySQL Community Server (GPL)

Copyright (c) 2000, 2017, Oracle and/or its affiliates. All rights reserved.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql>
```

So, we just connected to our **mysql server** container from a separate container running the **mysql shell** :) Let's break down the command, though:
* **-it** makes it run in interactive mode
* **--rm** will make the container remove itself once you detach from console
* **--network** as mentioned earlier, defines the network we want to connect to
* After that we exec the *mysql* program with appropriate parameters to connect to our database server - notice that we used the name of our previous container as host here

Basically, this is where we could end this tutorial, but let's create a Python script that will query our database from a separate container just for completion sake. Before we do that, though, we need to define some data in our database, so let's do that since we're already connected to the *mysql* shell:
* `CREATE DATABASE mydb;`
* `USE mydb;`
* `CREATE TABLE person (fname VARCHAR(20), lname VARCHAR(20));`
* `INSERT INTO person(fname, lname) VALUES ('Mick', 'Jagger');`

These will create a `mydb` database with a `person` table and a single row containing the `Mick Jagger` person entity. You can verify that by running `SELECT * FROM person;`.

Alright, let's now move on to the Python part. Oh, you can leave the *mysql* shell with `Ctrl-D`.

---
## Python script to query them all

In this part we'll have a peek at something we have not yet discussed - creating our own image. I won't go into details, as that's a topic for a separate post, so please just assume a magic box approach for now :)

A note to Windows users: we need to create our folder and script inside the `C:\Users\<someuser>` tree due to Docker limitation on Windows. I believe this is not an issue when working with native Docker, though, but to avoid problems let's stick to it.

Create a folder, for example `C:\Users\myuser\my-script` and inside that folder create a simple `Dockerfile` file (yes, no extension). The contents of the `Dockerfile` are as follows:

```
FROM python:2

WORKDIR /usr/src/app

RUN pip install MySQL-python

COPY . .

CMD [ "python", "./script.py" ]
```

As mentioned, I will not go into details of image creation in this post, so just a short explanation: this file will make our image extends the `python:2` image, setup a working directory, install the `MySQL-python` package, copy the contents of the current directory to the working directory we just defined and execute a `script.py` file.

Ok, so we now need our `script.py` file with the following contents:

```python
#!/usr/bin/python

import MySQLdb

db = MySQLdb.connect("mysql-server", "root", "secret", "mydb")
cursor = db.cursor()
cursor.execute("SELECT * FROM person")
data = cursor.fetchone()
fname = data[0]
lname = data[1]
print "fname=%s, lname=%s" % (fname, lname)
db.close()
```

This script will connect to our MySQL database (remember the name of the container is the host name) and select data from our table.

Ok, let's do this. From Docker terminal, we first need to move to our newly created folder containing the Dockerfile and script: `cd /c/users/myuser/my-script`

Now, that we're inside the proper directory, let's **build our image**: `docker build -t my-script .` (don't forget the dot at the end).

Our image is now built, we should see it when running `docker image ls`.

And now for the grand finale, run our newly created image: `docker run -it --rm --network my-network my-script`.

The very humble output, `fname=Mick, lname=Jagger`, proves that our script ran from one container was able to connect to a mysql database in another container and query it, which concludes this post :)

---
## Summary

There's not much to it:
* The old, deprecated method of linking containers is via the `--link` flag
* The new, proper method of linking containers is via Docker's **networking** capability
* There are some default networks available but the recommended way is to create your own network, specific for this particular application/use case
* To attach a container to a network, simply use the `--network` flag
* Using `--name` is important as the name you specify is the host address of the container visible from other containers in the same network

Commands to take away:
* `docker network ls` will list all available networks
* `docker network create <name>` will create a new network
* Adding a `--network <name>` flag to a `docker run` command will make the container run in this network's scope