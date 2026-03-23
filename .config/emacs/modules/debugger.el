;;; debugger.el --- All necessary tools for debugging -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; This file configures `dap-mode` (Debug Adapter Protocol).
;;
;; Key frameworks supported:
;; 1. PHP: Symfony (Docker Skeleton), Laravel (Sail), Laminas (Local).
;; 2. Go: Delve (dlv).
;; 3. Python: debugpy (Flask, Django, FastAPI).
;; 4. JS/TS: Node.js.
;; 5. Rust/C++: LLDB.
;;
;;; Code:

;; =============================================================================
;; COMPILER DECLARATIONS
;; =============================================================================

(defvar jmc-dap-prefix-map)
(defvar dap-python-executable)
(defvar dap-print-io)

(declare-function dap-breakpoint-toggle "dap-mode")
(declare-function dap-breakpoint-delete-all "dap-mode")
(declare-function dap-debug "dap-mode")
(declare-function dap-next "dap-mode")
(declare-function dap-step-in "dap-mode")
(declare-function dap-step-out "dap-mode")
(declare-function dap-continue "dap-mode")
(declare-function dap-debug-edit-template "dap-mode")
(declare-function dap-switch-stack-frame "dap-mode")
(declare-function dap-debug-last "dap-mode")
(declare-function dap-disconnect "dap-mode")
(declare-function dap-debug-recent "dap-mode")
(declare-function dap-gdb-lldb-setup "dap-gdb-lldb")
(declare-function dap-register-debug-template "dap-mode")
(declare-function dap-hydra "dap-hydra")
(declare-function dap-ui-controls-mode "dap-ui")

;; =============================================================================
;; DAP MODE CORE
;; =============================================================================

