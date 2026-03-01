;;; editor.el --- General editor settings and behaviors -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; This file configures the core text editing experience in Emacs.
;;
;; It focuses on the *act* of editing text itself, independent of any specific
;; programming language. This includes:
;;
;; 1. Core Behaviors: File handling, auto-reloading, UTF-8, and backups.
;; 2. Session & History: Remembering command history and cursor positions.
;; 3. Visual Aids: Line numbers, word wrap, indent guides, and bracket pairing.
;; 4. Editing Enhancements: Multiple cursors, semantic expansion, rapid jumping
;;    (`avy`), easy commenting, and an advanced undo tree (`vundo`).
;;
;;; Code:

;; =============================================================================
;; COMPILER DECLARATIONS (SILENCE WARNINGS)
;; =============================================================================

(defvar wgrep-auto-save-buffer)
(defvar vundo-glyph-alist)
(defvar vundo-unicode-symbols)
(defvar ctrlf-minibuffer-mode-map)
(defvar ctrlf-default-search-style)
(defvar ctrlf--minibuffer)

(declare-function electric-pair-conservative-inhibit "elec-pair")
(declare-function global-hl-todo-mode "hl-todo")
(declare-function whole-line-or-region-global-mode "whole-line-or-region")
(declare-function drag-stuff-global-mode "drag-stuff")
(declare-function drag-stuff-define-keys "drag-stuff")
(declare-function ctrlf-cancel "ctrlf")
(declare-function ctrlf-mode "ctrlf")
(declare-function evilnc-default-hotkeys "evil-nerd-commenter")

;; =============================================================================
;; CORE EDITOR BEHAVIOR
;; =============================================================================

;; Ensure all text files end with a single empty newline (POSIX standard).
(setq require-final-newline t)

;; Quit Emacs silently, even if sub-processes (like LSP or terminals) are running.
(setq confirm-kill-processes nil)

;; Enable CUA (Common User Access) mode.
;; -> Makes Emacs respect standard OS shortcuts: `C-x` (cut), `C-c` (copy), `C-v` (paste).
(cua-mode 1)

;; --- Auto-revert Mode ---
;; Automatically reload files if they are modified by an external program (e.g., `git checkout`).
(setq-default auto-revert-avoid-polling t)
(setq auto-revert-interval 5)
(setq auto-revert-check-vc-info t)
(global-auto-revert-mode 1)

;; Disable the archaic convention of requiring two spaces after a period.
(setq-default sentence-end-double-space nil)

;; Disable automatic backup files (e.g., `file.txt~`).
;; -> We rely on Git for version control; these files just create clutter.
(setq make-backup-files nil)

;; Enable `delete-selection-mode`.
;; -> If you highlight text and start typing, the highlighted text is instantly replaced.
(delete-selection-mode 1)

