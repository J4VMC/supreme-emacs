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
(defvar use-package-always-ensure)
(defvar gcmh-high-cons-threshold)
(defvar gcmh-idle-delay)
(defvar warning-suppress-log-types)
(defvar elpaca-lock-file)

(declare-function server-running-p "server")
(declare-function server-start "server")
(declare-function elpaca-generate-autoloads "elpaca")
(declare-function elpaca-process-queues "elpaca")
(declare-function elpaca "elpaca" (&rest args))
(declare-function elpaca-wait "elpaca")
(declare-function elpaca-use-package-mode "elpaca-use-package")
(declare-function no-littering-expand-var-file-name "no-littering")
(declare-function elpaca-update-all "elpaca")
(declare-function elpaca-write-lock-file "elpaca")

;; =============================================================================
;; STARTUP HOOKS
;; =============================================================================

(defun jmc/report-startup-time ()
  "Report the total startup time to the echo area."
  (message "Startup took %.2f seconds"
           (float-time (time-subtract after-init-time before-init-time))))

(add-hook 'emacs-startup-hook #'jmc/report-startup-time)

;; =============================================================================
;; HOMEBREW PATH BOOTSTRAP (macOS)
;; =============================================================================
;;
;; GUI Emacs launched from the Dock/Finder starts with a bare PATH
;; ("/usr/bin:/bin:..."), and our full environment import via
;; `exec-path-from-shell` is deliberately deferred behind an idle timer for
;; startup speed. Anything in this file that calls `executable-find` at load
;; time (gls, gcc) would therefore silently fail to find Homebrew binaries.
;;
;; -> The Homebrew prefix depends on the CPU architecture:
;;    * Apple silicon: /opt/homebrew
;;    * Intel:         /usr/local
;;
;; We detect which one exists and prepend its bin/ directory immediately, so
;; load-time lookups work. The idle-timer import later fills in everything
;; else (nvm-managed node, composer, go, etc.).

