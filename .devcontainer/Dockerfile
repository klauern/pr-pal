# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=3.4.4
FROM ghcr.io/rails/devcontainer/images/ruby:$RUBY_VERSION

# Install Bun
RUN curl -fsSL https://bun.sh/install | bash

# Add Bun to PATH for all users (root user by default)
ENV PATH="/root/.bun/bin:${PATH}"
