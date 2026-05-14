#!/bin/bash
set -e

mkdir -p /run/sshd
chmod 755 /run/sshd

/usr/sbin/sshd -p 2222 || true

exec cloudflared tunnel run ssh-tunnel
