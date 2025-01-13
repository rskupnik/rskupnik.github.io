---
layout: post
title: Using Raspberry Pi and Tailscale to join two home networks together
---

---

This is a project I did over Christmas 2024 - joining two physically separate home networks into a single network.

This means that any device in Site A can reach any device in Site B and vice-versa. Those devices do not need to have any custom software installed on them for this to work.

I accomplished this by leveraging two Raspberry Pis - one in each network - running a free VPN tool called Tailscale.

Here's how it looks like:

<p>
    <img src="{{sitre.baseurl}}/public/images/sts_vpn_final.png" style="width: auto; display: block; margin-left: auto; margin-right: auto;" alt="Site-to-site VPN"/>
</p>

---

## Goals

Here is what I wanted to achieve with this project and what I will show you how to do in this post:
1. Any device in Site A can reach any device in Site B (and the other way around)
2. Those devices DO NOT need to have any custom software installed to do that
3. The whole process is automated as much as possible, so I can come back to this in two years and be able to easily work with it
4. BONUS: I can reach any device in Site A or Site B from anywhere in the world using a pre-approved device when I connect it to the VPN

---

## Assumptions

Before I start describing how to do stuff, let's agree on a few definitions so it's easier to follow.

Let's assume we have two physically separates networks, called "Site A" and "Site B".

**Site A** uses the IPs: `192.168.1.0` up to `192.168.1.255`, so `192.168.1.0/24`

**Site B** uses the IPs: `192.168.2.0` up to `192.168.2.255`, so `192.168.2.0/24`

The **Raspberry Pi** in Site A has the IP `192.168.1.100`

The **Raspberry Pi** in Site B has the IP `192.168.2.100`

The **router** in Site A has the IP: `192.168.1.1`

The **router** in Site B has the IP: `192.168.2.1`

---

## Required software and hardware

The sites will be joined together using site-to-site VPN. If you have advanced enough routers at your disposal, you can probably achieve the same result by just properly configuring the VPN on those devices. My routers don't allow for this and I didn't feel like purchasing new ones, so I achieved the same using two Raspberry Pis I had lying around.

When it comes to software, we'll be using Tailscale. [Tailscale](https://tailscale.com/) is a VPN solution that we can self-host to connect the two sites together. Traffic between the sites will go through an encrypted tunnel over the public web.

So here's what we need:
* Two Raspberry Pi devices - one for each site. I used a new Raspberry Pi 5 in one of the sites and an older Raspberry Pi 3 in the other site.
* Tailscale - you just need to create an account, it's free.

---

## A word on automation

