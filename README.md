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
- A `~/.zshrc` file — [Oh My Zsh](https://ohmyz.sh/) is installed and configured by the managed `config/zsh/zshrc`

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
| `git`, `gh-stack` | Version control (GitHub CLI via mise) |
| `neovim` | Default editor |
| [mise](https://mise.jdx.dev/getting-started.html) | Runtimes, cloud/infra CLIs, and dev tools — see `config/mise/config.toml` |
| `asdf` | Installed via Homebrew for legacy `.tool-versions` / plugins (mise does not ship the asdf CLI) |
| `gcloud-cli` (cask) | Google Cloud CLI (`mise registry gcloud` exists; cask kept for macOS installer) |
| `task` (Homebrew) | Taskwarrior exposed as `tk` (go-task via mise as `task`) |
| `wget`, `tree`, `gnupg` | Not in mise registry — stay on Homebrew |

### Zsh plugins (Homebrew)

- `zsh-completions`
- `zsh-autosuggestions`
- `fast-syntax-highlighting` (Oh My Zsh custom plugin; cloned by `install.sh`)

### GUI apps (casks)

Bitwarden, Cursor, iTerm2, IntelliJ IDEA, Notion, VS Code, Fira Code font, and others.

To add a package, edit `Brewfile` and re-run `./install.sh`.

### mise (`config/mise/config.toml`)

[mise](https://mise.jdx.dev/getting-started.html) is installed from Homebrew; global tools live in **`config/mise/config.toml`** (symlinked to `~/.config/mise/config.toml`). Shell activation is in `config/zsh/mise.env`.

Re-run `dotinstall` (or `mise install`) after editing tools. Before moving a Homebrew formula into `[tools]`, confirm it with **`scripts/verify-mise-registry.zsh`** (also run from `scripts/check.sh` when `mise` is installed).

Node versions in projects with a **`.nvmrc`** are picked up automatically (`idiomatic_version_file_enable_tools` includes `node`).

In a repo with `.nvmrc`, run **`mu`** (or **`nvm use`**, which calls the same helper) to install that Node version and activate it in the current shell — without writing `mise.toml`. With `mise activate`, `cd` into the project also switches versions once the version is installed.

---

## Git configuration

From **`user-config.yml`** (copy from `user-config.example.yml`):

- `git config --global user.name` / `user.email` from `user.name` / `user.email`
- `github.username` → HTTPS→SSH URL rewrite for your repos, `gh` SSH protocol, and `GITHUB_USERNAME` in the shell
- `notes.directory` → `NOTES_DIR` in the shell (default: `$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/_Notes_`; use `$HOME` or `~`, not your macOS username)

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

### delta ([syntax-highlighting pager](https://github.com/dandavison/delta))

**Primary use:** configure `delta` as Git’s pager ([get started](https://github.com/dandavison/delta#get-started)). After `dotinstall`, `git diff`, `git show`, `git log -p`, and similar commands render through delta automatically.

**Two files (no git):**

```bash
delta file_A file_B
```

**Git-related extras:** `batdiff` uses delta when `BATDIFF_USE_DELTA=true` (`config/shell/bat`).

When `delta` is installed (`brew install git-delta`), `config/git/setup-delta` applies:

```bash
git config --global core.pager delta
git config --global interactive.diffFilter 'delta --color-only'
git config --global delta.navigate true
git config --global delta.dark true
git config --global merge.conflictStyle zdiff3
```

Re-run alone: `~/.config/git/setup-delta` (only changes values that differ)

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
2. Pick a type with **fzf** (or numbered menu as fallback): `feat`, `fix`, `refactor`, `docs`, `style`, `test`, `chore`, `perf`, `ci`, `build`, `revert`; enter commit message via **read**
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

On `dotinstall`, **`config/idea/install-keymap.sh`** merges VS Code/Cursor-style shortcuts from **`config/idea/keymaps/Dotfiles.xml`** into your active custom keymap (or activates **Dotfiles**):

| Shortcut | Action |
|----------|--------|
| **⌘T** | Show Pull Request in Tool Window |
| **⌘P** | Go to File |
| **⌘B** | Go to Declaration |
| **⌘⌥B** | Go to Implementation(s) |
| **⌘[** | Back |
| **⌘]** | Forward |
| **⌘D** | Add selection for next occurrence (multi-cursor) |
| **⌘⇧D** | Duplicate line or selection |
| **⌘⇧B** | Find usages |
| **⌘⌥K** | Toggle bookmark |
| **⌘⌥]** | Next bookmark |
| **⌘⌥[** | Previous bookmark |

Dotfiles unbinds **Move Caret to Code Block Start/End** on **⌘⌥[** / **⌘⌥]** so bookmarks can use those keys.

Open IntelliJ at least once before the first install so the config directory exists.

**VS Code / Cursor** share **`config/editor/keybindings.json`** (symlinked on `dotinstall`) for the same navigation and usage shortcuts as above. Bookmarks use the **[Bookmarks](https://marketplace.visualstudio.com/items?itemName=alefragnani.Bookmarks)** extension (`install-catppuccin.sh` installs it for `code` and `cursor`). Conflicting defaults (sidebar **⌘B**, build **⌘⇧B**, indent/outdent on **⌘[** / **⌘]**) are unbound where needed.

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

`aliases` is sourced from `~/.zshrc` (after Oh My Zsh; the installer runs `unalias gpr` / `gprm` first). It only loads `load`, which auto-sources every other file in `~/.config/shell/` (`editor`, `git`, `s`, …). Add a module by creating `config/shell/<name>` and re-running `dotinstall`.

| File | Contents |
|------|----------|
| `editor` | `vi` / `vim` → `nvim` |
| `ls` | `ls` / `ll` / `la` / `tree` → `eza`; `cat` → `bat` |
| `bat` | `batman --export-env` for highlighted `man` (see bat-extras below) |
| `git` | Git aliases and helpers (`gs`, `gco`, `gn`, `gac`, `gpr`, `grb`, …) |
| `github` | `GITHUB_USERNAME` from install (`~/.config/dotfiles/github.env`) |
| `notes` | `NOTES_DIR` from install (`~/.config/dotfiles/notes.env`) |
| `dotinstall` | `dotinstall` → `~/dotfiles/install.sh` |
| `s` / `open-project` / … | other helpers |

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
| `gm`, `gcl`, `gl`, `gt`, `gtp`, `gcp`, `grb` | merge, clone, log, tags, cherry-pick; `grb` → `git rebase -i --autostash` for commits since this branch was created |

**`s` / `se`**

| Command | Purpose |
|---------|---------|
| `s <pattern> [path]` | ripgrep; `*text` = ends with, `text*` = starts with |
| `se [editor] <pattern> [path]` | fzf + bat preview; open in nvim/cursor at the line |

**`s` patterns**

| Pattern | Meaning |
|---------|---------|
| `abc` | ripgrep search (regex; smart-case from `ripgreprc`) |
| `*abc` | lines **ending** with `abc` |
| `abc*` | lines **starting** with `abc` |
| `*abc*` | lines **containing** `abc` |

Quote patterns with `*` so the shell does not expand them: `s '*Error' ./src`

**`se`**

| Command | Opens in |
|---------|----------|
| `se timeout` | nvim (default) |
| `se vi timeout` | nvim (`vi`/`vim`/`nvim` are equivalent) |
| `se cursor '*Error' ./src` | Cursor |
| `se code timeout` | VS Code |

Optional editor comes first, then the same patterns as `s`. fzf uses bat preview (`highlight-line`, pane above); Enter opens at that line.

**Ctrl+F** / **Ctrl+N** — live fzf + bat preview; the search box is passed to **`rg`** as arguments (e.g. `-i -t md TODO`, `foo`, `-F 'exact'`). **`s`** / **`se`** wildcards do not apply there. **Ctrl+N** uses **`NOTES_DIR`**.

### Zsh startup (`config/zsh/`)

`~/.zshrc` gets **one** dotfiles block (`source ~/.config/zsh/zshrc`). Everything dotfiles owns lives in tracked files — edit them and the change applies to new shells; `dotinstall` only links.

| File | Loaded from | Purpose |
|------|-------------|---------|
| `zshrc` | `~/.zshrc` (single block) | Ordered interactive setup: completions, Oh My Zsh + plugins, fzf, zoxide, mise, kubectl completion, aliases |
| `zenv` | `~/.zshenv` (dotfiles block) | Universal env for every zsh (`DOTFILES_CONFIG`, `RIPGREP_CONFIG_PATH`, …) |
| `zprofile` | `~/.zprofile` (dotfiles block) | Login shell: `brew shellenv`, `~/.local/bin` on `PATH` |
| `zoxide.env` | `zshrc` | `eval "$(zoxide init zsh)"` when `zoxide` is installed |
| `mise.env` | `zshrc` | `mise activate zsh` — project tools, `.nvmrc`, and `JAVA_HOME` |
| `kubectl-completion.zsh` | `zshrc` | kubectl completion cached in `~/.cache/zsh/`, refreshed when the kubectl binary changes |

Optional, untracked hooks: `~/.config/zsh/pre-omz.zsh` (override `ZSH_THEME` / `plugins=(…)` before Oh My Zsh) and `~/.config/zsh/local.zsh` (machine-specific lines, runs last). Your own lines in `~/.zshrc` (PATH tweaks, secrets, aliases) are left alone.

**Migration:** on the first `dotinstall` after upgrading, the old patched blocks (`DOTFILES SETUP`, `ALIASES`, `KUBECTL COMPLETION`, the Oh My Zsh lines, the eager nvm lines) are removed from `~/.zshrc`, and a backup is written to `~/.zshrc.pre-managed.bak`. Custom OMZ theme/plugins are reported so you can move them to `pre-omz.zsh`.

`install.sh` also prepends managed blocks to `~/.zshenv` and `~/.zprofile` without replacing Docker, `sc-tools`, or other existing lines.

**Startup time:** run `dotprof` for a zprof report. mise activation is lighter than eager `nvm.sh`; kubectl completion is still cached on first use.

`zshrc` also sets `ZSH_DISABLE_COMPFIX=true`, puts Homebrew `zsh-completions` on `FPATH`, and `install.sh` fixes permissions on `$(brew --prefix)/share` to stop the compinit *"Ignore insecure directories"* prompt.

### Installer layout

`install.sh` is the ordered runner; function libraries live in `install/lib/` (`ui.sh` spinner, `ssh.sh`, `configure.sh` linking + defaults, `zsh.sh` Oh My Zsh + managed `~/.zshrc`). Run `scripts/check.sh` to syntax-check every shell file, run shellcheck on the bash scripts, and run `tests/`. Run `dothelp` to list commands and keybindings; add `# @help <name> | <description>` above anything new and it appears there.

---

## Search tooling

### fzf (`config/fzf/fzf.env`)

Based on [radleylewis/zsh `fzf.zsh`](https://github.com/radleylewis/zsh/blob/main/fzf.zsh):

- `fd` for files (Ctrl-T) and directories (Alt+C / `ç`); `--strip-cwd-prefix`
- Rounded border, 60% height, preview pane on the right (`bat` for file preview)
- Homebrew fzf completion and default key bindings (Ctrl-T, Alt+C)
- Zsh: `ç` → `fzf-cd-widget`; **Ctrl+F** / **Ctrl+N** → live **`rg`** in fzf (full rg args in query) with bat preview; Enter opens **nvim** at the match

### ripgrep (`config/ripgrep/ripgreprc`)

- Smart case matching
- Searches hidden files
- Honors `.gitignore` (including outside a git repo via `--no-require-git`)
- Skips `.git/` contents
- Zsh **`rg`** wrapper (`config/shell/rg`) uses **`noglob`** so patterns like `-g 'REA*'` reach ripgrep unchanged
- **Ctrl+F** / **Ctrl+N**: the search box is split into words and passed **verbatim** to **`rg`** (plus `--line-number --no-heading --color=never` for fzf display only). Example: `-g REA* gum`

### bat-extras (Homebrew `bat-extras`)

Installed via `Brewfile`; see upstream docs for options and formatters:

| Command | Purpose | Doc |
|---------|---------|-----|
| `prettybat` | Format source, then highlight with `bat` | [prettybat](https://github.com/eth-p/bat-extras/blob/master/doc/prettybat.md) |
| `batgrep` | Search with `rg`, print with `bat` | [batgrep](https://github.com/eth-p/bat-extras/blob/master/doc/batgrep.md) |
| `batdiff` | Diff vs git index, two files, or `--staged` | [batdiff](https://github.com/eth-p/bat-extras/blob/master/doc/batdiff.md) |
| `batman` | `man` through `bat` (fzf search if `fzf` installed) | [batman](https://github.com/eth-p/bat-extras/blob/master/doc/batman.md) |

`config/shell/bat` runs `eval "$(batman --export-env)"` so normal `man` uses `batman` when available.

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

Detaching tmux (`Ctrl+b d`) or closing the last tmux window returns you to a normal zsh prompt in iTerm (the profile no longer `exec`s into tmux only).

---

## iTerm2

- Profile built at install from `config/iterm2/profile.base.json` + [Catppuccin Mocha](https://github.com/mbadolato/iTerm2-Color-Schemes/blob/master/schemes/Catppuccin%20Mocha.itermcolors) (downloaded during `dotinstall`)
- Tmux startup script linked to `~/.config/iterm2/tmux-start.zsh`
- Quit confirmation disabled
- Tab style set to dark

Restart iTerm2 after install to pick up profile and theme changes.

---

## Terminal.app

- Profile **`config/terminal/github-dark.terminal`** (your exported Terminal settings) imported on every `dotinstall`
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
