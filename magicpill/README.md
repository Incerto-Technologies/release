# Pre Install steps

1. Install Nginx
```
# Ubuntu
sudo apt update && sudo apt install -y nginx

# RHEL
sudo yum install -y nginx

# Enable and start Nginx
sudo systemctl enable nginx
sudo systemctl start nginx
sudo systemctl status nginx
```

2. Remove `/etc/nginx/conf.d/default.conf` if it exists
```
[ -f /etc/nginx/conf.d/default.conf ] && sudo rm /etc/nginx/conf.d/default.conf
```

3. Copy `incerto.conf` into `/etc/nginx/conf.d/` and replace ${DOMAIN} variable
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

### For Certbot to work, port 80 and 443 are required

1. Install Certbot
```
sudo python3 -m venv /opt/certbot/
sudo /opt/certbot/bin/pip install --upgrade pip
sudo /opt/certbot/bin/pip install certbot certbot-nginx
sudo ln -sf /opt/certbot/bin/certbot /usr/bin/certbot
```

2. Use the below certbot commands to install certificates for Nginx
```
sudo certbot --nginx

# Follow the instruction process
```

3. Restart nginx
```
sudo systemctl restart nginx
```

# Custom Certificates

1. Follow the "SSL/TLS Setup via Lets Encrypt"

2. Replace your customer certificates in the `/etc/nginx/conf.d/incerto.conf`
```
...
    listen 443 ssl; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/test.incerto.in/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/test.incerto.in/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot
...
```

# MagicPill Installation

```
Ask the Incerto team for final command with secrets and keys.
```