SHELL = /bin/bash
DOTFILES_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
OS := $(shell bin/is-supported bin/is-macos macos linux)
PATH := $(DOTFILES_DIR)/bin:$(PATH)
NVM_DIR := $(HOME)/.nvm
VIM_DIR := ~/.vim_runtime
OH_MY_ZSH_DIR := ~/.oh-my-zsh
export XDG_CONFIG_HOME := $(HOME)/.config
export VSCODE_CONFIG_HOME := $(HOME)/Library/Application\ Support/Code/User

.PHONY: test

all: $(OS)

macos: sudo core-macos packages link install-vim select-shell-terminal

linux: core-linux link install-vim

core-macos: brew bash git npm ruby

core-linux:
	apt-get update
	apt-get upgrade -y
	apt-get dist-upgrade -f

stow-macos: brew
	is-executable stow || brew install stow

stow-linux: core-linux
	is-executable stow || apt-get -y install stow

sudo:
ifndef GITHUB_ACTION
	sudo -v
	while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
endif

packages: brew-packages cask-apps node-packages oh-my-zsh

link: stow-$(OS)
	for FILE in $$(\ls -A runcom); do if [ -f $(HOME)/$$FILE -a ! -h $(HOME)/$$FILE ]; then \
		mv -v $(HOME)/$$FILE{,.bak}; fi; done
	for FILE in $$(\ls -A VSCode); do if [ -f $(VSCODE_CONFIG_HOME)/$$FILE -a ! -h $(VSCODE_CONFIG_HOME)/$$FILE ]; then \
		mv -v $(VSCODE_CONFIG_HOME)/$$FILE{,.bak}; fi; done
	mkdir -p $(XDG_CONFIG_HOME)
	stow -v -t $(HOME) runcom
	stow -v -t $(XDG_CONFIG_HOME) config
	stow -v -t $(VSCODE_CONFIG_HOME) VSCode

unlink: stow-$(OS)
	stow --delete -t $(HOME) runcom
	stow --delete -t $(XDG_CONFIG_HOME) config
	stow --delete -t $(VSCODE_CONFIG_HOME) VSCode
	for FILE in $$(\ls -A runcom); do if [ -f $(HOME)/$$FILE.bak ]; then \
		mv -v $(HOME)/$$FILE.bak $(HOME)/$${FILE%%.bak}; fi; done
	for FILE in $$(\ls -A VSCode); do if [ -f $(VSCODE_CONFIG_HOME)/$$FILE.bak ]; then \
		mv -v $(VSCODE_CONFIG_HOME)/$$FILE.bak $(VSCODE_CONFIG_HOME)/$${FILE%%.bak}; fi; done

install-vim:
	if ! [ -d $(VIM_DIR) ]; then \
		git clone --depth=1 https://github.com/amix/vimrc.git $(VIM_DIR) && \
		sh ~/.vim_runtime/install_awesome_vimrc.sh && \
		echo ":set number" >> ~/.vimrc && \
    	echo ":set mouse=nicr" >> ~/.vimrc; \
	fi

brew:
	is-executable brew || curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh | bash

bash: BASH=/usr/local/bin/bash
bash: SHELLS=/private/etc/shells
bash: brew
ifdef GITHUB_ACTION
	if ! grep -q $(BASH) $(SHELLS); then \
		brew install bash bash-completion@2 pcre && \
		sudo append $(BASH) $(SHELLS) && \
		sudo chsh -s $(BASH); \
	fi
else
	if ! grep -q $(BASH) $(SHELLS); then \
		brew install bash bash-completion@2 pcre && \
		sudo append $(BASH) $(SHELLS) && \
		chsh -s $(BASH); \
	fi
endif

git: brew
	brew install git git-extras

npm:
	if ! [ -d $(NVM_DIR)/.git ]; then git clone https://github.com/creationix/nvm.git $(NVM_DIR); fi
	. $(NVM_DIR)/nvm.sh; nvm install --lts

ruby: brew
	brew install ruby

brew-packages: brew
	brew bundle --file=$(DOTFILES_DIR)/install/Brewfile

cask-apps: brew
	brew bundle --file=$(DOTFILES_DIR)/install/Caskfile --verbose || true
	for EXT in $$(cat install/Codefile); do code --install-extension $$EXT; done
	xattr -d -r com.apple.quarantine ~/Library/QuickLook

node-packages: npm
	. $(NVM_DIR)/nvm.sh; npm install -g $(shell cat install/npmfile)

test:
	. $(NVM_DIR)/nvm.sh; bats test

oh-my-zsh:
	if ! [ -d $(OH_MY_ZSH_DIR) ]; then \
		curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh -o install-oh-my-zsh.sh && \
		sh install-oh-my-zsh.sh --unattended && \
		rm install-oh-my-zsh.sh; \
	fi

select-shell-terminal:
  # Change default shell from /bin/bash to zsh
	chsh -s /bin/zsh
