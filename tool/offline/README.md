# README.md

Please follow the below steps to install Incerto's tool.

## VM with access to the internet

1. Download Nginx, Docker, Zip, Unzip (or any other dependencies)
    ```
    # Whatever procedure the team follows
    ```
 
2. Download Incerto
    ```
    # Ask the Incerto team for bundle command with secrets and keys.
    # incerto.zip should be created
    ```

3. Copy everything required
    ```
    scp or rsync or any other way to copy the files
    ```

## VM with no access to the internet

1. Install Nginx, Docker, Zip, Unzip (or any other dependencies) 

2. Remove `/etc/nginx/conf.d/default.conf` if it exists
    ```
    [ -f /etc/nginx/conf.d/default.conf ] && sudo rm /etc/nginx/conf.d/default.conf
    ```

### Certbot Certificates vs Custom Certificates

#### Certbot Certificates

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

#### Custom Certificates

1. Copy `incerto_custom.conf` into `/etc/nginx/conf.d/` and replace `${PRIVKEY}`, `${FULLCHAIN}`, `${DOMAIN}` variable. Eg - `incerto.example.com`.
    ```
    sudo vim /etc/nginx/conf.d/incerto.conf
    ```

2. Restart Nginx
    ```
    sudo systemctl restart nginx
    ```

### Tool

Install the tool using the `incerto.zip` via the below command (replace `${DOMAIN}`)
```
cd ~ && curl -sfL https://raw.githubusercontent.com/Incerto-Technologies/release/refs/heads/main/tool/offline/install.sh | bash -s -- --env prod --frontend true --backend true --ai true --domain <${DOMAIN}>
```

#### Setup Frontend 

```
Ask the Incerto team for Frontend `config.json`.
```

#### Setup Backend

```
Ask the Incerto team for Backend `.env`.
```

#### Setup AI

```
Ask the Incerto team for AI `.env`.
```