## PoC for the type confusion vulnerability of ActivityPub

This repository contains PoCs for Mastodon's [CVE-2024-25623] and Misskey's [CVE-2024-25636], a then-common vulnerability among ActivityPub implementations (which is now tracked by the ActivityPub specification at [w3c/activitypub#432]).

The PoCs' instructions assume that you know the outline of the vulnerability. See the linked reports of the vulnerabilities for the outline. Mastodon's vulnerability is somewhat limited in its exploitability, so I recommend reading Misskey's one.

### The PoCs

- [Mastodon](mastodon/README.md)
- [Misskey](misskey/README.md)

[CVE-2024-25623]: <https://github.com/mastodon/mastodon/security/advisories/GHSA-jhrq-qvrm-qr36>
[CVE-2024-25636]: <https://github.com/misskey-dev/misskey/security/advisories/GHSA-qqrm-9grj-6v32>
[w3c/activitypub#432]: <https://github.com/w3c/activitypub/issues/432>
