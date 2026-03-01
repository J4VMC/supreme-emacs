;;; init.el --- Main initialization file -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; Welcome to the main `init.el` file!
;;
;; This is the central nervous system of our Emacs configuration.
;; It is loaded immediately *after* `early-init.el`.
;;
;; Its primary responsibilities are:
;; 1. Bootstrapping our package manager (Elpaca).
;; 2. Loading your custom, modular configuration files from the `modules/` directory.
;; 3. Applying final, global configuration options.
;;
;; Note on `lexical-binding: t` (line 1):
;; This tells Emacs to use lexical scoping (standard in modern programming languages)
;; instead of dynamic scoping, making variables safer and more predictable.
;;
;;; Code:

;; =============================================================================
;; COMPILER DECLARATIONS (SILENCE WARNINGS)
;; =============================================================================
;; These tell the byte-compiler that these variables and functions will be
;; available at runtime, preventing "free variable" and "unknown function" warnings.

(defvar native-comp-driver-options)
(defvar native-comp-async-report-warnings-errors)
(defvar dired-use-ls-dired)
(defvar elpaca-use-package)
(defvar use-package-verbose)
(defvar gcmh-high-cons-threshold)
(defvar gcmh-idle-delay)
(defvar warning-suppress-log-types)

(declare-function server-running-p "server")
(declare-function server-start "server")
(declare-function elpaca-generate-autoloads "elpaca")
(declare-function elpaca-process-queues "elpaca")
(declare-function elpaca "elpaca" (&rest args))
(declare-function elpaca-use-package-mode "elpaca-use-package")
(declare-function no-littering-expand-var-file-name "no-littering")
(declare-function elpaca-update-all "elpaca")

;; =============================================================================
;; STARTUP HOOKS
;; =============================================================================

(defun jmc/report-startup-time ()
  "Report the total startup time to the echo area."
  (message "Startup took %.2f seconds"
           (float-time (time-subtract after-init-time before-init-time))))

(add-hook 'emacs-startup-hook #'jmc/report-startup-time)

;; =============================================================================
;; NATIVE COMPILATION (macOS FIX)
;; =============================================================================

