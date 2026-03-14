# Emacs 30 Configuration for macOS

A modern, IDE-like Emacs configuration for software development. This setup provides features similar to VS Code but runs entirely in Emacs.

## What You'll Get

* **Smart Code Completion**: Like IntelliSense in VS Code (Corfu + Cape)
* **Syntax Highlighting**: Powered by tree-sitter (faster and more accurate)
* **Project Navigation**: File tree sidebar (Treemacs) and fuzzy file search (Consult + Vertico)
* **Git Integration**: Visual Git interface (Magit) with GitHub/GitLab PR integration (Forge)
* **Auto-formatting**: Your code formats automatically when you save (Apheleia)
* **Error Checking**: See errors and warnings as you type (Flycheck)
* **Offline Documentation**: Blazing fast doc lookups (Dash-docs)
* **Support for Multiple Languages**: Python, JavaScript/TypeScript, Go, Rust, PHP, Java, Swift, Scala, Shell, SQL, MongoDB, Terraform, and more

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

Modern Emacs uses the standard `.config` directory. If you have an existing Emacs config, back it up first:

```bash
mv ~/.config/emacs ~/.config/emacs.backup
mv ~/.emacs.d ~/.emacs.d.backup 

```

Clone and set up this configuration with the Gruvbox Dark Hard theme:

```bash
git clone git@github.com:J4VMC/emacs-modular.git ~/.config/emacs

```

Or if you want to clone it with the Catppuccin Mocha theme:

```bash
git clone -b catppuccin git@github.com:J4VMC/emacs-modular.git ~/.config/emacs

```

### Step 3: Install Core Tools (Required for Everyone)

These tools are needed for basic functionality:

```bash
# Libraries required by Emacs packages
brew install ripgrep fd git libgccjit libvterm imagemagick

```

### Step 4: Install Language-Specific Tools

Install tools only for the languages you'll use. The configuration automatically detects and connects to them if they are installed on your system.

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
pipx install basedpyright ruff      # Language server & Linter/Formatter

# Add all of them to the path
fish_add_path ~/.local/bin

# Virtual environment manager
pipx install poetry

```

---

#### JavaScript / TypeScript / Web Technologies

*(This also covers automatic Prettier formatting for HTML, CSS, JSON, YAML, and Markdown)*

```bash
# Install Node.js and npm via Fisher (if using Fish)
fisher install jorgebucaran/nvm.fish
nvm install lts

# Install JavaScript/TypeScript tools
npm install -g typescript                    # TypeScript compiler
npm install -g typescript-language-server    # Language server
npm install -g prettier                      # Universal Code formatter
npm install -g eslint                        # Linter
npm install -g vscode-langservers-extracted  # ESLint Language server
npm install -g @tailwindcss/language-server  # Tailwind CSS support

```

---

#### Go

```bash
# Install Go
brew install go

# Install Go development tools
go install golang.org/x/tools/gopls@latest                             # Language server
go install golang.org/x/tools/cmd/goimports@latest                     # Formatter
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest  # Linter

# Add GOPATH to PATH
fish_add_path (go env GOPATH)/bin

```

---

#### Rust

```bash
# Install Rust (this also installs cargo, rustc, etc.)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Follow the prompts, then restart your terminal or run:
source "$HOME/.cargo/env.fish"

# Install Rust development tools (these come with rustup)
rustup component add rust-analyzer  # Language server
rustup component add rustfmt        # Formatter
rustup component add clippy         # Linter

```

---

#### PHP

```bash
# Install PHP & Composer
brew install php composer

# Install PHP development tools
npm install -g intelephense                            # Language server
composer global require squizlabs/php_code-sniffer     # Code style checker (phpcbf)
composer global require "dealerdirect/phpcodesniffer-composer-installer"
phpcs --config-set --default_standard PSR12
composer global require phpstan/phpstan                # Static analyzer
composer global require phpunit/phpunit                # Testing framework

# Add Composer to Path
fish_add_path (composer global config bin-dir --absolute)

```

---

#### Java

```bash
# Install Java Development Kit and Google's Formatter
brew install openjdk google-java-format

# Note: The Java Language Server (Eclipse JDTLS) will automatically 
# download and install itself via lsp-java on first launch.

```

---

#### Shell Scripting (Bash / Zsh / Fish)

```bash
# Install Shell development tools
brew install shellcheck shfmt        # Linter and Formatter
npm install -g bash-language-server  # Language server

```

---

#### Swift

```bash
# Install Xcode Command Line Tools
xcode-select --install

# Install additional Swift tools
brew install swiftlint      # Linter
brew install swift-format   # Formatter

```

*(Note: For the Swift LSP server to work, you need the full Xcode app installed from the Mac App Store).*

---

#### Scala

```bash
# Install Java (required for Scala)
brew install openjdk

# Install Coursier (Scala installer)
brew install coursier/formulas/coursier

# Install Scala and development tools
cs setup  

# Install Metals (Scala language server) and Formatter
cs install metals scalafmt

```

---

#### Databases (SQL, MongoDB, Redis)

```bash
# Install SQL formatter, linter, and language server
npm install -g sqlint sql-language-server sql-formatter

# Install MongoDB shell and Redis CLI
brew install mongosh redis

```

---

#### DevOps (Docker & Terraform)

```bash
# Install Docker Desktop for Mac
# Download from: https://desktop.docker.com/mac/main/arm64/Docker.dmg

# Install Docker & Terraform tooling
brew install hadolint terraform

```

---

#### Document Formats (Markdown & XML)

```bash
# Install Pandoc (for Markdown live-preview rendering)
brew install pandoc

# Install libxml2 (provides xmllint for XML formatting)
brew install libxml2

