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

(defvar typescript-indent-level)
(defvar js-indent-level)
(defvar web-mode-markup-indent-offset)
(defvar web-mode-css-indent-offset)
(defvar web-mode-code-indent-offset)
(defvar gofmt-command)
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
(defvar mongo-shell-program)
(defvar csv-mode-map)
(defvar markdown-fontify-code-blocks-natively)
(defvar markdown-command)
(defvar markdown-mode-map)

(declare-function projectile-project-root "projectile")
(declare-function pyvenv-activate "pyvenv")
(declare-function pyvenv-mode "pyvenv")
(declare-function python-django-mode "python-django")

;; =============================================================================
;; PHP
;; =============================================================================

(use-package php-mode
  :ensure t
  ;; Map all PHP-related extensions to the modern Tree-sitter mode.
  :mode (("\\.php\\'" . php-ts-mode)
         ("\\.phtml\\'" . php-ts-mode)
         ("\\.php[3-7]\\'" . php-ts-mode))
  :hook ((php-ts-mode . lsp-deferred)
         (php-ts-mode . apheleia-mode)
         (php-ts-mode . flycheck-mode)))

;; --- PHP Utilities ---

;; Composer: Access PHP's package manager commands directly via M-x.
(use-package composer
  :ensure t
  :after php-mode
  :commands (composer-install composer-update composer-require))

;; PHPUnit: Integration for running unit tests within Emacs.
(use-package phpunit
  :ensure t
  :after php-mode)

;; =============================================================================
;; JAVASCRIPT & TYPESCRIPT
;; =============================================================================

(use-package typescript-mode
  :ensure t
  ;; Associate modern Tree-sitter modes with JS/TS extensions.
  :mode (("\\.ts\\'" . typescript-ts-mode)
         ("\\.tsx\\'" . tsx-ts-mode)
         ("\\.js\\'" . js-ts-mode)
         ("\\.jsx\\'" . tsx-ts-mode))
  :hook ((typescript-ts-mode . lsp-deferred)
         (typescript-ts-mode . apheleia-mode)
         (typescript-ts-mode . flycheck-mode)
         (tsx-ts-mode . lsp-deferred)
         (tsx-ts-mode . apheleia-mode)
         (tsx-ts-mode . flycheck-mode)
         (js-ts-mode . lsp-deferred)
         (js-ts-mode . apheleia-mode)
         (js-ts-mode . flycheck-mode))
  :config
  ;; Standardize 2-space indentation for the JS ecosystem.
  (setq typescript-indent-level 2
        js-indent-level 2))

;; =============================================================================
;; WEB TECHNOLOGIES (HTML, TWIG)
;; =============================================================================

;; `web-mode` handles files that mix different languages (e.g., HTML + PHP).
(use-package web-mode
  :ensure t
  :mode (("\\.html?\\'" . web-mode)
         ("\\.twig\\'" . web-mode)
         ("\\.jsx\\'" . web-mode)
         ("\\.tsx\\'" . web-mode))
  :hook ((web-mode . lsp-deferred)
         (web-mode . apheleia-mode))
  :config
  ;; Enforce 2-space indents for HTML, CSS, and mixed code blocks.
  (setq web-mode-markup-indent-offset 2
        web-mode-css-indent-offset 2
        web-mode-code-indent-offset 2))

;; =============================================================================
;; PYTHON
;; =============================================================================

