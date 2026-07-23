;;; lang-server.el --- Language Server Protocol (LSP) Configuration -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; This file configures `lsp-mode`, the engine that turns Emacs into a
;; powerhouse IDE.
;;
;; ### Why is this file NOT called lsp.el? ⚠️
;; lsp-mode itself ships a library file named `lsp.el` (feature `lsp`).
;; Because our `modules/` directory sits at the front of `load-path`, a
;; module named `lsp.el` SHADOWS that library: any `(require 'lsp)` — from
;; lsp-mode internals or third-party packages — could load this config file
;; instead of the real library, depending on load-path ordering at that
;; moment. Renaming the module removes the collision entirely.
;;
;; ### What is LSP? 🧐
;; Language Server Protocol (LSP) is a standardized way for Emacs to talk to
;; external "Language Servers" (like `basedpyright` for Python or `gopls` for Go).
;;
;; Think of the Server as the "brain": it does the heavy lifting of parsing
;; code, while Emacs acts as the "face": the UI where you see the results.
;;
;; ### Key Features Provided:
;; * **Navigation**: Jump to Definition (`M-.`) and Find References (`M-?`).
;; * **Intelligence**: Context-aware autocompletion and hover documentation.
;; * **Diagnostics**: Real-time error highlighting and linting.
;; * **Refactoring**: Project-wide symbol renaming.
;;
;;; Code:

;; =============================================================================
;; COMPILER DECLARATIONS (SILENCE WARNINGS)
;; =============================================================================

(defvar lsp-use-plists)
(defvar lsp-mode-map)
(defvar lsp-ui-doc-enable)
(defvar lsp-ui-doc-use-childframe)
(defvar lsp-ui-doc-show-with-cursor)
(defvar lsp-ui-doc-include-signature)
(defvar lsp-ui-doc-position)
(defvar lsp-language-id-configuration)
(defvar lsp-tailwindcss-add-on-mode)
(defvar lsp-tailwindcss-major-modes)
(defvar lsp-metals-server-args)
(defvar lsp-metals-show-implicit-arguments)
(defvar lsp-metals-show-implicit-conversions-and-classes)
(defvar lsp-metals-show-inferred-type)
(defvar lsp-pyright-workspace-config)
(defvar lsp-pyright-multi-root)
(defvar lsp-rust-analyzer-cargo-watch-command)
(defvar lsp-rust-analyzer-server-display-inlay-hints)
(defvar lsp-rust-analyzer-display-lifetime-elision-hints-enable)
(defvar lsp-rust-analyzer-display-chaining-hints)
(defvar lsp-rust-analyzer-display-closure-return-type-hints)
(defvar lsp-go-analyses)
(defvar lsp-go-use-gofumpt)

(declare-function lsp-deferred "lsp-mode")
(declare-function projectile-project-root "projectile")
(declare-function lsp-register-client "lsp-mode")
(declare-function make-lsp-client "lsp-mode")
(declare-function lsp-stdio-connection "lsp-mode")

;; =============================================================================
;; LSP MODE CORE
;; =============================================================================

