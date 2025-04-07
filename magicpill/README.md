# README.md

Please follow the below steps to install Incerto's MagicPill.

# Nginx

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

## Certbot Certificates vs Custom Certificates

### Certbot Certificates

1. Copy `incerto_certbot.conf` into `/etc/nginx/conf.d/` and replace `${DOMAIN}` variable with your domain. Eg - `incerto.example.com`.
```
sudo vim /etc/nginx/conf.d/incerto.conf
```

2. Install Certbot using the below command.
```
sudo python3 -m venv /opt/certbot/
sudo /opt/certbot/bin/pip install --upgrade pip
sudo /opt/certbot/bin/pip install certbot certbot-nginx
sudo ln -sf /opt/certbot/bin/certbot /usr/bin/certbot
```

3. Install Certificates using Certbot. For Certbot to work, port 80 and 443 are required to be open to public internet.
```
sudo certbot --nginx
```

4. Restart Nginx.
```
sudo systemctl restart nginx
```

### Custom Certificates

1. Copy `incerto_custom.conf` into `/etc/nginx/conf.d/` and replace `${PRIVKEY}`, `${FULLCHAIN}`, `${DOMAIN}` variable. Eg - `incerto.example.com`.
```
sudo vim /etc/nginx/conf.d/incerto.conf
```

2. Restart Nginx
```
sudo systemctl restart nginx
```

# MagicPill

```
Ask the Incerto team for final command with secrets and keys.
```
