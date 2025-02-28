---
layout: post
title: Manage your secrets with SOPS and a GPG key
---

When self-hosting, it is not uncommon to come across some **secrets** that should not be stored as open text. Often times those secrets are provided in the form of environment variables. By using **SOPS** you can encrypt the relevant files in place, while still keeping them readable.

This is one of those cases where an example will serve as a better explanation. Here's how my **encrypted** docker-compose.yaml file for Pi-hole looks like:

```yaml
services:
    pihole:
        container_name: pihole
        image: pihole/pihole:latest
        ports:
            - 53:53/tcp
            - 53:53/udp
        environment:
            TZ: Europe/Warsaw
            WEBPASSWORD: ENC[AES256_GCM,data:hWoiSvYUuRlORT4=,iv:hP0En50hnms/k1fxR5NJjDejCstoyHLgrfRRdUnNzLc=,tag:MVvKNYC68cta4ci+7cWZaw==,type:str]
        volumes:
            - ./etc-pihole:/etc/pihole
            - ./custom.list:/etc/pihole/custom.list
        restart: unless-stopped
        networks:
            - raspberry-pi-network
networks:
    raspberry-pi-network:
        name: raspberry-pi-network
sops:
    kms: []
    gcp_kms: []
    azure_kv: []
    hc_vault: []
    age: []
    lastmodified: "2025-02-07T14:04:10Z"
    mac: ENC[AES256_GCM,data:NF0EESEuyN9H2U3juGhanPZvwuE9Qqn6Om4bQeqoL2qZnfgW+MFP6bflJIa2bDWpr9rozdntJDJhDFlYjOypvX5VXAaE7awRohzkCjXQTbkpLdQv9PYrmS312dCaekOkI07ZW0rTIu18rrU2BBleBRtSz3cZxvpUYo7Sfe0b8LM=,iv:vG0th/j7p9PXJYLLBjrbdmKU380XQBvNbzDPapHw8/8=,tag:mEvtx2D0qYzY2jdgUg4s9w==,type:str]
    pgp:
        - created_at: "2025-02-07T14:04:10Z"
          enc: |-
            -----BEGIN PGP MESSAGE-----

            hQGMA7UotOo+iXf0AQv9Fok8cmWzU0X4pzA3LKP9ajffkGy7FzQpMpB9UDqm6Fis
            UL3/2JI1nJjVQrLAvC7SO6IGh/4YFnckW5iERvJWdZ+oAMnsMwSearWqQI7jxa3l
            dZgFd4829egaSeqWLM8R3kXb1RCgFwSE1dwLc/16wxdW8trz4c5E3F5NX3HGdZwV
            5Kvpwz+dDxAWQFusj39dObbp2DgvOARjCODVFjuu1d7HZsyMgHQcfBSoDwhX0ZU/
            0y5xbCRmS9cygSZr9OgWUt6eq7Fh+gMN+ZBo5AWkB9KUmaIGR5y1xgN3z0mgHglu
            MJsd1l3zYL7lH94Y8njG4Bvdhs+Y+JEtQrai7p6OXvWZExgnGwOejKQq66CYY0b2
            E5ltwLU1JTeitEt3LH27mBdRolhCde8UQiPFY4aE/swkhUPUQhamyAYwDZRLqZ3p
            sak2ORfCXTgw1+8BEhOjo4Yir42LoTnegZlDqHxRZxbyRtolvqHBf04NIsoVF8qu
            w+yYlVLcL4FB0iEPoBKe1GgBCQIQoxG6LgBFEbBBwzCTQ8BRod/pylfrof4gnVrc
            +NAysB+kCpjYaUxcGF9GXMic7+0NsQb5P9qrwZhbZUyfthTOFSqzGMQrA1r26ech
            6JFgT6ypRVB5ZLXb4e7MyUM3zn+AkBjBuw==
            =BR1r
            -----END PGP MESSAGE-----
          fp: 7A3BC6EAE9EC0EF9156D6E8D0D02F4D5C2B918B5
    encrypted_regex: WEBPASSWORD
    version: 3.9.4
```

Notice how only the **WEBPASSWORD** environment variable is encrypted, and still in such a way that the structure of the entire file is preserved and easy to read.

There's also a `sops` section added at the bottom which tells SOPS which key was used so it knows how to decrypt. That section is removed when you decrypt the file, so it looks the same as before being encrypted.

Such a file is totally safe to commit to the repository - nobody will decrypt the contents without access to the key that was used to encrypt them - and you can still read through it, even when it's encrypted.

---

## How to do it

The first thing you need is [SOPS](https://getsops.io/) (which stands for Secrets OPerationS)

You also need the `gpg` tool, which is sometimes included by default on Linux machines - if you don't have it, get it (use homebrew on Mac)

Now you can generate your personal key with `gpg --full-generate-key` - follow the instructions

You can list your GPG keys with `gpg --list-keys`

It's a good idea to store it securely, for example in a password manager. You can export your key with `gpg --export-secret-keys --armor KEY_ID > private-key.asc`

You can now use it with sops. For example, to encrypt the entire file, run: `sops --encrypt --gpg <your_email@example.com> docker-compose.yaml > docker-compose.encrypted.yaml`. To decrypt, just run `sops --decrypt docker-compose.encrypted.yaml > docker-compose.yaml`

### How to encrypt only part of the file

To only encrypt a part of the file, like in the example at the beginning of this post, we need to create a `.sops.yaml` helper file (in the same folder as the file you are trying to encrypt):

```yaml
creation_rules:
  - path_regex: docker-compose\.yaml$
    encrypted_regex: WEBPASSWORD
    pgp: <your_gpg_key_id_here>
```

Make the regexes match what you want to encrypt and then just run `sops --encrypt --in-place docker-compose.yaml` (no need to specify the `--gpg` flag anymore, it is defined in the `.sops.yaml` and SOPS will pick that up automatically)

---

That's it! It's a really simple but powerful tool. It has a lot of features, including support for keys stored in cloud, keeping `.plaintext` files which you can then add to `.gitignore`, etc. I encourage you to have a look at their [github page](https://github.com/getsops/sops/tree/main) for all the things it can do.