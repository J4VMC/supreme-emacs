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

;; =============================================================================
;; CORE TREE-SITTER SETUP (TREESIT)
;; =============================================================================
;;
;; Emacs 31 made two external packages redundant here, and both were REMOVED
;; with the move to emacs-plus@31:
;;   * `treesit-auto'  -> `treesit-auto-install-grammar' + `treesit-enabled-modes'
;;   * `treesit-fold'  -> hideshow, which now folds tree-sitter blocks natively
;;                        (see CODE FOLDING below).

(use-package treesit
  ;; `:ensure nil` because `treesit` is a built-in feature of Emacs 29+.
  :ensure nil
  :custom
  ;; Set the font-lock level to the maximum (4).
  ;; -> Level 4 provides the most granular and colorful syntax highlighting.
  (treesit-font-lock-level 4)

  ;; --- Grammar installation ---
  ;; Ask before installing a missing grammar instead of installing silently:
  ;; a silent install was a SYNCHRONOUS git-clone + C-compile the moment a
  ;; file was opened (~10s freeze), and a grammar whose build FAILS is never
  ;; recorded as present, so it was retried on EVERY visit. With 'ask you get
  ;; a visible yes/no naming the grammar, which identifies a failing one
  ;; instantly. Every built-in ts mode registers its own PINNED recipe in
  ;; `treesit-language-source-alist' when it loads, so no URL list is kept
  ;; here. Install everything up front with `jmc-treesit-install-all-grammars'
  ;; (below), then day-to-day opens never block.
  (treesit-auto-install-grammar 'ask)

  ;; --- Mode remapping ---
  ;; languages.el maps every file extension to its ts mode explicitly; this
  ;; list covers the remaining paths where Emacs would still pick the legacy
  ;; mode (a shebang or mode cookie selecting `sh-mode'/`python-mode', a
  ;; `css-mode' buffer created by another package, ...) and lets the ts
  ;; modes' `*-ts-mode-maybe' autoloads offer a grammar install.
  ;; -> Deliberately a list, NOT t: `.rs' stays with rustic-mode and `.html'
  ;;    with web-mode (both decided in languages.el).
  (treesit-enabled-modes '(bash-ts-mode css-ts-mode dockerfile-ts-mode
                           go-ts-mode go-mod-ts-mode java-ts-mode js-ts-mode
                           json-ts-mode php-ts-mode python-ts-mode toml-ts-mode
                           tsx-ts-mode typescript-ts-mode yaml-ts-mode))
  :config
  ;; scala-ts-mode (external, languages.el) registers no grammar recipe of
  ;; its own; this is the one treesit-auto used to carry for it.
  (add-to-list 'treesit-language-source-alist
               '(scala "https://github.com/tree-sitter/tree-sitter-scala"))
  ;; swift-ts-mode (external) registers none either. Only this branch of the
  ;; grammar repo carries the generated parser.c; main needs a JS toolchain.
  (add-to-list 'treesit-language-source-alist
               '(swift "https://github.com/alex-pinkus/tree-sitter-swift"
                       :revision "with-generated-files"))
  ;; ...and, being external, it is not a candidate for `treesit-enabled-modes'
  ;; either. This remap is needed: sbt-mode pulls in the legacy scala-mode,
  ;; whose autoload claims `.scala' AFTER languages.el's mapping ran (Elpaca
  ;; activates packages after init), so without it Scala files opened in
  ;; scala-mode. treesit-auto used to add exactly this entry.
  (add-to-list 'major-mode-remap-alist '(scala-mode . scala-ts-mode))
  ;; hcl-ts-mode (used by terraform-mode) registers no recipe. The upstream
  ;; grammar moved from nickel-lang/tree-sitter-hcl (404) to the canonical
  ;; tree-sitter-grammars org.
  (add-to-list 'treesit-language-source-alist
               '(hcl "https://github.com/tree-sitter-grammars/tree-sitter-hcl")))

(defun jmc-treesit-install-all-grammars ()
  "Install every grammar this config uses that is not installed yet.
One supervised batch, the replacement for `treesit-auto-install-all'.
The mode libraries are loaded first so their pinned recipes are present
in `treesit-language-source-alist'. PHP needs several grammars; its mode
registers all of them."
  (interactive)
  (dolist (lib '(sh-script css-mode dockerfile-ts-mode go-ts-mode java-ts-mode
                 js json-ts-mode php-ts-mode python toml-ts-mode
                 typescript-ts-mode yaml-ts-mode))
    (require lib))
  (dolist (lang (mapcar #'car treesit-language-source-alist))
    (if (treesit-language-available-p lang)
        (message "treesit: %s already installed" lang)
      (message "treesit: installing %s..." lang)
      (treesit-install-language-grammar lang)))
  (message "treesit: all grammars present."))

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
;; CODE FOLDING (HIDESHOW)
;; =============================================================================
;;
;; Collapse and expand code blocks (functions, classes, loops) by their actual
;; syntax. Emacs 31's hideshow folds the tree-sitter `list' thing natively in
;; every ts mode and gained fringe indicators, `hs-cycle' and `hs-toggle-all',
;; so the external `treesit-fold' package (plus its indicators library, and the
;; Scala per-buffer workaround in dev.el that disabled those indicators) was
;; REMOVED with the move to emacs-plus@31.

(defun jmc-hs-enable-h ()
  "Turn on `hs-minor-mode', tolerating major modes hideshow cannot handle."
  (condition-case err
      (hs-minor-mode 1)
    (error (message "hideshow: %s" (error-message-string err)))))

(use-package hideshow
  :ensure nil ; Built-in
  :diminish hs-minor-mode
  :hook (prog-mode . jmc-hs-enable-h)
  :custom
  ;; Clickable +/- markers in the LEFT fringe for foldable and folded blocks.
  (hs-show-indicators t)
  ;; Show "N lines" next to the ellipsis of a folded block.
  (hs-display-lines-hidden t)
  ;; Super + Backspace toggles the fold at point (same key as before).
  :bind (:map hs-minor-mode-map
              ("s-<backspace>" . hs-toggle-hiding)))

;; =============================================================================
;; FINALIZE
;; =============================================================================

(provide 'tree)

;;; tree.el ends here
