;;; early-init.el --- Early configuration settings -*- lexical-binding: t; -*-
;;; Commentary:
;;
;; Emacs loads this file *before* `init.el` and before the package system
;; initializes. We use it to configure fundamental settings that must be
;; applied immediately, primarily to:
;;
;; 1. Optimize startup speed (e.g., deferring garbage collection).
;; 2. Prevent UI flickering (e.g., setting dark mode before drawing frames).
;; 3. Disable built-in package management in favor of a custom setup.
;;
;; Note on `lexical-binding: t` (line 1):
;; This tells Emacs to use lexical scoping (standard in modern languages)
;; instead of dynamic scoping, making variables safer and more predictable.
;;
;;; Code:

;; =============================================================================
;; PACKAGE MANAGEMENT
;; =============================================================================

;; Disable the built-in Emacs package manager (ELPA) during startup.
;; -> We use a third-party package manager. Disabling the built-in one
;;    here avoids redundant work and saves significant startup time.
(setq package-enable-at-startup nil)

;; =============================================================================
;; macOS SPECIFIC TWEAKS
;; =============================================================================

;; Apply these bindings only when running Emacs on macOS ('darwin').
(when (eq system-type 'darwin)

  ;; Map the macOS Command (⌘) key to the Emacs 'Super' modifier.
  (setq mac-command-modifier 'super)

  ;; Unbind 'Super-p' (Command-p).
  ;; -> Prevents accidental triggering of the macOS system print dialog.
  (global-unset-key (kbd "s-p"))

  ;; Free up the right Option key to act as a normal 'Meta' (Alt) key.
  ;; -> By default, macOS uses the right Option key for special characters.
  ;; -> Setting this allows us to use it for standard Emacs commands (like M-x).
  (setq ns-right-alternate-modifier 'none))

;; =============================================================================
;; PERFORMANCE & STARTUP OPTIMIZATIONS
;; =============================================================================

;; --- Garbage Collection (GC) ---

;; Temporarily increase the memory threshold before Emacs pauses to clean up.
;; -> A high threshold (100MB) means Emacs won't pause for GC during startup,
;;    drastically reducing load times.
;; -> Note: This must be reset to a normal value in `init.el` to avoid memory leaks.
(setq gc-cons-threshold 100000000) ; 100MB

;; --- Inter-Process Communication (IPC) ---

;; Instruct Language Server Protocol (LSP) modes to use a faster data format.
;; -> Plists parse faster than standard alists, improving LSP responsiveness.
(setenv "LSP_USE_PLISTS" "true")

;; Increase the amount of data Emacs reads from external processes at once.
;; -> Prevents UI freezing when external tools (like linters) send large data chunks.
(setq read-process-output-max (* 1024 1024 5)) ; 5MB

;; --- Compilation Warnings ---

;; Declare variables to silence byte-compiler warnings
(defvar warning-suppress-log-types)
(defvar native-comp-async-report-warnings-errors)

;; Reduce clutter in the *Messages* buffer by suppressing specific warnings
;; generated during asynchronous package compilation.
(setq byte-compile-warnings '(not obsolete))
(setq warning-suppress-log-types '((comp) (bytecomp)))
(setq native-comp-async-report-warnings-errors 'silent)

;; --- Native Compilation ---

;; Declare variables to silence byte-compiler warnings
(defvar native-comp-speed)
(defvar native-comp-jit-compilation)

;; Configure Emacs 28+ Native Compilation (compiles Lisp into machine code).
(when (featurep 'native-compile)
  ;; Optimization level 2 provides a good balance between compile speed and execution speed.
  (setq native-comp-speed 2)

  ;; Defer compilation to background idle time so it doesn't block your workflow.
  ;; (Renamed from native-comp-deferred-compilation in Emacs 29.1+)
  (setq native-comp-jit-compilation t))

;; =============================================================================
;; USER INTERFACE & FRAME SETTINGS
;; =============================================================================
;;
;; Applying these settings in `early-init` prevents Emacs from flashing a bright
;; white window or drawing default UI elements before your custom theme loads.

;; --- Startup Screen ---

;; Disable the default Emacs splash screen and scratch buffer message.
;; -> Starts Emacs with a completely blank canvas.
(setq inhibit-startup-message t
      initial-scratch-message nil)

;; Silence the "Welcome to Emacs" message in the echo area (bottom of screen).
(fset 'display-startup-echo-area-message #'ignore)

;; --- UI Elements ---

;; Disable the graphical toolbar (the row of icons at the top).
;; -> Saves vertical screen space; keyboard shortcuts are faster anyway.
(tool-bar-mode -1)

;; --- Frame (Window) Defaults ---

;; Allow Emacs to resize its window pixel-by-pixel instead of snapping to
;; rigid character grids. Looks much smoother in modern window managers.
(setq frame-resize-pixelwise t)

;; Configure default appearance for all new frames (windows).
(setq default-frame-alist
      '(;; Start Emacs fully maximized.
        (fullscreen . maximized)
        ;; Set a base dark color scheme immediately to prevent white flashes.
        (background-color . "#000000")
        (foreground-color . "#ffffff")
        ;; Integrate with macOS dark mode and make the titlebar transparent.
        (ns-appearance . dark)
        (ns-transparent-titlebar . t)))

;; =============================================================================
;; FINALIZE
;; =============================================================================

;; Register this file as a loaded feature.
;; -> This is standard Emacs Lisp practice so other packages know it has loaded.
(provide 'early-init)

;;; early-init.el ends here
