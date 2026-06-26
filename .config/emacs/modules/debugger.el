;;; debugger.el --- All necessary tools for debugging -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; This file configures `dape` (Debug Adapter Protocol for Emacs).
;; It replaces `dap-mode` with a native, lightweight, and strictly declarative
;; configuration architecture based on Emacs 29+ JSON-RPC.
;;
;; Key frameworks supported:
;; 1. PHP: Symfony (Docker Skeleton), Laravel (Sail), Laminas (Local).
;; 2. Go: Delve (dlv).
;; 3. Python: debugpy (Flask, Django).
;; 4. JS/TS: Node.js, NPM Scripts, Chrome Frontend.
;; 5. Rust/C++: LLDB.
;;
;;; Code:

(defvar jmc-dap-prefix-map)

;; =============================================================================
;; UTILITY FUNCTIONS
;; =============================================================================

(defun jmc-get-workspace-root ()
  "Safely grab the project root, falling back to the current directory.
This replaces internal dape functions to ensure update-proof stability."
  (if-let ((proj (project-current)))
      (expand-file-name (project-root proj))
    (expand-file-name default-directory)))

(defun jmc-python-venv-bin ()
  "Helper to find the local .venv python binary for Dape."
  (let ((venv (locate-dominating-file default-directory ".venv")))
    (if venv (expand-file-name ".venv/bin/python" venv) "python3")))

;; =============================================================================
;; DAPE CORE & KEYBINDINGS
;; =============================================================================

