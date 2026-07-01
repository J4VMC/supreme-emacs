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
(declare-function project-root "project")
(declare-function project-current "project")
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
    "Send the current clipboard/kill-ring text directly to the Ghostel process."
    (interactive)
    (let ((proc (get-buffer-process (current-buffer)))
          (text (current-kill 0 t)))
      (if proc
          (process-send-string proc text)
        (error "No active process found for this Ghostel buffer"))))
  
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
    "Find the project root using Project.el, Projectile, or Git."
    (or
     (when (fboundp 'project-root)
       (when-let* ((project (project-current nil)))
         (project-root project)))
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

  :bind (:map ghostel-mode-map
              ;; Bind to standard mode
              ("M-k" . jmc-ghostel-force-kill)
	      ("C-v" . jmc-ghostel-paste)
              ("C-y" . jmc-ghostel-paste))
  (:map ghostel-semi-char-mode-map
        ;; Bind to the active typing mode to prevent the shell from swallowing it
        ("M-k" . jmc-ghostel-force-kill))
  
  :config
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
