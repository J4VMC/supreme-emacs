;;; dev.el --- All settings relevant for Software Development -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; This file configures the essential tools for a modern software development
;; workflow inside Emacs. It transforms Emacs into a fully-featured IDE.
;;
;; Key tools configured here:
;; 1. Magit: The legendary Git client for Emacs.
;; 2. Restclient: An HTTP API testing tool (similar to Postman).
;; 3. Emmet: High-speed HTML/CSS abbreviation expansion.
;; 4. Apheleia: A "hands-off" auto-formatting system (runs on save).
;; 5. Flycheck: On-the-fly syntax and error checking (the red squiggles).
;;
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

;; Magit is a full-featured, interactive Git client right inside Emacs.
;; -> It is widely considered a "killer feature" of the Emacs ecosystem.
;; 
(use-package magit
  :ensure t
  ;; Magit relies on the `transient` package to draw its pop-up menus.
  ;; -> `:after` ensures we don't try to load Magit before its dependencies are ready.
  :after transient
  ;; Bind the main entry point, `magit-status`, to `C-x g`.
  ;; -> This opens a dashboard showing your current Git state (modified files, branches, etc.).
  :bind ("C-x g" . magit-status))

;; Forge integrates Magit with Git hosting platforms (GitHub, GitLab, etc.).
;; -> Allows you to fetch issues, create pull requests, and review code without leaving Emacs.
(use-package forge
  :after magit
  :ensure t
  :bind (:map magit-mode-map
              ("@" . forge-dispatch))
  :config
  ;; Tell Forge where to find your API authentication credentials (like a GitHub Personal Access Token).
  ;; -> `~/.authinfo.gpg` is the standard, secure Emacs location for encrypted passwords.
  (setq auth-sources '("~/.authinfo.gpg"))
  (add-hook 'magit-status-sections-hook #'magit-insert-forge-pullreqs nil t)
  (add-hook 'magit-status-sections-hook #'magit-insert-forge-issues nil t)
  (add-hook 'magit-status-sections-hook #'magit-insert-forge-notifications nil t))

;; =============================================================================
;; API TESTING (RESTCLIENT)
;; =============================================================================

;; Restclient allows you to write and execute HTTP requests from a plain text file.
;; -> It replaces heavy GUI apps like Postman or Insomnia, letting you keep your
;;    API tests in source control alongside your code.
(use-package restclient
  :ensure t
  ;; Automatically enable `restclient-mode` when opening files that end in `.http`.
  :mode ("\\.http\\'" . restclient-mode)
  :config
  ;; Load an extension that adds support for writing automated assertions
  ;; (e.g., verifying that an endpoint returns a 200 OK or a specific JSON value).
  (use-package restclient-test :ensure t))

;; =============================================================================
;; WEB DEVELOPMENT (EMMET)
;; =============================================================================

;; Emmet is a plugin for high-speed HTML and CSS coding.
;; -> Example: Typing `div#page>ul.nav>li*5` and pressing TAB will instantly
;;    expand into a full HTML list structure.
(use-package emmet-mode
  :ensure t
  ;; Automatically activate Emmet when working in HTML or CSS files.
  :hook ((web-mode . emmet-mode)
         (css-mode . emmet-mode))
  :config
  ;; Tweak for React/JSX development:
  ;; -> Forces Emmet to expand with `className="foo"` (React style) instead of
  ;;    `class="foo"` (standard HTML style) when inside JSX files.
  (setq emmet-expand-jsx-className? t))

;; =============================================================================
;; AUTO-FORMATTING (APHELEIA)
;; =============================================================================
;;
;; Apheleia is our "set it and forget it" code formatter.
;; It runs CLI tools (like Prettier, Black, or Gofmt) to format your buffer
;; automatically every time you save, *without* jumping your cursor around.

(use-package apheleia
  :ensure t
  ;; Hide the "Aph" indicator from the status bar to reduce clutter.
  :diminish ""
  :config

  ;; --- 1. Define Custom Formatters ---
  ;; Apheleia knows about many tools out of the box, but we explicitly define
  ;; our preferred CLI commands here for complete control.

  ;; PHP: Use PHP Code Beautifier (`phpcbf`) enforcing the PSR12 standard.
  (setf (alist-get 'phpcs-psr12 apheleia-formatters)
        '("phpcbf" "--standard=PSR12" "--stdin-path=" (or buffer-file-name "stdin")))

  ;; Python: Use `ruff`, a blazingly fast modern Python linter/formatter.
  (setf (alist-get 'ruff apheleia-formatters)
        '("ruff" "format" "--stdin-filename" filepath "-"))

  ;; Go: Use `goimports`, which formats the code AND organizes import statements.
  (setf (alist-get 'goimports apheleia-formatters)
        '("goimports"))

  ;; Rust: Use standard `rustfmt`.
  (setf (alist-get 'rustfmt apheleia-formatters)
        '("rustfmt" "--emit=stdout"))

  ;; Scala: Use `scalafmt`.
  (setf (alist-get 'scalafmt apheleia-formatters)
        '("scalafmt" "--stdin" "--stdout"))

  ;; SQL: Use `sql-formatter` and configure it to capitalize keywords (SELECT, FROM).
  (setf (alist-get 'sql-formatter apheleia-formatters)
        '("sql-formatter"
          "--language" "postgresql"
          "--indent" "2"
          "--uppercase"))

  ;; --- 2. Associate Modes with Formatters ---
  ;; Map Emacs language modes (e.g., `python-ts-mode`) to the formatter names defined above.

  ;; PHP
  (setf (alist-get 'php-ts-mode apheleia-mode-alist) 'phpcs-psr12)

  ;; Python (covers both standard and Tree-sitter modes)
  (setf (alist-get 'python-mode apheleia-mode-alist) 'ruff)
  (setf (alist-get 'python-ts-mode apheleia-mode-alist) 'ruff)

  ;; Go
  (setf (alist-get 'go-mode apheleia-mode-alist) 'goimports)
  (setf (alist-get 'go-ts-mode apheleia-mode-alist) 'goimports)

  ;; Rust
  (setf (alist-get 'rust-ts-mode apheleia-mode-alist) 'rustfmt)

  ;; Scala
  (setf (alist-get 'scala-ts-mode apheleia-mode-alist) 'scalafmt)

  ;; SQL
  (setf (alist-get 'sql-mode apheleia-mode-alist) 'sql-formatter)
  (setf (alist-get 'sql-ts-mode apheleia-mode-alist) 'sql-formatter)

  ;; Web Technologies (JavaScript, TypeScript, HTML, CSS, JSON, YAML, Markdown)
  ;; -> These all utilize the built-in `prettier` configurations provided by Apheleia.
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
  ;; Activate Apheleia everywhere. It will remain dormant until you edit a file
  ;; whose major mode is explicitly listed in the mapping above.
  (apheleia-global-mode t))

;; =============================================================================
;; ON-THE-FLY SYNTAX CHECKING (FLYCHECK)
;; =============================================================================
;;
;; Flycheck is the engine that provides inline error highlighting (red squiggles)
;; for syntax errors, style warnings, and linter issues as you type.
;; 

(use-package flycheck
  :ensure t
  :hook (prog-mode . flycheck-mode)
  :bind (:map flycheck-mode-map
              ;; Easy navigation between errors in the current file.
              ("M-n" . flycheck-next-error)     ; Jump to the next error
              ("M-p" . flycheck-previous-error)) ; Jump to the previous error
  :config

  ;; --- Custom Checker Definitions ---
  ;; Teach Flycheck how to use command-line linters it doesn't know natively.
  ;; We define the command to run, and a Regular Expression to parse the output.

  ;; TypeScript (`tsc`)
  (flycheck-define-checker typescript-tsc-syntax
    "A TypeScript syntax checker using tsc."
    :command ("tsc"
              "--noEmit"         ; Do not compile JS files, strictly type-check.
              "--pretty" "false" ; Output machine-readable, plain text errors.
              source-inplace)
    :error-patterns
    ((error line-start (file-name) "(" line "," column "): error TS"
            (message) line-end))
    :modes (typescript-ts-mode tsx-ts-mode))

  ;; Python (`ruff`)
  (flycheck-define-checker python-ruff
    "A Python syntax and style checker using Ruff."
    :command ("ruff" "check"
              ;; Explicitly select standard rule categories (Errors, Flakes, Warnings, etc.)
              "--select" "E,F,W,D,UP,B,SIM,S"
              "--output-format" "concise"
              "--stdin-filename" source-inplace
              "-")
    :standard-input t ; Feed code via standard input so it lints unsaved changes.
    :error-patterns
    ((error line-start (file-name) ":" line ":" column ": " (message) line-end))
    :modes (python-mode python-ts-mode))

  ;; SQL (`sqlint`)
  (flycheck-define-checker sql-sqlint
    "A SQL syntax checker using sqlint."
    :command ("sqlint")
    :standard-input t
    :error-patterns
    ((error line-start "stdin:" line ":" column ":ERROR " (message) line-end)
     (warning line-start "stdin:" line ":" column ":WARNING " (message) line-end))
    :modes (sql-mode sql-ts-mode))
  
  ;; Fish
  (flycheck-define-checker fish
    "A Fish shell syntax checker using `fish -n`."
    :command ("fish" "-n" source)
    :error-patterns
    ((error line-start (file-name) " (line " line "): " (message) line-end))
    :modes fish-mode)

  ;; --- Registering Checkers ---
  ;; Add our custom checkers to Flycheck's active roster.
  (add-to-list 'flycheck-checkers 'fish)
  (add-to-list 'flycheck-checkers 'sql-sqlint)

  ;; Tweak the built-in PHP checker (`phpcs`) to match our Apheleia PSR12 formatting.
  (setq flycheck-phpcs-standard "PSR12"))

;; =============================================================================
;; FLYCHECK "CHAINING" & ADD-ONS
;; =============================================================================
;;
;; "Chaining" prevents duplicate/noisy errors.
;; -> Example: Both your LSP server and your local linter (like Ruff) might report
;;    "unused import." By chaining them, we tell Flycheck: "Run the fast LSP checks
;;    first. Only if those pass, run the deeper linter checks."

;; Python: Let LSP run first, then fallback to `python-ruff`.
(add-hook 'lsp-mode-hook
          (lambda ()
            (when (derived-mode-p 'python-mode 'python-ts-mode)
              (flycheck-add-next-checker 'lsp 'python-ruff))))

;; Go: Let LSP run first, then fallback to `golangci-lint`.
(add-hook 'lsp-mode-hook
          (lambda ()
            (when (derived-mode-p 'go-mode 'go-ts-mode)
              (flycheck-add-next-checker 'lsp 'golangci-lint))))

;; SQL: Let LSP run first, then fallback to `sql-sqlint`.
(add-hook 'lsp-mode-hook
          (lambda ()
            (when (derived-mode-p 'sql-mode 'sql-ts-mode)
              (flycheck-add-next-checker 'lsp 'sql-sqlint))))

;; --- Language-Specific Flycheck Extensions ---
;; Community-provided packages that wire up complex linters automatically.

;; Go: Integrates the powerful `golangci-lint` tool.
(use-package flycheck-golangci-lint
  :ensure t
  :defer t
  :after flycheck
  :hook ((go-mode . flycheck-golangci-lint-setup)
         (go-ts-mode . flycheck-golangci-lint-setup)))

;; Rust: Integrates `cargo check` and `clippy`.
(use-package flycheck-rust
  :ensure t
  :defer t
  :after flycheck
  :hook (rust-ts-mode . flycheck-rust-setup))

;; PHP: Integrates `phpstan` (a strict static analyzer for PHP).
(use-package flycheck-phpstan
  :ensure t
  :defer t
  :after flycheck)

(defun jmc-php-setup-h ()
  "Enable Flycheck and PHPStan analysis when entering a PHP buffer."
  (require 'flycheck-phpstan)
  (flycheck-mode 1))

(add-hook 'php-ts-mode-hook #'jmc-php-setup-h)

;; Scala: The LSP server (Metals) handles all linting internally.
;; -> We just ensure Flycheck is turned on so the LSP errors have a UI to display on.
(add-hook 'lsp-mode-hook
          (lambda ()
            (when (derived-mode-p 'scala-ts-mode)
              (flycheck-mode 1))))

;; =============================================================================
;; QUICK-RUN
;; =============================================================================

;; `quickrun` provides a universal command to execute the file you are currently
;; viewing, regardless of the programming language.
;; -> Perfect for instantly testing a Python script, Go snippet, or shell script.
(use-package quickrun
  :ensure t
  ;; Bind to `Super-r` (Command-r on Mac, Win-r on Windows).
  :bind ("s-r" . quickrun))

;; =============================================================================
;; PACKAGE-LINT
;; =============================================================================

;; A linter specifically for developers writing their own Emacs Lisp packages.
(use-package package-lint
  :ensure t
  :defer t)

;; =============================================================================
;; FINALIZE
;; =============================================================================

;; Register this file as a loaded feature.
;; -> Allows `(require 'dev)` in `init.el` to successfully load this module.
(provide 'dev)

;;; dev.el ends here