I will be automating this process as much as possible by using a great tool called [Just](https://github.com/casey/just).

Just is a modern version of Make. It allows you to write small and simple scripts, called "recipes", which you can run from your terminal.

The end goal is to have a few of these recipes in place to manage this whole thing. A few examples:
* `just deploy` will copy the files from my local laptop to the Raspberry Pi
* `just start` will start the Tailscale service
* `just stop` will stop it
* `just log` will shows the logs
* `just install` will install the whole thing (along with a few changes outside Docker)
* `just uninstall` will reverse the installation process to leave a clean slate
* etc.

---

## Step 1: setup Rasberry Pis

I'm a big fan of using containers and isolating the applications so they can be easily installed and uninstalled without affecting the host system. Therefore, I will be using Docker and Docker Compose to install Tailscale.

There are, however, a few changes that need to be introduced outside Docker to make this work - but more on that later.

Once you have your Raspberry Pi OS installed (I used the newest 64-bit one) we need to **install docker**.

Having automation in mind, let's initiate our `justfile` with the first recipe, called `provision`, which will be responsible for installing all we need on our Raspberry Pi. In this case, the only thing we need there is Docker.

{% raw %}
```bash
rpi_user := "your_rpi_user"
rpi_hostname := "your_rpi_hostname_or_ip"

# Provision the Raspberry Pi (install Docker)
provision:
    ssh {{rpi_user}}@{{rpi_hostname}} 'curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh && sudo usermod -aG docker pi'
```
{% endraw %}

If we now run `just provision`, we should get Docker installed on the Raspberry Pi. We can now SSH there and verify with `docker --version`. While we're at it, we can add a `ssh` recipe:

{% raw %}
```bash
ssh:
    ssh {{rpi_user}}@{{rpi_hostname}}
```
{% endraw %}

That's it, our Raspberry Pi is ready to go. Remember to repeat this process on your second Raspberry Pi!

---

## Step 2: Install Tailscale

With both Pis provisioned, we now need to install Tailscale on each of them. Let's create a `docker-compose.yml` file, ideally in a folder, for example `tailscale`:

```yaml
services:
  tailscale:
    image: tailscale/tailscale:latest
    container_name: tailscale
    network_mode: "host" # Allows Tailscale to manage networking
    cap_add:
      - NET_ADMIN
      - NET_RAW
      - SYS_MODULE
    devices:
      - /dev/net/tun:/dev/net/tun
    security_opt:
      - apparmor:unconfined
    volumes:
      - /var/lib/tailscale:/var/lib/tailscale
    environment:
      - TS_AUTH_KEY=tskey-your-auth-key # Replace with your Tailscale auth key
    command: >
      tailscaled
      --state=/var/lib/tailscale/tailscaled.state
    restart: unless-stopped
    entrypoint:
      - sh
      - -c
      - |
        tailscaled --state=/var/lib/tailscale/tailscaled.state &
        sleep 1
        tailscale up --advertise-routes=192.168.1.0/24 --snat-subnet-routes=false --accept-routes
        wait
```

What does it do? Let's break it down:
* We use `network_mode: "host"` to allows Tailscale to route the traffic outside the container
* We add the necessary capabilities under `cap_add`
* We need to give it access to `/dev/net/tun` as that's something Tailscale requires
* We pass the `TS_AUTH_KEY`, which you need to generate in Tailscale console
* It runs Tailscale and advertises the `192.168.1.0/24` route
* It accepts other routes with `--accept-routes`
* I decided to disable SNAT with `--snat-subnet-routes=false` and do the routing myself

Notice the `--advertise-routes` flag. This is the only part of this file that will differ between the two Raspberry Pis. The Raspberry Pi in Site A needs to advertise the routes of Site A, so `192.168.1.0/24`. The Raspberry Pi in Site B needs to advertise the routes of Site B, so `192.168.2.0/24`.

So we need two `docker-compose.yml` files, both of them the same except for that one IP.

### Deploying

Once we have both `docker-compose.yml` files (one for Site A, one for Site B) we can deploy them to the Raspberry Pis and start them. Let's add these recipes to `justfile`:

{% raw %}
```bash
# Copy all the files (excluding MD, png) in tailscale/ to /home/pi/tailscale
deploy:
    rsync -avh --inplace --no-perms --exclude '*.MD' --exclude '*.png' tailscale/* {{rpi_user}}@{{rpi_hostname}}:/home/pi/tailscale/

# Start the service
start:
    ssh {{rpi_user}}@{{rpi_hostname}} 'cd tailscale && docker compose up -d --build'

# Stop the service
stop:
    ssh {{rpi_user}}@{{rpi_hostname}} 'cd tailscale && docker compose down'

# Display Docker logs for service
log service:
    ssh {{rpi_user}}@{{rpi_hostname}} 'docker logs -f tailscale'
```
{% endraw %}

(I used `rsync` here but you can just use `scp` if you want to)

`just deploy` will copy all files in the `tailscale` folder (excluding .png and .MD) to `/home/pi/tailscale` on the Pi.
`just start` and `just stop` will start and stop the service, respecively
`just log` will display logs of the running service

If we now run `just deploy` and then `just start`, we should see Docker building our app. If all goes fine, `just log` should display logs of a running Tailscale instance.

You can now go to the admin panel of Tailscale and you should see the Raspberry Pi appear as a connected machine. At this point, a few manual clicks are needed:
* Accept the routes being advertised
* (Optional) Disable key expiry

Great! This step should be repeated for the second Raspberry Pi. Remember to change the advertised routes to match the subnet of the second site!

If all goes well, you should see both Pis in the admin panel of Tailscale. Remember to accept the advertised routes (this is a one-time thing).

At this point you probably should be able to `ping` one Pi from the other using their respective Tailscale IPs (you can see them in the panel).

---

## Step 3: Setup routing

Okay cool, our two Pis can see each other but what about all the other devices in the networks? We want all devices in Site A to see all devices in Site B (and the othery way around) **without** needing to change **anything** on those devices. They should be unaware of Tailscale and our setup as a whole. From their perspective, they are all in a single network - that's what we want. So how do we get there? At this point we basically have this:

<p>
    <img src="{{sitre.baseurl}}/public/images/sts_vpn_before_routing.png" style="width: auto; display: block; margin-left: auto; margin-right: auto;" alt="Site-to-site VPN - before routing"/>
</p>

If we would now try to ping a device in Site B from a device in Site A it would fail. That's because our request goes to the router but it has no idea that in order to reach the other site it needs to go through the Raspberry Pi. The router will just try to "send it out there" to the internet and will fail miserably.

We need to setup a few things that will instruct our routers and Raspberry Pis on how to route the traffic so it reaches the destination:
* Enable IP Forwarding
* Setup routes in the `iptables` on the Pis
* Setup Static Routes on the router

Let's go through this one by one

### IP Forwarding

IP Forwarding refers to the process of enabling a device to forward IP packets from one network interface to another - which effectively turns the device into a router.

By default, Linux processes only packets addressed to its own IP addresses - but when IP forwarding is enabled, the system forwards packets from one network interface to another if the packet is not intended for that device.

In our case, we want packets arriving to the `wlan0` interface (or `eth0` if your RPi is connected to your LAN through a wire) that are intended for the other site to be forwarded to the `tailscale0` network interface. The `tailscale0` network interface is created when we install and run Tailscale - packets exiting through that interface will go to the Tailscale Network and be directed further.

Enabling IP Forwarding on Raspberry Pi is very simple, we just need to run this:

```bash
sudo sysctl -w net.ipv4.ip_forward=1
```

Note: this will not persist through a restart!

We want to automate this so that IP Forwarding gets enabled when we install Tailscale on the RPi and disabled if we uninstall it. Let's modify our `justfile`:

{% raw %}
```bash
# Install service from the ground up - deploy files, run setup, start the service
install service:
    just deploy
    just _setup
    just start

# Uninstall the service entirely - stop, run teardown, delete files
uninstall service:
    just stop
    just _teardown
    just remove

# Remove the whole /home/pi/tailscale folder
remove service:
    ssh {{rpi_user}}@{{rpi_hostname}} 'rm -rf /home/pi/tailscale'

_setup: _ip-forwarding-enable
_teardown: _ip-forwarding-disable

# Enable IP Forwarding
_ip-forwarding-enable:
    ssh {{rpi_user}}@{{rpi_hostname}} 'sudo sysctl -w net.ipv4.ip_forward=1'

# Disable IP Forwarding
_ip-forwarding-disable:
    ssh {{rpi_user}}@{{rpi_hostname}} 'sudo sysctl -w net.ipv4.ip_forward=0'

```
{% endraw %}

Running `just install` will deploy the files, enable IP Forwarding and start Tailscale. Running `just uninstall` will stop Tailscale, disable IP Forwarding and remove the files.

You may wonder about the weird definition of `_setup` and `_teardown` - we will make use of it in the next step.

### Routing rules in IP Tables

Alright, our Raspberry Pis now have IP Forwarding enabled and are able to route the traffic - but we need to setup rules that will tell them which traffic to route and where to direct it.

We set these rules in the IP Tables using the `iptables` command. For our case we want these scenarios:
* Grab packets on the `wlan0` interface (which means they arrive to the RPi through WiFi) where the source IP is this site's IP range (so 192.168.1.0/24 for Site A) AND whose destination IP is in the other site's IP range (so 192.168.2.0/24 for Site A) and forward them to the `tailscale0` interface (meaning they will continue their journey through the Tailscale Network)
* Grab packets on the `tailscale0` interface (which means they arrive from Tailscale) where the source IP is the other site's IP range (so 192.168.2.0/24 for Site A) AND whose desitination IP is in this site's IP range (so 192.168.1.0/24 for Site A) and forward them to the `wlan0` interface (meaning they will continue their journey through the Site's WiFi)

Commands for adding these look like this (example for Site A):

```bash
sudo iptables -A FORWARD -i wlan0 -o tailscale0 -s 192.168.1.0/24 -d 192.168.2.0/24 -j ACCEPT
sudo iptables -A FORWARD -i tailscale0 -o wlan0 -s 192.168.2.0/24 -d 192.168.1.0/24 -j ACCEPT
```

However, there's one caveat! When the packets go through Tailscale, it does something called SNAT - it overwrite the Source IP of the packet to be the Tailscale IP.

Consider this scenario:
* We are on a device in site A with IP 192.168.1.25
* We try to ping device in site B with IP 192.168.2.34
* Our packet is forwarded (per the new rules), goes to Tailscale Network, then arrivce to the Raspberry Pi in the other Site
* However, due to SNAT, the Raspberry Pi in the other network now sees the packet with an overwritten Source IP - so it's not 192.168.1.25 anymore, it is now, for example, 100.101.25.34 - which is the Tailscale IP of the Raspberry Pi
* Because of that our rules will fail

To solve that, we need to add another pair of rules that takes the Tailscale IPs into consideration (example for Site A and assuming Site B's Raspberry Pi Tailscale IP is `100.101.25.34`):

```bash
sudo iptables -A FORWARD -i wlan0 -o tailscale0 -s 192.168.1.0/24 -d 100.101.25.34 -j ACCEPT
sudo iptables -A FORWARD -i tailscale0 -o wlan0 -s 100.101.25.34 -d 192.168.1.0/24 -j ACCEPT
```

This will handle the SNAT.

Note: some useful commands around `iptables`:
* View all `FORWARD` rules (you should see the ones we created here): `sudo iptables -L FORWARD -n -v --line-numbers`
* Delete a `FORWARD` rule by line number (in case you messed something up): `sudo iptables -D FORWARD 11` (example for line 11)

Okay so we need to setup four routes on each of the Raspberry Pis, switching the IP ranges and stuff... how do we automate it? It's not that difficult, although slightly more complicated:

{% raw %}
```bash
this_subnet_cidr := "192.168.1.0/24"
other_subnet_cidr := "192.168.2.0/24"
other_rpi_tailscale_ip := "100.101.25.34"

_add-forwarding-rules:
    #!/usr/bin/env bash
    echo 'Checking if the rules are already set up'
    RULES_EXIST=$(ssh {{rpi_user}}@{{rpi_hostname}} "sudo iptables -L FORWARD -v -n --line-numbers | grep 'tailscale0.*wlan0.*{{other_subnet_cidr}}.*{{this_subnet_cidr}}'")
    if [[ -n "$RULES_EXIST" ]]; then
        echo 'Rules already exist, skipping this step'
    else
        echo 'Setting up forwarding rules'
        ssh {{rpi_user}}@{{rpi_hostname}} 'sudo iptables -A FORWARD -i tailscale0 -o wlan0 -s {{other_subnet_cidr}} -d {{this_subnet_cidr}} -j ACCEPT'
        ssh {{rpi_user}}@{{rpi_hostname}} 'sudo iptables -A FORWARD -i wlan0 -o tailscale0 -s {{this_subnet_cidr}} -d {{other_subnet_cidr}} -j ACCEPT'
        ssh {{rpi_user}}@{{rpi_hostname}} 'sudo iptables -A FORWARD -i tailscale0 -o wlan0 -s {{other_rpi_tailscale_ip}} -d {{this_subnet_cidr}} -j ACCEPT'
        ssh {{rpi_user}}@{{rpi_hostname}} 'sudo iptables -A FORWARD -i wlan0 -o tailscale0 -s {{this_subnet_cidr}} -d {{other_rpi_tailscale_ip}} -j ACCEPT'
    fi

_remove-forwarding-rules:
    #!/usr/bin/env bash
    echo 'Checking if the rules exist'
    RULES_EXIST=$(ssh {{rpi_user}}@{{rpi_hostname}} "sudo iptables -L FORWARD -v -n --line-numbers | grep 'tailscale0.*wlan0.*{{other_subnet_cidr}}.*{{this_subnet_cidr}}'")
    if [[ -n "$RULES_EXIST" ]]; then
        echo 'Removing forwarding rules'
        ssh {{rpi_user}}@{{rpi_hostname}} "sudo iptables -L FORWARD -v -n --line-numbers | grep 'tailscale0.*wlan0.*{{other_subnet_cidr}}.*{{this_subnet_cidr}}' | awk '{print \$1}' | xargs -r -I{} sudo iptables -D FORWARD {}"
        ssh {{rpi_user}}@{{rpi_hostname}} "sudo iptables -L FORWARD -v -n --line-numbers | grep 'wlan0.*tailscale0.*{{this_subnet_cidr}}.*{{other_subnet_cidr}}' | awk '{print \$1}' | xargs -r -I{} sudo iptables -D FORWARD {}"
        ssh {{rpi_user}}@{{rpi_hostname}} "sudo iptables -L FORWARD -v -n --line-numbers | grep 'tailscale0.*wlan0.*{{other_rpi_tailscale_ip}}.*{{this_subnet_cidr}}' | awk '{print \$1}' | xargs -r -I{} sudo iptables -D FORWARD {}"
        ssh {{rpi_user}}@{{rpi_hostname}} "sudo iptables -L FORWARD -v -n --line-numbers | grep 'wlan0.*tailscale0.*{{this_subnet_cidr}}.*{{other_rpi_tailscale_ip}}' | awk '{print \$1}' | xargs -r -I{} sudo iptables -D FORWARD {}"
    else
        echo "Rules don't exist, skipping this step"
    fi
```
{% endraw %}

Alright, this might seem daunting at first but at the gist of it are just the 4 rules we described and a simple if-else clause to create them if they are not in yet; and the other way around for removing them.

By defining the three variables at the top we make it easy for ourselves to edit this for the other Raspberry Pi. The names of the variables should be self explanatory, but just to make sure:
* `this_subnet_cidr` should contain the CIDR for "this" site (meaning the site where this Raspberry Pi lives). So for Site A this should be `192.168.1.0/24` and for Site B `192.168.2.0/24`
* `other_subnet_cidr` should contain the CIDR for the "other" site, so for Site A it's `192.168.2.0/24` and for Site B `192.168.1.0/24`
* `other_rpi_tailscale_ip` should contain the Tailscale IP address (view it on Tailscale panel) of the OTHER Raspberry Pi

The scripts themselves simply check if those rules are added already and if note - add them. Then on removal it checks if they are present and removes them (with `grep` and `xargs`).

Now all we need to do is to plug those `_add-forwarding-rules` and `_remove-forwarding-rules` into out `_setup` and `_teardown` recipes (which in turn are part of `install` and `uninstall` ):

Simply find this part of the `justfile`:

{% raw %}
```bash
_setup: _ip-forwarding-enable
_teardown: _ip-forwarding-disable
```
{% endraw %}

And switch it to this:

{% raw %}
```bash
_setup: _ip-forwarding-enable _add-forwarding-rules
_teardown: _ip-forwarding-disable _remove-forwarding-rules
```
{% endraw %}

So now our `_setup` (called by `install`) will call `_ip-forwarding-enable` and `_add-forwarding-rules` and our `_teardown` (called by `uninstall`) will call `_ip-forwarding-disable` and `_remove-forwarding-rules`.

---

Two notes for the avid reader:
* You might have noticed we don't need 4 rules, it would be enough to have just 2 - but I prefer to include both the case of SNAT working and not
* We are setting `--snat-subnet-routes=false` flag when starting Tailscale, so why is SNAT happening? The answer - I don't know, it just does


### Static Routes

Our Raspberry Pi's are now configured to route the traffic according to the rules we setup in the step above - but how do we make the traffic from our devices go through the Raspberry Pi's in the first place?

The simplest approach would be to configure each device and set the Raspberry Pi as the router - but that violates the goal we set for ourselves, which is that we do not want to change anything on the devices in the networks - they should just see each other out of the box.

So what we will do instead is we will setup two Static Routes inside our existing routers.

That way any device in the network will still go through the router, but if the packet has a Destination IP set to the other Site, the router will know to route it to the Raspberry Pi - which, in turn, will forward it to Tailscale, as per the rules we set up in the previous step.

Unfortunately, setting up static routes in the router is a manual step - and each router has a different UI for that. What you need to do is login to your router, find the place where you can add Static Routes and set them up there.

Each Router needs two static routes (examples for Site A):
* **Destination**: 192.168.2.0; **Subnet Mask**: 255.255.255.0; **Default Gateway**: 192.168.1.100 (this is the Raspberry Pi IP); **Interface**: LAN;
* **Destination**: 100.101.25.34 (this is the Tailscale IP of the OTHER Raspberry Pi); **Subnet Mask**: 255.255.255.0; **Default Gateway**: 192.168.1.100 (this is the Raspberry Pi IP); **Interface**: LAN;

Setup the same for Site B, modifying accordingly.

If we set this up, we now have this:

<p>
    <img src="{{sitre.baseurl}}/public/images/sts_vpn_noext.png" style="width: auto; display: block; margin-left: auto; margin-right: auto;" alt="Site-to-site VPN without external access"/>
</p>

---

With all of this in place, any device in one of the sites should now be able to reach any device in the other site!

You can try to test like this:
* Go to a device in Site A
* Try to ping a device in Site B (assuming it has IP 192.168.2.34): `ping 192.168.2.34`

If anything is wrong, refer to the Troubleshooting section

Remember to manually approve the advertised routes in the Tailscale Admin Panel!

---

## BONUS: Access both your networks from the internet

Another benefit of this setup is that you can connect to the Tailscale VPN Network from anywhere and be treated as if you were part of your both home networks!

To do that you need to go to the Admin Panel on Tailscale website and follow the instructions there to add a device to be approved for accessing the network. Those instructions will also tell you how to install the Tailscale Client to be able to do so.

With that in place, all you need to do is connect to VPN and done - you can now see your home network from anywhere.

I personally have connected my phone and MacBook and I keep them disconnected, only connecting to the VPN when I need to reach the home network.

With this in place, we reach the final outcome:

<p>
    <img src="{{sitre.baseurl}}/public/images/sts_vpn_final.png" style="width: auto; display: block; margin-left: auto; margin-right: auto;" alt="Site-to-site VPN"/>
</p>

---

## Troubleshooting

If you try to ping a device in one Site from the other Site and you are not getting a response, you can try to pinpoint the location of the problem using `tcpdump`.

Note: `tcpdump` is not preinstalled, you need to install it on whatever device you want to use it in (either Raspberry Pi or your own laptop, etc).

Once you have it, you can use it to monitor the flow of packets on that device. Here's how you can use `tcpdump`:
* Run `sudo tcpdump -i wlan0 192.168.1.54` to see all packets on the `wlan0` interface with their destination ip `192.168.1.54`
* Run `sudo tcpdump -i wlan0 icmp` to see all ICMP packets (ping packets) on the `wlan0` interface

Let's assume this scenario: you go to a device in Site A (192.168.1.25) and try to ping device in Site B (192.168.2.34) - but you get a timeout. Here's how I would trace the problem:

### Check if the packets are reaching the Raspberry Pi in Site A

SSH into Raspberry Pi in Site A and run `sudo tcpdump -i wlan0 icmp`. Do you see the packets arriving?

If so, continue to the next check

If there is nothing here, then the issue is that the packets from your device in Site A intended for Site B either don't know how to reach the Raspberry Pi in Site A or don't know that they should go through it.

Possible causes:
* There is no static route on the router to direct the traffic intended for Site B to go through the Raspberry Pi - refer to the "Static Routes" section
* The static route on the router is misconfigured - are you sure you instructed that router to route traffic intended for Site B (192.168.2.0/24, or 192.168.2.0 and mask 255.255.255.0) to go through Raspberry Pi in Site A (192.168.1.100)?
* The device you are using does not use you router at all - this might be to a variety of reasons. Are you connected to the WiFi and not using a mobile connection, for example?

### Check if the packets reaching Raspberry Pi in Site A are properly forwarded to Tailscale

If you see packets arriving to `wlan0` of the RPi (as in previous check), next thing to check is whether they are forwarded from `wlan0` to `tailscale0`.

You can check that by running: `sudo tcpdump -i tailscale0 icmp`. Do you see the packets here (should be the same as in the previous check)?

If so, continue to the next check

If there is nothing here, then the IP Forwarding and the rules we added to `iptables` are failing.

Possible causes:
* IP Forwarding is not enabled, check with `cat /proc/sys/net/ipv4/ip_forward` - it should return 1. If it returns 0, go back to the "IP Forwarding" section
* Are your four IP Tables rules in place? Check with `sudo iptables -L FORWARD -n -v --line-numbers`. If they are not there, go back to "Routing rules in IP Tables" section
* Are your IP Tables rules correct? Make sure you read through the "Routing rules in IP Tables" section and understand which Raspberry Pi needs to have which rules and that you didn't mix up the IP ranges, etc.

### Check if the packets are coming from Tailscale to the OTHER Raspberry Pi

If Raspberry Pi in Site A is receiving packets on `wlan0` and forwarding them to `tailscale0`, the next step is to check whether they are reaching the other Raspberry Pi.

SSH to the other Raspberry Pi and verify with: `sudo tcpdump -i tailscale0 icmp`. Do you see the packets here?

If so, continue to the next check

If there is nothing here, then Tailscale is not delivering the traffic.

A few checks to be made:
* Go to your Tailscale Admin Panel and check if there are both Raspberry Pis online
* Did you accept the routes they advertise? You need to go into each of them and explictly accept the routes
* Are the advertised routes properly setup? RPi in Site A should advertise IPs in Site A, so 192.168.1.0/24

If the devices are registered but offline then verify the logs of `tailscale`, either using `just log` or by running `docker logs tailscale` on the RPi. Make sure there are no errors

### Check if the packets coming from Tailscale to the OTHER Raspberry Pi are forwarded from tailscale0 to wlan0

If Tailscale is delivering packets to the other site, the next thing to check is the forwarding from `tailscale0` to `wlan0`.

Check using: `sudo tcpdump -i wlan0 icmp`. You should see the same packets as in `sudo tcpdump -i tailscale0 icmp`.

If there are packets, continue to the next check

Otherwise, the issue is with IP Forwarding or IP Tables rules.

Possible causes:
* IP Forwarding is not enabled, check with `cat /proc/sys/net/ipv4/ip_forward` - it should return 1. If it returns 0, go back to the "IP Forwarding" section
* Are your four IP Tables rules in place? Check with `sudo iptables -L FORWARD -n -v --line-numbers`. If they are not there, go back to "Routing rules in IP Tables" section
* Are your IP Tables rules correct? Make sure you read through the "Routing rules in IP Tables" section and understand which Raspberry Pi needs to have which rules and that you didn't mix up the IP ranges, etc.

### Check the destination device

It is possible that the destination device in Site B (192.168.2.34) is receiving the ping packets but doesn't know how to route them back.

Check on that device with `sudo tcpdump -i wlan0 icmp`.

If packets are arriving but the original device still gets a timeout in ping, then the ping packets don't know how to route back.

This might be caused by SNAT of Tailscale changing the Source IP and you not having the routes setup for Tailscale IPs:
* Does you router in Site B have a static route for Tailscale IP of the Raspberry Pi in Site A?
* Do your rules in IP Tables on both RPi A and RPi B take Tailscale IPs into consideration?

### Other checks

If none of the above helped, then I'm a bit out of ideas. Potential issues might be caused by:
* Firewalls at any point in the network
* Old routers
* Having you Raspberry Pis connected by cable and not by WiFi (in this case use `eth0` interface in place of `wlan0` interface)