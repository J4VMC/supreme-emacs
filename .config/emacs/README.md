# Emacs 30 Configuration for macOS

A modern, IDE-like Emacs configuration for software development. This setup provides an experience similar to VS Code or Cursor — including an integrated AI coding agent — but runs entirely in Emacs.

## What You'll Get

- **Smart Code Completion**: Like IntelliSense in VS Code (Corfu + Cape)
- **AI Coding Agents**: Claude Code integrated into the editor, plus a vendor-independent agent lane for Gemini (and any other ACP agent) — all with per-project credentials kept safely separated (claude-code + claude-code-ide + agent-shell + direnv)
- **Syntax Highlighting**: Powered by tree-sitter (faster and more accurate)
- **VS Code-style Projects**: Open a project and get the full file tree in a sidebar (Treemacs) — no "pick a file" prompt
- **Per-Project Workspaces**: Every project opens in its own workspace with an isolated buffer list, window layout, and sidebar (Perspective + Projectile) — switching back restores everything exactly as you left it
- **Fuzzy Search Everywhere**: Files, text, lines, and symbols (Consult + Vertico)
- **Git Integration**: Visual Git interface (Magit) with GitHub/GitLab PR integration (Forge), TODO overview (magit-todos), and per-line change markers in the fringe (diff-hl)
- **Auto-formatting**: Your code formats automatically when you save (Apheleia)
- **Error Checking**: See errors and warnings as you type (Flycheck), with a searchable error list (`M-s e`)
- **Spell Checking**: Context-aware — checks prose in text files, but only comments and strings in code (jinx)
- **Persistent Undo**: Undo history survives restarting Emacs, with a visual undo tree (undo-fu + vundo)
- **Integrated Terminal**: Fast pop-up terminal drawer (ghostel, powered by libghostty)
- **Consistent Icons**: One icon set (nerd-icons) across the welcome screen, sidebar, file manager, and completion popups
- **Support for Multiple Languages**: Python, JavaScript/TypeScript, Go, Rust, PHP, Java, Swift, Scala, Shell, SQL, Docker, Terraform, and more

## Prerequisites

You need macOS and Homebrew installed. If you don't have Homebrew:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

This configuration assumes the **fish shell**. Most commands below are written for fish.

## Complete Installation Guide

### Step 1: Install Emacs (emacs-plus)

```bash
brew tap d12frosted/emacs-plus
brew install emacs-plus --HEAD --with-debug --with-xwidgets --with-dbus --with-mailutils --with-ctags --with-imagemagick
```

Verify the installation:

```bash
emacs --version
```

You should see "GNU Emacs 30.2" or similar.

### Step 2: Install the Fonts (Required)

The configuration uses **FiraCode Nerd Font** as its main font, and **Symbols Nerd Font Mono** for all icons. Without the second one, icons appear cut in half or as hollow boxes.

```bash
brew install --cask font-fira-code-nerd-font
brew install --cask font-symbols-only-nerd-font
```

### Step 3: Install This Configuration

Modern Emacs uses the standard `.config` directory. If you have an existing Emacs config, back it up first:

```bash
mv ~/.config/emacs ~/.config/emacs.backup
mv ~/.emacs.d ~/.emacs.d.backup
```

Clone and set up this configuration:

```bash
git clone git@github.com:J4VMC/supreme-emacs.git ~/.config/emacs
```

The default theme is **Gruvbox Dark Hard**. To use **Catppuccin Mocha** on a
given machine instead, opt in via `local.el` — an untracked, git-ignored file
next to `init.el` (the same pattern as `custom.el`):

```bash
echo "(setq jmc-theme 'catppuccin)" > ~/.config/emacs/local.el
```

Both themes are installed on every machine, so `M-x load-theme` can switch
interactively at any time; `local.el` only controls which theme activates at
startup (and matches the indent-guide colors to it).

### Step 4: Install Core Tools (Required for Everyone)

```bash
# Libraries and tools required by Emacs packages
brew install ripgrep fd git libgccjit imagemagick coreutils direnv enchant pkgconf
```

What these are for, in plain words: `ripgrep` and `fd` power fast project search, `libgccjit` lets Emacs compile packages to native code (speed), `coreutils` provides `gls` for nicer file listings, `enchant` + `pkgconf` power the spell checker (jinx compiles a small native module against them on first launch), and `direnv` loads each project's own environment variables (see [Per-Project Secrets](#per-project-secrets-envrc) below — this is also how the AI agent gets the _right_ credentials per client).

