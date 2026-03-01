# Emacs 30 Configuration for macOS

A modern, IDE-like Emacs configuration for software development. This setup provides features similar to VS Code but runs entirely in Emacs.

## What You'll Get

- **Smart Code Completion**: Like IntelliSense in VS Code
- **Syntax Highlighting**: Powered by tree-sitter (faster and more accurate)
- **Project Navigation**: File tree sidebar, fuzzy file search
- **Git Integration**: Visual Git interface (Magit)
- **Auto-formatting**: Your code formats automatically when you save
- **Error Checking**: See errors and warnings as you type
- **Support for Multiple Languages**: Python, JavaScript/TypeScript, Go, Rust, PHP, Swift, Scala, and more

## Prerequisites

You need macOS and [Homebrew](https://brew.sh/) installed. If you don't have Homebrew:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

## Complete Installation Guide

### Step 1: Install from Emacs+

```bash
brew tap d12frosted/emacs-plus

brew install emacs-plus --HEAD --with-debug --with-xwidgets --with-dbus --with-mailutils --with-ctags --with-imagemagick
```

Verify the installation:

```bash
emacs --version
```

You should see "GNU Emacs 30.2" or similar.

### Step 2: Install This Configuration

If you have an existing Emacs config, back it up first:

```bash
mv ~/.emacs.d ~/.emacs.d.backup
```

Clone and set up this configuration with the Gruvbox Dark Hard theme:

```bash
git clone git@github.com:J4VMC/emacs-modular.git ~/.emacs.d
```

Or if you want to clone it with the Catppuccin Mocha theme:

```bash
git clone -b catppuccin git@github.com:J4VMC/emacs-modular.git ~/.emacs.d
```

### Step 3: Install Core Tools (Required for Everyone)

These tools are needed for basic functionality:

```bash
# Libraries required by Emacs packages
brew install ripgrep fd git libgccjit libvterm imagemagick
```

That's it! The configuration is already set up to use it automatically.

### Step 4: Install Language-Specific Tools

Install tools only for languages you'll use. You can always come back and add more later.

---

#### Python

```bash
# Install pyenv
brew install pyenv

# Add pyenv to fish shell
set -Ux PYENV_ROOT $HOME/.pyenv
echo 'pyenv init - fish | source' >> ~/.config/fish/config.fish
source ~/.config/fish/config.fish

# Install build dependencies
brew install openssl readline sqlite3 xz tcl-tk libb2 zstd zlib pkgconfig

# Install Python
pyenv install $(pyenv latest -k 3) && pyenv global $(pyenv latest 3)
# Install Pipx if not already installed
brew install pipx

# Install Python development tools
pipx install basedpyright ruff      # Language server (autocomplete, go-to-definition)

# Add all of them to the path
fish_add_path ~/.local/bin

# Virtual environment manager
pipx install poetry
```

**Test it works:**

```bash
which ruff  # Should show a path
```

---

#### JavaScript/TypeScript/React/Vue/Svelte

```bash
# Install Node.js and npm
fisher install jorgebucaran/nvm.fish

nvm install lts

# Install JavaScript/TypeScript tools
npm install -g typescript                    # TypeScript compiler
npm install -g typescript-language-server    # Language server
npm install -g prettier                      # Code formatter
npm install -g eslint                        # Linter
npm install -g vscode-langservers-extracted # ESLint Language server
npm install -g @tailwindcss/language-server  # For Tailwind CSS support
```

**Test it works:**

```bash
which typescript-language-server  # Should show a path
```

---

#### Go

````bash
# Install Go
brew install go

# Install Go development tools
go install golang.org/x/tools/gopls@latest              # Language server
go install golang.org/x/tools/cmd/goimports@latest      # Formatter
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest  # Linter

# Add GOPATH to PATH
fish_add_path (go env GOPATH)/bin

**Test it works:**
```bash
ls (go env GOPATH)/bin/gopls # Should show a path like /Users/you/go/bin/gopls
````

---

#### Rust

```bash
# Install Rust (this also installs cargo, rustc, etc.)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Follow the prompts, then restart your terminal or run:
source "$HOME/.cargo/env.fish"

# Install Rust development tools (these come with rustup)
rustup component add rust-analyzer  # Language server
rustup component add rustfmt         # Formatter
rustup component add clippy          # Linter
```

**Test it works:**

```bash
which rust-analyzer  # Should show a path in ~/.cargo/bin
```

---

#### PHP

```bash
# Install PHP
brew install php

# Install Composer (PHP package manager)
brew install composer

# Install PHP development tools
npm install -g intelephense  # Language server
composer global require squizlabs/php_code-sniffer     # Code style checker
composer global require "dealerdirect/phpcodesniffer-composer-installer"
phpcs --config-set --default_standard PSR12
composer global require phpstan/phpstan               # Static analyzer

# PHP unit testing
composer global require phpunit/phpunit
```

```bash
# Add Composer to Path
fish_add_path (composer global config bin-dir --absolute)
```

_Test it works:_

```bash
which phpcs  # Should show a path
```

---

#### Swift

Swift tools come with Xcode:

```bash
# Install Xcode Command Line Tools
xcode-select --install

# Install additional Swift tools
brew install swiftlint      # Linter
brew install swift-format   # Formatter
```

**Test it works:**

```bash
which swift  # Should show /usr/bin/swift
```

Note: For the Swift LSP server, you need the full Xcode app installed (not just command line tools). Download it from the Mac App Store.

---

#### Scala

```bash
# Install Java (required for Scala)
brew install openjdk

# Install Coursier (Scala installer)
brew install coursier/formulas/coursier

# Install Scala and development tools
cs setup  # This installs scala, sbt, and other tools

# Install Metals (Scala language server)
cs install metals
```

**Test it works:**

```bash
which metals  # Should show a path
```

---

#### SQL

```bash
# Install SQL formatter, linter, and language server
npm install -g sqlint
npm install -g sql-language-server
npm install -g sql-formatter

# Optional: Install PostgreSQL client for testing
brew install postgresql@18
```

**Test it works:**

```bash
which sqlint  # Should show a path
```

---

#### Docker

```bash
# Install Docker Desktop (includes Docker CLI)
[Download the installer](https://desktop.docker.com/mac/main/arm64/Docker.dmg)

# Start Docker Desktop from Applications folder

# Install Dockerfile linter
brew install hadolint
```

**Test it works:**

```bash
which docker    # Should show a path
which hadolint  # Should show a path
```

---

#### Markdown

```bash
# Install Pandoc (for Markdown preview)
brew install pandoc
```

**Test it works:**

```bash
which pandoc  # Should show a path
```

---

#### XML

```bash
# Install libxml2, which provides the xmllint formatting tool
brew install libxml2
```

---

### Step 5: Install Combobulate

The only package that elpaca fails to install from Github. It's a package that adds structured editing and movement to a wide range of programming languages.

```bash
git clone git@github.com:mickeynp/combobulate.git ~/.emacs.d/combobulate
```

### Step 6: Start Emacs

```bash
emacs
```

**What happens on first launch:**

1. Emacs will automatically download and install packages (takes 2-5 minutes)
2. You'll see a dashboard with recent files and projects
3. The first time you open a code file, Emacs will ask to install tree-sitter grammars

**Installing tree-sitter grammars:**

- When you open a `.py`, `.js`, `.go`, or other supported file for the first time
- Emacs might prompt: "Install tree-sitter grammar for python?"
- Press `y` to install it
- This happens once per language
- You can also install them with `M-x treesit-auto-install-all`

### Step 8: Verify Everything Works

Let's test with a Python file:

1. Press `C-x C-f` (hold Control, press x, release, then hold Control and press f)
2. Type `~/test.py` and press Enter
3. Type this code:

   ```python
   def hello(name):
       return f"Hello, {name}"

   print(hello("World"))
   ```

4. Save with `C-x C-s`

**You should see:**

- ✅ Line numbers on the left
- ✅ Syntax highlighting in color
- ✅ Auto-completion popup when you type
- ✅ Code auto-formats when you save

**If something doesn't work:**

- Check that the language server is installed: `which pyright`
- Open Emacs and press `M-x lsp-doctor` (hold Option/Alt, press x, type "lsp-doctor")
- This will show you what's missing

## Understanding Emacs Key Notation

Emacs uses special notation for keyboard shortcuts:

- `C-x` = Hold Control and press x
- `M-x` = Hold Option/Alt (⌥) and press x
- `C-c t` = Hold Control and press c, then release and press t
- `s-j` = Hold Command (⌘) and press j

## Essential Keyboard Shortcuts

Some of the shortcuts below are custom for this configuration. All custom keybindings aim to be as ergonomic as possible to prevent the dreaded _Emacs pinky_. We don't use evil-mode because there's no point in doing that.

### Files and Buffers

| Shortcut  | Action                    |
| --------- | ------------------------- |
| `C-x C-f` | Open a file               |
| `C-x C-s` | Save current file         |
| `C-x k`   | Close current file        |
| `C-x b`   | Switch between open files |
| `C-x C-c` | Quit Emacs                |

### Navigation

| Shortcut | Action                         |
| -------- | ------------------------------ |
| `C-s`    | Search forward                 |
| `C-r`    | Search backward                |
| `M-g g`  | Go to line number              |
| `C-c j`  | Jump to any line (visual)      |
| `s-j`    | Jump to any character (visual) |

### Project Management

| Shortcut  | Action                       |
| --------- | ---------------------------- |
| `C-c p f` | Find file in project (fuzzy) |
| `C-c p p` | Switch between projects      |
| `C-x t t` | Toggle file tree sidebar     |
| `M-0`     | Focus on file tree           |
| `C-c t a` | Show current project in tree |

### Git (Magit)

| Shortcut | Action          |
| -------- | --------------- |
| `C-x g`  | Open Git status |

**In Magit status buffer:**

- `s` = Stage file or hunk
- `u` = Unstage file or hunk
- `c c` = Commit (type message, then `C-c C-c` to confirm)
- `P p` = Push to remote
- `F p` = Pull from remote
- `q` = Quit Magit

### Terminal

| Shortcut  | Action                        |
| --------- | ----------------------------- |
| `C-c t`   | Toggle terminal at bottom     |
| `C-c p v` | Open terminal in project root |

### Code Navigation (when in a code file)

| Shortcut  | Action             |
| --------- | ------------------ |
| `M-.`     | Go to definition   |
| `M-,`     | Go back            |
| `C-c C-d` | Show documentation |
| `M-n`     | Next error         |
| `M-p`     | Previous error     |
| `C-c l`   | LSP command prefix |

### Editing

| Shortcut  | Action            |
| --------- | ----------------- |
| `C-space` | Start selection   |
| `C-w`     | Cut selection     |
| `M-w`     | Copy selection    |
| `C-y`     | Paste             |
| `M-;`     | Comment/uncomment |
| `C-/`     | Undo              |

### Getting Help

| Shortcut | Action                                            |
| -------- | ------------------------------------------------- |
| `C-h t`  | Start interactive tutorial                        |
| `C-h k`  | Describe key (press this, then press another key) |
| `C-h m`  | Show all shortcuts for current mode               |
| `C-h f`  | Describe function                                 |
