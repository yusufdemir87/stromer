# Development

## Overview

Before starting local development, read the [CONTRIBUTING] guide to understand
what changes are desirable and what general processes to use. You should also read the project's [AI Contribution Policy] to understand how we approach AI-assisted contributions.

## Environments

The following instructions will guide you through the process of setting up a local development instance of Mastodon on your computer.

There are instructions for these environments:

- [Vagrant](#vagrant)
- [macOS](#macos)
- [Linux](#linux)
- [Docker](#docker)
- [Dev Containers](#dev-containers)
- [GitHub Codespaces](#github-codespaces)

Once completed, continue with the [Next steps](#next-steps) section below.

### Vagrant

A **Vagrant** configuration is included for development purposes. To use it,
complete the following steps:

- Install Vagrant and Virtualbox
- Install the `vagrant-hostsupdater` plugin:
  `vagrant plugin install vagrant-hostsupdater`
- Run `vagrant up`
- Run `vagrant ssh -c "cd /vagrant && bin/dev"`
- Open `http://mastodon.local` in your browser

### macOS

To set up **macOS** for native development, complete the following steps:

- Install [Homebrew] and run:
  `brew install postgresql@14 redis libidn nvm vips`
  to install the required project dependencies
- Use a Ruby version manager to activate the ruby in `.ruby-version` and run
  `nvm use` to activate the node version from `.nvmrc`
- Start the database services by running `brew services start postgresql` and
  `brew services start redis`
- Run `RAILS_ENV=development bin/setup`, which will install the required ruby gems and node
  packages and prepare the database for local development

  (Note: If you are on Apple Silicon and get an error related to `libidn`, you should be able to fix this by running `gem install idn-ruby -- --with-idn-dir=$(brew --prefix libidn)`, then re-running the command above.)

- Finally, run the `bin/dev` script which will launch services via `overmind`
  (if installed) or `foreman`

### Linux

The Mastodon documentation has a [guide on installing Mastodon from source](https://docs.joinmastodon.org/dev/setup/#manual) on Linux.

### Docker

For production hosting and deployment with **Docker**, use the `Dockerfile` and
`docker-compose.yml` in the project root directory.

For local development, install and launch [Docker], and run:

```shell
docker compose -f .devcontainer/compose.yaml up -d
docker compose -f .devcontainer/compose.yaml exec app bin/setup
docker compose -f .devcontainer/compose.yaml exec app bin/dev
```

### Dev Containers

Within IDEs that support the [Development Containers] specification, start the
"Mastodon on local machine" container from the editor. The necessary `docker
compose` commands to build and setup the container should run automatically. For
**Visual Studio Code** this requires installing the [Dev Container extension].

### GitHub Codespaces

[GitHub Codespaces] provides a web-based version of VS Code and a cloud hosted
development environment configured with the software needed for this project.

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)][codespace]

- Click the button to create a new codespace, and confirm the options
- Wait for the environment to build (takes a few minutes)
- When the editor is ready, run `bin/dev` in the terminal
- Wait for an _Open in Browser_ prompt. This will open Mastodon
- On the _Ports_ tab "stream" setting change _Port visibility_ → _Public_

## Next steps

- Once you have successfully set up a development environment, it will be available on http://localhost:3000
- Log in as the default admin user with the username `admin@mastodon.local` or `admin@localhost` (depending on your setup) and the password `mastodonadmin`.
- Check out the [Mastodon docs] for tips on working with emails in development (you'll need this when creating new user accounts) as well as a list of useful commands for testing and updating your dev instance.
- You can optionally populate your database with sample data by running `bin/rails dev:populate_sample_data`. This will create a `@showcase_account` account with various types of contents.

[codespace]: https://codespaces.new/mastodon/mastodon?quickstart=1&devcontainer_path=.devcontainer%2Fcodespaces%2Fdevcontainer.json
[CONTRIBUTING]: ../CONTRIBUTING.md
[Dev Container extension]: https://containers.dev/supporting#dev-containers
[Development Containers]: https://containers.dev/supporting
[Docker]: https://docs.docker.com
[GitHub Codespaces]: https://docs.github.com/en/codespaces
[Homebrew]: https://brew.sh
[Mastodon docs]: https://docs.joinmastodon.org/dev/setup/#working-with-emails-in-development
[AI Contribution Policy]: https://github.com/mastodon/.github/blob/main/AI_POLICY.md

## Working on Stromer in this repository

Notes from building the agent features on a Windows machine with the dev container (`devcontainer-app-1`). They are habits that saved time, not part of upstream Mastodon.

- Specs: `docker exec -e RAILS_ENV=test devcontainer-app-1 bash -lc "cd /workspaces/mastodon && bundle exec rspec spec/lib/agent_art_spec.rb"`. Starting rspec takes about 25 seconds before the first example. Run `bundle exec rubocop <files>` the same way; the commit hook runs it and a failure there undoes the commit's staged changes, so run it first.
- Development server: `docker exec -d devcontainer-app-1 bash -lc "cd /workspaces/mastodon && bin/rails s -b 0.0.0.0 -p 3000"`. The first request after a start can take a minute. After pulling a migration, run `bin/rails db:migrate` in development, or every request fails with `PendingMigrationError`. Migration timestamps must not be more than a day ahead of the container's clock.
- The dev server does not reload new concerns. To check a request path after adding one, restart the server, or use an `ActionDispatch::Integration::Session` inside `rails runner`.
- Do not put `git stash` inside a `docker exec`; it stashed unrelated edits once.
- Images are drawn with libvips and the DejaVu font; both are present in the dev container, the production image is unchecked.
- The agent runtime lives in the separate private repository `stromer-agents`; this repository only exposes the catalog, identity, profile, analytics and builder endpoints it uses (`docs/AGENT_CATALOG_API.md`, `docs/EXTERNAL_AGENT_API.md`).
