# owenthewizard/stubby

A minimal (~5.5 MB) docker image that runs
[getdns/stubby](https://github.com/getdns/stubby),
preconfigured for DNS-over-TLS (DoT) using Cloudflare.

## Quick Start

#### Default Config (IPv4, IPv6, DoT via Cloudflare)

```bash
docker run --init -d --restart=unless-stopped --name=stubby -p 53:5300/tcp -p 53:5300/udp owenthewizard/stubby
dig +short @127.0.0.1 gnu.org # it works!
```

#### Custom Config

```bash
mkdir ~/stubby-config
vim ~/stubby-config/stubby.yml # Make your config
docker run --init -d --restart=unless-stopped --name=stubby -p 53:5300/tcp -p 53:5300/udp -v ~/stubby-config:/config:ro -e STUBBY_CONFIG=/config/stubby.yml owenthewizard/stubby # change 5300 to your port
```

## Coding Style

- Keep lines under 80 characters, where possible.
- Always check upstream signatures and hashes.
- Drop privileges, where possible.

## Contributing

Pull requests are always welcome.

Unless you explicitly state otherwise, any contribution intentionally submitted
for inclusion in the work by you, as defined in the Apache-2.0 license, shall
be licensed under the terms of the [MIT License](LICENSE.md).

## Versioning

This project uses a single version number.

Changes are documented in the [Changelog](CHANGELOG.md).

## Authors

See [the list of contributors](https://github.com/owenthewizard/stubby/contributors).

## License

See [LICENSE.md](LICENSE.md) for details.
