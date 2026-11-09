# Cleotic CLI

Command line tools for Cleotic.

Cleotic organizes your work into brands and studies, with commands for
each brand's primary brand and competitors. Use the CLI interactively,
in scripts, or through an AI agent to manage brands, competitors,
segments, and prompts, check site readiness, work through the
opportunity inbox, export AI traffic, and create client reports.

## Install

Install the latest release:

```sh
curl -fsSL https://raw.githubusercontent.com/Cleotic/cleotic-cli/main/install.sh | sh
```

Install a specific release:

```sh
curl -fsSL https://raw.githubusercontent.com/Cleotic/cleotic-cli/main/install.sh | CLEOTIC_VERSION=v0.6.1 sh
```

Install to a different directory (default is `$HOME/.local/bin`):

```sh
curl -fsSL https://raw.githubusercontent.com/Cleotic/cleotic-cli/main/install.sh | CLEOTIC_INSTALL_DIR="$HOME/bin" sh
```

## Keep Cleotic up to date

Run the update command whenever you want Cleotic to check for a newer
release:

```sh
cleotic update
```

If an update is available, Cleotic shows the new version and asks whether
you want to install it. You can also choose a mode that suits how you are
using the CLI:

```sh
# Check without installing anything
cleotic update --check

# Install an available update without a confirmation prompt
cleotic update --yes

# Get a machine-readable check result for a script or agent
cleotic update --check --json

# Install non-interactively and return a machine-readable result
cleotic update --yes --json --no-input
```

During normal interactive use, Cleotic also checks occasionally and prints
a short notice when a new version is available. These background checks do
not run with `--json`, `--no-input`, piped output, or in CI. Set
`CLEOTIC_NO_UPDATE_CHECK=1` if you prefer to turn them off entirely.

## Log in

```sh
cleotic auth login
```

Login opens your browser and signs you in as your Cleotic user. Tokens
are stored in your OS keychain and refreshed automatically. Over SSH, or
anywhere without a local browser, the CLI prints a link to open on any
device and asks you to paste the code shown after you sign in; pass
`--no-browser` to choose this yourself.

The CLI uses the organization you're signed in to in the browser. To
choose another, run `cleotic auth login --change-org`: you sign in again
and pick the organization. `cleotic auth status` shows the active session
and `cleotic auth logout` removes the local tokens.

If your organization still needs to accept Cleotic's Terms and
Conditions, the CLI opens the web app, waits for you to accept, and
continues on its own.

For CI and automation, use an API key created on the Cleotic API-keys
settings page (read-only or read-write) and provide it through the
environment:

```sh
CLEOTIC_API_KEY=... cleotic projects list --json
```

## Common Workflows

Cleotic organizes your work into **brands** and **studies**. Each brand
tracks one primary brand and its competitors. Behind every brand or study
is a project: its project ID is what `--project`, `cleotic projects use`,
and the `default_project_id` setting expect.

```sh
# First-time setup: read a brand's website and set up the brand, its
# competitors, a segment and prompts (needs `cleotic auth login`)
cleotic setup acme.com
cleotic setup acme.com --no-input --market GB --json
cleotic setup --resume <setup-id>          # continue a setup waiting for approval

# Read
cleotic brands list
cleotic studies list
cleotic projects list                      # every brand and study
cleotic projects show <project-id>
cleotic projects summary <project-id>
cleotic primary-brand show --project <project-id>
cleotic competitors list --project <project-id>
cleotic segments list --project <project-id>
cleotic prompts list --segment <segment-id>
cleotic readiness show <project-id>        # latest site readiness score
cleotic readiness issues <project-id>      # its open issues in fix order
cleotic opportunities list <project-id>    # the brand's opportunity inbox
cleotic opportunities show <opportunity-id> --project <project-id>
cleotic ai-traffic summary <project-id> --from 2026-10-01 --to 2026-10-31
cleotic ai-traffic pages <project-id> --json   # every page, last 30 days
cleotic reports list <project-id>          # the brand's client reports
cleotic reports show <report-id> --project <project-id>

# Gate CI on site readiness: exit code 3 below the threshold
cleotic readiness show <project-id> --wait --fail-under 70

# Write
cleotic projects use <project-id>
cleotic primary-brand set --name "Acme" --domain acme.com --alias "Acme Inc"
cleotic competitors create --name "Rival" --domain rival.com
cleotic competitors update <competitor-id> --alias "Rival Co"
cleotic segments create --name "Acme AI visibility"
cleotic prompts create --segment <segment-id> --text "best crm for smb"
cleotic opportunities move <opportunity-id> --stage watching   # its work shipped
cleotic reports create <project-id>        # last month's report and its public link

# Delete (asks for confirmation; --yes skips it)
cleotic prompts delete <prompt-id> --segment <segment-id>
cleotic segments delete <segment-id> --yes
cleotic competitors delete <competitor-id> --project <project-id>
cleotic projects delete <project-id>
```

`--alias` replaces the existing alias list.

`cleotic readiness show --fail-under <score>` exits with code 3 when the
site readiness score is below `<score>`, and 1 when there is no finished
scan to check. The CLI reads scans but cannot start one: after a brand's
first scan, scans only run on the weekly schedule.

## Scripting

The CLI holds a firm machine contract across every command:

- Every command supports `--json`: exactly one JSON document on stdout,
  with progress and prompts kept on stderr, so piping into `jq` just
  works.
- Exit codes are stable: `0` success, `1` the operation failed, `2` you
  got the usage wrong, `3` the site readiness score is below
  `readiness show --fail-under`.
- Deletes are safe by default: they ask for confirmation in a terminal,
  and with `--no-input` (or no terminal) a delete without `--yes` fails
  with exit code `2` instead of prompting.

## Configuration

Settings are resolved flag → environment → config file, first match
wins:

| Source | Key | Purpose |
|---|---|---|
| flag | `--api-url` | Cleotic API URL for this invocation |
| env | `CLEOTIC_API_URL` | Cleotic API URL |
| env | `CLEOTIC_API_KEY` | API-key auth for CI/automation; overrides any browser login |
| config | `api_url` | Persistent API URL (`cleotic config set api-url <url>`) |
| config | `default_project_id` | Default brand or study project (`cleotic projects use <id>`) |

The config file lives at `~/.config/cleotic/config.yaml` (honoring
`XDG_CONFIG_HOME`). Browser-login tokens are never written there — they
stay in the OS keychain.

## Release Assets

Release binaries are published as macOS and Linux tarballs for `arm64`
and `x86_64`.

The release asset filenames include the CLI version:

```text
cleotic_0.6.1_mac-os_arm64.tar.gz
cleotic_0.6.1_mac-os_x86_64.tar.gz
cleotic_0.6.1_linux_arm64.tar.gz
cleotic_0.6.1_linux_x86_64.tar.gz
```

Each archive has a matching `.sha256` checksum file.

## Support

For help, contact Cleotic support or your Cleotic account team.
