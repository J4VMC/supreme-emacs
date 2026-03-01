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
;; CORE TREE-SITTER SETUP (TREESIT)
;; =============================================================================

(use-package treesit
  ;; `:ensure nil` because `treesit` is a built-in feature of Emacs 29+.
  :ensure nil

  :preface
  ;; --- Grammar Installation Logic ---
  ;; Emacs provides the engine, but we must download the "grammars" (the rules)
  ;; for each language we want to support.
  (defun setup-install-grammars ()
    "Automatically download and compile Tree-sitter grammars if missing."
    (interactive)
    (dolist (grammar
             '((css        . ("https://github.com/tree-sitter/tree-sitter-css"))
               (go         . ("https://github.com/tree-sitter/tree-sitter-go"))
               (html       . ("https://github.com/tree-sitter/tree-sitter-html"))
               (javascript . ("https://github.com/tree-sitter/tree-sitter-javascript" "master" "src"))
               (json       . ("https://github.com/tree-sitter/tree-sitter-json"))
               (markdown   . ("https://github.com/ikatyang/tree-sitter-markdown"))
               (python     . ("https://github.com/tree-sitter/tree-sitter-python"))
               (rust       . ("https://github.com/tree-sitter/tree-sitter-rust"))
               (toml       . ("https://github.com/tree-sitter/tree-sitter-toml"))
               (scala      . ("https://github.com/tree-sitter/tree-sitter-scala"))
               (tsx        . ("https://github.com/tree-sitter/tree-sitter-typescript" "master" "tsx/src"))
               (typescript . ("https://github.com/tree-sitter/tree-sitter-typescript" "master" "typescript/src"))
               (php        . ("https://github.com/tree-sitter/tree-sitter-php" "master" "php/src"))
               (sql        . ("https://github.com/m-novikov/tree-sitter-sql"))
               (yaml       . ("https://github.com/ikatyang/tree-sitter-yaml"))
	       (bash       . ("https://github.com/tree-sitter/tree-sitter-bash" "master" "src"))))

      ;; 1. Register the download source for this language.
      (add-to-list 'treesit-language-source-alist grammar)

      ;; 2. Install only if not already present on the system to save time on startup.
      (unless (treesit-language-available-p (car grammar))
        (treesit-install-language-grammar (car grammar)))))

  ;; --- Major Mode Remapping ---
  ;;
  ;; This tells Emacs to favor the new Tree-sitter modes over the classic ones.
  ;; When you open a Python file, Emacs will now use `python-ts-mode` instead
  ;; of the legacy `python-mode`.
  (dolist (mapping
           '((python-mode     . python-ts-mode)
             (css-mode        . css-ts-mode)
             (typescript-mode . typescript-ts-mode)
             (js2-mode        . js-ts-mode)
             (bash-mode       . bash-ts-mode)
             (conf-toml-mode  . toml-ts-mode)
             (go-mode         . go-ts-mode)
             (php-mode        . php-ts-mode)
             (json-mode       . json-ts-mode)
             (sql-mode        . sql-ts-mode)
             (xml-mode        . xml-ts-mode)
             (scala-mode      . scala-ts-mode)
             (rust-mode       . rust-ts-mode)
             (js-json-mode    . json-ts-mode)))
    (add-to-list 'major-mode-remap-alist mapping))

  :config
  ;; Check for and install missing grammars on startup.
  (run-with-idle-timer 2.0 nil #'setup-install-grammars)

  ;; Set the font-lock level to the maximum (4).
  ;; -> Level 4 provides the most granular and colorful syntax highlighting.
  (setq treesit-font-lock-level 4)

  ;; ===========================================================================
  ;; COMBOBULATE (STRUCTURAL EDITING)
  ;; ===========================================================================
  ;;
  ;; Combobulate uses the syntax tree to let you navigate and edit code by its
  ;; logical structure (nodes) rather than just lines or characters.

  (use-package combobulate
    :ensure nil
    ;; This package must be manually cloned into your config directory.
    :load-path "combobulate"
    ;; Activate combobulate in common Tree-sitter modes.
    :hook ((python-ts-mode     . combobulate-mode)
           (js-ts-mode         . combobulate-mode)
           (tsx-ts-mode        . combobulate-mode)
           (typescript-ts-mode . combobulate-mode))
    :config
    ;; Set the command prefix to `C-c o`.
    ;; -> e.g., `C-c o n` moves the cursor to the next logical code node.
    (setq combobulate-key-prefix "C-c o")))

;; =============================================================================
;; TREE-SITTER CODE FOLDING
;; =============================================================================
;;
;; Allows you to collapse and expand code blocks (functions, classes, loops)
;; based on their actual syntax rather than just indentation levels.

(use-package treesit-fold
  :ensure (:host github :repo "emacs-tree-sitter/treesit-fold")
  :config
  ;; Bind Super + Backspace to toggle the fold at the current cursor position.
  (define-key treesit-fold-mode-map (kbd "s-<backspace>") 'treesit-fold-toggle))

;; Visual indicators (like a `+` sign) in the left margin for folded blocks.
(use-package treesit-fold-indicators
  :ensure (:host github :repo "emacs-tree-sitter/treesit-fold")
  :after treesit-fold
  :config
  ;; Enable the margin indicators globally across all supported modes.
  (global-treesit-fold-indicators-mode 1))

;; =============================================================================
;; FINALIZE
;; =============================================================================

(provide 'tree)

;;; tree.el ends here
