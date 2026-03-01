;;; interface.el --- User interface customizations -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; This module handles the visual appearance and core UI behavior of Emacs.
;;
;; We transform the default Emacs interface into a modern, aesthetically
;; pleasing development environment with:
;; 1. Font configuration (including Nerd Font icons and ligatures).
;; 2. Core UI improvements (transparency, scrolling, tabs).
;; 3. Icon packages for files, completions, and 'Dired'.
;; 4. A graphical dashboard (welcome screen).
;; 5. Enhanced mode-line and help system.
;;
;;; Code:

;; =============================================================================
;; COMPILER DECLARATIONS (SILENCE WARNINGS)
;; =============================================================================

(defvar display-time-format)
(defvar display-time-interval)
(defvar global-line-reminder-mode)
(defvar dashboard-projects-switch-function)
(defvar dimmer-mode)

(declare-function ligature-set-ligatures "ligature")
(declare-function global-ligature-mode "ligature")
(declare-function all-the-icons-completion-mode "all-the-icons-completion")
(declare-function dashboard-setup-startup-hook "dashboard")
(declare-function dashboard-open "dashboard")
(declare-function dashboard-modify-heading-icons "dashboard")
(declare-function helpful-callable "helpful")
(declare-function helpful-at-point "helpful")
(declare-function helpful-function "helpful")
(declare-function helpful-variable "helpful")
(declare-function helpful-key "helpful")
(declare-function helpful-command "helpful")

;; =============================================================================
;; FONT CONFIGURATION
;; =============================================================================

