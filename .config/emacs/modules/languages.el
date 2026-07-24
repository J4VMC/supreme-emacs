;;; languages.el --- Language-specific configurations -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; This file defines "Major Modes" for programming and markup languages.
;;
;; ### What is a Major Mode?
;; A Major Mode is a collection of settings specific to a single language.
;; It provides:
;; * **Syntax Highlighting**: Colors for keywords, strings, and variables.
;; * **Indentation**: Smart spacing based on the language's rules.
;; * **Keybindings**: Shortcuts like `C-c C-c` to compile or run the file.
;;
;; ### Tree-sitter (`-ts-mode`)
;; Modes ending in `-ts-mode` utilize **Tree-sitter**, a modern parsing engine.
;; It is faster and provides more accurate highlighting and code-aware
;; navigation compared to traditional regex-based modes.
;;
;; NOTE: only ts-modes that ACTUALLY EXIST are referenced here. A previous
;; revision mapped files to `sql-ts-mode`, `xml-ts-mode`, and `swift-ts-mode`
;; without any package providing them (verified absent from Emacs 30), which
;; made those files error on open.
;;
;; ### Standard Feature Hooks
;; Most languages here use a standard "stack" of features:
;; 1.  `lsp-deferred`: Starts the **Language Server Protocol** client (code
;;     completion, "jump to definition") only when the file is actually visible.
;; 2.  `apheleia-mode`: Enables **Auto-Formatting**. Your code is automatically
;;     tidied (using tools like `prettier` or `black`) every time you save.
;; 3.  `flycheck-mode`: Enables **Real-time Syntax Checking**. Errors are
;;     highlighted with red underlines as you type.
;;
;;; Code:

;; =============================================================================
;; COMPILER DECLARATIONS (SILENCE WARNINGS)
;; =============================================================================

(defvar js-indent-level)
(defvar typescript-ts-mode-indent-offset)
(defvar web-mode-markup-indent-offset)
(defvar web-mode-css-indent-offset)
(defvar web-mode-code-indent-offset)
(defvar python-mode-map)
(defvar python-ts-mode-map)
(defvar rustic-mode-map)
(defvar rustic-format-on-save)
(defvar rustic-lsp-client)
(defvar rustic-use-tree-sitter)
(defvar rustic-flycheck-checker)
(defvar rustic-analyzer-proc-macro-enable)
(defvar rustic-display-inlay-hints)
(defvar rustic-analyzer-display-chaining-hints)
(defvar rustic-analyzer-display-closure-return-type-hints)
(defvar rustic-analyzer-display-lifetime-elision-hints-enable)
(defvar sbt:program-options)
(defvar csv-mode-map)
(defvar markdown-fontify-code-blocks-natively)
(defvar markdown-command)
(defvar markdown-mode-map)

(declare-function projectile-project-root "projectile")
(declare-function pyvenv-activate "pyvenv")
(declare-function pyvenv-mode "pyvenv")
(declare-function python-django-mode "python-django")

;; =============================================================================
;; JAVA
;; =============================================================================

;; NOTE (config-wide): the per-language `flycheck-mode' hook entries that
;; used to appear in every block below were removed — dev.el enables
;; flycheck once via `prog-mode-hook', and every programming mode here
;; derives from prog-mode. Only markdown-mode (text-mode family) keeps
;; its own flycheck hook.

;; `java-ts-mode` is the real built-in feature name.
;; -> The previous `use-package java-mode` referenced a feature that does not
;;    exist (java-mode lives inside cc-mode); it only worked by accident of
;;    deferred loading.
(use-package java-ts-mode
  :ensure nil ; Built-in
  :mode ("\\.java\\'" . java-ts-mode)
  :hook ((java-ts-mode . lsp-deferred)
         (java-ts-mode . apheleia-mode)))

;; =============================================================================
;; PHP
;; =============================================================================

