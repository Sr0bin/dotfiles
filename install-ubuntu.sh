#!/bin/bash
# install-ubuntu.sh -- set this dotfiles repo up on an Ubuntu machine where you have sudo.
# Same result as install.sh, but system packages come from apt / upstream binaries
# instead of a home-dir Homebrew.
#
#   git clone https://github.com/Sr0bin/dotfiles ~/dotfiles && ~/dotfiles/install-ubuntu.sh
#
# Run it as your normal user: it calls sudo itself for the system steps, and the
# per-user steps (stow, oh-my-zsh, nvm, plugins) must not end up owned by root.
# Idempotent: each step is skipped when already done, so re-running is safe.
# Every top-level dir of the repo is a GNU stow package mirroring $HOME.

set -euo pipefail
DOT=$(cd "$(dirname "$0")" && pwd)
NODE_MAJOR=24
FZF_MIN=0.48 # .zshrc uses `fzf --zsh`; Ubuntu 24.04 ships 0.44
BACKUP="$HOME/.dotfiles-preinstall-backup"

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }
# clone URL DIR [TAG]: shallow clone, skipped if DIR already exists
clone() { [ -d "$2" ] || git clone -q --depth 1 ${3:+--branch "$3"} "$1" "$2"; }
# gh_bin OWNER/REPO BINARY: put BINARY from the latest linux x86_64 release tarball in /usr/local/bin
gh_bin() {
	local url tmp
	url=$(curl -fsSL "https://api.github.com/repos/$1/releases/latest" |
		grep -oiE '"browser_download_url": *"[^"]*linux_(amd64|x86_64)\.tar\.gz"' |
		head -n1 | grep -oE 'https://[^"]+')
	[ -n "$url" ] || { echo "no linux x86_64 tarball found for $1" >&2; return 1; }
	tmp=$(mktemp -d)
	curl -fsSL "$url" | tar -xz -C "$tmp" "$2"
	sudo install -m 755 "$tmp/$2" /usr/local/bin/
	rm -rf "$tmp"
	echo "installed $2 from $url"
}
version_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]; }

[ "$EUID" -ne 0 ] || { echo "run as your user, not root (sudo is called where needed)" >&2; exit 1; }
[ "$(uname -m)" = x86_64 ] || { echo "only x86_64 is handled (release binaries)" >&2; exit 1; }
sudo -v # ask for the password once, up front

step "apt packages"
# tmux 3.4 in 24.04 is new enough for .tmux.conf (needs >= 3.3)
# build-essential: nvim-treesitter compiles parsers; unzip: Mason unpacks servers with it
# gdb, valgrind: the C/C++ layout of ~/bin/tlayout runs gdb and valgrind-listener
sudo apt-get update -q
sudo apt-get install -y -q zsh git curl stow ripgrep tmux git-delta pipx unzip \
	build-essential software-properties-common gdb valgrind

step "Neovim (neovim-ppa/unstable; Ubuntu's own is 0.9)"
if ! grep -rqs neovim-ppa /etc/apt/sources.list.d/; then
	sudo add-apt-repository -y ppa:neovim-ppa/unstable
	sudo apt-get update -q
fi
sudo apt-get install -y -q neovim

step "GitHub CLI (official apt repo)"
if ! have gh; then
	sudo install -d -m 755 /etc/apt/keyrings
	curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg |
		sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
	sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
	echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" |
		sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
	sudo apt-get update -q
	sudo apt-get install -y -q gh
fi

step "Brave + Discord (launched by ~/bin/startup)"
if ! have brave-browser; then
	sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
		https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
	echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" |
		sudo tee /etc/apt/sources.list.d/brave-browser-release.list >/dev/null
	sudo apt-get update -q
	sudo apt-get install -y -q brave-browser
fi
have discord || sudo snap install discord

step "fzf, lazygit, lazydocker (upstream release binaries)"
fzf_ver=$(fzf --version 2>/dev/null | cut -d' ' -f1 || true)
if [ -z "$fzf_ver" ] || ! version_ge "$fzf_ver" "$FZF_MIN"; then
	# /usr/local/bin comes before /usr/bin in PATH, so this shadows an old apt fzf
	gh_bin junegunn/fzf fzf
fi
have lazygit || gh_bin jesseduffield/lazygit lazygit
have lazydocker || gh_bin jesseduffield/lazydocker lazydocker

step "compiledb, norminette (pipx)"
have compiledb || pipx install compiledb
have norminette || pipx install norminette # norminette42.nvim calls it
pipx ensurepath >/dev/null # .zshrc already adds ~/.local/bin; harmless otherwise

