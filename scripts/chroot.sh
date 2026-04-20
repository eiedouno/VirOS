#!/bin/bash

pln() {
    printf "\e[34m[chroot.sh] %b\n" "$@"
}

pln "Installing [gnupg]"
apt-get install -y gnupg
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 871920D1991BC93C
apt update

pln "Configuring Agetty for auto-root login."

mkdir -p /etc/systemd/system/getty@tty1.service.d/
tee /etc/systemd/system/getty@tty1.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I \$TERM
EOF
