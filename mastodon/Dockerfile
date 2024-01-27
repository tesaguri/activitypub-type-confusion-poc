ARG MASTODON_VERSION="v4.2.5"

FROM ghcr.io/mastodon/mastodon:${MASTODON_VERSION} as base

USER root
ENV RAILS_ENV="development"

# Reinstall Gems for the `development` environment.
FROM base as build

RUN \
  apt-get update \
  && apt-get -yq dist-upgrade \
  && apt-get install -y --no-install-recommends \
    build-essential \
    libjemalloc-dev \
  && bundle config --local without 'production test' \
  && bundle config --local with 'development' \
  && bundle install -j"$(nproc)"

FROM base

COPY --chown=mastodon:mastodon --from=build /opt/mastodon /opt/mastodon

# Recompile assets for the `development` environment.
RUN rails assets:precompile

USER mastodon