(use-package lsp-mode
  :diminish "LSP"
  :defer t
  :hook (;; Enable visual error underlining (diagnostics) immediately.
         (lsp-mode . lsp-diagnostics-mode)
         ;; Show keybinding hints for LSP commands via `which-key`.
         (lsp-mode . lsp-enable-which-key-integration))
  :custom
  ;; --- Basic Navigation ---

  ;; Prefix for all LSP-related commands.
  ;; -> Example: `C-c l r r` triggers a symbol rename.
  (lsp-keymap-prefix "C-c l")

  ;; --- Performance & Reliability ---

  ;; **IMPORTANT**: Hand off the completion UI to dedicated packages.
  ;; -> We use `corfu` for the actual pop-ups; LSP just provides the data.
  (lsp-completion-provider :none)

  ;; Use `flycheck` as the primary engine for displaying code errors.
  (lsp-diagnostics-provider :flycheck)

  ;; Persistence: Save server session data to avoid re-indexing on every restart.
  (lsp-session-file (locate-user-emacs-file ".lsp-session"))

  ;; **PERFORMANCE**: Disable IO logging.
  ;; -> Enabling this (`t`) will slow Emacs down significantly; use only for debugging.
  (lsp-log-io nil)
  (lsp-keep-workspace-alive nil)

  ;; Delay (seconds) after you stop typing before LSP checks for errors.
  (lsp-idle-delay 0.5)

  ;; --- Feature Toggles ---

  (lsp-enable-xref t)               ; Required for "Go to Definition".
  (lsp-auto-configure t)            ; Let LSP attempt to set up servers automatically.
  (lsp-eldoc-enable-hover t)        ; Show function signatures in the bottom bar.

  ;; DISABLED: this bridged LSP launch settings over to `dap-mode`, which we
  ;; replaced with `dape` (see debugger.el). lsp-mode guards the feature with
  ;; `(functionp 'dap-mode)` so leaving it on was a silent no-op, but nil
  ;; documents the migration and skips the check.
  (lsp-enable-dap-auto-configure nil)

  (lsp-enable-snippet nil)          ; Snippets are routed through Tempel instead.

  ;; **PERFORMANCE**: Disable built-in file watching.
  ;; -> This can be a massive resource hog in large projects.
  (lsp-enable-file-watchers nil)

  (lsp-enable-folding t)            ; Enable code folding support.
  (lsp-enable-imenu t)              ; Populate the `imenu` with functions/classes.
  (lsp-enable-indentation t)        ; Let LSP manage indentation (language dependent).
  (lsp-enable-links t)              ; Make URLs/paths clickable in code.
  (lsp-enable-on-type-formatting t) ; Auto-format small triggers (like adding `}`).
  (lsp-enable-suggest-server-download t) ; Prompt to download missing binaries.
  (lsp-enable-symbol-highlighting t) ; Highlight all instances of the word under cursor.

  ;; --- Visual UI Settings ---

  ;; Breadcrumbs: Show `Project > Folder > File > Function` at the top of the window.
  (lsp-headerline-breadcrumb-enable t)
  (lsp-headerline-breadcrumb-enable-diagnostics nil)
  (lsp-headerline-breadcrumb-enable-symbol-numbers nil)
  (lsp-headerline-breadcrumb-icons-enable nil)

  ;; **PERFORMANCE**: Clean up the status bar (modeline).
  ;; -> Removes redundant icons and "lightbulbs" to keep the UI snappy.
  (lsp-modeline-code-actions-enable nil)
  (lsp-modeline-diagnostics-enable nil)
  (lsp-modeline-workspace-status-enable nil)

  ;; --- Documentation & Hover ---

  (lsp-signature-doc-lines 1)       ; Limit signature help to one line.
  (lsp-eldoc-render-all nil)        ; Only show info for the specific symbol at point.

  ;; **PERFORMANCE**: Disable Code Lens & Semantic Tokens.
  ;; -> We use Tree-sitter for high-speed syntax highlighting; LSP tokens are
  ;;    redundant. (dev.el re-enables lenses per-buffer for Scala only.)
  (lsp-lens-enable nil)
  (lsp-semantic-tokens-enable nil)

  :init
  ;; **CRITICAL PERFORMANCE**: Enable faster data parsing via plists.
  ;; -> Pairs with the `LSP_USE_PLISTS` env var set in early-init.el.
  (setq lsp-use-plists t))

;; =============================================================================
;; LANGUAGE-SPECIFIC OVERRIDES
;; =============================================================================
;;
;; In the JS/TS ecosystem, we want `apheleia` (Prettier) to be the absolute
;; authority on formatting. We disable LSP formatting here to prevent conflicts.

(add-hook 'typescript-ts-mode-hook
          (lambda ()
            (setq-local lsp-enable-indentation nil)
            (setq-local lsp-enable-on-type-formatting nil)))

(add-hook 'tsx-ts-mode-hook
          (lambda ()
            (setq-local lsp-enable-indentation nil)
            (setq-local lsp-enable-on-type-formatting nil)))

(add-hook 'js-ts-mode-hook
          (lambda ()
            (setq-local lsp-enable-indentation nil)
            (setq-local lsp-enable-on-type-formatting nil)))

;; =============================================================================
;; COMPLETION & UI INTEGRATION
;; =============================================================================

