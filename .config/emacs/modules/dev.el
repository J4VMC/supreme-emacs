;;; dev.el --- All settings relevant for Software Development -*- lexical-binding: t; -*-

;;; Commentary:
;; This file configures the essential tools for a modern software development
;; workflow inside Emacs. It transforms Emacs into a fully-featured IDE.

;;; Code:

;; =============================================================================
;; COMPILER DECLARATIONS (SILENCE WARNINGS)
;; =============================================================================

(defvar magit-mode-map)
(defvar emmet-expand-jsx-className?)
(defvar apheleia-formatters)
(defvar apheleia-mode-alist)
(defvar flycheck-mode-map)
(defvar flycheck-checkers)
(defvar flycheck-phpcs-standard)

(declare-function apheleia-global-mode "apheleia")
(declare-function flycheck-add-next-checker "flycheck")
(declare-function flycheck-mode "flycheck")

(eval-when-compile
  (unless (fboundp 'flycheck-define-checker)
    (defmacro flycheck-define-checker (&rest _))))

;; =============================================================================
;; VERSION CONTROL (MAGIT)
;; =============================================================================

(use-package magit
  :ensure t
  :after transient
  :bind ("C-x g" . magit-status))

(use-package forge
  :after magit
  :ensure t
  :bind (:map magit-mode-map ("@" . forge-dispatch))
  :config
  (setq auth-sources '("~/.authinfo.gpg")))
  ;; NOTE: no section hooks needed here. Forge adds its pullreq/issue
  ;; sections to `magit-status-sections-hook' itself when it loads
  ;; (`forge-add-default-sections', on by default). The old add-hook calls
  ;; referenced functions that don't exist in forge
  ;; (`magit-insert-forge-*' — the real names are `forge-insert-*') and
  ;; passed `t' as add-hook's LOCAL flag, which registered them
  ;; buffer-locally in whatever buffer was current at load time — dead
  ;; code either way.

;; Surface TODO/FIXME/NOTE keywords (the same ones hl-todo highlights)
;; as a section in the magit status buffer. Scans with ripgrep.
(use-package magit-todos
  :after magit
  :config
  (magit-todos-mode 1))

;; =============================================================================
;; API TESTING (RESTCLIENT)
;; =============================================================================

(use-package restclient
  :ensure t
  :mode ("\\.http\\'" . restclient-mode)
  :config
  (use-package restclient-test :ensure t))

;; =============================================================================
;; WEB DEVELOPMENT (EMMET)
;; =============================================================================

(use-package emmet-mode
  :ensure t
  :hook ((web-mode . emmet-mode)
         (css-mode . emmet-mode))
  :config
  (setq emmet-expand-jsx-className? t))

;; =============================================================================
;; AUTO-FORMATTING (APHELEIA)
;; =============================================================================

;; Helper function for Scalafmt (Needs to be a function call, not a symbol)
(defun jmc-find-scalafmt-conf ()
  "Locate the .scalafmt.conf file in the project root."
  (let ((dir (locate-dominating-file (or buffer-file-name default-directory) ".scalafmt.conf")))
    (if dir
        (expand-file-name ".scalafmt.conf" dir)
      ".scalafmt.conf")))

(use-package apheleia
  :ensure t
  :diminish ""
  :config
  ;; --- 1. Define Custom Formatters ---
  (setf (alist-get 'phpcs-psr12 apheleia-formatters)
        '("sh" "-c" "phpcbf --standard=PSR12 --stdin-path=\"$1\" - || true" "--" filepath))
  (setf (alist-get 'google-java-format apheleia-formatters) '("google-java-format" "-"))
  (setf (alist-get 'goimports apheleia-formatters) '("goimports"))
  (setf (alist-get 'rustfmt apheleia-formatters) '("rustfmt" "--emit=stdout"))
  (setf (alist-get 'scalafmt apheleia-formatters)
        '("scalafmt" "--stdin" "--stdout"
          "--config" (jmc-find-scalafmt-conf)
          "--assume-filename" filepath))
  (setf (alist-get 'sql-formatter apheleia-formatters)
        '("sql-formatter" "--language" "postgresql" "--indent" "2" "--uppercase"))

  ;; --- 2. Associate Modes with Formatters ---
  (setf (alist-get 'php-ts-mode apheleia-mode-alist) 'phpcs-psr12)
  (setf (alist-get 'java-mode apheleia-mode-alist) 'google-java-format)
  (setf (alist-get 'java-ts-mode apheleia-mode-alist) 'google-java-format)
  (setf (alist-get 'python-mode apheleia-mode-alist) '(isort black))
  (setf (alist-get 'python-ts-mode apheleia-mode-alist) '(isort black))
  (setf (alist-get 'go-mode apheleia-mode-alist) 'goimports)
  (setf (alist-get 'go-ts-mode apheleia-mode-alist) 'goimports)
  (setf (alist-get 'rust-ts-mode apheleia-mode-alist) 'rustfmt)
  (setf (alist-get 'scala-ts-mode apheleia-mode-alist) 'scalafmt)
  ;; (No sql-ts-mode entry: that mode does not exist — see languages.el.)
  (setf (alist-get 'sql-mode apheleia-mode-alist) 'sql-formatter)

  ;; Web Technologies (Prettier)
  (setf (alist-get 'typescript-ts-mode apheleia-mode-alist) 'prettier-typescript)
  (setf (alist-get 'tsx-ts-mode apheleia-mode-alist) 'prettier-typescript)
  (setf (alist-get 'js-ts-mode apheleia-mode-alist) 'prettier-javascript)
  (setf (alist-get 'typescript-mode apheleia-mode-alist) 'prettier-typescript)
  (setf (alist-get 'js-mode apheleia-mode-alist) 'prettier-javascript)
  (setf (alist-get 'js2-mode apheleia-mode-alist) 'prettier-javascript)
  (setf (alist-get 'json-mode apheleia-mode-alist) 'prettier-json)
  (setf (alist-get 'json-ts-mode apheleia-mode-alist) 'prettier-json)
  (setf (alist-get 'css-mode apheleia-mode-alist) 'prettier-css)
  (setf (alist-get 'css-ts-mode apheleia-mode-alist) 'prettier-css)
  (setf (alist-get 'html-mode apheleia-mode-alist) 'prettier-html)
  (setf (alist-get 'web-mode apheleia-mode-alist) 'prettier-html)
  (setf (alist-get 'yaml-mode apheleia-mode-alist) 'prettier-yaml)
  (setf (alist-get 'yaml-ts-mode apheleia-mode-alist) 'prettier-yaml)

  ;; TOML (taplo — `brew install taplo`). NOT prettier: prettier has no
  ;; native TOML support (only an unmaintained community plugin), and
  ;; apheleia's other builtin choice for conf-toml-mode, dprint, refuses
  ;; to run without a per-project dprint.json. taplo is the standard
  ;; dedicated TOML formatter and works with zero config (reads an
  ;; optional taplo.toml/.taplo.toml when present).
  ;; -> toml-ts-mode -> taplo is already apheleia's builtin default;
  ;;    kept explicit here like every other mapping in this list. The
  ;;    conf-toml-mode entry OVERRIDES builtin dprint, as a fallback for
  ;;    any toml buffer that ends up in the non-ts mode.
  (setf (alist-get 'toml-ts-mode apheleia-mode-alist) 'taplo)
  (setf (alist-get 'conf-toml-mode apheleia-mode-alist) 'taplo)
  (setf (alist-get 'markdown-mode apheleia-mode-alist) 'prettier-markdown)
  (setf (alist-get 'gfm-mode apheleia-mode-alist) 'prettier-markdown)
  (setf (alist-get 'svelte-mode apheleia-mode-alist) 'prettier-svelte)

  ;; --- 3. Enable Globally ---
  (apheleia-global-mode t))

;; =============================================================================
;; ON-THE-FLY SYNTAX CHECKING (FLYCHECK)
;; =============================================================================

(use-package flycheck
  :ensure t
  ;; This prog-mode hook is the SINGLE source of truth for enabling
  ;; flycheck: every programming mode in languages.el derives from
  ;; prog-mode, so the per-language `flycheck-mode' hook entries that used
  ;; to be sprinkled there were redundant and have been removed. Only
  ;; markdown-mode (a text-mode derivative) keeps its own hook.
  :hook (prog-mode . flycheck-mode)
  :bind (:map flycheck-mode-map
              ("M-n" . flycheck-next-error)
              ("M-p" . flycheck-previous-error))
  :config

  (defface lsp-flycheck-info-unnecessary
    '((t :inherit shadow :strike-through -1))
    "Face used to fade out unused imports/variables.")
  
  (defface lsp-flycheck-warning-unnecessary
    '((t :inherit shadow :strike-through -1))
    "Face used to fade out unused imports/variables.")
  
  (flycheck-define-error-level 'lsp-flycheck-info-unnecessary
    :severity 0 :compilation-level 0 :overlay-category 'flycheck-info-overlay
    :fringe-bitmap 'flycheck-fringe-bitmap-info :fringe-face 'flycheck-fringe-info
    :error-list-face 'flycheck-error-list-info)

  (flycheck-define-error-level 'lsp-flycheck-warning-unnecessary
    :severity 1 :compilation-level 1 :overlay-category 'flycheck-warning-overlay
    :fringe-bitmap 'flycheck-fringe-bitmap-warning :fringe-face 'flycheck-fringe-warning
    :error-list-face 'flycheck-error-list-warning)
  ;; --- Custom Checker Definitions ---
  (flycheck-define-checker sql-sqlint
    "A SQL syntax checker using sqlint."
    :command ("sqlint")
    :standard-input t
    :error-patterns
    ((error line-start "stdin:" line ":" column ":ERROR " (message) line-end)
     (warning line-start "stdin:" line ":" column ":WARNING " (message) line-end))
    :modes (sql-mode))
  
  (flycheck-define-checker fish
    "A Fish shell syntax checker using `fish -n`."
    :command ("fish" "-n" source)
    :error-patterns
    ((error line-start (file-name) " (line " line "): " (message) line-end))
    :modes fish-mode)

  ;; --- Registering Checkers ---
  (add-to-list 'flycheck-checkers 'fish)
  (add-to-list 'flycheck-checkers 'sql-sqlint)
  (add-to-list 'flycheck-checkers 'rustic-clippy)

  (setq flycheck-phpcs-standard "PSR12"))

;; Consult-Flycheck: a searchable, previewable list of the buffer's errors
;; in the same Vertico UI as everything else — complements the one-at-a-time
;; `M-n'/`M-p' navigation above. `M-s e' fits the `M-s' search prefix
;; (`M-s r' ripgrep, `M-s l' line, `M-s d' docs).
(use-package consult-flycheck
  :after (consult flycheck)
  :bind (:map flycheck-mode-map
              ("M-s e" . consult-flycheck)))

;; =============================================================================
;; FLYCHECK "CHAINING" (THE RELAY RACE)
;; =============================================================================

(defun jmc-configure-flycheck-chains ()
  "Configure secondary linters to run after LSP finishes its primary checks."
  (cond
   ;; Python
   ((derived-mode-p 'python-mode 'python-ts-mode)
    (flycheck-add-next-checker 'lsp 'python-flake8))
   ;; Go
   ((derived-mode-p 'go-mode 'go-ts-mode)
    (flycheck-add-next-checker 'lsp 'golangci-lint))
   ;; SQL
   ((derived-mode-p 'sql-mode)
    (flycheck-add-next-checker 'lsp 'sql-sqlint))
   ;; PHP
   ((derived-mode-p 'php-mode 'php-ts-mode)
    (flycheck-add-next-checker 'lsp 'phpstan)
    (flycheck-add-next-checker 'phpstan 'php-phpcs))
   ;; Rust
   ((derived-mode-p 'rustic-mode 'rust-ts-mode 'rust-mode)
    (flycheck-add-next-checker 'lsp 'rustic-clippy))))
   ;; (The old Scala branch only called (flycheck-mode 1) — redundant:
   ;;  the prog-mode hook above already enables flycheck everywhere.)

(add-hook 'lsp-mode-hook #'jmc-configure-flycheck-chains)

;; =============================================================================
;; LANGUAGE-SPECIFIC SETUP HOOKS
;; =============================================================================

;; --- Go ---
(use-package flycheck-golangci-lint
  :ensure t
  :defer t
  :after flycheck
  ;; Only go-ts-mode: `.go' files map there (languages.el); the go-mode
  ;; package is no longer installed.
  :hook (go-ts-mode . flycheck-golangci-lint-setup))

;; --- PHP ---
(use-package flycheck-phpstan
  :ensure t
  :after flycheck)

(defun jmc-php-setup-h ()
  "Setup PHP buffer specific features."
  (setq-local indent-tabs-mode nil)
  (setq-local tab-width 4)
  (setq-local c-basic-offset 4)
  ;; Load the phpstan checker so the LSP -> phpstan -> phpcs chain works.
  ;; (flycheck-mode itself comes from the global prog-mode hook.)
  (require 'flycheck-phpstan))

(add-hook 'php-ts-mode-hook #'jmc-php-setup-h)

;; --- Rust ---
(defun jmc-rust-lsp-optimization ()
  "The ultimate rust-analyzer setup to prevent multi-server race conditions."
  (setq-local lsp-enable-on-type-formatting nil)
  (setq-local lsp-idle-delay 0.5))

(add-hook 'rust-ts-mode-hook #'jmc-rust-lsp-optimization)
(add-hook 'rustic-mode-hook #'jmc-rust-lsp-optimization)

;; --- SQL ---
;; We must use `hack-local-variables-hook` instead of `sql-mode-hook`.
;; This forces Emacs to read your `.dir-locals.el` database connections
;; BEFORE it attempts to boot up the `sqls` server.
(add-hook 'hack-local-variables-hook
          (lambda ()
            (when (derived-mode-p 'sql-mode)
              (lsp-deferred))))

;; --- Scala ---
(defun jmc-scala-setup-h ()
  ;; Disable the buggy indicators that cause the "Node type error"
  (when (fboundp 'treesit-fold-indicators-mode)
    (treesit-fold-indicators-mode -1))

  ;; Enable Code Lenses specifically for Scala to allow 1-click debugging
  (lsp-lens-mode 1))

(add-hook 'scala-ts-mode-hook #'jmc-scala-setup-h)

;; =============================================================================
;; QUICK-RUN & PACKAGE-LINT
;; =============================================================================

(use-package quickrun
  :ensure t
  :bind ("s-r" . quickrun))

(use-package package-lint
  :ensure t
  :defer t)

;; =============================================================================
;; FINALIZE
;; =============================================================================
(provide 'dev)
;;; dev.el ends here