step "kitty (official installer, in ~/.local/kitty.app)"
# apt's kitty is 0.32; this one is current and updates by re-running the installer
if [ ! -x "$HOME/.local/kitty.app/bin/kitty" ]; then
	curl -fsSL https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin launch=n
fi
mkdir -p "$HOME/.local/bin" "$HOME/.local/share/applications"
ln -sf "$HOME/.local/kitty.app/bin/kitty" "$HOME/.local/kitty.app/bin/kitten" "$HOME/.local/bin/"
# app-menu entries, pointed at the absolute paths (the menu doesn't see ~/.local/bin)
for f in kitty.desktop kitty-open.desktop; do
	sed -e "s|Icon=kitty|Icon=$HOME/.local/kitty.app/share/icons/hicolor/256x256/apps/kitty.png|" \
		-e "s|Exec=kitty|Exec=$HOME/.local/kitty.app/bin/kitty|" \
		"$HOME/.local/kitty.app/share/applications/$f" >"$HOME/.local/share/applications/$f"
done

step "Link config with stow"
# Move real files that would block a link to $BACKUP (same relative path).
# ponytail: only files are checked; an existing real dir (e.g. ~/.config/nvim with
# other files in it) is kept and stow links inside it instead of linking the dir.
cd "$DOT"
packages=()
for pkg in */; do packages+=("${pkg%/}"); done
for pkg in "${packages[@]}"; do
	while IFS= read -r rel; do
		target="$HOME/$rel"
		# already ours when it resolves into the repo (directly or through a linked parent dir)
		if [ -e "$target" ] && [ "$(realpath "$target")" != "$DOT/$pkg/$rel" ]; then
			mkdir -p "$BACKUP/$(dirname "$rel")"
			mv "$target" "$BACKUP/$rel"
			echo "backed up ~/$rel -> $BACKUP/$rel"
		fi
	done < <(cd "$pkg" && find . -type f -printf '%P\n')
done
stow -t "$HOME" "${packages[@]}"

step "oh-my-zsh"
# KEEP_ZSHRC: our stowed .zshrc is already in place
[ -d "$HOME/.oh-my-zsh" ] || RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
	sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

step "nvm + Node $NODE_MAJOR"
# PROFILE=/dev/null: the nvm loader lines are already in our .zshrc
[ -s "$HOME/.nvm/nvm.sh" ] || PROFILE=/dev/null \
	bash -c "$(curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh)"
export NVM_DIR="$HOME/.nvm"
set +u # nvm.sh is not written for `set -u`
. "$NVM_DIR/nvm.sh" || true # returns 3 when no default node exists yet
nvm install "$NODE_MAJOR" >/dev/null
nvm alias default "$NODE_MAJOR" >/dev/null
set -u

step "tree-sitter CLI (npm, into nvm's node)"
have tree-sitter || npm install -g --silent tree-sitter-cli

step "tmux plugins"
clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
clone https://github.com/tmux-plugins/tmux-yank "$HOME/.tmux/plugins/tmux-yank"
clone https://github.com/tmux-plugins/tmux-cpu "$HOME/.tmux/plugins/tmux-cpu"
# .tmux.conf also runs these two directly from ~/.config/tmux/plugins
clone https://github.com/catppuccin/tmux "$HOME/.config/tmux/plugins/catppuccin/tmux" v2.1.3
clone https://github.com/tmux-plugins/tmux-cpu "$HOME/.config/tmux/plugins/tmux-cpu"

step "Daily dotfiles sync (systemd user timer)"
if systemctl --user show-environment >/dev/null 2>&1; then
	systemctl --user daemon-reload
	systemctl --user enable --now dots-sync.timer
else
	echo "no systemd user session: skipped, run ~/bin/dots-sync by hand"
fi

step "Neovim plugins and language servers"
nvim --headless "+Lazy! sync" +qa
nvim --headless +MasonToolsInstallSync +qa

step "Default shell"
zsh_path=$(command -v zsh)
if [ "$(getent passwd "$USER" | cut -d: -f7)" != "$zsh_path" ]; then
	sudo chsh -s "$zsh_path" "$USER"
	echo "login shell set to $zsh_path (takes effect at next login)"
fi

step "Done"
cat <<EOF
Left to do by hand:
  - gh auth login          (dots-sync pushes over HTTPS with gh's credentials)
  - open a new terminal    (loads nvm, fzf from .zshrc)
EOF
[ -d "$BACKUP" ] && echo "Replaced files were moved to $BACKUP"
exit 0
