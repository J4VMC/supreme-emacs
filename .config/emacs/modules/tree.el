;;; tree.el --- Configuration related to Tree-sitter -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; This file configures Tree-sitter.
;;
;; ### What is Tree-sitter?
;; Tree-sitter is a modern, high-performance parsing system. Unlike the "old way"
;; that uses complex text patterns (regular expressions), Tree-sitter builds a
;; complete and accurate "syntax tree" of your source code.
;;
;; ### Why use it?
;; 1. **Superior Syntax Highlighting**: It understands code context. It knows
;;    exactly if a word is a variable, a function name, or a type, providing
;;    highly accurate colors.
;; 2. **Context-Aware Navigation**: Enables commands like "jump to next function"
;;    or "select the current class" because it understands the code's structure.
;; 3. **Reliable Code Folding**: Hides or shows code blocks based on actual
;;    logic (like function bodies) rather than just indentation.
;;
;; This file handles the installation of language grammars, remaps old modes
;; to new Tree-sitter versions, and configures advanced structural editing tools.
;;
;;; Code:

;; =============================================================================
;; COMPILER DECLARATIONS (SILENCE WARNINGS)
;; =============================================================================

(defvar combobulate-key-prefix)
(defvar treesit-fold-mode-map)

(declare-function global-treesit-auto-mode "treesit-auto")
(declare-function global-treesit-fold-mode "treesit-fold")
(declare-function global-treesit-fold-indicators-mode "treesit-fold-indicators")
(declare-function treesit-fold-toggle "treesit-fold")

;; =============================================================================
;; CORE TREE-SITTER SETUP (TREESIT)
;; =============================================================================

(use-package treesit
  ;; `:ensure nil` because `treesit` is a built-in feature of Emacs 29+.
  :ensure nil
  :config
  ;; Set the font-lock level to the maximum (4).
  ;; -> Level 4 provides the most granular and colorful syntax highlighting.
  (setq treesit-font-lock-level 4))

(use-package treesit-auto
  :custom
  ;; Ask before installing a missing grammar instead of installing silently.
  ;; -> `t` performed a SYNCHRONOUS git-clone + C-compile the moment a file
  ;;    with a missing grammar was opened, freezing Emacs for ~10s. Worse:
  ;;    a grammar whose install FAILS is never recorded as present, so the
  ;;    whole clone+compile was retried on EVERY file visit — the recurring
  ;;    freeze. With 'prompt you get a visible yes/no instead, and the
  ;;    prompt names the grammar, which identifies a failing one instantly.
  ;; -> Install everything up front in ONE supervised batch with
  ;;    `M-x treesit-auto-install-all` (plus `M-x php-ts-mode-install-parsers`
  ;;    for PHP's multi-grammar set), then day-to-day opens never block.
  (treesit-auto-install 'prompt)

  ;; Only manage grammars for languages this config actually uses.
  ;; -> The default list covers dozens of languages, including several with
  ;;    historically flaky grammar builds (latex, markdown, org). Pinning
  ;;    shrinks the failure surface and makes `treesit-auto-install-all`
  ;;    fast. If a grammar from this list keeps failing to build, remove it
  ;;    here and fall back to the non-ts mode for that language.
  (treesit-auto-langs '(python javascript typescript tsx go gomod rust php
                               java scala bash css html json yaml toml dockerfile))
  :config
  ;; THE MISSING ACTIVATION: `treesit-auto-install` is only *consulted* by
  ;; this globalized mode — without it the package did nothing at all, and
  ;; grammars only existed because they had been installed manually at some
  ;; point. With the mode on, opening a file whose grammar is missing
  ;; installs it automatically.
  ;;
  ;; NOTE: we deliberately do NOT call `treesit-auto-add-to-auto-mode-alist`.
  ;; languages.el manages `auto-mode-alist` explicitly, including choices
  ;; that differ from treesit-auto's defaults (e.g. `.rs` -> rustic-mode).
  ;; Letting treesit-auto mass-register its own mappings would risk
  ;; shadowing those decisions.
  (global-treesit-auto-mode))

;; ===========================================================================
;; COMBOBULATE (STRUCTURAL EDITING)
;; ===========================================================================
;;
;; Combobulate uses the syntax tree to let you navigate and edit code by its
;; logical structure (nodes) rather than just lines or characters.

(use-package combobulate
  ;; Managed by Elpaca like every other GitHub package in this config.
  ;; -> Previously this relied on a MANUAL clone into ~/.emacs.d/combobulate
  ;;    via `:load-path`; forgetting the clone on a new machine made every
  ;;    python/js/tsx buffer error when the autoloaded hook fired.
  ;;    The old clone directory can be deleted once this builds.
  :ensure (:host github :repo "mickeynp/combobulate")
  ;; Activate combobulate in common Tree-sitter modes.
  :hook ((python-ts-mode     . combobulate-mode)
         (js-ts-mode         . combobulate-mode)
         (tsx-ts-mode        . combobulate-mode)
         (typescript-ts-mode . combobulate-mode))
  :config
  ;; Set the command prefix to `C-c o`.
  ;; -> e.g., `C-c o n` moves the cursor to the next logical code node.
  ;; -> No conflict with oil anymore: explorer.el moved `oil-open` to
  ;;    `C-c O`, so this prefix is unambiguously combobulate's.
  (setq combobulate-key-prefix "C-c o"))

;; =============================================================================
;; TREE-SITTER CODE FOLDING
;; =============================================================================
;;
;; Allows you to collapse and expand code blocks (functions, classes, loops)
;; based on their actual syntax rather than just indentation levels.
;;
;; FIXED (two bugs in one):
;; 1. `treesit-fold-mode` was never enabled in any buffer, and a mode's keymap
;;    is inert while the mode is off — so the `s-<backspace>` binding (and
;;    folding in general) never worked. `global-treesit-fold-mode` fixes that.
;; 2. `treesit-fold` and `treesit-fold-indicators` were declared as two
;;    separate Elpaca packages built from the SAME repository, which makes
;;    Elpaca clone/build the repo twice under two names. The indicators
;;    library ships inside the treesit-fold repo, so one package declaration
;;    covers both.

(use-package treesit-fold
  :ensure (:host github :repo "emacs-tree-sitter/treesit-fold")
  :config
  ;; Enable folding in every tree-sitter-capable buffer.
  (global-treesit-fold-mode 1)

  ;; Bind Super + Backspace to toggle the fold at the current cursor position.
  ;; -> Defined here, AFTER the package loads, so the keymap exists.
  (define-key treesit-fold-mode-map (kbd "s-<backspace>") #'treesit-fold-toggle)

  ;; Visual indicators (like a `+` sign) in the left fringe for foldable and
  ;; folded blocks. Same repo, separate library.
  ;; -> NOTE: dev.el intentionally disables `treesit-fold-indicators-mode`
  ;;    per-buffer in Scala (`jmc-scala-setup-h`) to work around a node-type
  ;;    error; that per-buffer opt-out continues to work with the global
  ;;    mode enabled here.
  (require 'treesit-fold-indicators)
  (global-treesit-fold-indicators-mode 1))

;; =============================================================================
;; FINALIZE
;; =============================================================================

(provide 'tree)

;;; tree.el ends here
