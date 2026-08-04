# dotfiles

Personal macOS development environment — Homebrew packages, shell tooling, Git workflow, and app configs managed in one repo and applied with a single install script.

## Quick start

Clone the repo and run the installer:

```bash
git clone <your-repo-url> ~/dotfiles
cd ~/dotfiles
chmod +x install.sh
./install.sh
```

Already cloned? Re-apply everything anytime:

```bash
cd ~/dotfiles && ./install.sh
```

Open a **new terminal tab** when it finishes (or run `source ~/.zshrc`).

### Prerequisites

- macOS
- [Zsh](https://www.zsh.org/) as your default shell (macOS default)
- A `~/.zshrc` file — [Oh My Zsh](https://ohmyz.sh/) is supported; the installer patches it automatically

---

## What `install.sh` does

The installer is idempotent — safe to run multiple times.

| Step | Action |
|------|--------|
| Homebrew | Installs Homebrew if missing |
| Packages | Runs `brew bundle` from the `Brewfile` |
| Symlinks | Links config files into `~/.config` and other standard paths |
| Git | Sets global Git config (default branch, global ignore) |
| iTerm2 | Links dynamic profile and applies macOS defaults |
| Zsh | Fixes compinit warnings, wires plugins, sources aliases and fzf |
| Reload | Sources `~/.zshrc` at the end |

---

## Project structure

```
dotfiles/
├── install.sh              # Main installer
├── Brewfile                # Homebrew formulae, casks, and npm packages
├── ignore                  # Shared ignore rules (git, fd, ripgrep)
├── config/
│   ├── fzf/fzf.env         # fzf defaults and key bindings
│   ├── git/
│   │   ├── gac             # Conventional commit helper script
│   │   └── gpr             # GitHub pull request helper script
│   ├── iterm2/profile.json # iTerm2 dynamic profile
│   ├── ripgrep/ripgreprc   # ripgrep defaults
│   └── shell/aliases       # Shell aliases (git shortcuts, vi, gac)
└── README.md
```

---

## Homebrew packages (`Brewfile`)

### CLI tools

| Package | Purpose |
|---------|---------|
| `git`, `gh` | Version control and GitHub CLI |
| `neovim` | Default editor |
| `fzf`, `fd`, `ripgrep` | Fuzzy finding and fast search |
| `jq` | JSON processing |
| `go`, `python`, `protobuf` | Languages and tooling |
| `asdf`, `nvm` | Runtime version managers |
| `awscli`, `gcloud-cli` (cask) | Cloud CLIs |
| `terraform` (HashiCorp tap) | Infrastructure as code |
| `mongosh` | MongoDB shell |
| `go-task` | Task runner |

### Zsh plugins (Homebrew)

- `zsh-completions`
- `zsh-autosuggestions`
- `zsh-syntax-highlighting`

### GUI apps (casks)

Bitwarden, Cursor, iTerm2, IntelliJ IDEA, Notion, VS Code, Fira Code font, and others.

To add a package, edit `Brewfile` and re-run `./install.sh`.

---

## Git configuration

The installer sets these global options:

```bash
git config --global core.excludesfile ~/.global_ignore
git config --global init.defaultBranch main
```

- **`core.excludesfile`** — global gitignore via the shared `ignore` file
- **`init.defaultBranch main`** — new repos default to `main`

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

1. Enter PR **title**
2. Edit **description** in `nvim` (or `$EDITOR`) using a template:
   - `### Implementation`
   - `### Why`
3. Choose **ready** or **draft**
4. Push current branch if needed (`-u origin` on first push)
5. Create PR assigned to **you** (`@me`)
6. Print a **clickable URL** (OSC 8 hyperlink) and copy it to the clipboard

```bash
gprm    # PR into main/master
gpr     # PR into a branch you choose
```

Custom editor for the description:

```bash
export GIT_PR_EDITOR=vim
```

---

## Shell setup

### Aliases (`config/shell/aliases`)

Loaded automatically by `install.sh` via a `DOTFILES ALIASES` block appended to `~/.zshrc` (after Oh My Zsh). The installer runs `unalias gpr` first because the OMZ git plugin defines `gpr` as `git pull --rebase`.

| Alias / function | Maps to |
|------------------|---------|
| `vi`, `vim` | `nvim` |
| `gs` | `git status -sb` |
| `gco` | `git checkout` |
| `gcob <name>` | `git checkout -b <name>` |
| `gbd` | `git branch -d` |
| `gp` | `git pull` |
| `gpp` | `git push` (uses `-u origin <branch>` when no upstream is set) |
| `gac` | `~/.config/git/gac` |
| `gpr` | interactive PR via `gh` (choose base branch) |
| `gprm` | PR via `gh` into repo default branch |

### Zsh plugins (via `install.sh`)

Wired into `~/.zshrc`:

- Homebrew `zsh-completions` on `FPATH`
- `ZSH_DISABLE_COMPFIX=true` plus a permission fix on `$(brew --prefix)/share` to stop the compinit *"Ignore insecure directories"* prompt
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

## iTerm2

- Dynamic profile linked from `config/iterm2/profile.json` (font, size, colors)
- Quit confirmation disabled
- Tab style set to dark

Restart iTerm2 after install to pick up profile changes.

---

## Manual one-liners

If you only need part of the setup without a full reinstall:

```bash
# Symlink configs only (from repo root)
DOTFILES=~/dotfiles
ln -sfn "$DOTFILES/config/shell/aliases" ~/.config/shell/aliases
ln -sfn "$DOTFILES/config/git/gac" ~/.config/git/gac
ln -sfn "$DOTFILES/config/git/gpr" ~/.config/git/gpr
chmod +x ~/.config/git/gac ~/.config/git/gpr
source ~/.config/shell/aliases

# Git defaults
git config --global init.defaultBranch main
git config --global --unset include.path 2>/dev/null || true

# Fix zsh compinit prompt
chmod go-w "$(brew --prefix)/share"
```

---

## Customisation

1. Edit files under `config/` or `Brewfile`
2. Run `./install.sh` to re-link and re-apply
3. Open a new terminal or `source ~/.zshrc`