;; Force Emacs to see the Composer Global Binaries
(let ((composer-bin (expand-file-name "~/.config/composer/vendor/bin")))
  (when (file-directory-p composer-bin)
    (add-to-list 'exec-path composer-bin)
    (setenv "PATH" (concat composer-bin ":" (getenv "PATH")))))

;; `php-ts-mode` is BUILT INTO Emacs 30.
;; -> The `php-mode` package previously declared here never loaded: every
;;    extension was mapped to the built-in ts mode, so the package was pure
;;    dead weight (and its :after chains kept composer/phpunit from loading).
;; -> Tip: `M-x php-ts-mode-install-parsers` installs the full grammar set
;;    (php, phpdoc, html, css, js) that embedded-language highlighting needs.
(use-package php-ts-mode
  :ensure nil ; Built-in (Emacs 30+)
  :mode (("\\.php\\'" . php-ts-mode)
         ("\\.phtml\\'" . php-ts-mode)
         ("\\.php[3-7]\\'" . php-ts-mode))
  :hook ((php-ts-mode . lsp-deferred)
         (php-ts-mode . apheleia-mode)))

;; --- PHP Utilities ---

;; Composer: Access PHP's package manager commands directly via M-x.
;; -> `:after php-mode` removed: that feature never loads anymore, so the
;;    dependency would have prevented these from ever activating.
(use-package composer
  :commands (composer-install composer-update composer-require))

;; PHPUnit: Integration for running unit tests within Emacs.
(use-package phpunit
  :commands (phpunit-current-test phpunit-current-class phpunit-current-project))

;; =============================================================================
;; JAVASCRIPT & TYPESCRIPT
;; =============================================================================

;; The ts modes below are BUILT INTO Emacs 29+.
;; -> The old `typescript-mode` package never loaded (nothing mapped to it),
;;    which meant its `:config` — the ONLY place `js-indent-level` was set —
;;    never ran. `js-indent-level` defaults to 4, so js-ts buffers silently
;;    indented with 4 spaces despite the 2-space intent. The variables are
;;    now set unconditionally in `:init`.
(use-package typescript-ts-mode
  :ensure nil ; Built-in
  :mode (("\\.ts\\'" . typescript-ts-mode)
         ("\\.tsx\\'" . tsx-ts-mode)
         ("\\.js\\'" . js-ts-mode)
         ("\\.jsx\\'" . tsx-ts-mode))
  :init
  ;; Standardize 2-space indentation for the entire JS/TS ecosystem.
  (setq typescript-ts-mode-indent-offset 2 ; typescript-ts-mode & tsx-ts-mode
        js-indent-level 2)                 ; js-ts-mode
  :hook ((typescript-ts-mode . lsp-deferred)
         (typescript-ts-mode . apheleia-mode)

         (tsx-ts-mode . lsp-deferred)
         (tsx-ts-mode . apheleia-mode)

         (js-ts-mode . lsp-deferred)
         (js-ts-mode . apheleia-mode)

         ;; Force spaces instead of tabs, and set display width to 2.
         (typescript-ts-mode . (lambda () (setq-local indent-tabs-mode nil tab-width 2)))
         (tsx-ts-mode . (lambda () (setq-local indent-tabs-mode nil tab-width 2)))
         (js-ts-mode . (lambda () (setq-local indent-tabs-mode nil tab-width 2)))))

;; =============================================================================
;; WEB TECHNOLOGIES (HTML, TWIG, SVELTE, VUE)
;; =============================================================================

;; `web-mode` handles files that mix different languages (e.g., HTML + PHP).
;; We also use it as the underlying parsing engine for Svelte and Vue components.

;; 1. Define our custom modes explicitly so Emacs knows they exist.
(define-derived-mode svelte-mode web-mode "Svelte")
(define-derived-mode vue-mode web-mode "Vue")

;; 2. Forcibly route the file extensions to them (bypassing use-package lazy loading).
(add-to-list 'auto-mode-alist '("\\.svelte\\'" . svelte-mode))
(add-to-list 'auto-mode-alist '("\\.vue\\'" . vue-mode))

(use-package web-mode
  :mode (("\\.html?\\'" . web-mode)
         ("\\.twig\\'" . web-mode))
  :hook ((web-mode . lsp-deferred)
         (web-mode . apheleia-mode)
         (web-mode . (lambda () (setq-local indent-tabs-mode nil)))

         ;; --- SVELTE HOOKS ---
         (svelte-mode . lsp-deferred)
         (svelte-mode . apheleia-mode)
         (svelte-mode . (lambda ()
                          (setq-local indent-tabs-mode nil)
                          (setq-local lsp-disabled-clients (append lsp-disabled-clients '(eslint)))))

         ;; --- VUE HOOKS ---
         (vue-mode . lsp-deferred)
         (vue-mode . apheleia-mode)
         (vue-mode . (lambda () (setq-local indent-tabs-mode nil))))
  :config
  ;; Force web-mode to detect engines based on file extensions
  (setq web-mode-enable-engine-detection t)
  (add-to-list 'web-mode-engines-alist '("svelte" . "\\.svelte\\'"))
  (add-to-list 'web-mode-engines-alist '("vue" . "\\.vue\\'"))

  ;; Enforce 2-space indents for HTML, CSS, and mixed code blocks.
  (setq web-mode-markup-indent-offset 2
        web-mode-css-indent-offset 2
        web-mode-code-indent-offset 2))

;; =============================================================================
;; PYTHON
;; =============================================================================

(use-package python
  :ensure nil
  :mode ("\\.py\\'" . python-ts-mode)
  :hook ((python-ts-mode . lsp-deferred)
         (python-ts-mode . apheleia-mode)

         ;; Formatting
         (python-ts-mode . (lambda ()
                             (setq-local tab-width 4
                                         python-indent-offset 4
                                         indent-tabs-mode nil))))
  ;; NOTE: the old `dap-python-executable` hook was removed — it was a
  ;; leftover from dap-mode. Our debugger (dape, see debugger.el) resolves
  ;; the local .venv python itself via `jmc-python-venv-bin`.
  :preface
  ;; --- Custom Python Helpers ---
  (defun python-flask-run ()
    "Search for project root and launch a Flask development server."
    (interactive)
    (let* ((default-directory (projectile-project-root))
           (flask-app (read-string "Flask app (e.g., 'app:app'): " nil nil "app:app")))
      (setenv "FLASK_APP" flask-app)
      (setenv "FLASK_ENV" "development")
      (compile "flask run")))

  (defun python-add-breakpoint ()
    "Quickly insert a `breakpoint()` call at the current line."
    (interactive)
    (end-of-line)
    (newline-and-indent)
    (insert "breakpoint()  # FIXME: Remove this"))

  (defun python-remove-all-breakpoints ()
    "Scan the buffer and delete all lines containing `breakpoint()`."
    (interactive)
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward "^[[:space:]]*breakpoint().*$" nil t)
        (delete-region (line-beginning-position) (1+ (line-end-position))))))
  :config
  (setq python-shell-interpreter "python3")

  ;; Keybindings:
  ;; C-c ! f -> Run Flask
  ;; C-c b   -> Add Breakpoint
  ;; C-c B   -> Remove all Breakpoints
  ;;
  ;; IMPORTANT: bind on BOTH keymaps. `python-ts-mode-map` is created via
  ;; `(copy-keymap python-mode-map)` at load time (verified in Emacs 30
  ;; python.el) — a COPY, not a parent — so keys added only to
  ;; `python-mode-map` never reach the ts buffers our files actually open in.
  (dolist (map (list python-mode-map python-ts-mode-map))
    (define-key map (kbd "C-c ! f") #'python-flask-run)
    (define-key map (kbd "C-c b") #'python-add-breakpoint)
    (define-key map (kbd "C-c B") #'python-remove-all-breakpoints)))

;; --- Environment & Project Management ---

(defun jmc-python-venv-autoload-h ()
  "Automatically activate a local .venv if found in the project root, but only if it isn't already active."
  (interactive)
  (when-let* ((venv-dir (locate-dominating-file default-directory ".venv"))
              (venv-path (expand-file-name ".venv" venv-dir)))
    ;; Check if this exact venv is already active in the environment
    (unless (string-equal (getenv "VIRTUAL_ENV") venv-path)
      (pyvenv-activate venv-path))))

(use-package pyvenv
  :defer t
  :init
  ;; Hook on `python-base-mode-hook`, which BOTH python-mode and
  ;; python-ts-mode run. The old hooks were on `python-mode-hook`, which
  ;; python-ts-mode does NOT run (it derives from python-base-mode) — so
  ;; venv auto-activation never fired when simply opening a Python file.
  (add-hook 'python-base-mode-hook #'pyvenv-mode)
  (add-hook 'python-base-mode-hook #'jmc-python-venv-autoload-h)
  (add-hook 'projectile-after-switch-project-hook #'jmc-python-venv-autoload-h))

;; Pytest: Standardized testing interface.
(use-package python-pytest
  :after python
  :commands (python-pytest-dispatch python-pytest-file python-pytest-function))

;; Django: Enable specialized features if `manage.py` is present.
(use-package python-django
  :defer t
  :hook ((python-ts-mode . (lambda ()
                             (when (locate-dominating-file default-directory "manage.py")
                               (python-django-mode 1))))))

;; =============================================================================
;; MODERN FRAMEWORKS & LANGUAGES (GO, SWIFT)
;; =============================================================================

;; Force Emacs to see the Go binaries directory
(let ((go-bin (expand-file-name "~/go/bin")))
  (when (file-directory-p go-bin)
    (add-to-list 'exec-path go-bin)
    (setenv "PATH" (concat go-bin ":" (getenv "PATH")))))

;; `go-ts-mode` is BUILT INTO Emacs 29+.
;; -> The `go-mode` package previously declared here never loaded: every
;;    `.go' file was mapped to the built-in ts mode and all hook functions
;;    come from other packages, so it was pure dead weight — the same
;;    pattern as the removed `php-mode' above.
(use-package go-ts-mode
  :ensure nil ; Built-in
  :mode ("\\.go\\'" . go-ts-mode)
  :hook ((go-ts-mode . lsp-deferred)
         (go-ts-mode . apheleia-mode)
         ;; gopls also understands `go.mod` files: dependency diagnostics,
         ;; "upgrade dependency" code actions, hover docs on modules.
         ;; Emacs's built-in go-ts-mode.el maps go.mod -> go-mod-ts-mode,
         ;; and lsp-mode maps that mode to the "go.mod" language id, so
         ;; this works now that the gomod grammar is installed.
         (go-mod-ts-mode . lsp-deferred)))

;; Swift via the REAL tree-sitter package.
;; -> `swift-ts-mode` is provided by its own MELPA package
;;    (rechsteiner/swift-ts-mode). The previously installed `swift-mode`
;;    package does NOT define it, so `.swift` files errored on open.
(use-package swift-ts-mode
  :mode ("\\.swift\\'" . swift-ts-mode)
  :hook ((swift-ts-mode . lsp-deferred)
         (swift-ts-mode . apheleia-mode)))

;; =============================================================================
;; RUST (VIA RUSTIC)
;; =============================================================================

(use-package rustic
  :mode ("\\.rs\\'" . rustic-mode)
  :hook ((rustic-mode . lsp-deferred)
         (rustic-mode . apheleia-mode))
  :bind (:map rustic-mode-map
              ("C-c C-c l" . flycheck-list-errors)
              ("C-c C-c a" . lsp-execute-code-action)
              ("C-c C-c r" . lsp-rename)
              ;; FIXED twice over: previously `C-c C-d` -> `dap-hydra`, a
              ;; dap-mode command that no longer exists since the migration
              ;; to dape. And `C-c C-d` itself is unusable here anyway:
              ;; lsp-ui binds it in `lsp-mode-map` (lang-server.el), and
              ;; minor-mode maps outrank major-mode maps, so any rustic
              ;; binding on that key is shadowed in every LSP buffer.
              ;; `dape` now lives on the C-c C-c prefix rustic already uses.
              ("C-c C-c d" . dape)
              ("M-."       . lsp-find-definition)
              ("M-,"       . pop-tag-mark)
              ("M-?"       . lsp-find-references)
              ("C-c C-c h" . lsp-documentation)
              ("M-j"       . lsp-ui-imenu)
              ("C-c C-c s" . lsp-rust-analyzer-status)
              ("C-c C-c e" . lsp-rust-analyzer-expand-macro)
              ("C-c C-c j" . lsp-rust-analyzer-join-lines)
              ("C-c C-c q" . lsp-workspace-restart)
              ("C-c C-c Q" . lsp-workspace-shutdown))
  :config
  ;; Disable rustic's default formatter in favor of global `apheleia-mode`.
  (setq rustic-format-on-save nil)
  (setq rustic-lsp-client 'lsp-mode)
  (setq rustic-use-tree-sitter t)
  ;; Use `clippy` for deeper code analysis and linting.
  (setq rustic-flycheck-checker 'rustic-clippy)

  ;; --- Inlay Hints (Visual Type Annotations) ---
  (setq rustic-analyzer-proc-macro-enable t)
  (setq rustic-display-inlay-hints t)
  (setq rustic-analyzer-display-chaining-hints t)
  (setq rustic-analyzer-display-closure-return-type-hints t)
  (setq rustic-analyzer-display-lifetime-elision-hints-enable "skip_trivial"))

;; Cargo: Minor mode for Rust's build system and dependency manager.
(use-package cargo
  :hook (rustic-mode . cargo-minor-mode))

;; =============================================================================
;; SCALA
;; =============================================================================

(use-package scala-ts-mode
  :mode ("\\.scala\\'" . scala-ts-mode)
  :hook ((scala-ts-mode . lsp-deferred)
         (scala-ts-mode . apheleia-mode)))

;; SBT: Scala Build Tool integration.
;; -> NOTE: this block used to lack `:ensure t` and was therefore NEVER
;;    installed. With `use-package-always-ensure` (init.el) it now is.
(use-package sbt-mode
  :commands (sbt-start sbt-command)
  :config
  ;; Fix: Allow space key usage in sbt-command prompts.
  (substitute-key-definition 'minibuffer-complete-word 'self-insert-command minibuffer-local-completion-map)
  ;; Fix: Disable supershell to prevent UI corruption in Emacs.
  (setq sbt:program-options '("-Dsbt.supershell=false")))

;; =============================================================================
;; DATA & DATABASES (SQL, MONGODB, REDIS)
;; =============================================================================

;; Making sure Emacs sees ruby gems (needed for the `sqlint' checker).
;; -> DEFERRED to idle time: `gem env' shells out to ruby and cost
;;    100-300ms of pure startup latency when run at load. Nothing needs
;;    gem binaries in the first seconds of a session.
(run-with-idle-timer
 2 nil
 (lambda ()
   (when-let* ((gem-bin (condition-case nil
                            (string-trim (shell-command-to-string "gem env user_gemdir"))
                          (error nil)))
               (bin-dir (expand-file-name "bin" gem-bin))
               ((file-directory-p bin-dir)))
     (add-to-list 'exec-path bin-dir)
     (setenv "PATH" (concat bin-dir ":" (getenv "PATH"))))))

;; SQL: there is NO `sql-ts-mode` in Emacs (verified against the Emacs 30
;; tree) — the old mapping sent every `.sql` file to a void function.
;; -> `lsp-deferred` for SQL intentionally stays OUT of these hooks: dev.el
;;    starts it via `hack-local-variables-hook` so `.dir-locals.el` database
;;    connections are read BEFORE the `sqls` server boots.
(use-package sql
  :ensure nil ; Built-in
  :mode ("\\.sql\\'" . sql-mode)
  :hook (sql-mode . apheleia-mode)
  :bind (:map sql-mode-map ("C-c C-d" . sql-connect))
  :config
  (setq sql-product 'postgres))

;; MongoDB shell scripts (`.mongodb`) are JavaScript — highlight them as such.
;; -> The old block mapped them to `mongodb-mode` from the `mongo` package,
;;    but that package is a wire-protocol DRIVER library: it defines neither
;;    `mongodb-mode` nor `mongo-shell-program` (verified against its source),
;;    so `.mongodb` files errored on open and the package has been dropped.
(add-to-list 'auto-mode-alist '("\\.mongodb\\'" . js-ts-mode))

(use-package redis
  :defer t
  :config
  (require 'bookmark))

;; =============================================================================
;; STRUCTURED DATA (YAML, JSON, CSV, XML)
;; =============================================================================

;; `yaml-ts-mode` and `json-ts-mode` are BUILT INTO Emacs 29+.
;; -> The `yaml-mode' and `json-mode' packages previously declared here
;;    never loaded (same dead-weight pattern as php-mode/go-mode: files
;;    map to the built-in ts modes, hooks come from other packages).
;;    json-mode is gone entirely; yaml-mode still gets installed as a
;;    DEPENDENCY of docker-compose-mode below, just no longer declared.
(use-package yaml-ts-mode
  :ensure nil ; Built-in
  :mode ("\\.ya?ml\\'" . yaml-ts-mode)
  :hook ((yaml-ts-mode . lsp-deferred)
         (yaml-ts-mode . apheleia-mode)))

(use-package json-ts-mode
  :ensure nil ; Built-in
  :mode ("\\.json\\'" . json-ts-mode)
  :hook ((json-ts-mode . lsp-deferred)
         (json-ts-mode . apheleia-mode)))

;; TOML: `toml-ts-mode` is BUILT INTO Emacs 29+. Without this mapping,
;; `.toml` files fall back to the regex-based `conf-toml-mode` — the toml
;; grammar is already in `treesit-auto-langs' (tree.el), so the ts mode
;; just needed wiring up. Formatting runs through taplo (see dev.el).
(use-package toml-ts-mode
  :ensure nil ; Built-in
  :mode ("\\.toml\\'" . toml-ts-mode)
  :hook (toml-ts-mode . apheleia-mode))

(use-package csv-mode
  :mode ("\\.csv\\'" . csv-mode)
  :bind (:map csv-mode-map
              ("TAB" . csv-next-field)
              ("<tab>" . csv-next-field)
              ("<backtab>" . csv-previous-field)))

;; XML: there is NO `xml-ts-mode` in Emacs (verified) — use the excellent
;; built-in `nxml-mode` instead (schema-aware validation, smart completion).
;; -> lsp-mode pairs it with the `lemminx` XML language server.
(use-package nxml-mode
  :ensure nil ; Built-in
  :mode ("\\.xml\\'" . nxml-mode)
  :hook (nxml-mode . lsp-deferred))

;; =============================================================================
;; DOCKER & CONTAINERS
;; =============================================================================

(use-package dockerfile-mode
  :mode "Dockerfile\\'")

(use-package docker-compose-mode
  :mode "compose.*\\.ya?ml\\'")

;; Management UI for Docker containers and images.
;; -> MOVED from `C-c d` to `C-c D`: `C-c d` is the dape debugger prefix
;;    (debugger.el), and whichever module loaded last silently won the key —
;;    the docker binding was unreachable.
(use-package docker
  :commands (docker)
  :bind ("C-c D" . docker))

;; =============================================================================
;; MARKDOWN (WITH LIVE PREVIEW)
;; =============================================================================
;;
;; This configuration uses `pandoc` to convert Markdown to HTML and renders it
;; in a local `eww` browser buffer that updates automatically as you type.

(use-package markdown-mode
  :mode (("\\.md\\'" . markdown-mode)
         ("\\.markdown\\'" . markdown-mode))
  :hook ((markdown-mode . flycheck-mode)
         (markdown-mode . apheleia-mode))
  :preface
  ;; --- Preview Engine ---

  (defvar jmc-markdown-preview-buffer "*markdown-preview-eww*"
    "Internal buffer name for HTML rendering.")

  (defun jmc-markdown-preview--render ()
    "Convert current Markdown to HTML and refresh the eww buffer."
    (let* ((markdown-buffer (current-buffer))
           (html-output
            (with-temp-buffer
              (insert-buffer-substring markdown-buffer)
              (call-process-region (point-min) (point-max) "pandoc" t t nil "-f" "markdown" "-t" "html" "-s")
              (buffer-string))))
      (when (and html-output (> (length html-output) 0))
        (with-current-buffer (get-buffer-create jmc-markdown-preview-buffer)
          (eww-mode)
          (let ((inhibit-read-only t))
            (erase-buffer)
            (insert html-output)
            (let ((document (libxml-parse-html-region (point-min) (point-max))))
              (erase-buffer)
              (shr-insert-document document)))))))

  (defun jmc-markdown-preview-split ()
    "Launch side-by-side live preview."
    (interactive)
    (delete-other-windows)
    (split-window-right)
    (jmc-markdown-preview--render)
    (other-window 1)
    (switch-to-buffer jmc-markdown-preview-buffer)
    (other-window -1)
    (jmc-markdown-preview-live-start))

  (defvar jmc-markdown-preview--timer nil)

  (defun jmc-markdown-preview--update ()
    "Refresh if the buffer is modified and preview window is visible.
Guarded by a mode check: the idle timer fires with whatever buffer is
current, and without the guard, switching to any other modified buffer
while the preview window was visible pandoc-rendered THAT buffer into
the preview."
    (when (and (derived-mode-p 'markdown-mode)
               (buffer-modified-p)
               (get-buffer-window jmc-markdown-preview-buffer))
      (jmc-markdown-preview--render)))

  (defun jmc-markdown-preview-live-start ()
    "Initialize the idle timer for auto-updates."
    (interactive)
    (unless jmc-markdown-preview--timer
      (setq jmc-markdown-preview--timer (run-with-idle-timer 1.0 t #'jmc-markdown-preview--update))))

  (defun jmc-markdown-preview-live-stop ()
    "Halt the preview engine and cleanup buffers."
    (interactive)
    (when jmc-markdown-preview--timer
      (cancel-timer jmc-markdown-preview--timer)
      (setq jmc-markdown-preview--timer nil))
    (when-let ((buffer (get-buffer jmc-markdown-preview-buffer)))
      (kill-buffer buffer)))
  :config
  (setq markdown-fontify-code-blocks-natively t)
  (setq markdown-command "pandoc")

  ;; Shortcuts: C-c v (View preview), C-c V (Stop).
  ;; -> MOVED from C-c p / C-c P: perspective's global prefix (projects.el)
  ;;    took over "C-c p", and minor-mode maps outrank major-mode maps, so
  ;;    the old binding became unreachable in markdown buffers.
  (define-key markdown-mode-map (kbd "C-c v") #'jmc-markdown-preview-split)
  (define-key markdown-mode-map (kbd "C-c V") #'jmc-markdown-preview-live-stop))

;; =============================================================================
;; DEVOPS & ENVIRONMENTS (TERRAFORM, DOTENV)
;; =============================================================================

(use-package terraform-mode
  ;; Explicitly map both standard Terraform files and variables files
  :mode (("\\.tf\\'" . terraform-mode)
         ("\\.tfvars\\'" . terraform-mode))
  ;; Boot up the language server and auto-formatter
  :hook ((terraform-mode . lsp-deferred)
         (terraform-mode . apheleia-mode)))

(use-package supreme-dotenv
  :ensure (:host github :repo "J4VMC/supreme-dotenv"))

;; =============================================================================
;; SHELL SUPPORT (FISH)
;; =============================================================================

;; Provides syntax highlighting and indentation for .fish script files.
;; -> Useful if you use Fish as your interactive shell (configured below).
(use-package fish-mode
  :mode "\\.fish\\'"
  :hook (fish-mode . apheleia-mode))

;; Provides modern Tree-sitter syntax highlighting and LSP integration for shell scripts.
;; -> Requires `bash-language-server`, `shellcheck`, and `shfmt` installed on your OS.
(use-package sh-script
  :ensure nil ; Built-in
  :mode (("\\.sh\\'" . bash-ts-mode)
         ("\\.bash\\'" . bash-ts-mode)
         ("bashrc\\'" . bash-ts-mode)
         ("zshrc\\'" . bash-ts-mode))
  :hook ((bash-ts-mode . lsp-deferred)
         (bash-ts-mode . apheleia-mode))
  :config
  (setq sh-basic-offset 4))

(use-package docstr
  :hook ((php-ts-mode typescript-ts-mode tsx-ts-mode js-ts-mode python-ts-mode go-ts-mode
                      rustic-mode scala-ts-mode)
         . docstr-mode))

;; =============================================================================
;; FINALIZE
;; =============================================================================

;; This line tells Emacs that the 'languages' module is successfully loaded.
(provide 'languages)

;;; languages.el ends here
