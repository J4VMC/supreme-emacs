;;; explorer.el --- File-specific configurations -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; This file configures file exploration and management inside Emacs.
;;
;; The core of file management in Emacs is `Dired` (Directory Editor).
;; It is a built-in mode that turns a directory listing into a fully
;; editable text buffer.
;;
;; ;;
;;
;; To modernize the experience, we apply several quality-of-life tweaks
;; to Dired and install powerful packages like `dirvish` and `oil`. These
;; enhancements make Emacs feel like a highly capable, modern file explorer.
;;
;;; Code:

;; =============================================================================
;; COMPILER DECLARATIONS (SILENCE WARNINGS)
;; =============================================================================

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
  (setq dired-dwim-target t))

;; =============================================================================
;; MODERN FILE EXPLORER FRONTENDS
;; =============================================================================

;; Dirvish is a highly polished, modern frontend for Dired.
;; -> It adds features like a centered layout, file previews, and a cleaner UI.
(use-package dirvish
  :ensure t
  :after dired
  :config
  ;; Instruct Dirvish to completely take over Dired's functionality.
  ;; -> Whenever you launch the standard `dired` command, Dirvish will open instead.
  (dirvish-override-dired-mode t))

;; Oil.el is a modern alternative inspired by Vim's `oil.nvim`.
;; -> It allows you to manage files by literally editing the directory buffer
;;    as if it were a normal text file. For example, deleting a line of text
;;    in the buffer will delete the actual file.
(use-package oil
  :ensure (:host github :repo "yibie/Oil.el")
  :bind ("C-c o" . oil-open))

;; =============================================================================
;; FINALIZE
;; =============================================================================

(provide 'explorer)

;;; explorer.el ends here