(use-package python
  :ensure nil ; Built-in
  :hook ((python-ts-mode . lsp-deferred)
         (python-ts-mode . apheleia-mode)
         ;; PEP 8 Standard: Enforce 4-space indents and no physical tabs.
         (python-ts-mode . (lambda ()
                             (setq-local tab-width 4
                                         python-indent-offset 4
                                         indent-tabs-mode nil))))
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
  (define-key python-mode-map (kbd "C-c ! f") #'python-flask-run)
  (define-key python-mode-map (kbd "C-c b") #'python-add-breakpoint)
  (define-key python-mode-map (kbd "C-c B") #'python-remove-all-breakpoints))

;; --- Environment & Project Management ---

(defun jmc-python-venv-autoload-h ()
  "Automatically activate a local .venv if found in the project root."
  (interactive)
  (when-let ((venv (locate-dominating-file default-directory ".venv")))
    (pyvenv-activate (expand-file-name ".venv" venv))))

(use-package pyvenv
  :ensure t
  :defer t
  :config
  (add-hook 'python-mode-hook #'pyvenv-mode)
  (add-hook 'python-mode-hook #'jmc-python-venv-autoload-h)
  (add-hook 'projectile-after-switch-project-hook #'jmc-python-venv-autoload-h))

;; Pytest: Standardized testing interface.
(use-package python-pytest
  :ensure t
  :after python
  :commands (python-pytest-dispatch python-pytest-file python-pytest-function))

;; Django: Enable specialized features if `manage.py` is present.
(use-package python-django
  :ensure t
  :defer t
  :hook ((python-ts-mode . (lambda ()
                             (when (locate-dominating-file default-directory "manage.py")
                               (python-django-mode 1))))))

;; =============================================================================
;; MODERN FRAMEWORKS & LANGUAGES (SVELTE, GO, SWIFT)
;; =============================================================================

(use-package svelte-mode
  :ensure t
  :mode ("\\.svelte\\'" . svelte-mode)
  :hook ((svelte-mode . lsp-deferred)
         (svelte-mode . apheleia-mode)
         (svelte-mode . flycheck-mode)))

(use-package go-mode
  :ensure t
  :hook ((go-ts-mode . lsp-deferred)
         (go-ts-mode . apheleia-mode)
         (go-ts-mode . flycheck-mode))
  :config
  ;; `goimports` handles both formatting and automatic import management.
  (setq gofmt-command "goimports"))

(use-package swift-mode
  :ensure t
  :hook ((swift-ts-mode . lsp-deferred)
         (swift-ts-mode . apheleia-mode)
         (swift-ts-mode . flycheck-mode)))

;; =============================================================================
;; RUST (VIA RUSTIC)
;; =============================================================================

(use-package rustic
  :ensure t
  :mode ("\\.rs\\'" . rustic-mode)
  :hook ((rustic-mode . lsp-deferred)
         (rustic-mode . apheleia-mode)
         (rustic-mode . flycheck-mode))
  :bind (:map rustic-mode-map
              ("C-c C-c l" . flycheck-list-errors)
              ("C-c C-c a" . lsp-execute-code-action)
              ("C-c C-c r" . lsp-rename)
              ("C-c C-d"   . dap-hydra)
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
  :ensure t
  :hook (rustic-mode . cargo-minor-mode))

;; =============================================================================
;; SCALA
;; =============================================================================

(use-package scala-ts-mode
  :ensure t
  :interpreter ("scala" . scala-ts-mode)
  :hook ((scala-ts-mode . lsp-deferred)
         (scala-ts-mode . apheleia-mode)
         (scala-ts-mode . flycheck-mode)))

;; SBT: Scala Build Tool integration.
(use-package sbt-mode
  :commands sbt-start sbt-command
  :config
  ;; Fix: Allow space key usage in sbt-command prompts.
  (substitute-key-definition 'minibuffer-complete-word 'self-insert-command minibuffer-local-completion-map)
  ;; Fix: Disable supershell to prevent UI corruption in Emacs.
  (setq sbt:program-options '("-Dsbt.supershell=false")))

;; =============================================================================
;; DATA & DATABASES (SQL, MONGODB, REDIS)
;; =============================================================================

(use-package sql
  :ensure nil ; Built-in
  :hook ((sql-ts-mode . lsp-deferred)
         (sql-ts-mode . apheleia-mode)
         (sql-ts-mode . flycheck-mode))
  :bind (:map sql-mode-map ("C-c C-d" . sql-connect))
  :config
  (setq sql-product 'postgres))

(use-package mongo
  :ensure t
  :mode ("\\.mongodb\\'" . mongodb-mode)
  :config
  ;; Use the modern 'mongosh' shell.
  (setq mongo-shell-program "mongosh"))

(use-package redis
  :ensure t
  :defer t
  :config
  (require 'bookmark))

;; =============================================================================
;; STRUCTURED DATA (YAML, JSON, CSV, XML)
;; =============================================================================

(use-package yaml-mode
  :ensure t
  :hook ((yaml-ts-mode . lsp-deferred)
         (yaml-ts-mode . apheleia-mode)))

(use-package json-mode
  :ensure t
  :hook ((json-ts-mode . lsp-deferred)
         (json-ts-mode . apheleia-mode)))

(use-package csv-mode
  :ensure t
  :mode ("\\.csv\\'" . csv-mode)
  :bind (:map csv-mode-map
              ("TAB" . csv-next-field)
              ("<tab>" . csv-next-field)
              ("<backtab>" . csv-previous-field)))

(use-package xml-mode
  :ensure nil
  :hook ((xml-ts-mode . lsp-deferred)
         (xml-ts-mode . apheleia-mode)))

;; =============================================================================
;; DOCKER & CONTAINERS
;; =============================================================================

(use-package dockerfile-mode
  :ensure t
  :mode "Dockerfile\\'")

(use-package docker-compose-mode
  :ensure t
  :mode "compose.*\\.ya?ml\\'")

;; Management UI for Docker containers and images.
(use-package docker
  :ensure t
  :commands (docker)
  :bind ("C-c d" . docker))

;; =============================================================================
;; MARKDOWN (WITH LIVE PREVIEW)
;; =============================================================================
;;
;; 
;;
;; This configuration uses `pandoc` to convert Markdown to HTML and renders it
;; in a local `eww` browser buffer that updates automatically as you type.

(setq exec-path (append '("/usr/local/bin") exec-path))

(use-package markdown-mode
  :ensure t
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
    "Refresh if the buffer is modified and preview window is visible."
    (when (and (buffer-modified-p) (get-buffer-window jmc-markdown-preview-buffer))
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

  ;; Shortcuts: C-c p (Start), C-c P (Stop).
  (define-key markdown-mode-map (kbd "C-c p") #'jmc-markdown-preview-split)
  (define-key markdown-mode-map (kbd "C-c P") #'jmc-markdown-preview-live-stop))

;; =============================================================================
;; DEVOPS & ENVIRONMENTS (TERRAFORM, DOTENV)
;; =============================================================================

(use-package terraform-mode
  :ensure t)

(use-package supreme-dotenv
  :ensure (:host github :repo "J4VMC/supreme-dotenv"))

;; =============================================================================
;; SHELL SUPPORT (FISH)
;; =============================================================================

;; Provides syntax highlighting and indentation for .fish script files.
;; -> Useful if you use Fish as your interactive shell (configured below).
(use-package fish-mode
  :ensure t
  :mode "\\.fish\\'"
  :hook ((fish-mode . apheleia-mode)
         (fish-mode . flycheck-mode)))

;; Provides modern Tree-sitter syntax highlighting and LSP integration for shell scripts.
;; -> Requires `bash-language-server`, `shellcheck`, and `shfmt` installed on your OS.
(use-package sh-script
  :ensure nil ; Built-in
  :mode (("\\.sh\\'" . bash-ts-mode)
         ("\\.bash\\'" . bash-ts-mode)
         ("bashrc\\'" . bash-ts-mode)
         ("zshrc\\'" . bash-ts-mode))
  :hook ((bash-ts-mode . lsp-deferred)
         (bash-ts-mode . apheleia-mode)
         (bash-ts-mode . flycheck-mode))
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