(use-package dape
  :ensure t
  :init
  ;; --- Keybinding Setup ---
  ;; We keep your exact C-c d prefix, but map it to dape's native functions.
  (define-prefix-command 'jmc-dap-prefix-map)
  (global-set-key (kbd "C-c d") 'jmc-dap-prefix-map)

  (define-key jmc-dap-prefix-map (kbd "d") #'dape)
  (define-key jmc-dap-prefix-map (kbd "r") #'dape-quit)
  (define-key jmc-dap-prefix-map (kbd "b") #'dape-breakpoint-toggle)
  (define-key jmc-dap-prefix-map (kbd "B") #'dape-breakpoint-remove-all)
  (define-key jmc-dap-prefix-map (kbd "c") #'dape-continue)
  (define-key jmc-dap-prefix-map (kbd "n") #'dape-next)
  (define-key jmc-dap-prefix-map (kbd "i") #'dape-step-in)
  (define-key jmc-dap-prefix-map (kbd "o") #'dape-step-out)
  (define-key jmc-dap-prefix-map (kbd "w") #'dape-info)
  (define-key jmc-dap-prefix-map (kbd "R") #'dape-restart)

  :config
  ;; --- UI Config ---
  ;; Show the info buffers (locals, breakpoints, stack) in the right window
  (add-to-list 'display-buffer-alist
	       '("\\*dape-info\\*"
		 (display-buffer-in-side-window)
		 (side . right)
		 (window-width . 0.30)))

  ;; Automatically open the info window when debugging starts
  (add-hook 'dape-start-hook (lambda () (dape-info)))

  ;; Kill the info window when debugging ends
  (add-hook 'dape-kill-hook
	    (lambda ()
	      (when-let ((buf (get-buffer "*dape-info*")))
		(kill-buffer buf))))

  ;; Enable inline variable values in your code while debugging
  (setq dape-inlay-hints t)

  ;; =============================================================================
  ;; LANGUAGE ADAPTER CONFIGURATIONS
  ;; =============================================================================

  ;; --------------------------------------------------------------
  ;; PHP (Symfony, Laravel)
  ;; --------------------------------------------------------------
  (add-to-list 'dape-configs
	       `(php-local
		 modes (php-mode php-ts-mode)
		 port 9003
		 :type "php"
		 :request "launch"
		 :name "PHP :: Listen for XDebug (Local)"
		 :sourceMaps t))

  (add-to-list 'dape-configs
	       `(php-symfony-docker
		 modes (php-mode php-ts-mode)
		 port 9003
		 :type "php"
		 :request "launch"
		 :name "PHP :: Symfony Docker (Skeleton)"
		 :hostname "0.0.0.0"
		 :pathMappings ,(lambda () `(:/app ,(jmc-get-workspace-root)))
		 :sourceMaps t))

  (add-to-list 'dape-configs
	       `(php-laravel-sail
		 modes (php-mode php-ts-mode)
		 port 9003
		 :type "php"
		 :request "launch"
		 :name "PHP :: Laravel Sail"
		 :pathMappings ,(lambda () `(:/var/www/html ,(jmc-get-workspace-root)))
		 :sourceMaps t))

  ;; --------------------------------------------------------------
  ;; PYTHON (Flask, Django)
  ;; --------------------------------------------------------------
  (add-to-list 'dape-configs
	       `(python-flask
		 modes (python-mode python-ts-mode)
		 command jmc-python-venv-bin
		 command-args ("-m" "debugpy.adapter")
		 :type "python"
		 :request "launch"
		 :module "flask"
		 :args ["run" "--no-debugger" "--no-reload"]
		 :cwd jmc-get-workspace-root
		 :env (:FLASK_APP "app.py" :FLASK_DEBUG "1" :PYTHONPATH ".")))

  (add-to-list 'dape-configs
	       `(python-django
		 modes (python-mode python-ts-mode)
		 command jmc-python-venv-bin
		 command-args ("-m" "debugpy.adapter")
		 :type "python"
		 :request "launch"
		 :program "manage.py"
		 :args ["runserver" "--noreload"]
		 :cwd jmc-get-workspace-root
		 :django t))

  ;; --------------------------------------------------------------
  ;; JAVASCRIPT & TYPESCRIPT (Node.js & Chrome)
  ;; --------------------------------------------------------------
  (add-to-list 'dape-configs
	       `(js-node-file
		 ,@(alist-get 'js-debug-node dape-configs)
		 modes (js-ts-mode typescript-ts-mode tsx-ts-mode)
		 :name "JS/TS :: Run Current File"
		 :sourceMaps t))

  (add-to-list 'dape-configs
	       `(js-tsx-file
		 ,@(alist-get 'js-debug-node dape-configs)
		 modes (typescript-ts-mode tsx-ts-mode)
		 :name "JS/TS :: Run Raw TypeScript (tsx)"
		 :type "pwa-node"
		 :request "launch"
		 :cwd jmc-get-workspace-root
		 ;; Inject the tsx loader into the native Node process
		 :runtimeExecutable "node"
		 :runtimeArgs ["--import" "tsx"]
		 :program ,(lambda () (buffer-file-name))
		 :sourceMaps t
		 :resolveSourceMapLocations ["${workspaceFolder}/**" "!**/node_modules/**"]))

  (add-to-list 'dape-configs
	       `(js-npm-script
		 ,@(alist-get 'js-debug-node dape-configs)
		 modes (js-ts-mode typescript-ts-mode tsx-ts-mode)
		 :name "JS/TS :: NPM Run Script"
		 :runtimeExecutable "npm"
		 :runtimeArgs ["run" "dev"]
		 :console "integratedTerminal"))

  (add-to-list 'dape-configs
	       `(js-chrome-frontend
		 ,@(alist-get 'js-debug-chrome dape-configs)
		 modes (js-ts-mode typescript-ts-mode tsx-ts-mode)
		 :name "JS/TS :: Chrome Debugger"
		 :url "http://localhost:3000"))

  ;; --------------------------------------------------------------
  ;; GO (Delve)
  ;; --------------------------------------------------------------
  (add-to-list 'dape-configs
	       `(go-current-file
		 ,@(alist-get 'dlv dape-configs)
		 modes (go-mode go-ts-mode)
		 :name "Go :: Debug (Current File)"
		 :request "launch"
		 :mode "debug"
		 :program ,(lambda () (buffer-file-name))
		 :cwd jmc-get-workspace-root))

  (add-to-list 'dape-configs
	       `(go-package
		 ,@(alist-get 'dlv dape-configs)
		 modes (go-mode go-ts-mode)
		 :name "Go :: Debug (Current Package)"
		 :request "launch"
		 :mode "debug"
		 :program ,(lambda () (file-name-directory (buffer-file-name)))
		 :cwd jmc-get-workspace-root))

  (add-to-list 'dape-configs
	       `(go-test
		 ,@(alist-get 'dlv dape-configs)
		 modes (go-mode go-ts-mode)
		 :name "Go :: Debug (Tests)"
		 :request "launch"
		 :mode "test"
		 :program ,(lambda () (file-name-directory (buffer-file-name)))
		 :cwd jmc-get-workspace-root))

  ;; --------------------------------------------------------------
  ;; RUST (CodeLLDB)
  ;; --------------------------------------------------------------
  (add-to-list 'dape-configs
	       `(rust-codelldb
		 modes (rustic-mode rust-ts-mode)
		 ensure dape-ensure-command
		 command "codelldb"
		 command-args ("--port" :autoport)
		 port :autoport
		 :type "lldb"
		 :request "launch"
		 :cwd jmc-get-workspace-root
		 compile "cargo build"
		 ;; Dynamically build the path to the compiled binary based on the folder name
		 :program ,(lambda ()
			     (let ((root (jmc-get-workspace-root)))
			       (concat root "target/debug/"
				       (file-name-nondirectory
					(directory-file-name root))))))))

;; =============================================================================
;; FINALIZE
;; =============================================================================

(provide 'debugger)
;;; debugger.el ends here
