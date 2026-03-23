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

(declare-function magit-insert-forge-pullreqs "forge")
(declare-function magit-insert-forge-issues "forge")
(declare-function magit-insert-forge-notifications "forge")
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
  (setq auth-sources '("~/.authinfo.gpg"))
  (add-hook 'magit-status-sections-hook #'magit-insert-forge-pullreqs nil t)
  (add-hook 'magit-status-sections-hook #'magit-insert-forge-issues nil t)
  (add-hook 'magit-status-sections-hook #'magit-insert-forge-notifications nil t))

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

(use-package apheleia
  :ensure t
  :diminish ""
  :config
  ;; --- 1. Define Custom Formatters ---
  (setf (alist-get 'phpcs-psr12 apheleia-formatters)
        '("phpcbf" "--standard=PSR12" 
          (concat "--stdin-path=" (or buffer-file-name "stdin"))))
  (setf (alist-get 'google-java-format apheleia-formatters) '("google-java-format" "-"))
  (setf (alist-get 'goimports apheleia-formatters) '("goimports"))
  (setf (alist-get 'rustfmt apheleia-formatters) '("rustfmt" "--emit=stdout"))
  (setf (alist-get 'scalafmt apheleia-formatters) '("scalafmt" "--stdin" "--stdout"))
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
  (setf (alist-get 'sql-mode apheleia-mode-alist) 'sql-formatter)
  (setf (alist-get 'sql-ts-mode apheleia-mode-alist) 'sql-formatter)

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
  (setf (alist-get 'markdown-mode apheleia-mode-alist) 'prettier-markdown)
  (setf (alist-get 'gfm-mode apheleia-mode-alist) 'prettier-markdown)

  ;; --- 3. Enable Globally ---
  (apheleia-global-mode t))

;; =============================================================================
;; ON-THE-FLY SYNTAX CHECKING (FLYCHECK)
;; =============================================================================

(use-package flycheck
  :ensure t
  :hook (prog-mode . flycheck-mode)
  :bind (:map flycheck-mode-map
              ("M-n" . flycheck-next-error)
              ("M-p" . flycheck-previous-error))
  :config
  ;; --- Custom Checker Definitions ---
  (flycheck-define-checker typescript-tsc-syntax
    "A TypeScript syntax checker using tsc."
    :command ("tsc" "--noEmit" "--allowJs" "--pretty" "false" source-inplace)
    :error-patterns
    ((error line-start (file-name) "(" line "," column "): error TS" (message) line-end))
    :modes (typescript-ts-mode tsx-ts-mode js-ts-mode))

  (flycheck-define-checker sql-sqlint
    "A SQL syntax checker using sqlint."
    :command ("sqlint")
    :standard-input t
    :error-patterns
    ((error line-start "stdin:" line ":" column ":ERROR " (message) line-end)
     (warning line-start "stdin:" line ":" column ":WARNING " (message) line-end))
    :modes (sql-mode sql-ts-mode))
  
  (flycheck-define-checker fish
    "A Fish shell syntax checker using `fish -n`."
    :command ("fish" "-n" source)
    :error-patterns
    ((error line-start (file-name) " (line " line "): " (message) line-end))
    :modes fish-mode)

  ;; --- Registering Checkers ---
  (add-to-list 'flycheck-checkers 'typescript-tsc-syntax)
  (add-to-list 'flycheck-checkers 'fish)
  (add-to-list 'flycheck-checkers 'sql-sqlint)
  (add-to-list 'flycheck-checkers 'rustic-clippy)

  (setq flycheck-phpcs-standard "PSR12"))

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
   ((derived-mode-p 'sql-mode 'sql-ts-mode)
    (flycheck-add-next-checker 'lsp 'sql-sqlint))
   ;; JS/TS
   ((derived-mode-p 'typescript-ts-mode 'tsx-ts-mode 'js-ts-mode)
    (flycheck-add-next-checker 'lsp 'typescript-tsc-syntax))
   ;; PHP
   ((derived-mode-p 'php-mode 'php-ts-mode)
    (flycheck-add-next-checker 'lsp 'phpstan)
    (flycheck-add-next-checker 'phpstan 'php-phpcs))
   ;; Rust
   ((derived-mode-p 'rustic-mode 'rust-ts-mode 'rust-mode)
    (flycheck-add-next-checker 'lsp 'rustic-clippy))
   ;; Scala (Ensure Flycheck displays the LSP errors)
   ((derived-mode-p 'scala-ts-mode)
    (flycheck-mode 1))))

(add-hook 'lsp-mode-hook #'jmc-configure-flycheck-chains)

;; =============================================================================
;; LANGUAGE-SPECIFIC SETUP HOOKS
;; =============================================================================

;; --- Go ---
(use-package flycheck-golangci-lint
  :ensure t
  :defer t
  :after flycheck
  :hook ((go-mode . flycheck-golangci-lint-setup)
         (go-ts-mode . flycheck-golangci-lint-setup)))

;; --- PHP ---
(use-package flycheck-phpstan
  :ensure t
  :after flycheck)

(defun jmc-php-setup-h ()
  "Setup PHP buffer specific features."
  (setq-local indent-tabs-mode nil)
  (setq-local tab-width 4)
  (setq-local c-basic-offset 4)
  (require 'flycheck-phpstan)
  (flycheck-mode 1))

(add-hook 'php-ts-mode-hook #'jmc-php-setup-h)

;; --- Rust ---
(defun jmc-rust-lsp-optimization ()
  "The ultimate rust-analyzer setup to prevent multi-server race conditions."
  (setq-local lsp-disabled-clients '(semgrep-ls))
  (setq-local lsp-enable-on-type-formatting nil)
  (setq-local lsp-idle-delay 0.5))

(add-hook 'rust-ts-mode-hook #'jmc-rust-lsp-optimization)
(add-hook 'rustic-mode-hook #'jmc-rust-lsp-optimization)

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
