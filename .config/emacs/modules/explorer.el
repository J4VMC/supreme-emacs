;;; explorer.el --- File-specific configurations -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; This file configures file exploration and management inside Emacs.
;;
;; The core of file management in Emacs is `Dired` (Directory Editor).
;; It is a built-in mode that turns a directory listing into a fully
;; editable text buffer.
;;
;; To modernize the experience, we apply several quality-of-life tweaks
;; to Dired and install powerful packages like `dirvish` and `oil`. These
;; enhancements make Emacs feel like a highly capable, modern file explorer.
;;
;;; Code:

;; =============================================================================
;; COMPILER DECLARATIONS (SILENCE WARNINGS)
;; =============================================================================

(defvar oil--dir)

(declare-function dirvish-override-dired-mode "dirvish")

;; =============================================================================
;; FILE MANAGEMENT (DIRED)
;; =============================================================================

(use-package dired
  ;; `:ensure nil` prevents Elpaca from trying to download Dired.
  ;; -> Dired is built into Emacs; this block is purely for configuration.
  :ensure nil
  ;; Defer loading Dired until the `dired` command is actually called.
  :commands (dired)
  :hook
  (;; Automatically enable `dired-hide-details-mode` on startup.
   ;; -> Hides visual clutter like file permissions, owners, and size.
   ;; -> You can toggle this detailed view on and off by pressing `(` in Dired.
   (dired-mode . dired-hide-details-mode)
   ;; Highlight the current line to make visual navigation easier.
   (dired-mode . hl-line-mode))
  :config
  ;; --- Quality-of-Life Settings ---

  ;; Always copy directories recursively (including all nested contents)
  ;; without constantly prompting for confirmation.
  (setq dired-recursive-copies 'always)

  ;; Always delete directories recursively without prompting.
  (setq dired-recursive-deletes 'always)

  ;; **CRITICAL SAFETY SETTING**: Use the operating system's Trash/Recycle Bin.
  ;; -> By default, Emacs permanently deletes files (like the terminal `rm` command).
  ;; -> Enabling this ensures you can recover accidentally deleted files.
  (setq delete-by-moving-to-trash t)

  ;; Enable "Do What I Mean" (DWIM) target guessing.
  ;; -> If you have two Dired windows open side-by-side, copying or moving
  ;;    a file in one window will automatically assume the other window
  ;;    is your intended destination. Highly recommended!
  (setq dired-dwim-target t)

  ;; --- Navigate in place, VS Code style ---

  ;; Entering a directory REPLACES the current Dired buffer instead of
  ;; spawning a new buffer per folder (the default), so browsing a project
  ;; no longer accumulates a trail of dired buffers.
  ;; -> Dirvish explicitly honors this variable: when set, it routes
  ;;    navigation through `find-alternate-file'. Opening FILES is
  ;;    unaffected — only directory-to-directory movement reuses the buffer.
  ;; -> Note: going `^' (up) replaces the buffer too, so any marks you set
  ;;    are dropped when you leave a directory.
  (setq dired-kill-when-opening-new-dired-buffer t)

  ;; Mouse clicks open in the SAME window.
  ;; -> Stock Dired binds <mouse-2> to `dired-mouse-find-file-other-window',
  ;;    and left-click is translated to mouse-2 via `mouse-1-click-follows-link'
  ;;    — so every clicked folder landed in whatever window `display-buffer'
  ;;    picked. That was the erratic placement. `dired-mouse-find-file' is
  ;;    the same-window variant; dirvish inherits this binding unchanged.
  (define-key dired-mode-map [mouse-2] #'dired-mouse-find-file))

;; =============================================================================
;; MODERN FILE EXPLORER FRONTENDS
;; =============================================================================

;; NOTE: the `nerd-icons' package — backend for the dirvish icon attribute
;; below — is declared canonically in interface.el (ICON PACKAGES), which
;; loads before this module. The entire config shares that one backend.

;; Dirvish is a highly polished, modern frontend for Dired.
;; -> It adds features like file previews, rich attributes, and a cleaner UI.
(use-package dirvish
  :after dired
  :custom
  ;; Per-file columns rendered in every listing (all names verified against
  ;; dirvish's attribute definitions):
  ;; - vc-state:      git status indicator per file (staged/modified/...)
  ;; - subtree-state: expand/collapse arrow for inline subtrees
  ;; - nerd-icons:    file-type icons
  ;; - collapse:      flatten unique nested paths (a/b/c shown as one line)
  ;; - git-msg:       last commit message for the file, right-aligned
  ;; - file-size:     human-readable sizes (the stock default)
  (dirvish-attributes '(vc-state subtree-state nerd-icons collapse git-msg file-size))
  :config
  ;; Instruct Dirvish to completely take over Dired's functionality.
  ;; -> Whenever you launch the standard `dired` command, Dirvish will open instead.
  (dirvish-override-dired-mode t)

  ;; Preview the file at point in a small popup while narrowing candidates
  ;; in `find-file' / `s-p f' — VS Code's Quick Open preview, roughly.
  (dirvish-peek-mode 1))

;; Oil.el is a modern alternative inspired by Vim's `oil.nvim`.
;; -> It allows you to create files by literally editing the directory buffer
;;    as if it were a normal text file: type new filenames, `C-c C-c` creates.
(use-package oil
  :ensure (:host github :repo "yibie/Oil.el")
  ;; MOVED from `C-c o` to `C-c O`: `C-c o` is the combobulate prefix
  ;; (tree.el), whose minor-mode map shadowed oil in every python/js/tsx
  ;; buffer, while oil shadowed combobulate everywhere else.
  :bind ("C-c O" . oil-open)
  :config
  ;; --- Auto-open newly created files -------------------------------------
  ;; Oil's `oil-save` creates files with `make-empty-file` and just refreshes
  ;; the listing; it exposes no hook and doesn't return the created paths.
  ;; -> We wrap it: diff the directory contents before and after, then visit
  ;;    every file that appeared, leaving focus in the last one — mirroring
  ;;    the "create and start editing" flow you'd expect from an editor.
  (defun jmc-oil-visit-created-files-a (orig-fn &rest args)
    "Around-advice for `oil-save': visit files the save created."
    (let* ((dir oil--dir)
	   (before (directory-files dir nil directory-files-no-dot-files-regexp))
	   (result (apply orig-fn args))
	   (after (directory-files dir nil directory-files-no-dot-files-regexp))
	   (new (sort (seq-difference after before) #'string<)))
      (dolist (f new)
	(let ((path (expand-file-name f dir)))
	  (when (file-regular-p path)
	    (find-file path))))
      result))

  (advice-add 'oil-save :around #'jmc-oil-visit-created-files-a))

;; =============================================================================
;; FINALIZE
;; =============================================================================

(provide 'explorer)

;;; explorer.el ends here
