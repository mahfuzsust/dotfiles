# Manual setup for `install.sh`

Steps the installer cannot fully automate. Do these **before** or **after** `./install.sh` as noted.

## Before first run

### `user-config.yml` (required)

Copy and edit at the repo root:

```bash
cp user-config.example.yml user-config.yml
```

Set **`user.name`**, **`user.email`**, and **`github.username`**. The installer uses them for:

- Git `user.name` / `user.email`
- SSH key comment (`user.email`)
- Git URL rewrite: `https://github.com/<username>/…` → `git@github.com:<username>/…`
- `gh config set git_protocol ssh` (when `gh` is installed)
- `export GITHUB_USERNAME` in `~/.config/dotfiles/github.env` (sourced from your shell via `config/shell/github`)

**Add the public key to GitHub** (once per machine):

```bash
pbcopy < ~/.ssh/id_ed25519.pub
```

Open [GitHub → SSH and GPG keys → New SSH key](https://github.com/settings/ssh/new), paste, and save.

### GitHub CLI

```bash
gh auth login
```

### GPG public key on GitHub

If commit signing was configured, add the printed key to GitHub → **Settings → SSH and GPG keys**, or:

```bash
gpg --armor --export "$(git config user.signingkey)" | pbcopy
```

### App logins (casks from Brewfile)

Sign in or grant permissions as needed, for example:

- Bitwarden, Notion, Cursor, VS Code, IntelliJ
- **gcloud** / **AWS** CLI: run `gcloud auth login` / `aws configure` when you use them
