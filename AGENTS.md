# AGENTS.md — supreme-emacs

Instructions for AI coding agents working in this repository. [.config/emacs/README.md](.config/emacs/README.md) is the user guide (installation, every keybinding); this file is the rules.

## Context

This is the `emacs` submodule of [J4VMC/supreme-dotfiles](https://github.com/J4VMC/supreme-dotfiles), which stows `.config/emacs/` to `~/.config/emacs`. Install it **through the dotfiles**, following that repository's `AGENTS.md`: the Brewfile there builds `emacs-plus@31` with the right flags, installs the fonts, `libgccjit`, `tree-sitter`, `enchant`/`pkgconf` and every language tool, and the fish configuration provides the environment Emacs inherits through `exec-path-from-shell`. The only standalone install is a clone into `~/.config/emacs`.

If `~/dotfiles/emacs` is where you are working, you are inside a submodule checkout: run `git checkout main && git pull --ff-only` before committing (a parent `git pull` leaves it on a detached HEAD), push here first, then bump the pointer in the parent.

## Layout

```
.config/emacs/
├── early-init.el   # GC threshold, frame defaults, package.el off (Elpaca manages packages)
├── init.el         # Elpaca 0.12 bootstrap, use-package, module loading, envrc, global options
├── modules/        # one topic per file, loaded from init.el
│   ├── interface.el  completion.el  editor.el  projects.el  explorer.el  welcome.el
│   ├── dev.el  lang-server.el  languages.el  tree.el  debugger.el  terminal.el
│   └── ai.el  docs.el  web.el
└── templates       # tempel snippet definitions
```

Everything Elpaca builds lands in the gitignored `elpaca/`; caches go to `var/`, `etc/`, `eln-cache/`, `tree-sitter/`, all gitignored. `local.el` (per-machine theme choice) and `custom.el` are gitignored too.

## Hard rules

1. **Never commit anything under `elpaca/`, `var/`, `etc/`, `eln-cache/`, `tree-sitter/`, `custom.el` or `local.el`.** The `.gitignore` covers them; do not force-add. Package versions are pinned, when they are, by `elpaca.lock` (written with `M-x jmc-elpaca-write-lock`), which is the only Elpaca artefact that belongs in git. `.gitattributes` gives it a diff driver; keep that file here, attributes in the dotfiles parent do not apply inside a submodule.
2. **Packages are declared with `use-package` and installed by Elpaca.** Do not add `package-install`, `package.el` initialisation, `straight.el` or manual `load-path` hacks. Built-in packages use `:ensure nil`. Put a new package in the module that owns its topic, not in `init.el`.
3. **Every file starts with `-*- lexical-binding: t; -*-`** and the `jmc-` prefix is reserved for this configuration's own functions and variables. Keep the prefix; the README refers to those names.
4. **Keybindings are documented.** Any binding you add, move or remove must be reflected in the README's tables (and in the `which-key`-visible prefix maps: `C-c c`, `C-c i`, `C-c g`, `C-c d`, `C-c e`, `C-c l`, `C-c m`, `C-c p`, `C-c w`, `s-p`). Do not rebind `C-c p`, `s-l` or `s-p`; their ownership (Perspective, `tab-close`, the project jump map) is explained in comments where they are set.
5. **Do not launch Emacs non-interactively to test.** The first launch installs every package, compiles jinx's native module and asks before installing tree-sitter grammars; do that interactively, or ask the person to. For a syntax check, `emacs --batch -f batch-byte-compile <file>` on the changed file is acceptable (expect "free variable" warnings for symbols declared in other modules).
6. **Tree-sitter grammar sources live in `modules/tree.el`.** When a grammar's upstream moves (as HCL's did), change the source there; do not vendor grammars.
7. **Secrets and client details never enter this repository.** Credentials come from per-project `.envrc` via `envrc`; Forge tokens live in `~/.authinfo.gpg`. Do not add a hardcoded path that only exists on one machine; `local.el` is the per-machine escape hatch.
8. **Comments are part of the configuration.** Files explain *why* a setting exists, often after a bug; read the comment before changing a line and update it with the change. Do not strip comments to "clean up".
9. **Commits follow Conventional Commits** (`lefthook.yml` runs `cog verify`; scopes in use: `ui`, `tree`, `editor`, `dev`, `readme`, `emacs`). Do not run `lefthook install`; the dotfiles' global git hooks dispatch to lefthook. No AI attribution trailers.

## Where things are documented

| Topic | Where |
| ----- | ----- |
| Installation, prerequisites, language tools, every keybinding | `.config/emacs/README.md` |
| Package pinning and the weekly auto-update | `init.el`, "ELPACA" section, and the README's "Package updates & reproducibility" |
| Why a module avoids a certain hook or binding | the comment at that line; many begin with `->` |
| Machine setup around Emacs (fonts, fish environment, Karabiner) | `AGENTS.md` and `README.md` in the dotfiles repository |
