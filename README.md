# dotfiles

Personal macOS development environment — Homebrew packages, shell tooling, Git workflow, and app configs managed in one repo and applied with a single install script.

## Quick start

Clone the repo and run the installer:

```bash
git clone https://github.com/mahfuzsust/dotfiles ~/dotfiles
cd ~/dotfiles
chmod +x install.sh
./install.sh
```

Already cloned? Re-apply everything anytime:

```bash
dotinstall
```

Or:

```bash
cd ~/dotfiles && ./install.sh
```

Open a **new terminal tab** when it finishes (or run `source ~/.zshrc`).

### Prerequisites

- macOS
- [Zsh](https://www.zsh.org/) as your default shell (macOS default)
- A `~/.zshrc` file — [Oh My Zsh](https://ohmyz.sh/) is supported; the installer patches it automatically

---

### Manual steps

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

---

## Homebrew packages (`Brewfile`)

### CLI tools

| Package | Purpose |
|---------|---------|
| `git`, `gh`, `gh-stack` | Version control and GitHub CLI |
| `neovim` | Default editor |
| `fzf`, `fd`, `ripgrep` | Fuzzy finding and fast search |
| `jq` | JSON processing |
| `go`, `python`, `protobuf` | Languages and tooling |
| `asdf`, `nvm` | Runtime version managers |
| `awscli`, `gcloud-cli` (cask) | Cloud CLIs |
| `terraform` (HashiCorp tap) | Infrastructure as code |
| `mongosh` | MongoDB shell |
| `go-task` | Task runner exposed as `task` |
| `task` | Taskwarrior exposed as `tk` |

### Zsh plugins (Homebrew)

- `zsh-completions`
- `zsh-autosuggestions`
- `zsh-syntax-highlighting`

### GUI apps (casks)

Bitwarden, Cursor, iTerm2, IntelliJ IDEA, Notion, VS Code, Fira Code font, and others.

To add a package, edit `Brewfile` and re-run `./install.sh`.

---

## Git configuration

From **`user-config.yml`** (copy from `user-config.example.yml`):

- `git config --global user.name` / `user.email` from `user.name` / `user.email`
- `github.username` → HTTPS→SSH URL rewrite for your repos, `gh` SSH protocol, and `GITHUB_USERNAME` in the shell

The installer also sets:

```bash
git config --global core.excludesfile ~/.global_ignore
git config --global init.defaultBranch main
git config --global sequence.editor nvim   # interactive rebase todo list
git config --global core.editor nvim       # commit messages (incl. during rebase)
```

- **`core.excludesfile`** — global gitignore via the shared `ignore` file
- **`init.defaultBranch main`** — new repos default to `main`
- **`sequence.editor` / `core.editor`** — Neovim for `git rebase -i` and other Git editing (when `nvim` is installed)

### GPG commit signing

During `dotinstall`, the installer:

1. Skips setup if `user.signingkey` is already configured
2. Prompts for **email** and **name** (name only when creating a new key)
3. Creates an **Ed25519 key with no passphrase** if none exists for that email
4. Sets `user.signingkey`, `user.email`, `user.name`, and `commit.gpgsign true`
5. Saves the public key to `~/.config/git/gpg-public-key.asc` and prints a copy command using your key fingerprint

Run it alone anytime:

```bash
~/dotfiles/config/git/setup-gpg
```

---

### `gac` — conventional commits

Shell alias that runs an interactive commit helper:

```bash
gac
```

What it does:

1. `git add -A`
2. Pick a type with **fzf** (or a numbered menu as fallback): `feat`, `fix`, `refactor`, `docs`, `style`, `test`, `chore`, `perf`, `ci`, `build`, `revert`
3. Enter a commit message
4. Trim trailing whitespace and a trailing `.`
5. Commit with format: **`type(branch-name): message`**

Example:

```
feat(main): add terraform to brewfile
```

### `gpr` / `gprm` — GitHub pull requests

Interactive PR creation via the [GitHub CLI](https://cli.github.com/) (`gh`). Requires `gh auth login`.

| Command | Base branch |
|---------|-------------|
| `gprm` | Repo default (`main`, `master`, or GitHub default) |
| `gpr` | You pick from remote branches (fzf) |

Flow for both:

1. Pick **base** branch (`gprm` uses repo default)
2. **`git rebase -i --autostash origin/<base>`** — edit/squash/reword only this branch’s commits (uses `sequence.editor`, usually `nvim`)
3. Enter PR **title** (pre-filled if exactly one commit ahead of base after rebase)
4. Edit **description** in `nvim` (or `$EDITOR`) using a template:
   - `### Implementation`
   - `### Why`
5. Choose **ready** or **draft**
6. Push (including `--force-with-lease` if rebase rewrote history)
7. Create PR assigned to **you** (`@me`)
8. Print a **clickable URL** (OSC 8 hyperlink) and copy it to the clipboard

```bash
gprm    # PR into main/master
gpr     # PR into a branch you choose
```

Custom editor for the description:

```bash
export GIT_PR_EDITOR=vim
```

### IntelliJ IDEA keymap (`config/idea/`)

On `dotinstall`, **`config/idea/install-keymap.sh`** sets **⌘T** to **Show Pull Request in Tool Window** (`Github.Pull.Request.Show.In.Toolwindow`) on your active custom keymap, or installs the **Dotfiles** keymap (parent: macOS defaults).

Open IntelliJ at least once before the first install so the config directory exists.

### `greview` — review a pull request in IntelliJ IDEA

```bash
greview https://github.com/owner/repo/pull/123
```

Clones into `~/projects/<repo>` if needed (SSH), `git fetch origin`, runs `gh pr checkout <url>` in that directory, then opens **IntelliJ IDEA** on the project in the background (no separate worktree or IDE diff view).

### `gclean` — branch cleanup

```bash
gclean      # prune + list
gclean -f   # also delete branches with no upstream
```

What it does:

1. `git fetch --prune`
2. **Deletes** local branches that are merged into the default base and whose remote was deleted (`[gone]`)
3. **Lists** local branches with no upstream tracking (never deletes current, `main`, or `master`)
4. With **`-f`**, **deletes** all local branches with no upstream tracking

---

## Shell setup

### Shell modules (`config/shell/`)

`aliases` is sourced from `~/.zshrc` (after Oh My Zsh; the installer runs `unalias gpr` / `gprm` first). It only loads `load`, which auto-sources every other file in `~/.config/shell/` (`editor`, `git`, `search`, …). Add a module by creating `config/shell/<name>` and re-running `dotinstall`.

| File | Contents |
|------|----------|
| `editor` | `vi` / `vim` → `nvim` |
| `git` | Git aliases and helpers (`gs`, `gco`, `gn`, `gac`, `gpr`, `grb`, …) |
| `github` | `GITHUB_USERNAME` from install (`~/.config/dotfiles/github.env`) |
| `dotinstall` | `dotinstall` → `~/dotfiles/install.sh` |
| `search` / `open-project` / … | other helpers |

**Git module (`config/shell/git`)** — highlights:

| Alias / function | Maps to |
|------------------|---------|
| `gs` | `git status -sb` |
| `gco` | `git checkout` |
| `gcob <name>` | `git checkout -b <name>` |
| `grr` | discard all local changes (`git reset --hard` + `git clean -fd`) |
| `gn <name>` | create branch with changeset from `main`/`master` |
| `gbd` | `git branch -d` |
| `gp` | pull with rebase + autostash |
| `gpp` | `git push` |
| `gppr` | rebase onto `origin/main` (or master) with `--autostash`, then push (`-u origin` if new; `--force-with-lease` if diverged) |
| `grbm` | `git rebase origin/main --autostash` only (no push) |
| `gac`, `gpr`, `gprm`, `greview`, `gclean` | `~/.config/git/*` scripts |
| `gm`, `gcl`, `gl`, `gt`, `gtp`, `gcp`, `grb` | merge, clone, log, tags, cherry-pick, interactive rebase |

**`search`**

| Command | Purpose |
|---------|---------|
| `search <pattern> [path]` | ripgrep; `*text` = ends with, `text*` = starts with |
| `searche [editor] <pattern> [path]` | fzf pick, open in nvim/cursor at the line |

**`search` patterns**

| Pattern | Meaning |
|---------|---------|
| `abc` | ripgrep search (regex; smart-case from `ripgreprc`) |
| `*abc` | lines **ending** with `abc` |
| `abc*` | lines **starting** with `abc` |
| `*abc*` | lines **containing** `abc` |

Quote patterns with `*` so the shell does not expand them: `search '*Error' ./src`

**`searche`**

| Command | Opens in |
|---------|----------|
| `searche timeout` | nvim (default) |
| `searche vi timeout` | nvim (`vi`/`vim`/`nvim` are equivalent) |
| `searche cursor '*Error' ./src` | Cursor |
| `searche code timeout` | VS Code |

Optional editor comes first, then the same patterns as `search`. fzf shows `file:line:content`; Enter opens at that line.

### Zsh plugins (via `install.sh`)

Wired into `~/.zshrc`:

- Homebrew `zsh-completions` on `FPATH`
- `ZSH_DISABLE_COMPFIX=true` plus a permission fix on `$(brew --prefix)/share` to stop the compinit *"Ignore insecure directories"* prompt
- `source <(kubectl completion zsh)` for kubectl tab completion
- `zsh-autosuggestions` and `zsh-syntax-highlighting` (sourced last)

---

## Search tooling

### fzf (`config/fzf/fzf.env`)

- Uses `fd` for file and directory search (respects ignore rules)
- Reverse layout, border, inline info
- Shell completion and key bindings from Homebrew fzf
- Custom zsh bindkey `ç` → `fzf-cd-widget`

### ripgrep (`config/ripgrep/ripgreprc`)

- Smart case matching
- Searches hidden files
- Skips `.git/` contents

### Shared ignore file (`ignore`)

Symlinked to three locations so one file drives all ignore behaviour:

| Path | Used by |
|------|---------|
| `~/.global_ignore` | Git (`core.excludesfile`) |
| `~/.config/fd/ignore` | `fd` |
| `~/.ignore` | `ripgrep` |

---

## tmux

Config: `config/tmux/tmux.conf` (linked to `~/.tmux.conf`).

iTerm2 starts or attaches session `main` via `~/.config/iterm2/tmux-start.zsh`.

**Prefix:** `Ctrl+b`

| Keys | Action |
|------|--------|
| `v` | vertical split (side by side) |
| `\\` | horizontal split (top / bottom) |
| `r` | reload tmux config |

Click a pane or status-bar tab to switch. After changing config, run `dotinstall` or `Ctrl+b r`. If needed: `tmux kill-server` then open a new iTerm tab.

---

## iTerm2

- Profile built at install from `config/iterm2/profile.base.json` + [Catppuccin Mocha](https://github.com/mbadolato/iTerm2-Color-Schemes/blob/master/schemes/Catppuccin%20Mocha.itermcolors) (downloaded during `dotinstall`)
- Tmux startup script linked to `~/.config/iterm2/tmux-start.zsh`
- Quit confirmation disabled
- Tab style set to dark

Restart iTerm2 after install to pick up profile and theme changes.

---

## Terminal.app

- Profile **`config/terminal/catppuccin-mocha.terminal`** (your exported Terminal settings) imported on every `dotinstall`
- Set as **Default Window Settings** and **Startup Window Settings**
- Open a **new** Terminal window after install; if import fails, open Terminal once and re-run `config/terminal/install.sh`

---

## Manual one-liners

If you only need part of the setup without a full reinstall:

```bash
# Symlink configs only (from repo root)
DOTFILES=~/dotfiles
ln -sfn "$DOTFILES/config/shell/aliases" ~/.config/shell/aliases
ln -sfn "$DOTFILES/config/tmux/tmux.conf" ~/.tmux.conf
ln -sfn "$DOTFILES/config/iterm2/tmux-start.zsh" ~/.config/iterm2/tmux-start.zsh
chmod +x ~/.config/iterm2/tmux-start.zsh
curl -fsSL "https://raw.githubusercontent.com/mbadolato/iTerm2-Color-Schemes/master/schemes/Catppuccin%20Mocha.itermcolors" \
  -o ~/.config/iterm2/Catppuccin\ Mocha.itermcolors
python3 "$DOTFILES/config/iterm2/build-profile.py" \
  "$DOTFILES/config/iterm2/profile.base.json" \
  ~/.config/iterm2/Catppuccin\ Mocha.itermcolors \
  "$HOME/Library/Application Support/iTerm2/DynamicProfiles/profile.json"
ln -sfn "$DOTFILES/config/git/gac" ~/.config/git/gac
ln -sfn "$DOTFILES/config/git/gpr" ~/.config/git/gpr
ln -sfn "$DOTFILES/config/git/greview" ~/.config/git/greview
ln -sfn "$DOTFILES/config/git/gclean" ~/.config/git/gclean
chmod +x ~/.config/git/gac ~/.config/git/gpr ~/.config/git/greview ~/.config/git/gclean
source ~/.config/shell/aliases

# Git defaults
git config --global init.defaultBranch main
git config --global --unset include.path 2>/dev/null || true

# Fix zsh compinit prompt
chmod go-w "$(brew --prefix)/share"
```
