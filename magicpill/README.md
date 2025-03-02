# Pre Install steps

1. Install Nginx
```
# RHEL
sudo apt update && sudo apt install -y nginx

# Ubuntu
sudo yum install -y nginx

# Enable and start Nginx
sudo systemctl enable nginx
sudo systemctl start nginx
sudo systemctl status nginx
```

2. Remove nginx default.conf
```
sudo rm /etc/nginx/conf.d/default.conf
```

3. Create incerto.conf into /etc/nginx/conf.d/ replacing ${DOMAIN} variable
```
sudo vim /etc/nginx/conf.d/incerto.conf

# Replace ${DOMAIN} with your domain 
# Eg - magicpill.incerto.in
```

4. Restart nginx
```
sudo systemctl restart nginx
```

# SSL/TLS Setup via Lets Encrypt

1. Install certbot
```
sudo python3 -m venv /opt/certbot/
sudo /opt/certbot/bin/pip install --upgrade pip
sudo /opt/certbot/bin/pip install certbot
sudo ln -sf /opt/certbot/bin/certbot /usr/bin/certbot
```

2. Use the below certbot commands to install certificates for nginx
```
sudo certbot --nginx

# Follow the instruction process
```

# Post Install Steps
