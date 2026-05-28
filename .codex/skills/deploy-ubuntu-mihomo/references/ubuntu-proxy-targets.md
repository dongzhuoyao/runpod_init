# Ubuntu Proxy Targets

Use `http://127.0.0.1:7890` for HTTP and HTTPS proxy variables because Mihomo's mixed port accepts HTTP proxy traffic. Use `socks5h://127.0.0.1:7890` for `all_proxy` when SOCKS with remote DNS is needed.

## Shell

File:

```text
/etc/profile.d/proxy.sh
```

Variables:

```bash
export http_proxy="http://127.0.0.1:7890"
export https_proxy="http://127.0.0.1:7890"
export all_proxy="socks5h://127.0.0.1:7890"
export HTTP_PROXY="$http_proxy"
export HTTPS_PROXY="$https_proxy"
export ALL_PROXY="$all_proxy"
export no_proxy="localhost,127.0.0.1,::1,169.254.169.254,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
export NO_PROXY="$no_proxy"
```

## Apt

File:

```text
/etc/apt/apt.conf.d/95proxy
```

Content:

```text
Acquire::http::Proxy "http://127.0.0.1:7890/";
Acquire::https::Proxy "http://127.0.0.1:7890/";
```

## Git

Commands:

```bash
git config --global http.proxy http://127.0.0.1:7890
git config --global https.proxy http://127.0.0.1:7890
```

Unset:

```bash
git config --global --unset http.proxy
git config --global --unset https.proxy
```

## Docker Daemon

Changing Docker daemon proxy settings requires restarting Docker.

File:

```text
/etc/systemd/system/docker.service.d/http-proxy.conf
```

Content:

```ini
[Service]
Environment="HTTP_PROXY=http://127.0.0.1:7890"
Environment="HTTPS_PROXY=http://127.0.0.1:7890"
Environment="NO_PROXY=localhost,127.0.0.1,::1,169.254.169.254,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
```

Apply:

```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
```

## Docker CLI And Containers

File:

```text
~/.docker/config.json
```

Content:

```json
{
  "proxies": {
    "default": {
      "httpProxy": "http://127.0.0.1:7890",
      "httpsProxy": "http://127.0.0.1:7890",
      "noProxy": "localhost,127.0.0.1,::1,169.254.169.254,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
    }
  }
}
```

