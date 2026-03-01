;;; web.el --- Web browsing and network tools -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; This module configures the built-in web browsing capabilities of Emacs.
;;
;; The primary tool used is EWW (Emacs Web Wowser). EWW is a text-based web
;; browser that renders HTML directly inside an Emacs buffer. It is perfect
;; for reading documentation, blog posts, or StackOverflow without leaving
;; your development environment.
;;
;; Our configuration focuses on:
;; 1. Improving readability (Reader Mode aesthetics).
;; 2. Streamlining buffer management (Unique names for multiple tabs).
;; 3. Ergonomic navigation.
;;
;;; Code:

;; =============================================================================
;; EWW (EMACS WEB WOWSER) CONFIGURATION
;; =============================================================================

(use-package eww
  ;; `:ensure nil` because EWW is built into Emacs; no download required.
  :ensure nil
  ;; Defer loading until you actually call a command like `M-x eww`.
  :defer t
  :config
  ;; --- Buffer Management ---

  ;; Automatically rename EWW buffers to the title of the website.
  ;; -> By default, EWW uses a single buffer named "*eww*".
  ;; -> Enabling this allows you to have multiple websites open simultaneously
  ;;    without them overwriting each other.
  (setq eww-auto-rename-buffer t)

  ;; --- Visual Rendering (SHR) ---
  ;; SHR is the library EWW uses to "render" HTML into text.

  ;; Use variable-width (proportional) fonts for web content.
  ;; -> Makes articles feel like a "Reader Mode" document rather than code.
  (setq shr-use-fonts t)

  ;; Limit the text width to 80 characters.
  ;; -> Prevents lines from stretching across the entire screen on wide monitors,
  ;;    which significantly improves reading comfort.
  (setq shr-width 80)

  ;; Disable website-defined colors.
  ;; -> Many websites use colors that clash with your Emacs theme.
  ;; -> Disabling this ensures a consistent, accessible look across all pages.
  (setq shr-use-colors nil)

  ;; --- Navigation Tweaks ---

  ;; Map the 'q' key to kill the buffer and close the window immediately.
  ;; -> The default behavior is to "bury" the buffer (hide it), which can
  ;;    lead to many unused buffers cluttering your session.
  (define-key eww-mode-map (kbd "q") 'quit-window))

;; =============================================================================
;; FINALIZE
;; =============================================================================

(provide 'web)

;;; web.el ends here
