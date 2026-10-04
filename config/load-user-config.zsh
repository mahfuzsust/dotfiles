#!/usr/bin/env zsh
# Load user-config.yml into USER_NAME, USER_EMAIL, GITHUB_USERNAME.
# Usage: ensure_user_config /path/to/user-config.yml && load_user_config /path/to/user-config.yml

prompt_nonempty() {
    local var_name="$1" prompt_text="$2" value=""
    while true; do
        read -r "value?${prompt_text}: " </dev/tty
        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"
        if [[ -n "$value" ]]; then
            eval "${var_name}=\$value"
            return 0
        fi
        echo "Value cannot be empty." >/dev/tty
    done
}

DEFAULT_NOTES_DIR="${DEFAULT_NOTES_DIR:-$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/_Notes_}"

write_user_config_file() {
    local config_file="$1" name="$2" email="$3" github_user="$4"

    if [[ ! -x /usr/bin/ruby ]]; then
        echo "install requires /usr/bin/ruby to write user-config.yml" >&2
        return 1
    fi

    UC_NAME="$name" UC_EMAIL="$email" UC_GITHUB="$github_user" UC_NOTES="$DEFAULT_NOTES_DIR" \
        /usr/bin/ruby -ryaml -e '
          require "yaml"
          File.write(
            ARGV[0],
            {
              "user" => {"name" => ENV.fetch("UC_NAME"), "email" => ENV.fetch("UC_EMAIL")},
              "github" => {"username" => ENV.fetch("UC_GITHUB")},
              "notes" => {"directory" => ENV.fetch("UC_NOTES")}
            }.to_yaml
          )
        ' "$config_file"
}

ensure_user_config() {
    local config_file="$1"
    local name="" email="" github_user=""

    if [[ -f "$config_file" ]]; then
        return 0
    fi

    if [[ ! -e /dev/tty ]]; then
        echo "Missing $config_file and no TTY to create it interactively." >&2
        echo "Copy user-config.example.yml to user-config.yml and edit, or run ./install.sh in a terminal." >&2
        return 1
    fi

    {
        print -r -- ""
        print -r -- "user-config.yml not found."
        print -r -- "Enter the values used for Git, SSH, and GitHub (written to ${config_file:t})."
        print -r -- ""
    } >/dev/tty

    prompt_nonempty name "Full name (user.name)"
    prompt_nonempty email "Email (user.email)"
    prompt_nonempty github_user "GitHub username (github.username)"

    write_user_config_file "$config_file" "$name" "$email" "$github_user"
    echo "Wrote $config_file" >/dev/tty
}

