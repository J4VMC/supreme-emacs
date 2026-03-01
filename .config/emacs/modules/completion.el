;;; completion.el --- Additional tools for completion utilities -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; This file configures the entire "completion" experience in Emacs.
;; "Completion" is Emacs's term for autocompletion, fuzzy finding, and
;; narrowing down lists of options.
;;
;; ;; 
;;
;; The configuration is broken into two distinct ecosystems:
;;
;; 1. MINIBUFFER COMPLETION (The "Vertico Stack"):
;;    Handles anything you do in the command bar at the bottom of the screen.
;;    - `M-x` (find command)
;;    - `C-x C-f` (find file)
;;    - `C-x b` (switch buffer)
;;    Core packages: Vertico, Consult, Orderless, Marginalia, Embark.
;;
;; 2. IN-BUFFER COMPLETION (The "Corfu Stack"):
;;    Handles the "autocomplete" pop-up that appears *in your code*
;;    as you are typing.
;;    Core packages: Corfu, Cape, Tempel.
;;
;; These two stacks are modern, minimal, and work together perfectly
;; to create a fast and highly capable completion system.
;;
;;; Code:

;; =============================================================================
;; COMPILER DECLARATIONS (SILENCE WARNINGS)
;; =============================================================================

(defvar vertico-map)
(defvar corfu-map)
(defvar tempel-map)
(defvar consult-ripgrep-args)
(defvar consult-narrow-key)
(defvar consult-line-numbers-widen)

(declare-function vertico-mode "vertico")
(declare-function vertico-multiform-mode "vertico")
(declare-function marginalia-mode "marginalia")
(declare-function embark-prefix-help-command "embark")
(declare-function global-corfu-mode "corfu")
(declare-function corfu-terminal-mode "corfu-terminal")
(declare-function cape-file "cape")
(declare-function cape-dabbrev "cape")
(declare-function cape-elisp-block "cape")
(declare-function cape-keyword "cape")
(declare-function cape-dict "cape")
(declare-function cape-wrap-super "cape")
(declare-function tempel-expand "tempel")
(declare-function global-tempel-abbrev-mode "tempel")

;; =============================================================================
;; CORE EMACS COMPLETION BEHAVIOR
;; =============================================================================