Hook direnv into fish (one time):

```bash
echo 'direnv hook fish | source' >> ~/.config/fish/config.fish
```

### Step 5: Install Language-Specific Tools

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
pipx install basedpyright black flake8 isort      # Language server, Formatters & Linter

# Add all of them to the path
fish_add_path ~/.local/bin

# Virtual environment manager
pipx install poetry
poetry config virtualenvs.in-project true
```

---

#### JavaScript / TypeScript / Web Technologies

_(This also covers automatic Prettier formatting for HTML, CSS, JSON, YAML, and Markdown)_

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

_(Bonus: opening a `go.mod` file also gets language-server support — dependency warnings and "upgrade dependency" actions come for free.)_

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
composer global require squizlabs/php_codesniffer      # Code style checker (phpcbf)
composer global require "dealerdirect/phpcodesniffer-composer-installer"
phpcs --config-set --default_standard PSR12
composer global require phpstan/phpstan                # Static analyzer
composer global require phpunit/phpunit                # Testing framework

# Add Composer to Path
fish_add_path (composer global config bin-dir --absolute)
```

After your first launch, run `M-x php-ts-mode-install-parsers` once from inside any PHP file. This installs the extra syntax grammars PHP needs for highlighting doc-comments and inline HTML/CSS/JS.

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

_(Note: For the Swift LSP server to work, you need the full Xcode app installed from the Mac App Store)_.

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

#### Document Formats (Markdown, XML & TOML)

```bash
# Install Pandoc (for Markdown live-preview rendering)
brew install pandoc

# Install libxml2 (provides xmllint for XML formatting)
brew install libxml2

# Install taplo (TOML formatter — auto-format on save for .toml files)
brew install taplo
```

---

### Step 6: Install the AI Agents (Optional but Recommended)

