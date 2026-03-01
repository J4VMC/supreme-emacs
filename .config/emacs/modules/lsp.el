;;; lsp.el --- Language Server Protocol (LSP) Configuration -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; This file configures `lsp-mode`, the engine that turns Emacs into a
;; powerhouse IDE.
;;
;; ### What is LSP? 🧐
;; Language Server Protocol (LSP) is a standardized way for Emacs to talk to
;; external "Language Servers" (like `pyright` for Python or `gopls` for Go).
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
  :ensure t
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
  (lsp-enable-dap-auto-configure t) ; Bridge settings over to the debugger (`dap-mode`).

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
  ;; 
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
  ;; Use "childframes": sleek, floating pop-up windows for documentation.
  (lsp-ui-doc-use-childframe t)
  (lsp-eldoc-render-all nil)        ; Only show info for the specific symbol at point.

  ;; **PERFORMANCE**: Disable Code Lens & Semantic Tokens.
  ;; -> We use Tree-sitter for high-speed syntax highlighting; LSP tokens are redundant.
  (lsp-lens-enable nil)
  (lsp-semantic-tokens-enable nil)

  :init
  ;; **CRITICAL PERFORMANCE**: Enable faster data parsing via plists.
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
(use-package lsp-completion
  :no-require
  :hook ((lsp-mode . lsp-completion-mode)))

;; LSP UI: Manages the "pretty" visual elements.
(use-package lsp-ui
  :ensure t
  :defer t
  :commands (lsp-ui-doc-show lsp-ui-doc-glance)
  :bind (:map lsp-mode-map
              ;; Map `C-c C-d` to "glance" at documentation in a floating window.
              ("C-c C-d" . 'lsp-ui-doc-glance))
  :after (lsp-mode)
  :config
  (setq lsp-ui-doc-enable t)
  (setq lsp-ui-doc-show-with-cursor nil) ; Don't show on every move; only on command.
  (setq lsp-ui-doc-include-signature t)
  (setq lsp-ui-doc-position 'at-point)) ; Pop up right at the cursor.

;; Consult-LSP: Integrate LSP search with our fuzzy-finding UI.
(use-package consult-lsp
  :ensure t
  :defer t
  :after (consult lsp-mode))

;; Treemacs-LSP: Show error icons and health status in the file sidebar.
(use-package lsp-treemacs
  :ensure t
  :defer t
  :after (lsp-mode treemacs))

;; =============================================================================
;; LANGUAGE SERVER EXTENSIONS
;; =============================================================================

;; --- ESLint (JS/TS) ---
(use-package lsp-eslint
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
  :ensure t
  :defer t
  :init (setq lsp-tailwindcss-add-on-mode t)
  :config
  (dolist (tw-major-mode
           '(css-mode css-ts-mode typescript-mode typescript-ts-mode tsx-ts-mode js2-mode js-ts-mode clojure-mode))
    (add-to-list 'lsp-tailwindcss-major-modes tw-major-mode)))

;; --- Scala (Metals) ---
(use-package lsp-metals
  :ensure t
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
  :ensure t
  :defer t
  ;; We use `basedpyright`, a more feature-rich community fork of Microsoft's Pyright.
  :custom (lsp-pyright-langserver-command "basedpyright")
  (lsp-pyright-python-executable-cmd "python3")
  :hook (python-ts-mode . (lambda ()
                            (require 'lsp-pyright)
                            (lsp-deferred)))
  :preface
  (defun jmc-set-pyright-paths ()
    "Dynamically detect project root and Python version to calibrate Pyright."
    (let ((project-root (projectile-project-root)))
      (when project-root
        ;; Ask the currently active Python for its major.minor version (e.g., "3.12")
        (let* ((py-version-cmd "python3 -c 'import sys; print(f\"{sys.version_info.major}.{sys.version_info.minor}\")'")
               (py-version-clean (string-trim (shell-command-to-string py-version-cmd))))
          
          (setq lsp-pyright-workspace-config
                `(:python.analysis.extraPaths [,project-root]
					      :pythonVersion ,py-version-clean))))))
  :init
  (add-hook 'python-mode-hook #'jmc-set-pyright-paths))


;; --- Rust (rust-analyzer) ---
(use-package lsp-rust
  :after lsp-mode
  :defer t
  :hook (rust-ts-mode . (lambda ()
                          (require 'lsp-rust)
                          (lsp-deferred)))
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
(with-eval-after-load 'lsp-mode
  (add-hook 'go-ts-mode-hook #'lsp-deferred)
  (setq lsp-go-analyses '((fieldalignment . t) (nilness . t) (unusedwrite . t) (unusedparams . t))
        lsp-go-use-gofumpt t)) ; Use the stricter 'gofumpt' formatter.

;; --- SQL (sql-language-server) ---
(with-eval-after-load 'lsp-mode
  (add-hook 'sql-ts-mode-hook #'lsp-deferred)
  (lsp-register-client
   (make-lsp-client
    :new-connection (lsp-stdio-connection '("sql-language-server" "up" "--method" "stdio"))
    :major-modes '(sql-mode sql-ts-mode)
    :priority -1
    :server-id 'sql-ls)))

;; =============================================================================
;; FINALIZE
;; =============================================================================

(provide 'lsp)

;;; lsp.el ends here