;; Tweak built-in Emacs settings before loading third-party packages.
(use-package emacs
  :ensure nil
  :init
  ;; Allow running minibuffer commands *while* you are already in a minibuffer.
  ;; -> Essential for complex workflows (e.g., searching for a file while inside `M-x`).
  (setq enable-recursive-minibuffers t)
  :custom
  ;; Start cycling through completion candidates with TAB after 3 options.
  (completion-cycle-threshold 3)
  ;; Make TAB "smart": first try to indent the current line. If the line is
  ;; already indented, then try to trigger autocomplete.
  (tab-always-indent 'complete)
  ;; For Emacs 30+: Disable a built-in completion feature that conflicts
  ;; with our custom Corfu/Cape setup below.
  (text-mode-ispell-word-completion nil)
  ;; Make M-x (`execute-extended-command`) show *all* available commands,
  ;; rather than Emacs trying to hide commands it thinks are irrelevant.
  (read-extended-command-predicate #'command-completion-default-include-p))

;; =============================================================================
;; MINIBUFFER COMPLETION (THE VERTICO STACK)
;; =============================================================================

;; Vertico: The core User Interface for the minibuffer.
;; -> Replaces the default, clunky grid with a clean, fast, vertical list.
(use-package vertico
  :ensure t
  :init
  (vertico-mode) ; Enable the vertical UI globally.
  (vertico-multiform-mode)
  :bind (:map vertico-map
              ("RET" . vertico-directory-enter)
              ("DEL" . vertico-directory-delete-char)
              ("M-DEL" . vertico-directory-delete-word))
  :custom
  ;; Allow navigation to wrap around. Pressing 'down' at the bottom of the
  ;; list takes you back to the top, and vice-versa.
  (vertico-cycle t)
  (vertico-multiform-categories
   '((file (styles basic partial-completion orderless))
     (consult-grep buffer) ; -> Use a wider view for grep results
     (emoji grid)
     (symbol (vertico-sort-function . vertico-sort-alpha)))))

;; Vertico Directory: Improves file path navigation inside the minibuffer.
(use-package vertico-directory
  :ensure nil ; Built-in with Vertico, so no need to download.
  :after vertico
  :bind (:map vertico-map
              ;; In `C-x C-f` (find-file), `M-DEL` (Alt-Backspace) deletes
              ;; exactly one directory level (e.g., "foo/bar/" becomes "foo/").
              ("M-DEL" . vertico-directory-delete-word)))

;; Orderless: The "brains" behind the search filtering.
;; -> Lets you type search terms in *any order*, separated by spaces.
(use-package orderless
  :ensure t
  :init
  ;; --- Completion Style Priority ---
  ;; 1. basic: Try strict prefix matching first (typing 'i' matches 'init.el').
  ;; 2. orderless: If no prefix match exists, search anywhere in any order.
  (setq completion-styles '(basic orderless))
  
  ;; Clear default completion categories to ensure our styles take precedence.
  (setq completion-category-defaults nil)

  ;; --- Category Overrides ---
  ;; Force specific behavior for different types of data.
  (setq completion-category-overrides
        '((file (styles basic partial-completion orderless)) ; -> Better path/file navigation
          (buffer (styles basic orderless))                  ; -> Prioritize buffer name starts
          (command (styles basic orderless)))))              ; -> Prioritize M-x command starts

;; Marginalia: Adds rich annotations (metadata) to the side of Vertico lists.
;; -> `find-file` shows file permissions and sizes.
;; -> `describe-function` shows the function's documentation string.
(use-package marginalia
  :ensure t
  :after vertico
  :init (marginalia-mode))

;; Consult: Provides supercharged versions of built-in Emacs search commands.
;; -> All of these seamlessly use the Vertico/Orderless UI setup above.
(use-package consult
  :ensure t
  :after vertico
  :bind (;; `C-x b`: A vastly improved buffer switcher with previews.
         ("C-x b" . consult-buffer)
         ;; `M-y`: A fuzzy-searchable clipboard history (yank-pop).
         ("M-y" . consult-yank-pop)
         ;; `M-s r`: Blazing fast project-wide search using `ripgrep` (rg).
         ("M-s r" . consult-ripgrep)
         ;; `M-s l`: Fuzzy-search for a specific line *in the current buffer*.
         ("M-s l" . consult-line)
         ;; `M-s L`: Fuzzy-search for a specific line *across all open buffers*.
         ("M-s L" . consult-line-multi)
         ;; `M-s o`: Fuzzy-search through headlines/outlines in the current buffer.
         ("M-s o" . consult-outline))
  :config
  ;; Arguments passed to `ripgrep` under the hood.
  ;; -> Configured for smart casing, hidden files, and ignoring `.git/` folders.
  (setq consult-ripgrep-args
        "rg --null --line-buffered --max-columns=150 --max-columns-preview --max-filesize 1M --ignore-case --path-separator /\\ --smart-case --no-heading --line-number --hidden --glob !.git/ .")
  ;; Press `/` during a Consult search to narrow results by category.
  (setq consult-narrow-key "/")
  ;; -> Use the current region/symbol as the initial search term
  (setq consult-line-numbers-widen t))

;; Consult-Projectile integration.
;; -> Makes Consult respect Projectile's concept of what a "project" is.
(use-package consult-projectile
  :after (consult projectile)
  :ensure t)

;; Embark: The "Actions" framework.
;; -> Acts like a powerful right-click menu for the minibuffer.
;; -> Once you find a candidate (a file, a buffer, a package), press `C-.`
;;    to see a list of actions you can perform on it (delete, rename, copy, etc.).
(use-package embark
  :ensure t
  :bind (;; `C-.`: Open the Embark action menu for the currently highlighted item.
         ("C-." . embark-act)
         ;; `C-;`: Execute the most obvious/default action immediately (Do What I Mean).
         ("C-;" . embark-dwim)
         ;; `C-h B`: Show all available Embark actions for this specific type of item.
         ("C-h B" . embark-bindings))
  :init
  ;; Integrates with `which-key` to display the action menu cleanly.
  (setq prefix-help-command #'embark-prefix-help-command)
  :config
  ;; Hide the mode-line in Embark "Collect" buffers to keep the UI clean.
  ;; -> A Collect buffer is generated when you want to export search results to a list.
  (add-to-list 'display-buffer-alist
               '("\\`\\*Embark Collect \\(Live\\|Completions\\)\\*"
                 nil (window-parameters (mode-line-format . none)))))

;; Embark-Consult integration.
;; -> Connects Embark's export functions with Consult's live-preview features.
(use-package embark-consult
  :ensure t
  :after (embark consult)
  :hook
  ;; Enable live previews as you move your cursor through an Embark Collect buffer.
  (embark-collect-mode . consult-preview-at-point-mode))

;; =============================================================================
;; IN-BUFFER COMPLETION (THE CORFU STACK)
;; =============================================================================

;; Corfu: The core UI for in-buffer code completion.
;; -> A clean, fast, and minimal pop-up that appears directly next to your cursor.
(use-package corfu
  :ensure t
  :init
  (global-corfu-mode) ; Enable autocomplete globally.
  :custom
  (corfu-cycle t) ; Allow navigation to wrap from bottom to top.
  (corfu-auto t)  ; Trigger the pop-up automatically as you type (no need to hit TAB).
  (corfu-preselect 'first) ; -> Always preselect the first candidate
  (corfu-indexed-mode t) ; -> Type M-1 to select the 1st candidate, M-2 for the 2nd, etc.
  :bind (:map corfu-map
              ;; Map TAB and Shift-TAB to navigate up and down the pop-up list.
              ;; -> This is the most standard and ergonomic setup for developers.
              ("TAB" . corfu-next)
              ([tab] . corfu-next)
              ("S-TAB" . corfu-previous)
              ([backtab] . corfu-previous)))

;; Corfu Popupinfo: Displays documentation alongside the autocomplete pop-up.
(use-package corfu-popupinfo
  :after corfu
  :ensure nil ; Built-in with Corfu.
  :hook (corfu-mode . corfu-popupinfo-mode)
  :custom
  ;; Wait 0.25 seconds before showing the documentation pane to avoid flickering.
  (corfu-popupinfo-delay '(0.25 . 0.1))
  ;; Keep the documentation pane visible until you move away.
  (corfu-popupinfo-hide nil)
  :config
  (corfu-popupinfo-mode))

;; Corfu Terminal: Ensures the UI still works if you run Emacs in the terminal (`emacs -nw`).
(use-package corfu-terminal
  :if (not (display-graphic-p)) ; Only load if running in a CLI environment.
  :ensure t
  :config
  (corfu-terminal-mode))

;; Cape: The "Backends" (Data Sources) for Corfu.
;; -> Corfu provides the visual pop-up, but Cape feeds it the actual data.
(use-package cape
  :ensure t
  :preface
  ;; Group several backends together into a single "super" backend.
  ;; -> This allows Corfu to suggest keywords, dictionary words, and buffer words simultaneously.
  (defun super-capf-cape ()
    (cape-wrap-super #'cape-dabbrev #'cape-dict #'cape-keyword))
  :init
  ;; `completion-at-point-functions` (capf) is the master list Emacs uses
  ;; to figure out what to suggest. We append Cape's specialized engines here.
  (add-hook 'completion-at-point-functions #'cape-file)        ; File paths
  (add-hook 'completion-at-point-functions #'cape-dabbrev)     ; Words from open buffers
  (add-hook 'completion-at-point-functions #'cape-elisp-block) ; Emacs Lisp blocks
  (add-hook 'completion-at-point-functions #'cape-keyword)     ; Programming language keywords
  (add-hook 'completion-at-point-functions #'cape-dict)        ; Dictionary words
  :config
  ;; Apply the super backend to the local buffer.
  (setq-local completion-at-point-functions (list #'super-capf-cape)))

;; Tempel: The Snippet Engine.
;; -> Expands short trigger words (e.g., "for") into full code blocks.
(use-package tempel
  :ensure t
  :custom
  ;; Define the location of your custom, handwritten snippet files.
  (tempel-path (locate-user-emacs-file "templates"))
  :bind (;; `M-*` inserts a snippet by manually searching its name.
         ("M-*" . tempel-insert)
         ;; `M-+` attempts to expand the word directly under the cursor into a snippet.
         ("M-+" . tempel-complete)
         ;; Keybindings active *while* you are filling out a generated snippet.
         :map tempel-map
         ("C-c RET" . tempel-done)    ; Finalize the snippet and exit.
         ("C-<down>" . tempel-next)   ; Jump to the next fill-in field.
         ("C-<up>" . tempel-previous) ; Jump to the previous fill-in field.
         ("M-<down>" . tempel-next)
         ("M-<up>" . tempel-previous))
  :preface
  ;; --- Integrating Tempel with Corfu ---
  (defun jmc-tempel-setup-capf-h ()
    ;; Adds Tempel snippets directly into the Corfu autocomplete pop-up.
    ;; -> You will see snippet suggestions mixed in with standard code completion.
    (add-hook 'completion-at-point-functions #'tempel-expand -1 'local))

  ;; --- Conventional Commits Integration ---
  (defun jmc-magit-commit-conventional-h ()
    "Custom setup for conventional commits in Magit buffers."
    (jmc-tempel-setup-capf-h)
    (let ((commit-buf (current-buffer)))
      (run-with-idle-timer 0.05 nil
                           (lambda ()
                             (when (buffer-live-p commit-buf)
                               (with-current-buffer commit-buf
                                 (goto-char (point-min))
                                 (when (looking-at-p "^$")
                                   ;; Bypass file lookup and hardcode the exact empty placeholders
                                   (tempel-insert '("feat(" p "): " p)))))))))
  :init
  ;; Activate snippet integration in all text and programming environments.
  (add-hook 'conf-mode-hook #'jmc-tempel-setup-capf-h)
  (add-hook 'prog-mode-hook #'jmc-tempel-setup-capf-h)
  (add-hook 'text-mode-hook #'jmc-tempel-setup-capf-h)

  ;; Explicitly activate in Magit commit buffers
  (add-hook 'git-commit-setup-hook #'jmc-tempel-setup-capf-h)

  ;; Specialized hook for Git commit messages.
  (add-hook 'git-commit-setup-hook #'jmc-magit-commit-conventional-h)
  :config
  ;; Automatically expand a snippet if you type its trigger word followed by SPACE.
  (global-tempel-abbrev-mode 1))

;; Tempel Collection: A pre-made library of community snippets.
;; -> Provides boilerplate snippets for Python, JS, Go, C++, etc., out of the box.
(use-package tempel-collection
  :ensure t
  :after tempel)

;; =============================================================================
;; FINALIZE
;; =============================================================================

(provide 'completion)

;;; completion.el ends here