load_user_config() {
    local config_file="$1"
    local -a fields=()

    if [[ ! -f "$config_file" ]]; then
        echo "Missing $config_file" >&2
        return 1
    fi

    if [[ ! -x /usr/bin/ruby ]]; then
        echo "install requires /usr/bin/ruby to read user-config.yml" >&2
        return 1
    fi

    if ! fields=("${(@f)$(/usr/bin/ruby -ryaml -e '
        d = YAML.load_file(ARGV[0])
        u = d.fetch("user")
        gh = d.fetch("github")
        [u.fetch("name"), u.fetch("email"), gh.fetch("username")].each do |v|
          v = v.to_s.strip
          abort "user-config.yml: name, email, and github.username must be non-empty" if v.empty?
          puts v
        end
    ' "$config_file")}"); then
        return 1
    fi

    if (( ${#fields[@]} != 3 )); then
        echo "user-config.yml: expected user.name, user.email, github.username" >&2
        return 1
    fi

    USER_NAME="$fields[1]"
    USER_EMAIL="$fields[2]"
    GITHUB_USERNAME="$fields[3]"
}

ensure_homebrew_prefix_ownership() {
    local prefix="/opt/homebrew" owner="" mac_user=""

    [[ -d "$prefix" ]] || return 0

    mac_user="$(whoami 2>/dev/null || id -un 2>/dev/null || true)"
    [[ -n "$mac_user" ]] || return 0

    owner="$(stat -f '%Su' "$prefix" 2>/dev/null || true)"
    if [[ "$owner" == "$mac_user" ]]; then
        echo "Homebrew prefix already owned by $mac_user"
        return 0
    fi

    if ! command -v sudo >/dev/null 2>&1; then
        echo "sudo not found; skipping chown of $prefix" >&2
        return 0
    fi

    echo "Fixing ownership of $prefix (sudo chown -R ${mac_user})…"
    if [[ -e /dev/tty ]]; then
        sudo chown -R "$mac_user" "$prefix" </dev/tty >/dev/tty
    else
        sudo chown -R "$mac_user" "$prefix"
    fi
}

ensure_brew_trusted_taps() {
    local tap="" trusted_json=""

    command -v brew >/dev/null 2>&1 || return 0

    trusted_json="$(brew trust --json v1 2>/dev/null || true)"

    for tap in mahfuzsust/tap; do
        if [[ -n "$trusted_json" ]] && print -r -- "$trusted_json" | grep -Fq "$tap"; then
            echo "Homebrew tap already trusted: $tap"
            continue
        fi
        if brew trust --tap "$tap" 2>/dev/null; then
            echo "Trusted Homebrew tap: $tap"
        else
            echo "brew trust --tap $tap failed; continuing" >&2
        fi
    done
}

load_notes_dir_from_config() {
    local config_file="$1"

    if [[ ! -f "$config_file" ]]; then
        echo "Missing $config_file" >&2
        return 1
    fi

    if [[ ! -x /usr/bin/ruby ]]; then
        echo "install requires /usr/bin/ruby to read user-config.yml" >&2
        return 1
    fi

    NOTES_DIR="$(NOTES_DEFAULT="$DEFAULT_NOTES_DIR" HOME="$HOME" /usr/bin/ruby -ryaml -e '
        d = YAML.load_file(ARGV[0])
        home = ENV.fetch("HOME")
        default = ENV.fetch("NOTES_DEFAULT")
        raw = d.dig("notes", "directory")
        raw = default if raw.nil? || raw.to_s.strip.empty?
        raw = raw.to_s.strip
        raw = raw.sub(/\A~(?=\/)/, home)
        raw = raw.gsub(/\$\{HOME\}|\$HOME/, home)
        puts File.expand_path(raw)
    ' "$config_file")" || return 1

    if [[ -z "$NOTES_DIR" ]]; then
        echo "user-config.yml: notes.directory resolved to empty path" >&2
        return 1
    fi
}

write_notes_env() {
    local dest="$1" new_content=""

    new_content="$(print -r -- "# Generated by install.sh from user-config.yml — do not edit"
print -r -- "export NOTES_DIR=${(q)NOTES_DIR}")"

    if [[ -f "$dest" ]] && [[ "$(<"$dest")" == "$new_content" ]]; then
        return 0
    fi

    mkdir -p "$(dirname "$dest")"
    print -r -- "$new_content" >"$dest"
}

git_config_set_if_needed() {
    local key="$1" expected="$2" current=""

    current="$(git config --global "$key" 2>/dev/null || true)"
    if [[ "$current" == "$expected" ]]; then
        return 0
    fi
    git config --global "$key" "$expected"
}

apply_git_user_from_config() {
    git_config_set_if_needed user.name "$USER_NAME"
    git_config_set_if_needed user.email "$USER_EMAIL"
}

write_github_env() {
    local dest="$1" new_content=""

    new_content="$(print -r -- "# Generated by install.sh from user-config.yml — do not edit"
print -r -- "export GITHUB_USERNAME=${(q)GITHUB_USERNAME}")"

    if [[ -f "$dest" ]] && [[ "$(<"$dest")" == "$new_content" ]]; then
        return 0
    fi

    mkdir -p "$(dirname "$dest")"
    print -r -- "$new_content" >"$dest"
}

apply_github_from_config() {
    local insteadof="https://github.com/${GITHUB_USERNAME}/"
    local url_key="url.git@github.com:${GITHUB_USERNAME}/.insteadof"
    local current="" gh_protocol=""

    current="$(git config --global --get "$url_key" 2>/dev/null || true)"
    if [[ "$current" != "$insteadof" ]]; then
        git config --global \
            url."git@github.com:${GITHUB_USERNAME}/".insteadOf \
            "$insteadof"
    fi

    if command -v gh >/dev/null 2>&1; then
        gh_protocol="$(gh config get git_protocol -h github.com 2>/dev/null || true)"
        if [[ "$gh_protocol" != "ssh" ]]; then
            gh config set git_protocol ssh -h github.com 2>/dev/null || true
        fi
    fi
}