This configuration integrates [Claude Code](https://docs.claude.com/en/docs/claude-code/overview), Anthropic's coding agent, directly into Emacs.

```bash
npm install -g @anthropic-ai/claude-code
claude   # run once in a terminal to log in
```

For **Gemini models**, install Google's agent CLI as well — Emacs drives it through the vendor-neutral agent-shell package (`C-c g`):

```bash
npm install -g @google/gemini-cli
```

The first `C-c g` session prompts you to authenticate — a personal Google login gives you a generous free tier, no API key needed.

See the [AI Agent shortcuts](#ai-agents-claude-code--gemini) and [Per-Project Secrets](#per-project-secrets-envrc) sections below for how to use them safely with multiple clients or projects.

### Step 7: Start Emacs

```bash
emacs
```

**What happens on first launch:**

1. Emacs will automatically download and install packages (takes 2-5 minutes).
2. You'll land on a welcome screen listing your recent files and projects. Everything on it is keyboard-driven: press the digit shown next to an item to open it, move between items with `TAB` / `S-TAB` or the arrow keys and press `RET` (the mouse works too), or use the action keys — `f` find a file, `r` search all recent files, `e` open this configuration as a project. Wherever you are, `s-p h` brings the screen back.
3. Emacs may ask to update packages (answer `y` or `n`).
4. When you open a code file for a language whose syntax grammar isn't installed yet, Emacs **asks permission** to install it. Answer `y` — it takes a few seconds, once per language.
    - Prefer to get it all over with at once? Run `M-x treesit-auto-install-all` and grab a coffee.

**Package updates & reproducibility:** packages auto-update in the background at most once a week. Once your setup works the way you like, run `M-x jmc-elpaca-write-lock` and commit the generated `elpaca.lock` file — from then on, every machine installs **exactly** those package versions, and automatic updates switch off. To update after that, run `M-x jmc-elpaca-update-unlocked` deliberately, verify everything still works, then re-run `M-x jmc-elpaca-write-lock`.

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
- ✅ Auto-completion popup when you type (with icons)
- ✅ Code auto-formats when you save
- ✅ After a `git commit`, colored change markers appear in the right fringe as you edit

**If something doesn't work:**

- Check that the language server is installed: `which basedpyright`
- Open Emacs and press `M-x lsp-doctor` (hold Option/Alt, press x, type "lsp-doctor")
- If icons look cut in half or like empty boxes, re-check Step 2 (fonts), then restart Emacs.

## Understanding Emacs Key Notation

Emacs uses special notation for keyboard shortcuts:

- `C-x` = Hold Control and press x
- `M-x` = Hold Option/Alt (⌥) and press x
- `C-c t` = Hold Control and press c, then release and press t
- `s-j` = Hold Command (⌘) and press j

**Tip:** whenever you press a prefix (like `C-c` or `s-p`) and pause, a small panel pops up showing every key you can press next. You never need to memorize full tables — just start typing and read.

## Essential Keyboard Shortcuts

Our keybindings act as a hybrid between classic Emacs bindings and modern IDE conveniences to prevent the dreaded _Emacs pinky_.

### Files and Buffers

| Shortcut  | Action                    |
| --------- | ------------------------- |
| `C-x C-f` | Open a file               |
| `C-x C-s` | Save current file         |
| `C-x k`   | Close current file        |
| `C-x b`   | Switch between open files (current workspace only) |
| `C-x C-c` | Quit Emacs                |

Quitting asks its questions ("save this file?") in the small area at the very bottom of the frame — answer with `y` or `n` there.

### Window & Tab Management

| Shortcut     | Action                                            |
| ------------ | ------------------------------------------------- |
| `s-<arrows>` | Move focus between split windows                  |
| `s-t`        | Open a new tab (workspace)                        |
| `s-l`        | Close the current tab                             |
| `C-c w`      | Window menu: resize with arrows, split, balance   |
| `C-x 1`      | Maximize current window (close rest)              |
| `C-x 2`      | Split window vertically                           |
| `C-x 3`      | Split window horizontally                         |

`C-c w` opens a small pop-up menu that stays active: tap the arrow keys repeatedly to resize the current window, `=` to re-balance, `q` (or any other command) to leave.

### Projects (`s-p` Prefix)

`Command-p` (`s-p`) is the central "Command Palette" for project actions. Switching to a project opens it **VS Code-style**: the full file tree appears in the sidebar and the project folder in the main window — no file prompt.

Every project also gets its **own workspace** (a "perspective"): its buffers, window layout, and sidebar are isolated from every other project. Opening a project — via `s-p p`, or from the welcome screen by digit key / `RET` / click — creates its workspace (or re-enters it, restored exactly as you left it). The welcome screen itself lives in the initial `main` workspace, so it's always there to come back to (`s-p h` jumps straight to it).

The isolation runs through the whole config: `C-x b` lists only the current workspace's buffers (press `/ b` inside it to reach every buffer globally — handy for pulling a buffer over from another project), and the mode-line's bottom-right corner always shows which workspace you're in.

**Workspaces are session-scoped** (deliberately): they're built as you open projects and die with Emacs — nothing is saved on quit or restored on launch. Automatic restore was removed because it visited every saved file synchronously (startup jank) and routinely resurrected stale, half-broken layouts; re-opening a project is one `s-p p` (or one keypress on the welcome screen). For a one-off snapshot, `C-c p C-s` / `C-c p C-l` still save/load workspace state to a file of your choice.

| Shortcut  | Action                                      |
| --------- | ------------------------------------------- |
| `s-p p`   | Open / switch project (own workspace, tree + folder view) |
| `s-p f`   | Find file in current project (Fuzzy)        |
| `s-p g`   | Search text across project (live results)   |
| `s-p t`   | Toggle file tree sidebar                    |
| `s-p d`   | Open the project root in the file manager   |
| `s-p r`   | Toggle the project terminal                 |
| `s-p c`   | Compile / Build project                     |
| `s-p A`   | Launch the AI agent for the current project |
| `s-p h`   | Back to the welcome screen                  |
| `s-0`     | Move cursor focus to the file tree          |
| `C-c t d` | Manually add a folder to the sidebar        |

**Workspace management** lives on the `C-c p` prefix (press it and pause to see every option):

| Shortcut  | Action                                        |
| --------- | --------------------------------------------- |
| `C-c p s` | Switch workspace by name (or create one)      |
| `C-c p n` | Next workspace                                |
| `C-c p p` | Previous workspace                            |
| `C-c p b` | Switch buffer within the current workspace    |
| `C-c p r` | Rename the current workspace                  |
| `C-c p c` | Close the current workspace                   |
| `C-c p k` | Remove a buffer from the current workspace    |

**In the sidebar and file manager:** a single click opens files and expands folders. The file manager navigates "in place" (entering a folder replaces the view instead of opening new buffers), and `^` goes up one level.

### Navigation & Search

| Shortcut | Action                                          |
| -------- | ----------------------------------------------- |
| `C-s`    | Search in the current file (live, fuzzy)        |
| `M-s L`  | Search for a line across all open files         |
| `M-s o`  | Jump to a heading/function in the current file  |
| `M-s r`  | Project-wide text search (Ripgrep)              |
| `M-s e`  | Searchable list of the current buffer's errors  |
| `M-s d`  | Search offline Dash docs (word at cursor)       |
| `C-c j`  | Jump instantly to any visible line              |
| `s-j`    | Jump instantly to any visible character         |

**Tips:** inside the `C-s` search, press `M-n` to insert the word under the cursor as the search term, and `C-.` to act on a result (e.g. export all matches to an editable list). `M-s l` is an alias for the same search. `C-r` still runs Emacs's classic incremental search, which also works inside keyboard macros.

### Git & GitHub (Magit & Forge)

| Shortcut | Action          |
| -------- | --------------- |
| `C-x g`  | Open Git status |

**In Magit status buffer:**

- `s` = Stage file or hunk
- `u` = Unstage file or hunk
- `c c` = Commit (type message, then `C-c C-c` to confirm)
- `P p` = Push to remote
- `F p` = Pull from remote
- `@` = Open Forge menu (Pull Requests & Issues)
- `q` = Quit Magit

The status buffer also lists every `TODO` / `FIXME` in the project (magit-todos), and edited lines show colored markers in the right fringe of your code buffers, updating live as you type (diff-hl).

> **Note on Forge (GitHub/GitLab Integration):**
> To use Forge to manage Pull Requests, you must create a Personal Access Token on GitHub and store it in `~/.authinfo.gpg` using this format:
> `machine api.github.com login YOUR_USERNAME^forge password YOUR_TOKEN`

### Terminal

| Shortcut  | Action                                    |
| --------- | ----------------------------------------- |
| `s-9`     | Toggle "Quake-style" popup terminal       |
| `C-u s-9` | Open an additional, separate terminal     |
| `M-k`     | Force kill terminal (bypasses prompts)    |
| `Cmd-V`   | Paste into the terminal (`C-v` works too) |

### AI Agents (Claude Code & Gemini)

Three integrations are included: a quick Claude command interface (`C-c c`), a full IDE-style Claude integration with diffs and tool access (`C-c i`), and a vendor-neutral agent shell currently wired to Gemini (`C-c g`).

| Shortcut  | Action                                          |
| --------- | ----------------------------------------------- |
| `s-p A`   | Launch the agent for the current project        |
| `C-c c`   | Claude Code command menu (pause to see options) |
| `C-c i i` | Start an IDE-integrated agent session           |
| `C-c i m` | Open the agent menu                             |
| `C-c i t` | Show/hide the most recent agent window          |
| `C-c i c` | Continue the previous conversation              |
| `C-c i r` | Resume an earlier session                       |
| `C-c i l` | List active sessions                            |
| `C-c i !` | Toggle `--dangerously-skip-permissions` (off by default) |
| `C-c g`   | Start a Gemini agent session (agent-shell)      |

`C-c i !` bypasses the CLI's own permission prompts for file edits and shell commands in every session started afterward — it does not affect a session already running, and does not disable the ediff review step. Off by default; the mode-line message confirms the current state whenever you toggle it.

**How the Gemini session differs:** it's a plain Emacs buffer, not a terminal app — search, copy, and paste work like in any other buffer. The agent's proposed file edits appear as inline diffs with approve/deny prompts (Claude's `C-c i` sessions instead open a side-by-side ediff where you accept or reject individual hunks). Under the hood it speaks ACP, an open protocol — the same interface can drive Codex, Goose, and other agents if you ever want them.

**Important habit:** start any agent from a file _inside_ the project you want it to work on. The agent inherits that project's environment and credentials (see next section).

### Per-Project Secrets (.envrc)

Each project can have its own environment variables — API keys, database URLs, client credentials — in a `.envrc` file at the project root. They are loaded **per project** and never leak between projects, which matters when you work for multiple clients:

1. Create a `.envrc` in the project root, e.g. `export API_KEY=...`
   (better: put real secrets in a gitignored `.env.local` and have `.envrc` contain `dotenv .env.local`)
2. Approve it once: `C-c e a` inside the project (or `direnv allow` in a terminal)
3. After editing `.envrc`, reload with `C-c e r`

Everything you launch from that project's buffers — terminals, language servers, the AI agent — automatically gets that project's environment, and only that one.

To keep the AI agent from _reading_ your secret files, add this to `~/.claude/settings.json`:

```json
{
	"permissions": {
		"deny": ["Read(./.envrc)", "Read(./.env)", "Read(./.env.*)"]
	}
}
```

### Code Navigation & Intelligence (LSP)

| Shortcut    | Action                                   |
| ----------- | ---------------------------------------- |
| `M-.`       | Go to definition                         |
| `M-,`       | Go back                                  |
| `M-?`       | Find all references                      |
| `M-n`       | Jump to next code error                  |
| `M-p`       | Jump to previous code error              |
| `C-c l`     | All LSP commands (pause to see the menu) |
| `C-c l r r` | Rename symbol across project             |

### Editing (CUA Mode Enabled)

This configuration enables `cua-mode`, meaning standard OS copy/paste shortcuts work when text is highlighted:

| Shortcut        | Action                                                 |
| --------------- | ------------------------------------------------------ |
| `C-space`       | Start selection                                        |
| `C-c`           | Copy (when text is selected)                           |
| `C-x`           | Cut (when text is selected)                            |
| `C-v`           | Paste (when text is selected)                          |
| `C-z`           | Undo                                                   |
| `C-S-z`         | Redo                                                   |
| `M-J`           | Expand selection semantically (word -> string -> func) |
| `M-/`           | Comment / Uncomment line or block                      |
| `M-$`           | Correct the misspelled word at cursor                  |
| `s-<backspace>` | Fold / unfold the code block at cursor                 |

Your undo history is **saved to disk**: even after restarting Emacs, you can keep undoing yesterday's edits. Run `M-x vundo` to browse the whole undo history as a visual tree.

**Multiple cursors** (edit many places at once):

| Shortcut  | Action                                                  |
| --------- | ------------------------------------------------------- |
| `C-c m`   | Cursor menu: place cursors with single keys (see below) |
| `C->`     | Add a cursor at the next matching word                  |
| `C-<`     | Add a cursor at the previous matching word              |
| `C-c C-<` | Add cursors at ALL matching words                       |
| `C-M-j`   | Add a cursor to each selected line                      |

`C-c m` is the comfortable way in: a pop-up menu where `n`/`p` mark the next/previous match, `N`/`P` skip one, `u`/`U` unmark — then just start typing to edit with all cursors (`C-g` collapses back to one).

### Debugging (Dape)

Press `C-c d` and pause to see all debugger actions. **The best way to drive a session is `C-c d h`**: it opens a pop-up menu that stays active, so stepping is single keys — `n` (next), `i` (in), `o` (out), `c` (continue) — instead of re-typing the prefix for every step.

| Shortcut  | Action                             |
| --------- | ---------------------------------- |
| `C-c d h` | Debug menu (one-key stepping)      |
| `C-c d d` | Start Debugging (select template)  |
| `C-c d b` | Toggle Breakpoint                  |
| `C-c d B` | Remove all Breakpoints             |
| `C-c d n` | Step Over                          |
| `C-c d i` | Step Into                          |
| `C-c d o` | Step Out                           |
| `C-c d c` | Continue                           |
| `C-c d w` | Show debug info windows            |
| `C-c d R` | Restart                            |
| `C-c d r` | Quit debugging                     |

_(In Rust files, `C-c C-c d` starts the debugger with Rust-specific setup.)_

### Getting Help

| Shortcut | Action                                            |
| -------- | ------------------------------------------------- |
| `C-h t`  | Start interactive tutorial                        |
| `C-h k`  | Describe key (press this, then press another key) |
| `C-h f`  | Describe function                                 |
| `C-h v`  | Describe variable                                 |

The help pages in this config are upgraded (helpful.el): they show the documentation, the source code, and usage examples in one place.
