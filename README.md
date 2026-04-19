# VirOS

A perfectly normal OS

# Building

**You must be running Ubuntu.**

Copy the repo

```bash
git clone https://github.com/eiedouno/VirOS
cd VirOS
```

Run the build script

```bash
chmod +x build.sh
sudo ./build.sh
```

## For Docker:

If you're running Ubuntu inside docker, make sure you started the container with `--privileged`

Example: `docker run -ti --privileged --name "ubuntu-tmp" ubuntu:22.04 bash`

Then use `build-docker.sh` instead:

```bash
chmod +x build-docker.sh
./build-docker.sh
```

If nothing failed, `exit` the container.

### Extract the iso file from the container.

First find the id of the `ubuntu-tmp` container.

```bash
docker ps -af name=ubuntu-tmp
```

(It's the `CONTAINER ID`)

Extract it.

```bash
docker cp <container_id>:/VirOS/build/VirOS.iso .
```

If you're not using the container anymore, you can delete it.

```bash
docker rm ubuntu-tmp
```

---

The final build is `./VirOS/build/VirOS.iso`. Use `dd` or another program to burn it to a USB drive.

Example: 

```bash
dd if=./VirOS.iso of=/dev/sda2 bs=4M status=progress
sync
```

If it's inside docker, you'll need to extract the iso file from inside the container before burning.