(use-package dap-mode
  :ensure t
  :after lsp-mode
  :init
  ;; --- Keybinding Setup ---
  (define-prefix-command 'jmc-dap-prefix-map)
  (global-set-key (kbd "C-c d") 'jmc-dap-prefix-map)

  (define-key jmc-dap-prefix-map (kbd "b") #'dap-breakpoint-toggle)
  (define-key jmc-dap-prefix-map (kbd "B") #'dap-breakpoint-delete-all)
  (define-key jmc-dap-prefix-map (kbd "d") #'dap-debug)
  (define-key jmc-dap-prefix-map (kbd "n") #'dap-next)
  (define-key jmc-dap-prefix-map (kbd "i") #'dap-step-in)
  (define-key jmc-dap-prefix-map (kbd "o") #'dap-step-out)
  (define-key jmc-dap-prefix-map (kbd "c") #'dap-continue)
  (define-key jmc-dap-prefix-map (kbd "e") #'dap-debug-edit-template)
  (define-key jmc-dap-prefix-map (kbd "w") #'dap-switch-stack-frame)
  (define-key jmc-dap-prefix-map (kbd "l") #'dap-debug-last)
  (define-key jmc-dap-prefix-map (kbd "r") #'dap-disconnect)
  (define-key jmc-dap-prefix-map (kbd "R") #'dap-debug-recent)

  :hook
  ((lsp-mode . dap-mode)
   (lsp-mode . dap-ui-mode))

  :config
  ;; Load UI and controls
  (require 'dap-ui)
  (dap-ui-mode 1)
  (dap-ui-controls-mode 1)

  ;; Setup Hydra to pop up when the debugger stops at a breakpoint
  (add-hook 'dap-stopped-hook (lambda (_arg) (call-interactively #'dap-hydra))))

;; =============================================================================
;; LANGUAGE-SPECIFIC ADAPTERS & TEMPLATES
;; =============================================================================

;; --- PHP (Symfony, Laravel, Laminas) ---
(use-package dap-php
  :ensure nil
  :after dap-mode
  :hook (php-ts-mode . dap-php-setup)
  :config
  ;; 1. Local Development (Symfony CLI, Artisan Serve, Laminas Local)
  (dap-register-debug-template "PHP :: Listen for XDebug (Local)"
			       (list :type "php"
				     :request "launch"
				     :name "PHP :: Listen for XDebug (Local)"
				     :port 9003
				     :sourceMaps t))

  ;; 2. Symfony Docker Skeleton (Official)
  ;; Maps the container's WORKDIR /app to your local workspace.
  (dap-register-debug-template "PHP :: Symfony Docker (Skeleton)"
			       (list :type "php"
				     :request "launch"
				     :name "PHP :: Symfony Docker (Skeleton)"
				     :port 9003
				     :pathMappings (ht ("/app" "${workspaceFolder}"))
				     :hostname "0.0.0.0"
				     :sourceMaps t))

  ;; 3. Laravel Sail / Generic Docker
  ;; Laravel Sail typically uses /var/www/html.
  (dap-register-debug-template "PHP :: Laravel Sail"
			       (list :type "php"
				     :request "launch"
				     :name "PHP :: Laravel Sail"
				     :port 9003
				     :pathMappings (ht ("/var/www/html" "${workspaceFolder}"))
				     :sourceMaps t)))

;; --- Python ---
(use-package dap-python
  :ensure nil
  :after dap-mode
  :hook (python-ts-mode . dap-python-setup)
  :preface
  (defun jmc-dap-python-get-executable ()
    "Return the active venv Python path, falling back to system python3."
    (let ((venv (getenv "VIRTUAL_ENV")))
      (if (and venv (not (string-empty-p venv)))
	  (expand-file-name "bin/python3" venv)
	"python3")))
  :config
  (setq dap-python-executable (jmc-dap-python-get-executable))

  (dap-register-debug-template "Python :: Debug (Flask)"
			       (list :type "python" :args "" :cwd nil
				     :env '(("FLASK_APP" . "app:app") ("FLASK_ENV" . "development"))
				     :module "flask" :name "Python :: Debug (Flask)"))

  (dap-register-debug-template "Python :: Debug (Django)"
			       (list :type "python" :args "manage.py runserver" :cwd nil
				     :name "Python :: Debug (Django)")))

;; --- Go ---
(use-package dap-dlv-go
  :ensure nil
  :after dap-mode
  :hook (go-ts-mode . dap-go-setup)
  :config
  (dap-register-debug-template "Go :: Debug (Current File)"
			       (list :type "go" :name "Go :: Debug (Current File)" :mode "debug"
				     :request "launch" :program "${file}")))

;; --- JS / Node ---
(use-package dap-node
  :ensure nil
  :after dap-mode
  :hook ((js-ts-mode typescript-ts-mode tsx-ts-mode) . dap-node-setup))

;; --- Rust (via CodeLLDB) ---
(use-package dap-codelldb
  :ensure nil
  :after dap-mode
  :config
  (dap-register-debug-template "Rust :: Debug (CodeLLDB)"
			       (list :type "lldb"  ; <--- THIS WAS THE CULPRIT. It must be "lldb"
				     :name "Rust :: Debug (CodeLLDB)"
				     :request "launch"
				     :cargo (list :args '("build"))
				     :program "${workspaceFolder}/target/debug/${workspaceFolderBasename}"
				     :cwd "${workspaceFolder}")))

;; =============================================================================
;; DAP UI WINDOW LAYOUT
;; =============================================================================

(use-package dap-ui
  :ensure nil
  :after dap-mode
  :custom
  (dap-ui-buffer-configurations
   `((,(regexp-quote "*dap-ui-locals*")      . ((side . right) (slot . 1) (window-width . 0.20)))
     (,(regexp-quote "*dap-ui-expressions*") . ((side . right) (slot . 2) (window-width . 0.20)))
     (,(regexp-quote "*dap-ui-breakpoints*") . ((side . left)  (slot . 2) (window-width . 0.20)))
     (,(regexp-quote "*dap-ui-sessions*")    . ((side . left)  (slot . 3) (window-width . 0.20))))))

;; =============================================================================
;; FINALIZE
;; =============================================================================

(provide 'debugger)
;;; debugger.el ends here
