ARG MISSKEY_VERSION=2024.2.0-beta.10

FROM misskey/misskey:$MISSKEY_VERSION

USER root

# `ca-certificates` is required because we use `NODE_OPTIONS=--use-openssl-ca` to make the Misskey
# instances use a self-signed certificate for federation, and `pnpm` insists to connect to
# <https://registry.npmjs.org/>.
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates

USER misskey
