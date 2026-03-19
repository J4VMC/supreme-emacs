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

(use-package treesit
  ;; `:ensure nil` because `treesit` is a built-in feature of Emacs 29+.
  :ensure nil
  :config
  ;; Set the font-lock level to the maximum (4).
  ;; -> Level 4 provides the most granular and colorful syntax highlighting.
  (setq treesit-font-lock-level 4))

(use-package treesit-auto
  :ensure t
  :custom
  ;; Automatically install missing grammars when you open a file.
  ;; -> Set to 'prompt if you want Emacs to ask for permission first.
  ;; -> Set to t to install silently in the background.
  (treesit-auto-install t))

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
  (setq combobulate-key-prefix "C-c o"))

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