;; Set the default font family and size.
;; -> The `:height` value of 150 represents 15.0 points.
(set-face-attribute 'default nil
                    :family "FiraCode Nerd Font"
                    :height 150
                    :weight 'normal)

;; Enable Nerd Font icons throughout Emacs.
;; -> This tells Emacs to use FiraCode Nerd Font for characters in the
;;    Nerd Font Unicode range (U+E000 to U+F8FF).
;; -> Fixes broken icons in vterm, dashboard, and other tools.
(set-fontset-font t '(#xe000 . #xf8ff) "FiraCode Nerd Font")

;; macOS-specific emoji font fallback.
;; -> Ensures emoji render correctly on macOS systems.
(when (string-equal system-type "darwin")
  (set-fontset-font t 'symbol "Apple Color Emoji" nil 'prepend))

;; -----------------------------------------------------------------------------
;; Ligatures (Combined Character Symbols)
;; -----------------------------------------------------------------------------
;; Ligatures replace character sequences like "=>" with single, stylized glyphs.
;; This improves readability in code without changing the underlying text.


(use-package ligature
  :ensure t
  :config
  ;; Enable the "www" ligature universally.
  (ligature-set-ligatures 't '("www"))
  
  ;; Enable comprehensive ligature sets for programming modes.
  ;; -> Covers all Cascadia Code and Fira Code ligatures.
  ;; -> Examples: == === => != >= <= :: ... <!-- -->
  (ligature-set-ligatures 'prog-mode
                          '(;; Equals-based: == === ==== => =| =/=
                            ("=" (rx (+ (or ">" "<" "|" "/" "~" ":" "!" "="))))
                            ;; Semicolons: ;; ;;;
                            (";" (rx (+ ";")))
                            ;; Ampersands: && &&&
                            ("&" (rx (+ "&")))
                            ;; Exclamation: !! !!! != !== !~
                            ("!" (rx (+ (or "=" "!" "\." ":" "~"))))
                            ;; Question marks: ?? ??? ?: ?= ?.
                            ("?" (rx (or ":" "=" "\." (+ "?"))))
                            ;; Percent: %% %%%
                            ("%" (rx (+ "%")))
                            ;; Pipes: |> ||> ||| |-> || |==
                            ("|" (rx (+ (or ">" "<" "|" "/" ":" "!" "}" "\]"
                                            "-" "=" ))))
                            ;; Backslashes: \\ \\\ \/
                            ("\\" (rx (or "/" (+ "\\"))))
                            ;; Plus: ++ +++ +>
                            ("+" (rx (or ">" (+ "+"))))
                            ;; Colons: :: ::: := :> :<
                            (":" (rx (or ">" "<" "=" "//" ":=" (+ ":"))))
                            ;; Slashes: // /// /* /> /=
                            ("/" (rx (+ (or ">"  "<" "|" "/" "\\" "\*" ":" "!"
                                            "="))))
                            ;; Dots: .. ... .... .= .-
                            ("\." (rx (or "=" "-" "\?" "\.=" "\.<" (+ "\."))))
                            ;; Hyphens: -- --- -> ->> -|
                            ("-" (rx (+ (or ">" "<" "|" "~" "-"))))
                            ;; Asterisks: ** *** *> */
                            ("*" (rx (or ">" "/" ")" (+ "*"))))
                            ;; Multiple w's: www wwww
                            ("w" (rx (+ "w")))
                            ;; Less-than: <> <!-- <| <- <= <=> <<
                            ("<" (rx (+ (or "\+" "\*" "\$" "<" ">" ":" "~"  "!"
                                            "-"  "/" "|" "="))))
                            ;; Greater-than: >: >- >>- >= >== >>
                            (">" (rx (+ (or ">" "<" "|" "/" ":" "=" "-"))))
                            ;; Hash/Pound: #: #= #! #( #[ ## ###
                            ("#" (rx (or ":" "=" "!" "(" "\?" "\[" "{" "_(" "_"
                                         (+ "#"))))
                            ;; Tilde: ~~ ~~~ ~= ~- ~@ ~>
                            ("~" (rx (or ">" "=" "-" "@" "~>" (+ "~"))))
                            ;; Underscores: __ ___ _|_
                            ("_" (rx (+ (or "_" "|"))))
                            ;; Hex literals: 0xFF 0x12
                            ("0" (rx (and "x" (+ (in "A-F" "a-f" "0-9")))))
                            ;; Special letter combinations
                            "Fl"  "Tl"  "fi"  "fj"  "fl"  "ft"
                            ;; Miscellaneous symbols
                            "{|"  "[|"  "]#"  "(*"  "}#"  "$>"  "^="))
  
  ;; Activate ligatures globally.
  (global-ligature-mode t))

;; =============================================================================
;; CORE UI TWEAKS
;; =============================================================================

;; Enable window transparency.
;; -> The value 70 represents 70% opacity (30% transparent).
;; -> Creates a modern, layered aesthetic when overlapping windows.
(add-to-list 'default-frame-alist '(alpha-background . 70))

;; Explicitly set default font size again for redundancy.
;; -> Ensures the setting persists across theme changes.
(set-face-attribute 'default nil :height 150)

;; Use a horizontal bar cursor instead of the default block.
;; -> Other options: 'block', 'box', '(bar . WIDTH)'.
;; -> The horizontal bar is less visually intrusive.
(setq-default cursor-type 'hbar)

;; Display column numbers in the mode-line.
;; -> Complements the default line numbers for precise navigation.
(column-number-mode 1)

;; Enable line numbers globally.
;; -> Uses the modern built-in `display-line-numbers-mode`.
;; -> Faster and more flexible than legacy packages like `linum-mode`.
(global-display-line-numbers-mode 1)

;; Improve underline rendering.
;; -> Respects font descenders (the parts of letters that hang below the baseline).
;; -> Makes underlines under links and spell-check warnings look cleaner.
(setq-default x-underline-at-descent-line t)

;; Disable audible bell, enable visual flash.
;; -> On error or invalid action, the screen flashes instead of beeping.
;; -> Much less disruptive in quiet environments.
(setq visible-bell t)

;; Simplify yes/no prompts to y/n.
;; -> Saves keystrokes and speeds up common confirmations.
(setq use-short-answers t)

;; Enable pixel-perfect smooth scrolling (Emacs 29+).
;; -> Provides a smoother, more modern scrolling experience.
;; -> Wrapped in a version check to avoid errors on older Emacs versions.
(when (>= emacs-major-version 29)
  (pixel-scroll-precision-mode 1))

;; Enable right-click context menus in graphical mode.
;; -> Provides familiar GUI-style interactions.
(when (display-graphic-p)
  (context-menu-mode 1))

;; -----------------------------------------------------------------------------
;; Window Management Keybindings
;; -----------------------------------------------------------------------------

;; Navigate between split windows using Super (Cmd/Win) + Arrow keys.
;; -> Super-Left:  Move to the window on the left.
;; -> Super-Right: Move to the window on the right.
;; -> Super-Up:    Move to the window above.
;; -> Super-Down:  Move to the window below.
(global-set-key (kbd "s-<left>") 'windmove-left)
(global-set-key (kbd "s-<right>") 'windmove-right)
(global-set-key (kbd "s-<up>") 'windmove-up)
(global-set-key (kbd "s-<down>") 'windmove-down)

;; -----------------------------------------------------------------------------
;; Mouse and Trackpad Settings
;; -----------------------------------------------------------------------------

;; Enable horizontal scrolling with trackpad or tilt-wheel.
;; -> Allows side-to-side scrolling for wide content.
(setq mouse-wheel-tilt-scroll t)

;; Use "natural" scrolling direction.
;; -> Content moves in the direction of your finger/scroll.
;; -> Matches macOS and modern touchpad behavior.
(setq mouse-wheel-flip-direction t)

;; -----------------------------------------------------------------------------
;; Tab Bar Configuration
;; -----------------------------------------------------------------------------

;; Enable the tab-bar (browser-style tabs at the top of the frame).
(setq tab-bar-mode 1)

;; Always show the tab bar, even with a single tab.
;; -> Options: t (always), nil (never), 1 (always, even for one tab).
(setq tab-bar-show 1)

;; Keybindings for tab management.
;; -> Super-t: Open a new tab.
;; -> Super-l: Close the current tab.
(global-set-key (kbd "s-t") 'tab-new)
(global-set-key (kbd "s-l") 'tab-close)

;; Add a live clock to the tab-bar.
;; -> Displays the current date and time on the right side.
;; -> Format: "Sat 2025-10-25 18:32:13"
(add-to-list 'tab-bar-format 'tab-bar-format-align-right 'append)
(add-to-list 'tab-bar-format 'tab-bar-format-global 'append)
(setq display-time-format "%a %F %T")
(setq display-time-interval 1) ; Update every second
(display-time-mode)

;; -----------------------------------------------------------------------------
;; Visual Feedback for Edits
;; -----------------------------------------------------------------------------

;; Highlight modified lines in the fringe (left margin).
;; -> Shows which lines have been changed since the last git commit.
;; -> Provides instant visual feedback during editing.
(use-package line-reminder
  :ensure t
  :defer t
  :config
  (setq global-line-reminder-mode t))

;; Preview color values inline.
;; -> Displays a color swatch next to hex codes like "#FFFFFF".
;; -> Only activates in programming modes to avoid distraction in prose.
(use-package colorful-mode
  :diminish
  :ensure t
  :defer t
  :custom
  (colorful-use-prefix t)
  (colorful-only-strings 'only-prog)
  (css-fontify-colors nil) ; Let colorful-mode handle CSS colors
  :config
  (global-colorful-mode t)
  ;; Also enable in helpful-mode buffers.
  (add-to-list 'global-colorful-modes 'helpful-mode))

;; =============================================================================
;; ICON PACKAGES
;; =============================================================================
;; Icons enhance visual clarity throughout Emacs, making it easier to
;; distinguish file types, completion candidates, and UI elements.

;; Core icon package and font installer.
;; -> Provides the fundamental icon glyphs used by other packages.
(use-package all-the-icons
  :ensure t
  :defer t)

;; Add icons to minibuffer completion candidates.
;; -> Works with `marginalia` to show file-type icons during completion.
(use-package all-the-icons-completion
  :ensure t
  :after (marginalia all-the-icons)
  :hook (marginalia-mode . all-the-icons-completion-marginalia-setup)
  :init
  (all-the-icons-completion-mode))

;; Add icons to Dired (the Emacs file manager).
;; -> Shows folder and file-type icons in directory listings.
(use-package all-the-icons-dired
  :ensure t
  :defer t
  :hook
  (dired-mode . all-the-icons-dired-mode))

;; Add icons to Corfu completion popups.
;; -> Displays small icons next to completion candidates.
;; -> Examples: 🟪 for functions, 🟦 for variables, 🟨 for keywords.
(use-package kind-icon
  :ensure t
  :after corfu
  :defer t
  :custom
  (kind-icon-use-icons t)
  (kind-icon-default-face 'corfu-default))

;; =============================================================================
;; DASHBOARD (STARTUP SCREEN)
;; =============================================================================
;; The dashboard replaces the default *scratch* buffer with a modern,
;; graphical welcome screen showing recent files and projects.

(provide 'ffap)

(use-package dashboard
  :ensure t
  
  :init
  ;; Activate the dashboard natively during the startup sequence.
  ;; -> This blocks the screen from drawing until the dashboard is fully ready,
  ;;    preventing the ugly 0.5s flash of the *scratch* buffer.
  (dashboard-setup-startup-hook)
  
  ;; Make dashboard the default initial buffer.
  ;; -> Unless Emacs was started with a file argument (e.g., `emacs file.txt`).
  (unless (> (length command-line-args) 1)
    (setq initial-buffer-choice #'dashboard-open))

  :custom
  ;; Define the layout order.
  ;; -> Banner (logo) first, then items list.
  (dashboard-startupify-list '(dashboard-insert-banner
                               dashboard-insert-newline
                               dashboard-insert-items))
  
  ;; Use the built-in Emacs logo.
  (dashboard-startup-banner 'logo)
  
  ;; Center content both horizontally and vertically.
  ;; -> Creates a balanced, visually appealing layout.
  (dashboard-center-content t)
  (dashboard-vertically-center-content t)
  
  ;; Enable icons for section headings and files.
  (dashboard-set-heading-icons t)
  (dashboard-set-file-icons t)
  
  ;; Use Projectile for project discovery.
  (dashboard-projects-backend 'projectile)
  
  ;; Show 5 recent files and 5 recent projects.
  (dashboard-items '((recents . 5)
                     (projects . 5)))
  
  ;; Hide default footer and shortcuts.
  (dashboard-show-shortcuts nil)
  (dashboard-set-footer nil)
  
  :config
  ;; Customize the icon for the "Projects" section.
  (dashboard-modify-heading-icons '((projects . "file-directory")))
  
  ;; Clean up the *scratch* buffer after dashboard loads.
  ;; -> Since we're using dashboard, we don't need *scratch* anymore.
  (add-hook 'dashboard-after-initialize-hook
            (lambda ()
              (when (get-buffer "*scratch*")
                (kill-buffer "*scratch*")))))

;; -----------------------------------------------------------------------------
;; Dashboard Customizations
;; -----------------------------------------------------------------------------

;; Hide the cursor in the dashboard buffer.
;; -> The dashboard is non-interactive, so a visible cursor is unnecessary.
(defun jmc-dashboard-hide-cursor-h ()
  "Hide the cursor in the dashboard buffer."
  (setq-local cursor-type nil)
  (setq-local blink-cursor-mode nil))

(add-hook 'dashboard-mode-hook #'jmc-dashboard-hide-cursor-h)

;; Create a "lockdown" mode to make the dashboard completely static.
;; -> Disables all scrolling and movement keys.
;; -> Prevents accidental navigation that would break the centered layout.

;; Define a keymap that disables all movement commands.
(defvar dashboard-lock-keymap
  (let ((map (make-sparse-keymap)))
    ;; Disable arrow key navigation.
    (define-key map (kbd "<up>") 'ignore)
    (define-key map (kbd "<down>") 'ignore)
    (define-key map (kbd "<left>") 'ignore)
    (define-key map (kbd "<right>") 'ignore)
    ;; Disable page up/down.
    (define-key map (kbd "<prior>") 'ignore)
    (define-key map (kbd "<next>") 'ignore)
    ;; Disable Emacs scroll commands.
    (define-key map (kbd "C-v") 'ignore)
    (define-key map (kbd "M-v") 'ignore)
    ;; Disable mouse wheel scrolling.
    (define-key map (kbd "<wheel-up>") 'ignore)
    (define-key map (kbd "<wheel-down>") 'ignore)
    ;; Disable horizontal scrolling.
    (define-key map (kbd "<wheel-left>") 'ignore)
    (define-key map (kbd "<wheel-right>") 'ignore)
    ;; Disable jump-to-beginning/end commands.
    (define-key map (kbd "M-<") 'ignore)
    (define-key map (kbd "M->") 'ignore)
    map)
  "Keymap that disables all scrolling and navigation for the dashboard.")

;; Package the keymap into a toggleable minor mode.
(define-minor-mode dashboard-lock-mode
  "Lock the dashboard view by disabling all movement and scrolling."
  :init-value nil
  :lighter " Lock"
  :keymap dashboard-lock-keymap)

;; Setup function to initialize the locked dashboard state.
(defun setup-dashboard-lock ()
  "Configure window properties and activate dashboard lock mode."
  ;; Hide scroll bars.
  (set-window-scroll-bars (selected-window) nil nil)
  ;; Reset horizontal scroll position.
  (set-window-hscroll (selected-window) 0)
  ;; Prevent line wrapping.
  (setq-local truncate-lines t)
  ;; Activate the lock mode.
  (dashboard-lock-mode 1))

;; Clean up any legacy dashboard lock functions from previous configurations.
;; -> Ensures only our current implementation runs.
(dolist (hook-func '(dashboard-lock-view-final
                     dashboard-force-reset-view
                     my-dashboard-absolutely-lock-window
                     my-dashboard-lock-window
                     my-dashboard-disable-scrolling
                     dashboard-lock-view-definitively
                     setup-dashboard-lock))
  (remove-hook 'dashboard-mode-hook hook-func))

;; Activate the dashboard lock when dashboard-mode starts.
(add-hook 'dashboard-mode-hook #'setup-dashboard-lock)

(setq dashboard-projects-switch-function 'projectile-switch-project-by-name)

;; =============================================================================
;; MODE-LINE AND HELP SYSTEM
;; =============================================================================

;; Use `telephone-line` for a modern, customizable mode-line.
;; -> The mode-line is the status bar at the bottom of each window.
;; -> Shows information like file name, git branch, line/column, errors, etc.
(use-package telephone-line
  :ensure t
  :custom
  ;; Left-hand side segments.
  ;; -> Git branch, project name, minor modes, and buffer name.
  (telephone-line-lhs
   '((evil   . (telephone-line-vc-segment))
     (accent . (telephone-line-project-segment
                telephone-line-process-segment))
     (nil    . (telephone-line-minor-mode-segment
                telephone-line-buffer-segment))))
  
  ;; Right-hand side segments.
  ;; -> File encoding, error count, major mode, and position info.
  (telephone-line-rhs
   '((nil    . (telephone-line-atom-encoding-segment))
     (accent . (telephone-line-flycheck-segment
                telephone-line-major-mode-segment))
     (evil   . (telephone-line-misc-info-segment))))
  
  ;; Set the height of the mode-line.
  (telephone-line-height 24)
  
  :config
  (telephone-line-mode 1))

;; Replace the default help system with `helpful`.
;; -> Provides richer, more detailed help buffers.
;; -> Shows source code, references, and usage examples.
(use-package helpful
  :ensure t
  :defer t)

;; Rebind default help keys to use helpful.
;; -> C-h f: Describe function or macro.
;; -> C-c C-d: Describe symbol at point.
;; -> C-h F: Describe function (functions only).
;; -> C-h v: Describe variable.
;; -> C-h k: Describe key binding.
;; -> C-h x: Describe command.
(global-set-key (kbd "C-h f") #'helpful-callable)
(global-set-key (kbd "C-c C-d") #'helpful-at-point)
(global-set-key (kbd "C-h F") #'helpful-function)
(global-set-key (kbd "C-h v") #'helpful-variable)
(global-set-key (kbd "C-h k") #'helpful-key)
(global-set-key (kbd "C-h x") #'helpful-command)

;; Dim inactive windows to improve focus.
;; -> Makes the active window brighter and more prominent.
;; -> Reduces visual clutter when working with multiple splits.
(use-package dimmer
  :ensure t
  :defer t
  :config
  (setq dimmer-mode t))

;; =============================================================================
;; FINALIZE
;; =============================================================================

(provide 'interface)

;;; interface.el ends here
