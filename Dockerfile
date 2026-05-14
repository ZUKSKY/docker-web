FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update -y && apt install --no-install-recommends -y \
    xfce4 xfce4-goodies \
    tigervnc-standalone-server \
    novnc websockify \
    openssh-server \
    sudo xterm vim net-tools curl wget git tzdata \
    dbus-x11 x11-utils x11-xserver-utils x11-apps \
    software-properties-common \
    ca-certificates \
    openssl \
    && rm -rf /var/lib/apt/lists/*

RUN add-apt-repository ppa:mozillateam/ppa -y
RUN echo 'Package: *' >> /etc/apt/preferences.d/mozilla-firefox && \
    echo 'Pin: release o=LP-PPA-mozillateam' >> /etc/apt/preferences.d/mozilla-firefox && \
    echo 'Pin-Priority: 1001' >> /etc/apt/preferences.d/mozilla-firefox

RUN apt update -y && apt install -y firefox xubuntu-icon-theme && rm -rf /var/lib/apt/lists/*

RUN wget -O /tmp/cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb && \
    dpkg -i /tmp/cloudflared.deb && \
    rm /tmp/cloudflared.deb

RUN mkdir -p /run/sshd /root/.ssh && \
    chmod 755 /run/sshd && \
    touch /root/.Xauthority

RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    echo 'Port 2222' >> /etc/ssh/sshd_config && \
    echo 'UsePAM no' >> /etc/ssh/sshd_config

RUN cat > /start.sh << 'EOF'
#!/bin/bash
set -e

mkdir -p /run/sshd
chmod 755 /run/sshd

if [ -n "$SSH_PASSWORD" ]; then
  echo "root:$SSH_PASSWORD" | chpasswd
fi

if [ -n "$SSH_PUBLIC_KEY" ]; then
  mkdir -p /root/.ssh
  echo "$SSH_PUBLIC_KEY" > /root/.ssh/authorized_keys
  chmod 700 /root/.ssh
  chmod 600 /root/.ssh/authorized_keys
fi

/usr/sbin/sshd -p 2222

vncserver -localhost no -SecurityTypes None -geometry 1024x768 --I-KNOW-THIS-IS-INSECURE

openssl req -new -subj "/C=JP" -x509 -days 365 -nodes -out /root/self.pem -keyout /root/self.pem

websockify -D --web=/usr/share/novnc/ --cert=/root/self.pem 6080 localhost:5901

if [ -n "$CLOUDFLARED_TOKEN" ]; then
  cloudflared tunnel run --token "$CLOUDFLARED_TOKEN"
else
  echo "CLOUDFLARED_TOKEN is not set. Running VNC only."
  tail -f /dev/null
fi
EOF

RUN chmod +x /start.sh

EXPOSE 5901
EXPOSE 6080
EXPOSE 2222

CMD ["/start.sh"]
