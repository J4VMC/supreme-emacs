;;; projects.el --- Project management and sidebar navigation -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; This file centralizes the configuration for "projects."
;; In Emacs, a project is defined as any directory containing a version control
;; marker (like a `.git` folder) or a project-specific file.
;;
;; This configuration utilizes two primary packages:
;;
;; 1. Projectile: The "Logic" Engine.
;;    A backend tool that understands project boundaries. It allows you to find
;;    files, switch between projects, and perform project-wide searches.
;;
;; 2. Treemacs: The "Visual" Sidebar.
;;    Provides a classic IDE-style file explorer sidebar. It allows you to browse
;;    the file tree visually using either the keyboard or mouse.
;;
;; 3. Perspective: The "Workspace" Layer.
;;    Each project opens in its own perspective — an isolated buffer list and
;;    window layout — bridged to Projectile via `persp-projectile'.
;;
;; We also unify these tools under a custom "Jump" keymap using the `s-p`
;; (Super-p) prefix for a streamlined developer experience.
;;
;;; Code:

;; =============================================================================
;; COMPILER DECLARATIONS (SILENCE WARNINGS)
;; =============================================================================

(defvar projectile-enable-keymap)
(defvar projectile-switch-project-action)
(defvar projectile-project-search-path)
(defvar projectile-generic-command)
(defvar projectile-grep-command)
(defvar projectile-enable-caching)
(defvar treemacs-mode-map)
(defvar treemacs-python-executable)
(defvar treemacs-collapse-dirs)
(defvar treemacs-display-in-side-window)
(defvar treemacs-indentation)
(defvar treemacs-width)
(defvar treemacs-follow-after-init)
(defvar treemacs-file-follow-delay)
(defvar treemacs-missing-project-action)
(defvar treemacs-no-delete-other-windows)
(defvar treemacs-persist-file)
(defvar treemacs-litter-directories)
(defvar treemacs-position)
(defvar treemacs-show-hidden-files)
(defvar treemacs-workspace-switch-cleanup)
(defvar treemacs-create-file-functions)
(defvar jmc-jump-map)
(defvar projectile-known-projects)
(defvar persp-mode-prefix-key)
(defvar persp-modestring-short)
(defvar persp-consult-source)
(defvar consult-buffer-sources)
(defvar consult--source-buffer)

(declare-function dashboard-refresh-buffer "dashboard")
(declare-function persp-mode "perspective")
(declare-function projectile-mode "projectile")
(declare-function treemacs-set-scope-type "treemacs-scope")
(declare-function projectile-project-root "projectile")
(declare-function treemacs-follow-mode "treemacs")
(declare-function treemacs-filewatch-mode "treemacs")
(declare-function treemacs-fringe-indicator-mode "treemacs")
(declare-function treemacs-git-mode "treemacs")
(declare-function treemacs-current-visibility "treemacs")
(declare-function treemacs-get-local-window "treemacs")
(declare-function treemacs-add-and-display-current-project-exclusively "treemacs")
(declare-function treemacs-goto-file-node "treemacs")
(declare-function jmc-ghostel-toggle "terminal")

;; =============================================================================
;; PROJECTILE (THE LOGIC ENGINE)
;; =============================================================================

(use-package projectile
  :init
  ;; Disable Projectile's default "C-c p" keymap so we can use our custom setup.
  (setq projectile-enable-keymap nil)

  ;; Define the root directories where your code projects live.
  ;; -> Projects are nested a few levels deep (e.g.
  ;;    "~/Projects/Software/SuperSecret/some-project"), so search each path
  ;;    (DIRECTORY . DEPTH) levels down to where they actually live, instead
  ;;    of relying on the default depth of 1, which would stop one level in,
  ;;    at "~/Projects/Software".
  (setq projectile-project-search-path '(("~/Projects" . 3))

        ;; PERFORMANCE: Use `rg` (ripgrep) for file indexing.
        ;; -> Significantly faster than the built-in Emacs `find` command.
        projectile-generic-command "rg -0 --files --color=never --hidden --glob !.git/ --max-filesize 1M"

        ;; PERFORMANCE: Use `rg` for project-wide searching (grep).
        projectile-grep-command "rg -n --with-filename --no-heading --max-columns=150 --ignore-case --max-filesize 1M --glob !.git/"

        ;; Enable caching for even faster subsequent file lookups.
        projectile-enable-caching t

        ;; Automatically pick up new project directories under
        ;; `projectile-project-search-path' instead of only remembering
        ;; projects that have already been visited once.
        projectile-auto-discover t)
  :config
  ;; Recognize bare Go modules (no VCS) as projects too.
  ;; -> `go.mod' is missing from Projectile's default marker list, so a Go
  ;;    project without its own `.git' directory would otherwise be invisible
  ;;    to project discovery.
  (add-to-list 'projectile-project-root-files "go.mod")

  ;; Recognize any directory with a direnv `.envrc' as a project root.
  ;; -> NOTE: this list is consulted by projectile's TOP-DOWN search, which
  ;;    runs AFTER the bottom-up VCS search — so inside a git repo, the git
  ;;    root still wins (usually what you want). If you ever need `.envrc'
  ;;    to define sub-project roots INSIDE a monorepo, add it to
  ;;    `projectile-project-root-files-bottom-up' instead.
  (add-to-list 'projectile-project-root-files ".envrc")

  ;; Activate Projectile globally.
  (projectile-mode 1)

  ;; Re-scan the search path so newly created project directories are known
  ;; without having been visited once. `projectile-auto-discover' only
  ;; triggers discovery from interactive switch commands, and the dashboard
  ;; reads `projectile-known-projects-file' directly, so an explicit scan is
  ;; still needed.
  ;; -> DEFERRED to idle time: the scan walks ~/Projects three levels deep,
  ;;    which was pure startup latency when run synchronously here. If the
  ;;    scan finds new projects while you are still looking at the
  ;;    dashboard, the dashboard is refreshed in place; otherwise the new
  ;;    entries simply show up in `s-p p' and on the next launch.
  (run-with-idle-timer
   1 nil
   (lambda ()
     (let ((before (length projectile-known-projects)))
       (projectile-discover-projects-in-search-path)
       (when (and (> (length projectile-known-projects) before)
                  (fboundp 'dashboard-refresh-buffer)
                  (eq (window-buffer (selected-window))
                      (get-buffer "*dashboard*")))
         (dashboard-refresh-buffer))))))

;; =============================================================================
;; PERSPECTIVE (PER-PROJECT WORKSPACES)
;; =============================================================================
;;
;; Perspective gives each "workspace" its own isolated buffer list and window
;; layout. Combined with Projectile (via `persp-projectile' below), every
;; project you open gets its own perspective: buffers from project A never
;; clutter project B's buffer switcher, and each project remembers its own
;; window arrangement when you switch back to it.

(use-package perspective
  :init
  ;; Perspective refuses to enable unless a prefix key is set (or the
  ;; warning is explicitly suppressed). "C-c p" is free here — Projectile's
  ;; default map on that key was disabled above (`projectile-enable-keymap'
  ;; nil), and all project actions live on `s-p' instead. This prefix gives
  ;; access to the full perspective command set (s: switch, r: rename,
  ;; c: kill, b: switch buffer in persp, ...).
  (setq persp-mode-prefix-key (kbd "C-c p"))

  ;; Mode-line: show only the CURRENT perspective's name, not the whole
  ;; list. Perspective publishes its modestring through
  ;; `global-mode-string', which telephone-line already renders in its
  ;; misc-info segment (bottom right) — no extra wiring needed. The
  ;; default (full list of every open perspective) grows unbounded as
  ;; projects are opened; the current name is the only part that matters.
  (setq persp-modestring-short t)
  :config
  (persp-mode 1)

  ;; --- NO workspace persistence across restarts (deliberate) ---
  ;;
  ;; Perspectives are SESSION-scoped: they are built as you open projects
  ;; (`s-p p' / the dashboard) and die with Emacs. Nothing is saved on
  ;; exit and nothing is restored on launch.
  ;;
  ;; This config used to save `persp-state-default-file' from
  ;; `kill-emacs-hook' and reload it from an idle timer after
  ;; `elpaca-after-init-hook'. Both halves were removed:
  ;; -> STARTUP COST: restoring visits every saved file synchronously —
  ;;    major modes, tree-sitter grammars, and an lsp server per
  ;;    project — so a few days of accumulated workspaces turned into
  ;;    seconds of jank right after the dashboard painted. Deferring it
  ;;    to an idle timer moved the stall, it did not remove it.
  ;; -> CORRECTNESS: the restored state was routinely wrong — buffers
  ;;    whose files had moved or been deleted, Treemacs/terminal
  ;;    placeholders that never came back properly, and perspectives
  ;;    landing in a half-built layout that had to be killed by hand.
  ;;
  ;; Re-opening a project takes one `s-p p', which rebuilds the
  ;; perspective correctly and only for the project actually wanted.
  ;; `persp-state-save'/`persp-state-load' still exist as interactive
  ;; commands (`C-c p C-s' / `C-c p C-l') for anyone who wants a
  ;; one-off snapshot; they just prompt for a file instead of using a
  ;; default one wired into startup.

  ;; Consult integration: scope `C-x b' to the current perspective.
  ;; -> Without this, `consult-buffer' lists EVERY buffer globally,
  ;;    defeating the whole point of per-project isolation. Perspective
  ;;    ships a ready-made consult source; we make it the default and
  ;;    HIDE (not remove) consult's global buffer source. The global
  ;;    list stays one narrow away: `C-x b / b' (consult-narrow-key is
  ;;    "/", see completion.el) — useful for grabbing a buffer that
  ;;    lives in another perspective.
  ;; -> Runs in `with-eval-after-load': consult is deferred behind its
  ;;    autoloaded keybindings (completion.el) and usually loads AFTER
  ;;    perspective does at startup.
  (with-eval-after-load 'consult
    (consult-customize consult--source-buffer :hidden t :default nil)
    (add-to-list 'consult-buffer-sources persp-consult-source)))

;; Projectile Integration: The "Bridge" package.
;; -> Provides `projectile-persp-switch-project': switch to (or create) a
;;    perspective NAMED AFTER the project, THEN run the normal projectile
;;    switch flow inside it. If the project's perspective already exists,
;;    it just switches to it — window layout and buffers restored as you
;;    left them, no re-run of `projectile-switch-project-action'.
(use-package persp-projectile
  :after (perspective projectile))

;; =============================================================================
;; TREEMACS (THE VISUAL SIDEBAR)
;; =============================================================================

(use-package treemacs
  :bind
  (("s-0" . treemacs-select-window)       ; Move cursor focus to the sidebar.
   ("C-c t d" . treemacs-select-directory)) ; Manually add a folder to the sidebar.
  :config
  ;; UX: Enable single-click to expand or collapse folders (default is double-click).
  (define-key treemacs-mode-map [mouse-1] 'treemacs-single-click-expand-action)

  ;; UX: HAND pointer over clickable nodes, ARROW everywhere else — like
  ;; any other tree UI. Built on the text-property lookup chain, which is
  ;; overlays > character's own props > CATEGORY symbol > buffer DEFAULTS:
  ;; -> Treemacs propertizes every clickable node (file, dir, project —
  ;;    all node types) with `category: treemacs-button`, and category
  ;;    indirection makes properties of that SYMBOL apply to all of them.
  ;;    One `put' = hand cursor on every clickable, present and future.
  ;; -> `default-text-properties' (buffer-local, so scoped to the sidebar)
  ;;    is the bottom of the chain: anything WITHOUT a more specific
  ;;    pointer — indentation, annotations, gaps — falls through to arrow.
  ;;    Space past end-of-line is already an arrow (`void-text-area-pointer').
  ;; -> NOTE: do NOT reintroduce a buffer-spanning `pointer' overlay here;
  ;;    overlays outrank text properties and would mask the hand.
  (put 'treemacs-button 'pointer 'hand)
  (defun jmc-treemacs-pointer-defaults-h ()
    "Make the arrow pointer the default over non-clickable sidebar text."
    (setq-local default-text-properties '(pointer arrow)))
  (add-hook 'treemacs-mode-hook #'jmc-treemacs-pointer-defaults-h)

  ;; --- Core Sidebar Settings ---
  (setq treemacs-collapse-dirs (if (bound-and-true-p treemacs-python-executable) 3 0)
        treemacs-display-in-side-window t
        treemacs-indentation 2         ; Folder indent spacing.
        treemacs-width 50               ; Default sidebar width in columns.

        ;; UI Syncing:
        treemacs-follow-after-init t   ; Highlight the current file on startup.
        treemacs-file-follow-delay 0.2 ; How quickly to sync the sidebar with the editor.

        ;; Persistence & Cleanup:
        treemacs-missing-project-action 'ask
        treemacs-no-delete-other-windows t ; Prevent sidebar from closing when splitting windows.
        treemacs-persist-file (expand-file-name ".cache/treemacs-persist" user-emacs-directory)

        ;; Exclusion List: Hide "junk" directories to keep the tree clean.
        treemacs-litter-directories '("/node_modules" "/.venv" "/.cask" "/vendor")

        treemacs-position 'left
        treemacs-show-hidden-files t   ; Show dotfiles like .env or .gitignore.
        treemacs-workspace-switch-cleanup nil)

  ;; --- Auto-open newly created files ---
  ;; `treemacs-create-file-functions' receives the path of anything created
  ;; via `treemacs-create-file'/`treemacs-create-dir'. We visit files (not
  ;; dirs) in the main editing area. This must be an IDLE timer: a plain
  ;; `run-with-timer' with delay 0 fires inside the `accept-process-output'
  ;; calls treemacs makes while awaiting its async git/flatten helpers —
  ;; i.e. in the middle of `treemacs--create-file/dir'. Visiting the file
  ;; at that point steals the selected window and current buffer, which
  ;; made the command's final `recenter' fail ("'recenter'ing a window
  ;; that does not display current-buffer") and raced its process
  ;; sentinels. Idle timers only fire once the command loop is done.
  (defun jmc-treemacs-visit-created-file-h (path)
    "Visit PATH in a non-sidebar window after Treemacs creates it."
    (when (file-regular-p path)
      (run-with-idle-timer 0 nil (lambda () (find-file-other-window path)))))

  (add-hook 'treemacs-create-file-functions #'jmc-treemacs-visit-created-file-h)

  ;; --- Treemacs Modes ---

  (treemacs-follow-mode t)     ; Automatically select the current file in the tree.
  (treemacs-filewatch-mode t)   ; Refresh the tree if files are changed externally (e.g., Git pull).
  (treemacs-fringe-indicator-mode 'always) ; Show expansion icons in the left margin.

  ;; Git Integration: Show file status (modified, new, ignored) via colors/icons.
  (pcase (cons (not (null (executable-find "git")))
               (not (null (bound-and-true-p treemacs-python-executable))))
    (`(t . t) (treemacs-git-mode 'deferred))
    (`(t . _) (treemacs-git-mode 'simple)))

  ;; Expanding a directory parses the output of an async python helper
  ;; (`treemacs-dirs-to-collapse.py') with a raw `read'. When that output
  ;; comes back empty — seen as transient "treemacs--expand-dir-node: End
  ;; of file during parsing" errors that abort the whole expansion — treat
  ;; it as "nothing to flatten" instead of failing.
  (define-advice treemacs--parse-flattened-dirs
      (:around (fn &rest args) jmc-eof-guard)
    (condition-case nil
        (apply fn args)
      (end-of-file nil))))

;; =============================================================================
;; VS CODE-STYLE PROJECT OPENING
;; =============================================================================
;;
;; By default, `projectile-switch-project' immediately prompts you to
;; pick a FILE in the new project — `projectile-find-file' is the default
;; `projectile-switch-project-action'. We replace that with a VS Code /
;; Cursor-style flow: the project opens with its full tree in the Treemacs
;; sidebar (single-root, exclusively this project) and the project root in
;; the main window — no file prompt. Both `s-p p' and the dashboard's
;; project entries go through `projectile-persp-switch-project', which
;; creates/switches the project's perspective and then runs this same
;; action, so both entry points behave identically.

(defun jmc-projectile-switch-action-vscode ()
  "Open the switched-to project VS Code-style: sidebar tree + root listing.
Projectile calls this with `default-directory' bound to the new project's
root. The Treemacs sidebar shows ONLY this project, and focus stays in
the main window, ready for `s-p f' or the tree."
  (require 'treemacs)
  (let ((root default-directory))
    ;; 1. Main area: the project root in Dired (rendered by dirvish).
    ;;    Swap this line for whatever "landing" view you prefer — e.g.
    ;;    (magit-status root) for a VCS-first flow — or delete it to keep
    ;;    whatever buffer was already showing.
    (dired root)
    ;; 2. Sidebar: display this project exclusively, then hand focus back
    ;;    to the main window (treemacs selects its own window when opening).
    (let ((main-window (selected-window)))
      (treemacs-add-and-display-current-project-exclusively)
      (when (window-live-p main-window)
        (select-window main-window)))))

(setq projectile-switch-project-action #'jmc-projectile-switch-action-vscode)

;; =============================================================================
;; SIDEBAR INTEGRATIONS
;; =============================================================================

;; NOTE: the old `treemacs-icons-dired' integration was REMOVED. Dirvish
;; (explorer.el) takes over every Dired buffer and renders its own icons and
;; attributes; layering treemacs icons on top of dirvish buffers produces
;; doubled/misaligned icons. If you ever drop dirvish, restore:
;;   (use-package treemacs-icons-dired
;;     :hook (dired-mode . treemacs-icons-dired-enable-once))

;; Magit Integration: Better Git awareness within the tree.
(use-package treemacs-magit
  :after (treemacs magit)
  :defer t)

;; Unify the sidebar with the config-wide nerd-icons backend.
;; -> Treemacs otherwise ships its own bundled icon theme — the last
;;    visually distinct icon family in the config. Expect the sidebar's
;;    icons to change appearance after this loads.
(use-package treemacs-nerd-icons
  :after (treemacs nerd-icons)
  :config
  (treemacs-load-theme "nerd-icons")

  ;; Give ICONS the hand pointer too. The `treemacs-button' category trick
  ;; (treemacs block above) covers node LABELS only — icons are separate
  ;; cached strings without the category property, which is why a label
  ;; showed the hand while its own icon showed the arrow. Theme icons are
  ;; SHARED string objects: adding the property to each string once covers
  ;; every line that renders it. Must run AFTER the theme is loaded; the
  ;; buffer picks it up on the next (re)render.
  (maphash (lambda (_ext icon)
             (when (and (stringp icon) (> (length icon) 0))
               (add-text-properties 0 (length icon) '(pointer hand) icon)))
           (treemacs-theme->gui-icons treemacs--current-theme)))

;; Projectile Integration: The "Bridge" package.
;; -> Ensures Treemacs understands Projectile's project definitions.
(use-package treemacs-projectile
  :after (treemacs projectile))

;; Perspective Integration: one sidebar per perspective.
;; -> WITHOUT this, Treemacs keeps a single global workspace across all
;;    perspectives: our switch action displays each project EXCLUSIVELY,
;;    so opening project B would silently rewrite what project A's
;;    perspective shows in its sidebar when you switch back. Scoping by
;;    perspective gives every project workspace its own Treemacs buffer
;;    and workspace, so each perspective's sidebar keeps showing its own
;;    project tree.
(use-package treemacs-perspective
  :after (treemacs perspective)
  :config
  (treemacs-set-scope-type 'Perspectives))

;; =============================================================================
;; UNIFIED "JUMP" KEYMAP (SUPER-P)
;; =============================================================================
;;
;; We group all project-related actions under the `s-p` prefix. This provides a
;; centralized "Command Palette" for project navigation.

;; 1. Initialize the prefix command.
(define-prefix-command 'jmc-jump-map)
;; 2. Bind it to Super-p.
(global-set-key (kbd "s-p") 'jmc-jump-map)

;; 3. Projectile Shortcuts (Project Logic)
;; -> No `with-eval-after-load` needed! These are just pointers to commands.
;; Open another project — in its OWN perspective (persp-projectile). Falls
;; through to the same `projectile-switch-project-action' (VS Code-style
;; flow below) when the perspective is new.
(define-key jmc-jump-map (kbd "p") 'projectile-persp-switch-project)
(define-key jmc-jump-map (kbd "f") 'projectile-find-file)        ; Find file in project.
(define-key jmc-jump-map (kbd "b") 'projectile-switch-to-buffer) ; Search project buffers.
(define-key jmc-jump-map (kbd "d") 'projectile-dired)            ; Open file manager at root.
;; Search text in project — `consult-ripgrep' (same engine as `M-s r'),
;; not `projectile-grep': live-updating results in the Vertico UI instead
;; of a static grep buffer, and one search frontend fewer to maintain.
(define-key jmc-jump-map (kbd "g") 'consult-ripgrep)
(define-key jmc-jump-map (kbd "c") 'projectile-compile-project)  ; Trigger build command.
(define-key jmc-jump-map (kbd "a") 'claude-code)                 ; Launch Claude at root (ai.el).

;; Terminal at project root.
;; -> FIXED: this used to be `projectile-run-vterm' (and `s-p v' was
;;    `vterm-toggle') — but NOTHING in this config installs vterm anymore;
;;    the terminal is ghostel (terminal.el). Both keys signalled
;;    void-function errors. `jmc-ghostel-toggle' already resolves the
;;    project root itself, so it is the drop-in replacement. (`s-9' remains
;;    the global toggle for the same drawer.)
(define-key jmc-jump-map (kbd "r") 'jmc-ghostel-toggle)

;; 4. Treemacs Shortcuts (UI Controls)
(defun jmc-find-top-git-root (dir)
  "Walk up from DIR to find the topmost git repository root.
Returns the topmost directory containing a .git entry, or nil."
  (let ((top nil)
        (current (directory-file-name (expand-file-name dir))))
    (while (not (string= current (file-name-directory current)))
      (when (file-exists-p (expand-file-name ".git" current))
        (setq top current))
      (setq current (directory-file-name (file-name-directory current))))
    top))

(defun jmc-treemacs-smart-toggle ()
  "Toggle Treemacs open or closed.
When opening, display the topmost git root and navigate to the current file."
  (interactive)
  (require 'treemacs)

  (if (eq (treemacs-current-visibility) 'visible)
      (delete-window (treemacs-get-local-window))
    (let* ((file-path (buffer-file-name))
           (start-dir (or (and file-path (file-name-directory file-path))
                          default-directory))
           (top-root (or (jmc-find-top-git-root start-dir)
                         (projectile-project-root))))
      ;; Temporarily override projectile's root so Treemacs picks up the top-level repo
      (cl-letf (((symbol-function 'projectile-project-root) (lambda (&rest _) top-root)))
        (treemacs-add-and-display-current-project-exclusively))
      (if file-path
          (run-with-idle-timer 0.1 nil
                               (lambda ()
                                 (when (treemacs-get-local-window)
                                   (treemacs-goto-file-node file-path))))
        (message "Current buffer is not visiting a file")))))

(define-key jmc-jump-map (kbd "0") 'treemacs-select-window)      ; Focus the sidebar.
(define-key jmc-jump-map (kbd "t") 'jmc-treemacs-smart-toggle)   ; Custom open & follow

;; =============================================================================
;; FINALIZE
;; =============================================================================

(provide 'projects)

;;; projects.el ends here