;; Completion "Glue": Connects LSP data to the `corfu` autocomplete UI.
;; -> `:ensure nil` is REQUIRED: `lsp-completion` is a library INSIDE the
;;    lsp-mode package, not a package of its own. With
;;    `use-package-always-ensure` (init.el), omitting it makes Elpaca try to
;;    install a nonexistent "lsp-completion" package on every startup.
(use-package lsp-completion
  :ensure nil
  :no-require
  :hook ((lsp-mode . lsp-completion-mode)))

;; LSP UI: Manages the "pretty" visual elements.
(use-package lsp-ui
  :defer t
  :commands (lsp-ui-doc-show lsp-ui-doc-glance)
  :bind (:map lsp-mode-map
              ;; Map `C-c C-d` to "glance" at documentation in a floating window.
              ;; NOTE: minor-mode maps outrank BOTH the global map and major
              ;; mode maps, so in every LSP buffer this shadows the global
              ;; `helpful-at-point` binding (interface.el) — intentional:
              ;; in code, LSP hover docs beat elisp help.
              ("C-c C-d" . 'lsp-ui-doc-glance))
  :after (lsp-mode)
  :config
  (setq lsp-ui-doc-enable t)
  ;; Use "childframes": sleek, floating pop-up windows for documentation.
  ;; -> (Moved here from the lsp-mode block: it's an lsp-ui variable.)
  (setq lsp-ui-doc-use-childframe t)
  (setq lsp-ui-doc-show-with-cursor nil) ; Don't show on every move; only on command.
  (setq lsp-ui-doc-include-signature t)
  (setq lsp-ui-doc-position 'at-point)) ; Pop up right at the cursor.

;; Consult-LSP: Integrate LSP search with our fuzzy-finding UI.
(use-package consult-lsp
  :defer t
  :after (consult lsp-mode))

;; Treemacs-LSP: Show error icons and health status in the file sidebar.
(use-package lsp-treemacs
  :defer t
  :after (lsp-mode treemacs))

;; =============================================================================
;; LANGUAGE SERVER EXTENSIONS
;; =============================================================================

;; --- Java (Eclipse JDTLS) ---
(use-package lsp-java
  :defer t
  :after lsp-mode
  :hook (java-ts-mode . (lambda ()
                          (require 'lsp-java)
                          (lsp-deferred))))

;; --- ESLint (JS/TS) ---
;; -> `:ensure nil`: `lsp-eslint` ships inside lsp-mode (clients/lsp-eslint.el);
;;    it is NOT a standalone package (same always-ensure trap as above).
(use-package lsp-eslint
  :ensure nil
  :defer t
  :after lsp-mode
  :custom
  (lsp-eslint-auto-fix-on-save nil) ; Handled by Apheleia.
  (lsp-eslint-enable t)
  (lsp-eslint-package-manager "npm")
  (lsp-eslint-server-command '("vscode-eslint-language-server" "--stdio"))
  :config
  ;; Teach ESLint about our Tree-sitter major modes.
  (add-to-list 'lsp-language-id-configuration '(typescript-ts-mode . "typescript"))
  (add-to-list 'lsp-language-id-configuration '(tsx-ts-mode . "typescriptreact"))
  (add-to-list 'lsp-language-id-configuration '(js-ts-mode . "javascript")))

;; --- TailwindCSS ---
(use-package lsp-tailwindcss
  :defer t
  :init (setq lsp-tailwindcss-add-on-mode t)
  :config
  (dolist (tw-major-mode
           '(css-mode css-ts-mode typescript-mode typescript-ts-mode tsx-ts-mode js2-mode js-ts-mode clojure-mode))
    (add-to-list 'lsp-tailwindcss-major-modes tw-major-mode)))

;; --- Scala (Metals) ---
(use-package lsp-metals
  :defer t
  :hook (scala-ts-mode . (lambda ()
                           (require 'lsp-metals)
                           ;; `lsp-deferred` ensures the server only starts when needed.
                           (lsp-deferred)))
  :config
  (setq lsp-metals-server-args '("-J-Dmetals.allow-multiline-string-formatting=off")
        lsp-metals-show-implicit-arguments t
        lsp-metals-show-implicit-conversions-and-classes t
        lsp-metals-show-inferred-type t))

;; --- Python (Basedpyright) ---
(use-package lsp-pyright
  :defer t
  ;; We use `basedpyright`, a more feature-rich community fork of Microsoft's Pyright.
  :custom
  (lsp-pyright-langserver-command "basedpyright")
  (lsp-pyright-python-executable-cmd "python3")
  :hook (python-ts-mode . (lambda ()
                            (require 'lsp-pyright)
                            (lsp-deferred)))
  :preface
  (defun jmc-set-pyright-paths ()
    "Dynamically detect project root to calibrate Pyright."
    (let ((project-root (projectile-project-root)))
      (when project-root
        (setq lsp-pyright-workspace-config
              `(:python.analysis.extraPaths [,project-root])))))
  :init
  ;; ONE pyright per project, not one shared multi-root server.
  ;; -> lsp-pyright registers its client as multi-root by default: every
  ;;    python project gets FOLDED into a single server as an extra
  ;;    workspace folder. With overlapping roots in the lsp session
  ;;    (e.g. a monorepo root AND a sub-project inside it), a file under
  ;;    both matches twice — "Received redundant open text document
  ;;    command" warnings, doubled "Connected to pyright" messages, and
  ;;    potentially duplicated diagnostics. Per-project servers also
  ;;    keep each project's own .venv (pyvenv, languages.el) cleanly
  ;;    separated.
  ;; -> MUST be set before lsp-pyright loads: the flag is captured at
  ;;    client registration, so flipping it later has no effect. After
  ;;    changing this, stale sessions need `M-x lsp-workspace-remove-all-folders'
  ;;    (or delete .lsp-session) once.
  (setq lsp-pyright-multi-root nil)

  ;; Hook on `python-base-mode-hook`, which BOTH python-mode and
  ;; python-ts-mode run. The old hook was on `python-mode-hook`, which
  ;; python-ts-mode does NOT run — so the workspace paths were never set
  ;; for the ts buffers our files actually open in.
  (add-hook 'python-base-mode-hook #'jmc-set-pyright-paths))


;; --- Rust (rust-analyzer) ---
;; -> `:ensure nil`: `lsp-rust` also ships inside lsp-mode (clients/lsp-rust.el).
;; -> The old `rust-ts-mode` hook was removed: `.rs` files open in
;;    `rustic-mode` (languages.el), so that hook never fired. lsp-mode loads
;;    `lsp-rust` itself when a Rust buffer starts LSP, at which point the
;;    `:config` below applies.
(use-package lsp-rust
  :ensure nil
  :defer t
  :config
  ;; Use `clippy` as the background checker for superior Rust linting.
  (setq lsp-rust-analyzer-cargo-watch-command "clippy"
        lsp-rust-analyzer-server-display-inlay-hints t
        lsp-rust-analyzer-display-lifetime-elision-hints-enable "skip_trivial"
        lsp-rust-analyzer-display-chaining-hints t
        lsp-rust-analyzer-display-closure-return-type-hints t))

;; =============================================================================
;; BUILT-IN & MANUAL SERVER REGISTRATION
;; =============================================================================

;; --- Go (gopls) ---
;; -> The duplicate `go-ts-mode-hook` -> lsp-deferred was removed: languages.el
;;    already installs that hook. Only the server settings live here.
(with-eval-after-load 'lsp-mode
  (setq lsp-go-analyses '((nilness . t) (unusedwrite . t) (unusedparams . t))
        lsp-go-use-gofumpt t)) ; Use the stricter 'gofumpt' formatter.

;; --- SQL (sql-language-server) ---
;; -> The `sql-ts-mode-hook` was removed: that mode does not exist (see
;;    languages.el). LSP startup for SQL buffers is handled by dev.el via
;;    `hack-local-variables-hook`, so `.dir-locals.el` database connections
;;    are read BEFORE the server boots.
(with-eval-after-load 'lsp-mode
  (lsp-register-client
   (make-lsp-client
    :new-connection (lsp-stdio-connection '("sql-language-server" "up" "--method" "stdio"))
    :major-modes '(sql-mode)
    :priority -1
    :server-id 'sql-ls)))

;; =============================================================================
;; FINALIZE
;; =============================================================================

(provide 'lang-server)

;;; lang-server.el ends here