;; Fix for "error invoking gcc driver" on macOS.
(when (and (eq system-type 'darwin) (functionp 'native-comp-available-p))
  (let ((gcc-path (executable-find "gcc")))
    ;; 1. Ensure gcc is found AND it's NOT Apple's default clang wrapper
    (when (and gcc-path (not (string-equal gcc-path "/usr/bin/gcc")))
      ;; 2. Point libgccjit to this driver using the -B flag
      (setq native-comp-driver-options (list (concat "-B" (file-name-directory gcc-path))))
      ;; 3. Ensure the directory is in exec-path
      (add-to-list 'exec-path (file-name-directory gcc-path)))))

;; Silence asynchronous native compilation warnings.
(setq native-comp-async-report-warnings-errors 'silent)

;; =============================================================================
;; EMACS SERVER
;; =============================================================================

;; Start the Emacs daemon/server if it isn't already running.
;; -> This allows you to open files in this *existing* session from the terminal
;;    using `emacsclient -c` or `emacsclient -t`. It is instantly fast compared
;;    to starting a cold Emacs process every time.

(add-hook 'after-init-hook
          (lambda ()
            (require 'server)
            (unless (server-running-p)
              (server-start))))

;; =============================================================================
;; DIRED (FILE MANAGER) CONFIGURATION
;; =============================================================================
;;
;; Settings for Dired, the built-in Emacs file manager.

;; Use `gls` (GNU ls, from coreutils) if available.
;; -> Commonly installed via Homebrew on macOS. It provides features like
;;    `--group-directories-first` which the default macOS/BSD `ls` lacks.
(setq insert-directory-program (executable-find "gls"))

;; Allow Dired to parse custom `ls` program switches.
(setq dired-use-ls-dired t)

;; Configure directory listing flags:
;; -a: Show all files (including hidden dotfiles).
;; -l: Use long listing format (permissions, owner, size, etc.).
;; -h: Show human-readable file sizes (e.g., "5.0K", "1.2M").
;; --group-directories-first: List all folders before files.
(setq dired-listing-switches "-alh --group-directories-first")

;; =============================================================================
;; WARNING SUPPRESSION
;; =============================================================================

;; Suppress specific warnings from the `elpaca` package.
;; -> Helps keep the *Messages* buffer clean during startup.
(setq warning-suppress-log-types '((elpaca)))

;; =============================================================================
;; PACKAGE MANAGEMENT (ELPACA BOOTSTRAP)
;; =============================================================================
;;
;; This is the standard bootstrap boilerplate for Elpaca, our package manager.
;; It is responsible for downloading and installing Elpaca automatically on the
;; first run. Generally, this block does not need to be modified.

(defvar elpaca-installer-version 0.11)
(defvar elpaca-directory (expand-file-name "elpaca/" user-emacs-directory))
(defvar elpaca-builds-directory (expand-file-name "builds/" elpaca-directory))
(defvar elpaca-repos-directory (expand-file-name "repos/" elpaca-directory))

(defvar elpaca-order '(elpaca :repo "https://github.com/progfolio/elpaca.git"
                              :ref nil :depth 1 :inherit ignore
                              :files (:defaults "elpaca-test.el")
                              :build (:not elpaca--activate-package)))

(let* ((repo  (expand-file-name "elpaca/" elpaca-repos-directory))
       (build (expand-file-name "elpaca/" elpaca-builds-directory))
       (order (cdr elpaca-order))
       (default-directory repo))
  (add-to-list 'load-path (if (file-exists-p build) build repo))
  (unless (file-exists-p repo)
    (make-directory repo t)
    (when (<= emacs-major-version 28) (require 'subr-x))
    (condition-case-unless-debug err
        (if-let* ((buffer (pop-to-buffer-same-window "*elpaca-bootstrap*"))
                  ((zerop (apply #'call-process `("git" nil ,buffer t "clone"
                                                  ,@(when-let* ((depth (plist-get order :depth)))
                                                      (list (format "--depth=%d" depth) "--no-single-branch"))
                                                  ,(plist-get order :repo) ,repo))))
                  ((zerop (call-process "git" nil buffer t "checkout"
                                        (or (plist-get order :ref) "--"))))
                  (emacs (concat invocation-directory invocation-name))
                  ((zerop (call-process emacs nil buffer nil "-Q" "-L" "." "--batch"
                                        "--eval" "(byte-recompile-directory \".\" 0 'force)")))
                  ((require 'elpaca))
                  ((elpaca-generate-autoloads "elpaca" repo)))
            (progn (message "%s" (buffer-string)) (kill-buffer buffer))
          (error "%s" (with-current-buffer buffer (buffer-string))))
      ((error) (warn "%s" err) (delete-directory repo 'recursive))))
  (unless (require 'elpaca-autoloads nil t)
    (require 'elpaca)
    (elpaca-generate-autoloads "elpaca" repo)
    (let ((load-source-file-function nil))
      (unless (featurep 'elpaca-autoloads) ;; Only load if not already present
        (load (expand-file-name "elpaca-autoloads" elpaca-directory) t t)))))

;; Tell Elpaca to process any pending package operations (installs, etc.)
;; *after* Emacs has finished initializing.
(add-hook 'after-init-hook #'elpaca-process-queues)

;; Tell Elpaca to install *itself* using the recipe defined above.
(elpaca `(,@elpaca-order))

;; =============================================================================
;; USE-PACKAGE CONFIGURATION
;; =============================================================================
;;
;; `use-package` is a macro that dramatically simplifies package configuration.
;; We rely on it heavily for a clean, readable setup.

;; Install the Elpaca-aware version of `use-package`.
(elpaca elpaca-use-package
  ;; Enable support so `use-package :ensure t` routes through Elpaca automatically.
  (elpaca-use-package-mode))

;; Enable verbose logging for `use-package`.
;; -> Extremely helpful for debugging package load times and errors.
(setq use-package-verbose t)

;; =============================================================================
;; NO LITTERING CONFIGURATION
;; =============================================================================

(use-package no-littering
  :ensure t
  :config
  ;; Keep auto-save files out of the project directories
  (setq auto-save-file-name-transforms
        `((".*" ,(no-littering-expand-var-file-name "auto-save/") t))))

;; =============================================================================
;; SHELL ENVIRONMENT
;; =============================================================================
;;
;; Ensures Emacs inherits environment variables (like $PATH) from your shell.
;; Without this, GUI Emacs on macOS often fails to find CLI tools (git, rg, python).

(use-package exec-path-from-shell
  :ensure t
  :demand t ;; Load immediately (do not lazy-load).
  :init
  ;; Define which variables to import from the shell.
  (setq exec-path-from-shell-arguments '("-l"))
  (setq exec-path-from-shell-variables '("PATH" "MANPATH" "VIRTUAL_ENV" "PYTHONPATH" "LEFTHOOK_CONFIG"))
  :config
  ;; Apply the variables only in graphical Emacs.
  ;; -> Terminal Emacs (`emacs -nw`) inherits the correct environment automatically.
  (run-with-idle-timer 1.0 nil (lambda ()
				 (when (memq window-system '(mac ns x))
				   (exec-path-from-shell-initialize)))))

;; =============================================================================
;; CORE PACKAGES & UI
;; =============================================================================

;; Install `transient`, a required dependency for complex pop-up menus (e.g., Magit).
(use-package transient
  :ensure t)

;; `diminish` hides or shortens minor mode names in the mode-line (status bar)
;; to reduce visual clutter.
(use-package diminish
  :ensure t
  :config
  ;; Example: Hide 'Eldoc Mode' since it is almost always active.
  (diminish 'eldoc-mode))

;; Install and apply the Gruvbox theme.
(use-package gruvbox-theme
  :ensure t
  :init
  ;; Load the theme during the `:init` phase (before the package fully loads).
  ;; -> Prevents the default UI from flashing before the theme applies.
  (load-theme 'gruvbox-dark-hard t))

;; =============================================================================
;; CUSTOMIZATION FILE
;; =============================================================================

;; Route automatically generated settings (from `M-x customize`) to a separate file.
;; -> Keeps this `init.el` clean and purely handwritten.
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))

;; Load the custom file if it exists.
;; -> `noerror` prevents failures on a fresh install where the file doesn't exist yet.
(load custom-file 'noerror)

;; =============================================================================
;; MODULAR CONFIGURATION
;; =============================================================================
;;
;; Instead of a single monolithic file, we split our configuration into focused
;; modules inside the `modules/` directory.

;; 1. Add the `modules/` directory to Emacs's load path.
;; -> `eval-when-compile` ensures this is available during byte-compilation.
(eval-when-compile
  (add-to-list 'load-path (expand-file-name "modules" user-emacs-directory)))

;; 2. Load the modules in logical order.
;; -> Each module must end with a corresponding `(provide 'module-name)`.

(require 'interface)   ; UI customizations (dashboard, mode-line)
(require 'editor)      ; General editing (line numbers, matching parens)
(require 'completion)  ; Completion frameworks (Vertico, Company)

(require 'explorer)    ; File management tools (Dired tweaks)
(require 'terminal)    ; Built-in terminals (vterm, eshell)
(require 'tree)        ; Tree-sitter (advanced syntax highlighting)
(require 'languages)   ; Language-specific major modes
(require 'dev)         ; Development tools (Magit, Docker)
(require 'lsp)         ; Language Server Protocol clients
(require 'docs)        ; Offline documentation tools
(require 'debug)       ; Debugging tools (DAP-mode)
(require 'projects)    ; Project management (Projectile, Treemacs)
(require 'web)         ; Web development configuration

;; =============================================================================
;; FINAL PERFORMANCE TWEAKS
;; =============================================================================

;; We use Garbage Collection Magic Hack to improve the garbage collection.
(use-package gcmh
  :ensure t
  :hook (emacs-startup . gcmh-mode)
  :config
  ;; Set the "typing" threshold to a high number (e.g., 100MB)
  (setq gcmh-high-cons-threshold (* 100 1024 1024))
  ;; Trigger cleanup after 2 seconds of inactivity
  (setq gcmh-idle-delay 2.0))

;; =============================================================================
;; AUTOMATIC DAILY ELPACA UPDATE
;; =============================================================================
;;
;; Runs `elpaca-update-all` silently in the background once per day.
;; State is persisted using a timestamp file to avoid redundant updates.

(defvar jmc-elpaca--timestamp-file
  (expand-file-name "elpaca-last-update.txt" user-emacs-directory)
  "File path to store the date of the last Elpaca update.")

(defun jmc-elpaca--read-update-date ()
  "Read the date string from the timestamp file.
Return nil if file is missing or unreadable."
  ;; -> Wraps file access in condition-case to gracefully handle I/O errors.
  (condition-case nil
      (when (file-exists-p jmc-elpaca--timestamp-file)
        (with-temp-buffer
          (insert-file-contents jmc-elpaca--timestamp-file)
          (string-trim (buffer-string))))
    (error nil)))

(defun jmc-elpaca--save-update-date ()
  "Write today's date to the timestamp file."
  (with-temp-buffer
    (insert (format-time-string "%Y-%m-%d"))
    ;; -> Write silently to prevent spamming the echo area.
    (write-region (point-min) (point-max) jmc-elpaca--timestamp-file nil 'silent)))

(defun jmc-elpaca-auto-update ()
  "Run `elpaca-update-all` safely and silently."
  (message "Checking for package updates...")
  (dlet ((elpaca-log-functions nil))
    (condition-case err
        (progn
          (elpaca-update-all)
          (message "Packages updated successfully."))
      (error
       (message "Automatic daily package update failed — %s" (error-message-string err))))))

(defun jmc-elpaca-daily-update-h ()
  "Check today's date against the saved file and run update if needed."
  (let ((current-date (format-time-string "%Y-%m-%d"))
        (last-update-date (jmc-elpaca--read-update-date)))

    (if (string= current-date last-update-date)
        ;; If dates match, do nothing (or log a quiet message).
        (message "Skipping Elpaca update (already updated today: %s)" last-update-date)

      ;; If dates don't match (or file is missing/nil), proceed with update.
      (message "Running daily package update in the background...")
      (jmc-elpaca-auto-update)
      
      ;; Save the new date to the file immediately.
      (jmc-elpaca--save-update-date))))

;; Schedule the update check to run 30 seconds after Elpaca finishes initializing.
;; -> This prevents the update process from slowing down your initial startup.
(add-hook 'elpaca-after-init-hook
          (lambda ()
            (run-with-idle-timer 60 nil #'jmc-elpaca-daily-update-h)))

;;; init.el ends here