```

---

### Step 5: Install Combobulate

The only package that elpaca fails to install from Github. It's a package that adds structured editing and movement to a wide range of programming languages.

```bash
git clone git@github.com:mickeynp/combobulate.git ~/.config/emacs/combobulate

```

### Step 6: Start Emacs

```bash
emacs

```

**What happens on first launch:**

1. Emacs will automatically download and install packages (takes 2-5 minutes).
2. You'll see a dashboard with recent files and projects.
3. Emacs will prompt you to update packages (you can select `y` or `n`).
4. When you open a code file, the `treesit-auto` package will automatically download and install the required syntax grammar in the background.

### Step 7: Verify Everything Works

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

* ✅ Line numbers on the left
* ✅ Syntax highlighting in color
* ✅ Auto-completion popup when you type
* ✅ Code auto-formats when you save

**If something doesn't work:**

* Check that the language server is installed: `which basedpyright`
* Open Emacs and press `M-x lsp-doctor` (hold Option/Alt, press x, type "lsp-doctor")
* This will show you what's missing

## Understanding Emacs Key Notation

Emacs uses special notation for keyboard shortcuts:

* `C-x` = Hold Control and press x
* `M-x` = Hold Option/Alt (⌥) and press x
* `C-c t` = Hold Control and press c, then release and press t
* `s-j` = Hold Command (⌘) and press j

## Essential Keyboard Shortcuts

Our keybindings act as a hybrid between classic Emacs bindings and modern IDE conveniences to prevent the dreaded *Emacs pinky*.

### Files and Buffers

| Shortcut | Action |
| --- | --- |
| `C-x C-f` | Open a file |
| `C-x C-s` | Save current file |
| `C-x k` | Close current file |
| `C-x b` | Switch between open files |
| `C-x C-c` | Quit Emacs |

### Window & Tab Management

| Shortcut | Action |
| --- | --- |
| `s-<arrows>` | Move focus between split windows |
| `s-t` | Open a new tab (workspace) |
| `s-l` | Close the current tab |
| `C-x 1` | Maximize current window (close rest) |
| `C-x 2` | Split window vertically |
| `C-x 3` | Split window horizontally |

### Navigation & Search

| Shortcut | Action |
| --- | --- |
| `M-s l` | Search for a line in the current file (Fuzzy) |
| `M-s L` | Search for a line across all open files |
| `M-s r` | Project-wide text search (Ripgrep) |
| `C-c j` | Jump instantly to any visible line |
| `s-j` | Jump instantly to any visible character |

### Project Management (`s-p` Prefix)

We use the `Command-p` (`s-p`) prefix as our central "Command Palette" for project actions:

| Shortcut | Action |
| --- | --- |
| `s-p p` | Switch between known projects |
| `s-p f` | Find file in current project (Fuzzy) |
| `s-p g` | Grep (Search) text across project |
| `s-p t` | Toggle file tree sidebar |
| `s-p 0` | Focus cursor on the file tree |
| `s-p v` | Toggle project terminal |
| `s-p c` | Compile / Build project |

### Git & GitHub (Magit & Forge)

| Shortcut | Action |
| --- | --- |
| `C-x g` | Open Git status |

**In Magit status buffer:**

* `s` = Stage file or hunk
* `u` = Unstage file or hunk
* `c c` = Commit (type message, then `C-c C-c` to confirm)
* `P p` = Push to remote
* `F p` = Pull from remote
* `@` = Open Forge menu (Pull Requests & Issues)
* `q` = Quit Magit

> **Note on Forge (GitHub/GitLab Integration):**
> To use Forge to manage Pull Requests, you must create a Personal Access Token on GitHub and store it in `~/.authinfo.gpg` using this format:
> `machine api.github.com login YOUR_USERNAME^forge password YOUR_TOKEN`

### Terminal

| Shortcut | Action |
| --- | --- |
| `s-9` | Toggle "Quake-style" popup terminal |
| `M-k` | Force kill terminal (bypasses prompts) |

### Code Navigation & Intelligence (LSP)

| Shortcut | Action |
| --- | --- |
| `M-.` | Go to definition |
| `M-,` | Go back |
| `M-?` | Find all references |
| `C-c C-d` | Show LSP hover documentation |
| `M-s d` | Search offline Dash docs (word at cursor) |
| `M-n` | Jump to next code error |
| `M-p` | Jump to previous code error |
| `C-c l r r` | Rename symbol across project |

### Editing (CUA Mode Enabled)

This configuration enables `cua-mode`, meaning standard OS copy/paste shortcuts work when text is highlighted:

| Shortcut | Action |
| --- | --- |
| `C-space` | Start selection |
| `C-c` | Copy (when text is selected) |
| `C-x` | Cut (when text is selected) |
| `C-v` | Paste (when text is selected) |
| `M-J` | Expand selection semantically (word -> string -> func) |
| `M-/` | Comment / Uncomment line or block |
| `C-/` | Undo |
| `M-up` | Move current line/selection up |
| `M-down` | Move current line/selection down |

### Debugging (DAP Mode)

| Shortcut | Action |
| --- | --- |
| `C-c d d` | Start Debugging (select template) |
| `C-c d b` | Toggle Breakpoint |
| `C-c d n` | Step Over |
| `C-c d i` | Step Into |
| `C-c d c` | Continue |
| `C-c d r` | Stop / Disconnect Debugger |

### Getting Help

| Shortcut | Action |
| --- | --- |
| `C-h t` | Start interactive tutorial |
| `C-h k` | Describe key (press this, then press another key) |
| `C-h f` | Describe function |
| `C-h v` | Describe variable |
