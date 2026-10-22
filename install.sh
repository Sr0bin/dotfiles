#!/bin/bash
# install.sh -- set this dotfiles repo up on a fresh machine, without sudo.
#
#   git clone https://github.com/Sr0bin/dotfiles ~/dotfiles && ~/dotfiles/install.sh
#
# Idempotent: each step is skipped when already done, so re-running is safe.
# Every top-level dir of the repo is a GNU stow package mirroring $HOME.

set -euo pipefail
DOT=$(cd "$(dirname "$0")" && pwd)
BREW_PREFIX="$HOME/linuxbrew/.linuxbrew" # .zshrc expects brew exactly here
NODE_MAJOR=24
BACKUP="$HOME/.dotfiles-preinstall-backup"

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }
# clone URL DIR [TAG]: shallow clone, skipped if DIR already exists
clone() { [ -d "$2" ] || git clone -q --depth 1 ${3:+--branch "$3"} "$1" "$2"; }

step "Homebrew in $BREW_PREFIX"
[ -x "$BREW_PREFIX/bin/brew" ] || git clone -q https://github.com/Homebrew/brew "$BREW_PREFIX"
eval "$("$BREW_PREFIX/bin/brew" shellenv)"

step "CLI tools"
pkgs=(neovim lazygit lazydocker fzf git-delta gh tree-sitter-cli compiledb)
# system versions are fine when present (command:formula)
for pair in tmux:tmux stow:stow rg:ripgrep; do
	have "${pair%%:*}" || pkgs+=("${pair#*:}")
done
brew install --quiet "${pkgs[@]}"

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

step "Done"
cat <<EOF
Left to do by hand:
  - gh auth login          (dots-sync pushes over HTTPS with gh's credentials)
  - open a new terminal    (loads brew, nvm, fzf from .zshrc)
  - default shell: zsh     (chsh -s "\$(command -v zsh)" if it isn't already)
EOF
[ -d "$BACKUP" ] && echo "Replaced files were moved to $BACKUP"
exit 0
