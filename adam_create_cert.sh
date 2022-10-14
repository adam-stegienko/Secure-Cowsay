#!/bin/bash

# Setting up basic HTTP nginx configuration
cat << EOF > ./reverse_proxy/conf/nginx.conf
events {}

http {

  upstream cowsay_server {
    server cowsay_server:8080;
  }

  server {
    server_name            adam2cowsay.hopto.org;

    if (\$host != "adam2cowsay.hopto.org") {
      return 404;
    }


    location / {

      try_files    \$uri \$uri/index.js @server;
      add_header   source-nginx  true;
      add_header   source-backend false;
      
    }

    location @server {

      proxy_pass         http://cowsay_server;
      proxy_redirect     off;
      add_header         source-nginx     false;
      add_header         source-backend   true;
      proxy_set_header   Host             \$host;
      proxy_set_header   X-Real-IP        \$remote_addr;
      proxy_set_header   X-Forwarded-For  \$proxy_add_x_forwarded_for;

    }

  }
}
EOF

# Proof of nginx test working
sudo docker-compose down
sudo docker-compose up --detach --build


# Logging into the nginx container
sudo docker exec -i reverse_nginx bash << EOF

# Installing Certbot using Pip
apt update -y
apt install python3 python3-venv libaugeas0 -y
python3 -m venv /opt/certbot/
/opt/certbot/bin/pip install --upgrade pip
/opt/certbot/bin/pip install certbot certbot-nginx
ln -s /opt/certbot/bin/certbot /usr/bin/certbot

# Certbot configuration
printf "adam.stegienko1@gmail.com\nY\n\n" | certbot --nginx

# Cronjob for regular updating of the certificate
echo "0 0,12 * * * root /opt/certbot/bin/python -c 'import random; import time; time.sleep(random.random() * 3600)' && sudo certbot renew -q" | tee -a /etc/crontab > /dev/null

# Exiting the container
command exit
EOF