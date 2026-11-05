;;; terminal.el --- Terminal emulation and shell configuration -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; This file configures the terminal experience inside Emacs.
;;
;; We use `ghostel`, a fast terminal emulator leveraging `libghostty-vt`.
;; It provides a snappy, modern terminal experience natively within Emacs.
;;
;; Key features:
;; 1. "Quake-style" pop-up terminal in a half-width window on the right.
;; 2. Intelligent project-root detection for automatic `cd` on launch
;;    (`jmc-project-root', shared with debugger.el for dape's cwd).
;; 3. Multi-terminal support via prefix arguments.
;; 4. Force-kill functionality to bypass "Process is running" prompts.
;;
;; Buffers whose shell exits are killed by ghostel itself
;; (`ghostel-kill-buffer-on-exit', default t) — no sentinel is needed here.
;;
;;; Code:

;; =============================================================================
;; COMPILER DECLARATIONS (SILENCE WARNINGS)
;; =============================================================================

(defvar ghostel-eval-cmds)
(defvar ghostel-mode-map)
(defvar ghostel-semi-char-mode-map)
(defvar ghostel-char-mode-map)

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
    "Silence the exit prompt and brutally kill the Ghostel buffer.
Also works on a terminal whose shell has already exited: the
query-on-exit flag is only touched while there is a live process."
    (interactive)
    (let ((buffer (current-buffer)))
      (when-let* ((proc (get-buffer-process buffer)))
        (set-process-query-on-exit-flag proc nil))
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
same buffer. debugger.el uses this same function for dape's cwd, so the
terminal and the debugger always agree on the root."
    (or
     (when (fboundp 'projectile-project-root)
       (projectile-project-root))
     (when-let* ((git-dir (locate-dominating-file default-directory ".git")))
       (expand-file-name git-dir))
     default-directory))

  ;; ===========================================================================
  ;; THE "QUAKE-STYLE" POP-UP DRAWER & MULTI-TERMINAL SUPPORT
  ;; ===========================================================================

  (defun jmc-ghostel-toggle (&optional arg)
    "Toggle a Quake-style Ghostel terminal in the project root.
With prefix ARG (C-u), create a new separate terminal buffer. If a
Ghostel window is already visible, the new terminal opens beside it
(the window is split) instead of replacing it."
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
          ;; -> `ghostel' looks up an existing terminal by IDENTITY (slot),
          ;;    not by buffer name, so a plain (ghostel) returns the live
          ;;    terminal we already renamed and we would rename it AGAIN:
          ;;    C-u s-9 then showed one buffer in two mirrored windows (and
          ;;    a second project's s-9 stole the first project's terminal).
          ;;    A non-nil arg makes it always create a fresh instance.
          (save-window-excursion
            (with-current-buffer (ghostel t)
              (rename-buffer buf-name t)))
          (setq buf (get-buffer buf-name)))
        ;; -> The `display-buffer-alist' rule below ("^\\*ghostel", in
        ;;    direction right, reuse window) hands a NEW terminal the window
        ;;    the first one already occupies, so C-u s-9 silently swapped
        ;;    the buffers instead of adding a second pane. With a prefix
        ;;    arg and a visible terminal, split that window ourselves.
        (let ((term-win (and arg
                             (seq-find (lambda (w)
                                         (string-prefix-p "*ghostel" (buffer-name (window-buffer w))))
                                       (window-list)))))
          (if term-win
              (let ((new-win (split-window term-win nil 'right)))
                (set-window-buffer new-win buf)
                (set-window-dedicated-p new-win t)
                (select-window new-win))
            (pop-to-buffer buf))))))

  ;; ===========================================================================
  ;; KEYBINDINGS
  ;; ===========================================================================
  ;;
  ;; PASTE ROUTING — why `cua-paste' is REMAPPED instead of `C-v' rebound:
  ;; CUA installs its keys (C-v = `cua-paste') through Emacs's EMULATION
  ;; keymap layer, which outranks every minor- and major-mode map. A plain
  ;; ("C-v" . ghostel-yank) here can therefore NEVER fire — C-v always
  ;; resolved to `cua-paste', which yanked into the BUFFER instead of
  ;; sending to the shell process. Command remapping, however, is consulted
  ;; across all active keymaps AFTER the key resolves to a command, so
  ;; remapping `cua-paste' wins where shadowing the key lost.
  ;; -> The target is ghostel's own `ghostel-yank' (this config used to
  ;;    ship its own paste command, which wrapped EVERY paste in bracketed
  ;;    paste escapes; `ghostel-yank' only does so when the running program
  ;;    enabled bracketed paste — fish, the Claude TUI and modern REPLs
  ;;    do — so multi-line pastes still arrive as ONE block there and a
  ;;    program that didn't enable it never sees raw escape codes).
  ;; -> ghostel already remaps `yank' to `ghostel-yank' in its semi-char,
  ;;    char and read-only maps, which covers `C-y' and macOS Cmd-V (`s-v'
  ;;    is globally `yank' in the NS port); the explicit `s-v' below only
  ;;    makes the binding visible to `C-h k' and which-key.
  ;; -> `ghostel-mode-map' is the parent of the semi-char and read-only
  ;;    maps. The char-mode map (Claude Code IDE sessions run in char mode
  ;;    for TUI fidelity) has NO parent, so it gets the `cua-paste' remap
  ;;    separately; Cmd-V there already works through ghostel's own remap.
  :bind ((:map ghostel-mode-map
               ("M-k" . jmc-ghostel-force-kill)
               ("s-v" . ghostel-yank)
               ([remap cua-paste] . ghostel-yank))
         (:map ghostel-semi-char-mode-map
               ;; Bound here too so the shell can't swallow these keys
               ;; while the active-typing mode's map has precedence.
               ("M-k" . jmc-ghostel-force-kill))
         (:map ghostel-char-mode-map
               ([remap cua-paste] . ghostel-yank)))

  :config
  ;; --- Directory & File Integration ---
  ;; Whitelist Emacs functions the shell can call through ghostel's OSC
  ;; "eval" hook. The shape is (("name-sent-by-the-shell" FUNCTION) ...):
  ;; ghostel looks the string up with `assoc', so a bare list of symbols
  ;; (what this used to be) made every call fail as "unknown eval command".
  ;; Added on top of the defaults (`find-file-other-window',
  ;; `dired-other-window', ...), not replacing them.
  (add-to-list 'ghostel-eval-cmds '("ediff-files" ediff-files))

  ;; --- Window Placement Rules ---
  ;; A ghostel buffer pops up in a new window on the RIGHT, half the frame
  ;; wide. Only `window-width' applies to a sideways split — a
  ;; `window-height' entry here would be inert. (ai.el's claude-code-ide
  ;; window is a right side window too, sized in columns.)
  (add-to-list 'display-buffer-alist
               '("^\\*ghostel"
                 (display-buffer-reuse-window display-buffer-in-direction)
                 (direction . right)
                 (dedicated . t)
                 (reusable-frames . visible)
                 (window-width . 0.5)))

  ;; Make URLs and file paths inside the terminal clickable.
  (add-hook 'ghostel-mode-hook #'goto-address-mode))

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
