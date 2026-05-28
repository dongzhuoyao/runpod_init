# Security

Mihomo exposes two sensitive local surfaces:

- `mixed-port`, usually `7890`, accepts HTTP and SOCKS proxy traffic.
- `external-controller`, usually `127.0.0.1:9090`, controls proxy groups and runtime state.

Default deployment must keep both localhost-only:

```yaml
mixed-port: 7890
allow-lan: false
external-controller: 127.0.0.1:9090
```

Do not bind proxy or controller ports to `0.0.0.0` on a public VPS. If the user explicitly needs LAN access, require all of:

- private-interface binding or firewall allowlist
- controller secret if the controller is reachable beyond localhost
- proxy authentication for shared access
- clear explanation that an open proxy can be abused

Never commit subscription URLs, proxy credentials, UUIDs, private keys, or controller secrets unless they are already intentionally tracked in the repo and the user explicitly wants that file deployed.