(when (eq system-type 'darwin)
  (let* ((brew-prefix (if (file-directory-p "/opt/homebrew")
                          "/opt/homebrew"   ; Apple silicon
                        "/usr/local"))      ; Intel
         (brew-bin (expand-file-name "bin" brew-prefix)))
    (when (file-directory-p brew-bin)
      (add-to-list 'exec-path brew-bin)
      (setenv "PATH" (concat brew-bin ":" (getenv "PATH"))))))

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
              (server-start))
            ;; Exit without the "This Emacs session has clients; exit
            ;; anyway?" question. Connected emacsclient sessions are simply
            ;; disconnected (their terminals just return) — a fair trade for
            ;; a quit that never silently blocks. Delete this line to
            ;; restore the safety prompt.
            (remove-hook 'kill-emacs-query-functions
                         #'server-kill-emacs-query-function)))

;; =============================================================================
;; DIRED (FILE MANAGER) CONFIGURATION
;; =============================================================================
;;
;; Settings for Dired, the built-in Emacs file manager.

;; Use `gls` (GNU ls, from coreutils) if available.
;; -> Installed via Homebrew on macOS; found thanks to the PATH bootstrap above.
;; -> It provides features like `--group-directories-first` which the default
;;    macOS/BSD `ls` lacks.
;;
;; IMPORTANT: only enable the GNU-specific switches when gls actually exists.
;; -> Previously the switches were set unconditionally; on a machine (or Dock
;;    launch) where gls wasn't visible, BSD ls choked on
;;    `--group-directories-first` and broke every Dired buffer.
(if-let* ((gls (executable-find "gls")))
    (setq insert-directory-program gls
          dired-use-ls-dired t
          ;; -a: all files (dotfiles). -l: long format. -h: human-readable sizes.
          ;; --group-directories-first: folders before files.
          dired-listing-switches "-alh --group-directories-first")
  ;; Fallback: BSD ls understands only the portable flags.
  (setq dired-use-ls-dired nil
        dired-listing-switches "-alh"))

;; =============================================================================
;; WARNING SUPPRESSION
;; =============================================================================

;; Suppress warnings from the `elpaca` package.
;; -> Use `add-to-list` instead of `setq` so we EXTEND the suppression list
;;    from early-init.el ('(comp) and '(bytecomp)) rather than clobber it.
;;    Overwriting it here silently re-enabled native-comp warning spam.
(add-to-list 'warning-suppress-log-types '(elpaca))

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

;; --- Lock file (reproducible package set) -----------------------------------
;; Many packages here track GitHub HEAD (`:ref nil`), so without pinning,
;; every machine (and every update) gets whatever upstream happens to be at
;; that moment. When the lock file exists, Elpaca uses it as its first menu:
;; installs and updates resolve to the EXACT refs recorded in it.
;;
;; Workflow:
;;   * `M-x jmc-elpaca-write-lock`      -> snapshot the current, working
;;     package set into the lock file (COMMIT it to the repo).
;;   * `M-x jmc-elpaca-update-unlocked` -> deliberately pull new upstream
;;     refs (ignores the lock for this session); test, then re-write the
;;     lock file.
;; The automatic weekly update below is SKIPPED while a lock file exists —
;; updating against pinned refs is a no-op, and unpinned drift is exactly
;; what the lock prevents.
(defvar jmc-elpaca-lock-file (expand-file-name "elpaca.lock" user-emacs-directory)
  "Where the Elpaca lock file lives. Tracked in git, unlike elpaca/*.")

(when (file-exists-p jmc-elpaca-lock-file)
  (setq elpaca-lock-file jmc-elpaca-lock-file))

(defun jmc-elpaca-write-lock ()
  "Snapshot the current package state into `jmc-elpaca-lock-file'."
  (interactive)
  (elpaca-write-lock-file jmc-elpaca-lock-file)
  (message "Elpaca lock file written to %s — commit it." jmc-elpaca-lock-file))

(defun jmc-elpaca-update-unlocked ()
  "Run `elpaca-update-all' ignoring the lock file for this session.
After updating and verifying everything works, run
`jmc-elpaca-write-lock' to pin the new state."
  (interactive)
  (setq elpaca-lock-file nil)
  (elpaca-update-all))

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
  ;; Enable support so `use-package` routes through Elpaca automatically.
  (elpaca-use-package-mode))

;; Block until `elpaca-use-package-mode` is actually active.
;; -> `elpaca` queues its body asynchronously. Without this wait, `use-package`
;;    forms evaluated below could expand BEFORE the Elpaca integration exists,
;;    silently skipping installation. This is the upstream-recommended pattern.
(elpaca-wait)

;; Treat EVERY `use-package` block as `:ensure t` by default.
;; -> Packages must now explicitly opt out with `:ensure nil` (reserved for
;;    Emacs built-ins like dired, savehist, elec-pair, treesit, python...).
;; -> This fixes packages that were silently never installed because their
;;    block forgot `:ensure t` (e.g. `visual-replace`, `sbt-mode`).
(setq use-package-always-ensure t)

;; Enable verbose logging for `use-package`.
;; -> Extremely helpful for debugging package load times and errors.
(setq use-package-verbose t)

;; =============================================================================
;; COMPAT (FORWARD-COMPATIBILITY LIBRARY)
;; =============================================================================
;; Declared explicitly, FIRST among packages, and waited on — for two reasons:
;;
;; 1. Emacs 30 advertises a builtin `compat' (version 30.x) in
;;    `package--builtin-versions', so Elpaca treats every package's compat
;;    dependency as already satisfied and never installs the real GNU ELPA
;;    package. That broke jinx (editor.el), which requires compat >= 31 —
;;    a version the builtin stub can never satisfy.
;;
;; 2. It must be declared BEFORE no-littering: no-littering.el does
;;    `(require 'compat)` at load time, so if compat's explicit order came
;;    later, the feature would already be in `features' when Elpaca
;;    activates it — the "compat loaded before Elpaca activation" warning
;;    on every startup. Same reasoning for every other compat dependent
;;    (consult, magit, forge, jinx...): explicit order first, loads later.
(use-package compat
  :defer t)
(elpaca-wait)

;; =============================================================================
;; NO LITTERING CONFIGURATION
;; =============================================================================

(use-package no-littering
  :config
  ;; Keep auto-save files out of the project directories
  (setq auto-save-file-name-transforms
        `((".*" ,(no-littering-expand-var-file-name "auto-save/") t))))

;; Block until Elpaca finishes installing/activating `no-littering`.
;; -> `no-littering` redirects `recentf-save-file`, `savehist-file`, etc. to
;;    `var/` as a side effect of loading, but Elpaca installs packages
;;    asynchronously. Without this wait, later modules (e.g. `editor`)
;;    can enable `recentf-mode`/`savehist-mode` before the redirect happens,
;;    which makes them read/write the default (wrong) location and silently
;;    lose history, since these modes refuse to re-initialize once enabled.
(elpaca-wait)

;; =============================================================================
;; SHELL ENVIRONMENT
;; =============================================================================
;;
;; Ensures Emacs inherits environment variables (like $PATH) from your shell
;; (fish). Without this, GUI Emacs on macOS fails to find CLI tools installed
;; via nvm.fish, composer, go, etc.
;;
;; NOTE: this import is deferred behind an idle timer for startup speed.
;; Load-time lookups in THIS file must not depend on it — that's what the
;; "Homebrew PATH bootstrap" section near the top is for.

(use-package exec-path-from-shell
  :demand t ;; Load immediately (do not lazy-load).
  :init
  ;; `-l` runs fish as a login shell, so config.fish (and universal
  ;; `fish_user_paths`) are applied.
  (setq exec-path-from-shell-arguments '("-l"))
  (setq exec-path-from-shell-variables '("PATH" "MANPATH" "VIRTUAL_ENV" "PYTHONPATH" "LEFTHOOK_CONFIG" "JAVA_HOME"))
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
(use-package transient)

;; `diminish` hides or shortens minor mode names in the mode-line (status bar)
;; to reduce visual clutter.
(use-package diminish
  :config
  ;; Example: Hide 'Eldoc Mode' since it is almost always active.
  (diminish 'eldoc-mode)
  (diminish 'visual-line-mode)   ; " Wrap"
  (diminish 'auto-revert-mode)   ; " ARev"
  (diminish 'cua-mode))          ; " CUA"

;; Install and apply the Gruvbox theme.
(use-package gruvbox-theme
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
;; -> `eval-and-compile` runs this BOTH at compile time (so the byte-compiler
;;    can find the modules) AND at load time. The previous `eval-when-compile`
;;    only worked because init.el is loaded uncompiled — had it ever been
;;    byte-compiled, the load-path entry would have vanished at runtime and
;;    every `require` below would fail.
(eval-and-compile
  (add-to-list 'load-path (expand-file-name "modules" user-emacs-directory)))

;; 2. Load the modules in logical order.
;; -> Each module must end with a corresponding `(provide 'module-name)`.

(require 'editor)      ; General editing (line numbers, matching parens)
(require 'interface)   ; UI customizations (dashboard, mode-line)
(require 'completion)  ; Completion frameworks (Vertico, Corfu)

(require 'explorer)    ; File management tools (Dired tweaks)
(require 'terminal)    ; Built-in terminals (ghostel)
(require 'tree)        ; Tree-sitter (advanced syntax highlighting)
(require 'languages)   ; Language-specific major modes
(require 'dev)         ; Development tools (Magit, Docker)
(require 'ai)          ; Agentic AI coding (claude-code-ide composer flow)
(require 'lang-server) ; Language Server Protocol clients (renamed from lsp.el:
					; lsp-mode ships its own lsp.el, which a module named
					; `lsp' would shadow on the load-path)
(require 'docs)        ; Offline documentation tools
(require 'debugger)    ; Debugging tools (dape)
(require 'projects)    ; Project management (Projectile, Treemacs)
(require 'web)         ; Web development configuration

;; =============================================================================
;; PER-PROJECT ENVIRONMENTS (DIRENV / .envrc)
;; =============================================================================
;;
;; envrc.el applies each project's `.envrc` BUFFER-LOCALLY: every buffer in
;; the project gets its own `process-environment` and `exec-path`, so LSP
;; servers, flycheck checkers, apheleia formatters, and dape adapters all
;; launch with that project's environment (project-local tool versions,
;; DATABASE_URL, nix shells, ...). This is deliberately buffer-local —
;; unlike direnv.el, which mutates the GLOBAL environment on every buffer
;; switch and leaks env between projects.
;;
;; Requirements:
;; * The `direnv` binary: `brew install direnv` (found via the Homebrew
;;   bootstrap above regardless of Apple silicon vs Intel prefix).
;; * ghostel/fish terminals don't need envrc.el — direnv is handled by the
;;   shell hook there: add `direnv hook fish | source` to config.fish.
;;
;; IMPORTANT: enabled here, AFTER all modules, on purpose (per upstream
;; docs). envrc works by adding itself to mode/file hooks and must run
;; BEFORE hooks like `lsp-deferred` so servers start with the project
;; environment; enabling the global mode as late as possible places its
;; hook functions at the front of the chain.
;;
;; `:demand t` is required alongside `:bind` here — the keymap binding
;; would otherwise defer the package forever, and the global mode in
;; `:config` would never activate.
(use-package envrc
  :demand t
  :bind (:map envrc-mode-map
              ;; e.g. `C-c e r` = envrc-reload, `C-c e a` = envrc-allow.
              ("C-c e" . envrc-command-map))
  :config
  (envrc-global-mode 1)

  ;; --- Propagate project environments into agent/terminal processes -------
  ;; envrc keeps each project's environment BUFFER-LOCAL. Terminal-style
  ;; major modes, however, often spawn their process inside the mode body —
  ;; BEFORE the globalized envrc hook fires on the fresh buffer — so a
  ;; Claude session or ghostel drawer could launch with the global
  ;; (credential-less) environment despite the buffer acquiring the right
  ;; env an instant later. `inheritenv-add-advice' (inheritenv ships with
  ;; envrc) closes that race: the advised commands, and every process they
  ;; create, run with the environment of the buffer they were INVOKED from.
  ;; -> Net effect: start an agent from a client-A buffer, it carries
  ;;    exactly client A's .envrc credentials; from client B, exactly B's.
  (require 'inheritenv)
  (with-eval-after-load 'claude-code
    (inheritenv-add-advice 'claude-code)
    (inheritenv-add-advice 'claude-code-start-in-directory))
  (with-eval-after-load 'claude-code-ide
    (inheritenv-add-advice 'claude-code-ide)
    (inheritenv-add-advice 'claude-code-ide-continue)
    (inheritenv-add-advice 'claude-code-ide-resume))
  ;; Same treatment for the ACP agents (ai.el): a Gemini session started
  ;; from a project buffer carries that project's .envrc — which is also
  ;; how a per-project GEMINI_API_KEY reaches the gemini process.
  (with-eval-after-load 'agent-shell
    (inheritenv-add-advice 'agent-shell-google-start-gemini))
  (when (fboundp 'jmc-ghostel-toggle)
    (inheritenv-add-advice 'jmc-ghostel-toggle)))

;; =============================================================================
;; FINAL PERFORMANCE TWEAKS
;; =============================================================================

;; We use Garbage Collection Magic Hack to improve the garbage collection.
;;
;; NOTE: gcmh OWNS the `gc-cons-threshold` lifecycle from here on. It keeps
;; the threshold high while you type and drops it to a low value on idle.
;; -> The old `emacs-startup-hook` that manually reset the threshold to 800KB
;;    has been REMOVED: it ran after gcmh started and fought its strategy,
;;    forcing GC pauses during activity that gcmh exists to prevent.
(use-package gcmh
  :hook (emacs-startup . gcmh-mode)
  :diminish gcmh-mode
  :config
  ;; Set the "typing" threshold to a high number (e.g., 100MB)
  (setq gcmh-high-cons-threshold (* 100 1024 1024))
  ;; Trigger cleanup after 2 seconds of inactivity
  (setq gcmh-idle-delay 2.0))

;; =============================================================================
;; AUTOMATIC PERIODIC ELPACA UPDATE
;; =============================================================================
;;
;; Runs `elpaca-update-all` in the background once per update interval.
;; State is persisted using a timestamp file to avoid redundant updates.
;;
;; NOTE: many packages here track the HEAD of GitHub repos (`:ref nil`), so
;; every update is a small breakage lottery — which is why the interval is
;; WEEKLY (it used to be daily), and why the whole mechanism is disabled
;; once a lock file exists (see the lock-file section above): with pinned
;; refs, updates are a deliberate `jmc-elpaca-update-unlocked' action.

(defvar jmc-elpaca-update-interval-days 7
  "Minimum number of days between automatic `elpaca-update-all' runs.")

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

(defun jmc-elpaca--days-since-update ()
  "Return the number of days since the last recorded update.
Return nil when no valid timestamp exists (forcing an update)."
  (when-let* ((last (jmc-elpaca--read-update-date)))
    (condition-case nil
        (/ (float-time (time-subtract (current-time)
                                      (date-to-time (concat last " 00:00:00"))))
           86400)
      (error nil))))

(defun jmc-elpaca-auto-update ()
  "Kick off `elpaca-update-all' safely in the background.
Elpaca updates are ASYNCHRONOUS: this function returning does not mean the
update succeeded, only that it started. Inspect `elpaca-log' for results."
  (message "Updating packages in the background — see M-x elpaca-log for results...")
  (let ((elpaca-log-functions nil))
    (condition-case err
        (elpaca-update-all)
      (error
       (message "Automatic package update failed to start — %s"
                (error-message-string err))))))

(defun jmc-elpaca-daily-update-h ()
  "Run an update when at least `jmc-elpaca-update-interval-days' have passed.
Does nothing while a lock file is active: pinned refs make automatic
updates pointless — use `jmc-elpaca-update-unlocked' deliberately."
  (cond
   ((and (boundp 'elpaca-lock-file) elpaca-lock-file)
    (message "Elpaca lock file active — automatic updates disabled (use M-x jmc-elpaca-update-unlocked)"))
   (t
    (let ((days-since (jmc-elpaca--days-since-update)))
      (if (and days-since (< days-since jmc-elpaca-update-interval-days))
          (message "Skipping Elpaca update (last update: %s)"
                   (jmc-elpaca--read-update-date))
        (jmc-elpaca-auto-update)
        ;; Save the new date immediately.
        (jmc-elpaca--save-update-date))))))

;; Schedule the update check to run 60 seconds of idle time after Elpaca
;; finishes initializing, so it never slows down the initial startup.
(add-hook 'elpaca-after-init-hook
          (lambda ()
            (run-with-idle-timer 60 nil #'jmc-elpaca-daily-update-h)))

;;; init.el ends here
