;;; terminal.el --- Terminal emulation and shell configuration -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; This file configures the terminal experience inside Emacs.
;;
;; We use `ghostel`, a fast terminal emulator leveraging `libghostty-vt`.
;; It provides a snappy, modern terminal experience natively within Emacs.
;;
;; Key features:
;; 1. "Quake-style" pop-up terminal at the bottom of the screen.
;; 2. Intelligent project-root detection for automatic `cd` on launch.
;; 3. Multi-terminal support via prefix arguments.
;; 4. Force-kill functionality to bypass "Process is running" prompts.
;; 5. Auto-kill buffers when the underlying shell process exits.
;;
;;; Code:

;; =============================================================================
;; COMPILER DECLARATIONS (SILENCE WARNINGS)
;; =============================================================================

(defvar ghostel-eval-cmds)
(defvar ghostel-mode-map)
(defvar ghostel-semi-char-mode-map)

(declare-function ghostel "ghostel")
(declare-function projectile-project-root "projectile")

;; =============================================================================
;; GHOSTEL (THE TERMINAL EMULATOR)
;; =============================================================================

(use-package ghostel
  ;; Tell Elpaca to keep all files (including the terminfo folder) to prevent color warnings.
  :ensure (:host github :repo "dakra/ghostel" :files (:defaults "*"))
  :defer t
  ;; Tell Emacs to load the package the moment `ghostel` is called
  :commands (ghostel)
  :preface

  ;; ===========================================================================
  ;; CUSTOM PASTE LOGIC FOR CUA-MODE
  ;; ===========================================================================

  (defun jmc-ghostel-paste ()
    "Send the current clipboard/kill-ring text to the Ghostel terminal.
Uses ghostel's own send primitive when available, and wraps the text in
BRACKETED-PASTE escapes so multiline pastes arrive as ONE block.
Without the wrapping, the Claude Code TUI submits the message at the
first raw newline, and fish executes each pasted line as it lands.
\(Caveat: a program that never enabled bracketed paste would display
the escape codes literally — fish, the Claude TUI, and modern REPLs
all enable it.)"
    (interactive)
    (let* ((text (current-kill 0 t))
           (bracketed (concat "\e[200~" text "\e[201~")))
      (cond
       ((fboundp 'ghostel-send-string)
        (ghostel-send-string bracketed))
       ((get-buffer-process (current-buffer))
        (process-send-string (get-buffer-process (current-buffer)) bracketed))
       (t
        (error "No active process found for this Ghostel buffer")))))

  ;; ===========================================================================
  ;; CUSTOM "FORCE KILL" LOGIC
  ;; ===========================================================================

  (defun jmc-kill-buffer-and-its-windows (buffer)
    "Kill BUFFER and all windows displaying it without mercy."
    (interactive (list (read-buffer "Kill buffer: " (current-buffer) 'existing)))
    (setq buffer (get-buffer buffer))
    (if (buffer-live-p buffer)
        (let ((wins (get-buffer-window-list buffer nil t)))
          (when (kill-buffer buffer)
            (dolist (win wins)
              (when (window-live-p win)
                (condition-case nil
                    (delete-window win)
                  (error nil))))))
      (when (called-interactively-p 'interactive)
        (error "Buffer `%s` is already dead" buffer))))

  (defun jmc-ghostel-force-kill ()
    "Silence the exit prompt and brutally kill the Ghostel buffer."
    (interactive)
    (let ((buffer (current-buffer)))
      (set-process-query-on-exit-flag (get-buffer-process buffer) nil)
      (jmc-kill-buffer-and-its-windows buffer)))

  ;; ===========================================================================
  ;; ROBUST PROJECT ROOT DETECTION
  ;; ===========================================================================

  (defun jmc-project-root ()
    "Find the project root using Projectile, Git, or `default-directory'.
Projectile is this config's SINGLE source of truth for project
boundaries — it knows the extra root markers registered in projects.el
(`.envrc', `go.mod'). The old version consulted project.el first, which
could resolve a different root than the `s-p' commands for the very
same buffer."
    (or
     (when (fboundp 'projectile-project-root)
       (projectile-project-root))
     (when-let ((git-dir (locate-dominating-file default-directory ".git")))
       (expand-file-name git-dir))
     default-directory))

  ;; ===========================================================================
  ;; THE "QUAKE-STYLE" POP-UP DRAWER & MULTI-TERMINAL SUPPORT
  ;; ===========================================================================

  (defun jmc-ghostel-toggle (&optional arg)
    "Toggle a Quake-style Ghostel terminal in the project root.
With prefix ARG (C-u), create a new separate terminal buffer."
    (interactive "P")
    (let* ((default-directory (jmc-project-root))
           (proj-name (file-name-nondirectory (directory-file-name default-directory)))
           (base-name (format "*ghostel: %s*" proj-name))
           (buf-name (if arg
                         (generate-new-buffer-name base-name)
                       base-name))
           (buf (get-buffer buf-name)))

      (if (and buf (get-buffer-window buf))
          (delete-window (get-buffer-window buf))
        (unless buf
          (require 'ghostel)
          (save-window-excursion
            (with-current-buffer (ghostel)
              (rename-buffer buf-name t)))
          (setq buf (get-buffer buf-name)))
        (pop-to-buffer buf))))

  ;; ===========================================================================
  ;; KEYBINDINGS
  ;; ===========================================================================
  ;;
  ;; PASTE ROUTING — why these are command REMAPS, not key bindings:
  ;; CUA installs its keys (C-v = `cua-paste') through Emacs's EMULATION
  ;; keymap layer, which outranks every minor- and major-mode map. A plain
  ;; ("C-v" . jmc-ghostel-paste) here can therefore NEVER fire — C-v always
  ;; resolved to `cua-paste', which yanked into the BUFFER instead of
  ;; sending to the shell process. Command remapping, however, is consulted
  ;; across all active keymaps AFTER the key resolves to a command, so
  ;; remapping `cua-paste' wins where shadowing the key lost.
  ;; -> [remap cua-paste] catches CUA's C-v.
  ;; -> [remap yank] catches macOS Cmd-V (`s-v' is globally bound to
  ;;    `yank' by the NS port) and C-y in one stroke.
  ;; Both maps get the remaps so paste works regardless of which ghostel
  ;; input mode is active.
  :bind ((:map ghostel-mode-map
               ("M-k" . jmc-ghostel-force-kill)
               ("s-v" . jmc-ghostel-paste)
               ([remap cua-paste] . jmc-ghostel-paste)
               ([remap yank] . jmc-ghostel-paste))
         (:map ghostel-semi-char-mode-map
               ;; Bound here too so the shell can't swallow these keys
               ;; while the active-typing mode's map has precedence.
               ("M-k" . jmc-ghostel-force-kill)
               ("s-v" . jmc-ghostel-paste)
               ([remap cua-paste] . jmc-ghostel-paste)
               ([remap yank] . jmc-ghostel-paste)))

  :config
  ;; --- Paste coverage for RAW/char input mode (Claude Code IDE) ---------
  ;; The Claude Code IDE session runs its ghostel buffer in raw "char"
  ;; input mode for TUI fidelity. In that mode, ghostel's char-mode keymap
  ;; intercepts keys AS KEYS — Cmd-V never resolves to `yank' at all, so
  ;; the [remap yank] entries above are never consulted. The cure is a
  ;; DIRECT `s-v' binding (plus the remaps, for completeness) in the same
  ;; high-precedence maps doing the intercepting. Guarded with `boundp'
  ;; since the exact map names depend on the installed ghostel version;
  ;; if paste still fails in a Claude buffer, run `C-h k' + Cmd-V there —
  ;; it names the intercepting command and its keymap.
  (dolist (map-sym '(ghostel-char-mode-map ghostel-semi-char-mode-map))
    (when (boundp map-sym)
      (let ((map (symbol-value map-sym)))
        (define-key map (kbd "s-v") #'jmc-ghostel-paste)
        (define-key map [remap yank] #'jmc-ghostel-paste)
        (define-key map [remap cua-paste] #'jmc-ghostel-paste))))
  ;; --- Directory & File Integration ---
  ;; Whitelist Emacs functions your shell can call directly.
  (setq ghostel-eval-cmds '(find-file message dired ediff-files))

  ;; --- Window Placement Rules ---
  ;; This tells Emacs: "If it's a ghostel buffer, pop it up at the right
  ;; and make it take up exactly 50% of the screen height."
  (add-to-list 'display-buffer-alist
               '("^\\*ghostel"
                 (display-buffer-reuse-window display-buffer-in-direction)
                 (direction . right)
                 (dedicated . t)
                 (reusable-frames . visible)
                 (window-height . 0.5)
                 (window-width . 0.5)))

  ;; Make URLs and file paths inside the terminal clickable.
  (add-hook 'ghostel-mode-hook #'goto-address-mode)

  ;; --- Auto-Kill on Exit ---
  ;; Attach a process sentinel. When you type `exit` in the shell, this spots
  ;; the "finished" event and cleanly kills the buffer behind it.
  (add-hook 'ghostel-mode-hook
            (lambda ()
              (let ((proc (get-buffer-process (current-buffer))))
                (when proc
                  (set-process-sentinel proc
                                        (lambda (process event)
                                          (when (string-match-p "finished\\|exited" event)
                                            (kill-buffer (process-buffer process))))))))))

;; =============================================================================
;; GLOBAL CONTROLS
;; =============================================================================

;; Toggle the terminal drawer globally.
;; `s-9` = Cmd-9 (macOS) or Win-9 (Linux/Windows).
(global-set-key (kbd "s-9") #'jmc-ghostel-toggle)

;; =============================================================================
;; FINALIZE
;; =============================================================================

(provide 'terminal)

;;; terminal.el ends here