;; --- Encoding ---
;; Force UTF-8 encoding everywhere to ensure special characters always render correctly.
(prefer-coding-system 'utf-8)
(set-default-coding-systems 'utf-8)

;; =============================================================================
;; HISTORY & SESSION PERSISTENCE
;; =============================================================================

;; Save Minibuffer History.
;; -> Remembers your previous `M-x` commands and search queries across Emacs restarts.
(use-package savehist
  :ensure nil ; Built-in
  :init (savehist-mode 1)
  :config (setq history-length 1000)) ; Retain the last 1000 history items.

;; Save Cursor Position.
;; -> When you reopen a file, your cursor will be exactly where you left it.
(use-package saveplace
  :ensure nil ; Built-in
  :init (save-place-mode 1))

;; Track recently opened files (supercharges consult-buffer)
(use-package recentf
  :ensure nil
  :init
  (recentf-mode 1)
  :config
  (setq recentf-max-menu-items 100)
  (setq recentf-max-saved-items 1000))

;; =============================================================================
;; VISUAL AIDS & FORMATTING
;; =============================================================================

;; Enable line numbers, but only in programming modes.
(add-hook 'prog-mode-hook #'display-line-numbers-mode)
(setq-default display-line-numbers-width 3) ; Reserve 3 columns of width.

;; Enable visual word wrap in text modes (Markdown, plain text).
(add-hook 'text-mode-hook #'visual-line-mode)

;; Highlight the line the cursor is currently on.
(use-package hl-line
  :ensure nil ; Built-in
  :hook ((prog-mode . hl-line-mode)
         (text-mode . hl-line-mode)
         (markdown-mode . hl-line-mode)))

;; --- Bracket Pairing ---

;; Built-in `electric-pair-mode`: Automatically inserts closing brackets `()`, `[]`, `""`.
(use-package elec-pair
  :preface
  (defun jmc-electric-pair-inhibit-p (char)
    "Define when Emacs should *not* auto-insert a closing bracket."
    (or
     ;; 1. Never auto-pair while typing in the minibuffer command line.
     (minibufferp)
     ;; 2. Disable auto-pairing for `<`, `>`, and `~` (useful for HTML/XML/Markdown).
     (member char '(?< ?> ?~))
     ;; 3. Fallback to default conservative pairing logic for everything else.
     (electric-pair-conservative-inhibit char)))
  :config
  (setq electric-pair-inhibit-predicate #'jmc-electric-pair-inhibit-p)
  (electric-pair-mode t))

;; Explicitly add curly braces `{}` to the pairing list.
(setq electric-pair-pairs '((?\{ . ?\})))

;; `rainbow-delimiters`: Color-codes matching brackets.
;; -> Makes deeply nested Lisp, JSON, or JavaScript much easier to read.
(use-package rainbow-delimiters
  :ensure t
  :hook ((prog-mode . rainbow-delimiters-mode)
         (text-mode . rainbow-delimiters-mode)
         (markdown-mode . rainbow-delimiters-mode)))

;; `supreme-brackets`: Advanced manual manipulation of brackets.
(use-package supreme-brackets
  :ensure (:host github :repo "J4VMC/supreme-brackets")
  :config
  (supreme-brackets-setup-extended-keybindings))

;; --- Indentation Guides ---
;; Draws vertical lines to visualize code indentation blocks (crucial for Python/YAML).
(use-package highlight-indent-guides
  :ensure t
  :hook (prog-mode . highlight-indent-guides-mode)
  :custom
  (highlight-indent-guides-method 'fill)
  (highlight-indent-guides-responsive 'top)
  (highlight-indent-guides-auto-enabled nil) ;; Manually define colors below.

  :custom-face
  ;; Define subtle, glassy vertical lines that blend into a dark theme.
  (highlight-indent-guides-even-face ((t (:background "#262727"))))
  (highlight-indent-guides-odd-face  ((t (:background "#32302f"))))

  ;; Highlight the specific indentation block the cursor is currently inside.
  (highlight-indent-guides-top-even-face ((t (:background "#45352b"))))
  (highlight-indent-guides-top-odd-face  ((t (:background "#2f232b")))))

;; Highlights semantic keywords like "TODO:", "FIXME:", and "NOTE:" in comments.
(use-package hl-todo
  :ensure t
  :init (global-hl-todo-mode))

;; Renders `^L` (form feed) characters as clean horizontal divider lines.
(use-package page-break-lines
  :ensure t
  :config (global-page-break-lines-mode))

;; Automatically strip trailing whitespace from lines when saving a file.
(use-package whitespace-cleanup-mode
  :ensure (:host github :repo "purcell/whitespace-cleanup-mode")
  :defer t
  :hook (prog-mode . whitespace-cleanup-mode)
  :config (setq whitespace-cleanup-mode-preserve-point t))

;; =============================================================================
;; EDITING ENHANCEMENTS
;; =============================================================================

;; `crux`: A collection of essential utility commands.
;; -> E.g., `crux-rename-file-and-buffer`, `crux-duplicate-current-line-or-region`.
(use-package crux
  :ensure t
  :defer t)

;; `hydra`: Framework for creating pop-up keybinding menus.
(use-package hydra
  :ensure t)

;; Makes copy/cut commands apply to the *entire current line* if no text is highlighted.
(use-package whole-line-or-region
  :ensure t
  :config (whole-line-or-region-global-mode t))

;; `multiple-cursors`: VS Code-style multi-caret editing.
;; 
(use-package multiple-cursors
  :ensure t
  :bind ("C-M-j"   . mc/edit-lines)                 ; Add cursor on next/prev line.
  :bind ("C->"     . mc/mark-next-like-this)          ; Add cursor at next matching word.
  :bind ("C-<"     . mc/mark-previous-like-this)      ; Add cursor at prev matching word.
  :bind ("C-c C-<" . mc/mark-all-like-this)       ; Add cursors at ALL matching words.
  :bind ("C-M-="   . mc/mark-all-symbols-like-this))

;; `expreg`: Semantic selection expansion.
;; -> Press `M-J` repeatedly to grow selection: word -> string -> argument -> function.
(use-package expreg
  :ensure t
  :bind ("M-J" . expreg-expand))

;; `visual-replace`: A cleaner, visual interface for find-and-replace.
(use-package visual-replace
  :defer t)

;; `drag-stuff`: Move lines or highlighted regions up/down using `M-up` and `M-down`.
(use-package drag-stuff
  :ensure t
  :defer 1
  :config
  (drag-stuff-global-mode 1)
  (drag-stuff-define-keys))

;; `avy`: Blazing fast on-screen navigation.
;; -> Triggers a search that overlays hotkeys on matches. Type the hotkey to jump instantly.
(use-package avy
  :ensure t
  :bind (("C-c j" . avy-goto-line)      ; Jump to a specific visible line.
         ("s-j"   . avy-goto-char-timer))) ; Jump to any visible character sequence.

;; `rg`: Frontend for `ripgrep` (ultra-fast project search).
;; -> Integrated with `wgrep` to allow editing search results directly (project-wide replace).
(use-package rg
  :ensure t
  :defer t
  :after transient
  :config
  (setq wgrep-auto-save-buffer t)
  (add-hook 'rg-mode-hook 'wgrep-rg-setup))

;; `vundo`: Visual Undo Tree.
;; -> Displays your undo history as a branching tree, allowing you to easily
;;    navigate past states without losing "undone" changes.
(use-package vundo
  :ensure t
  :defer 1
  :init (setq vundo-glyph-alist vundo-unicode-symbols))

;; `ctrlf`: A modern, non-blocking, visual search replacement for `C-s`.
(use-package ctrlf
  :ensure t
  :defer 1
  :preface
  (defun jmc-ctrlf-auto-cancel-h ()
    "Automatically cancel the search if the user clicks out of the minibuffer."
    (when (and (bound-and-true-p ctrlf--active-p)
               (not (minibufferp))
               (not (eq (current-buffer) ctrlf--minibuffer)))
      (ctrlf-cancel)))
  :config
  (define-key ctrlf-minibuffer-mode-map (kbd "C-r") 'ctrlf-backward-default)
  (setq ctrlf-default-search-style 'literal) ; Search for exact text, not Regex.
  (add-hook 'post-command-hook #'jmc-ctrlf-auto-cancel-h)
  (ctrlf-mode t))

;; `dash` & `s`: Essential List and String manipulation libraries for Emacs Lisp.
(use-package dash :ensure t)
(use-package s    :ensure t)

;; `evil-nerd-commenter`: Rapid code commenting/uncommenting (e.g., via `M-/`).
(use-package evil-nerd-commenter
  :ensure t
  :defer 1
  :config
  (evilnc-default-hotkeys t))

(use-package which-key
  :ensure nil ; Built into Emacs 30+
  :init
  (which-key-mode)
  :config
  (setq which-key-idle-delay 0.5)    ; Pop up a bit faster
  (setq which-key-add-column-padding 1))

;; =============================================================================
;; FINALIZE
;; =============================================================================

(provide 'editor)

;;; editor.el ends here
