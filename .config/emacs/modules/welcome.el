;;; welcome.el --- Bespoke startup welcome screen -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; A hand-rolled startup screen that REPLACES the `dashboard' package.
;;
;; Why bespoke? The dashboard config had painted itself into a corner:
;; * `dashboard-show-shortcuts' was nil AND a custom "lock mode" disabled
;;   every movement/scroll key to protect the centered layout — so the
;;   recent-files and projects lists were effectively MOUSE-ONLY.
;; * recentf fed it internal junk (treemacs-persist, package sources),
;;   because the exclusions lived nowhere (fixed in editor.el).
;; Rather than fight the package's rendering pipeline, this module draws
;; the whole screen itself (~an insert loop) and gets to be keyboard-first
;; by construction. No lock mode: movement keys are BOUND TO item
;; navigation instead of disabled. What IS locked, deliberately, is
;; SCROLLING — the layout centers itself against the window, so any
;; scroll (wheel, trackpad, SPC/C-v, scroll-bar drag) only breaks it.
;; Scroll commands are remapped away and a window hook snaps back
;; anything that slips through; see the "Scroll lock" sections below.
;;
;; The screen:
;;   * ASCII banner + a footer with package count / startup time.
;;   * A quick-action row and two live sections:
;;       Recent Files - recentf, junk filtered, dead files skipped.
;;       Projects     - projectile-known-projects, newest first.
;;   * Every item is a real button: TAB / S-TAB / arrows / C-n / C-p move
;;     between them, RET (or mouse-1) opens.
;;   * Action keys: f find-file, r recent files (consult), p switch
;;     project, e open this config's project. `g' re-renders (standard
;;     special-mode revert), `q' buries the buffer. `d' FORGETS the item
;;     under point — list bookkeeping only, nothing is touched on disk;
;;     see `jmc-welcome-forget-item' for the auto-discovery caveats.
;;   * Projects open through `projectile-persp-switch-project', exactly
;;     like `s-p p' — each lands in its own perspective (projects.el).
;;
;; The buffer re-centers itself whenever its window geometry changes and
;; refreshes its project list when projectile finishes loading (packages
;; install asynchronously via Elpaca, so projectile is usually NOT ready
;; the first time this renders at startup).
;;
;; NOTE on the file name: this module provides `welcome'. The name was
;; checked against the package archives the way lang-server.el's rename
;; taught us to — nothing on (M)ELPA ships a `welcome.el' that could be
;; shadowed on the load-path.
;;
;;; Code:

;; =============================================================================
;; COMPILER DECLARATIONS (SILENCE WARNINGS)
;; =============================================================================
;; Everything external is loaded lazily at RENDER time (this module must
;; not slow startup down by requiring projectile/nerd-icons itself).

(defvar recentf-list)
(defvar projectile-known-projects)

(defvar projectile-project-search-path)

(declare-function projectile-project-root "projectile")
(declare-function projectile-remove-known-project "projectile")
(declare-function projectile-persp-switch-project "persp-projectile")
(declare-function consult-recent-file "consult")
(declare-function nerd-icons-icon-for-file "nerd-icons")
(declare-function nerd-icons-icon-for-dir "nerd-icons")
(declare-function nerd-icons-octicon "nerd-icons")
(declare-function elpaca--queued "elpaca")

;; =============================================================================
;; FACES & OPTIONS
;; =============================================================================
;; All faces inherit from standard font-lock faces, so the screen adapts
;; to whichever theme is active on this machine (`jmc-theme' in init.el /
;; local.el) with no per-theme tweaking here:
;;   * gruvbox-dark-hard: banner/headings red, keys purple, muted gray.
;;   * catppuccin mocha:  banner/headings mauve, keys peach, muted overlay.
;; Face inheritance resolves at DISPLAY time, so even switching themes in
;; a running session recolors the screen without a re-render.

(defgroup jmc-welcome nil
  "Bespoke startup welcome screen."
  :group 'convenience
  :prefix "jmc-welcome-")

(defface jmc-welcome-banner-face
  '((t :inherit font-lock-keyword-face :weight bold))
  "Face for the ASCII banner.")

(defface jmc-welcome-heading-face
  '((t :inherit font-lock-keyword-face :weight bold))
  "Face for section headings (matches the old `dashboard-heading' look).")

(defface jmc-welcome-key-face
  '((t :inherit font-lock-constant-face :weight bold))
  "Face for the action keys in the quick-action row.")

(defface jmc-welcome-muted-face
  '((t :inherit font-lock-comment-face))
  "Face for de-emphasized text: paths, hints, the footer.")

(defface jmc-welcome-focus-face
  '((t :inherit highlight))
  "Face for the item under point (applied via `cursor-face').")

(defvar jmc-welcome-recents-count 5
  "How many recent files to list.")

(defvar jmc-welcome-projects-count 5
  "How many projects to list.")

(defvar jmc-welcome-width 66
  "Column width of the content block.  Lines are padded to center it.")

;; =============================================================================
;; BANNER
;; =============================================================================

(defconst jmc-welcome--banner
  '("███████╗ ███╗   ███╗  █████╗   ██████╗ ███████╗"
    "██╔════╝ ████╗ ████║ ██╔══██╗ ██╔════╝ ██╔════╝"
    "█████╗   ██╔████╔██║ ███████║ ██║      ███████╗"
    "██╔══╝   ██║╚██╔╝██║ ██╔══██║ ██║      ╚════██║"
    "███████╗ ██║ ╚═╝ ██║ ██║  ██║ ╚██████╗ ███████║"
    "╚══════╝ ╚═╝     ╚═╝ ╚═╝  ╚═╝  ╚═════╝ ╚══════╝")
  "ANSI-shadow \"EMACS\", 47 columns wide.
Box-drawing + block glyphs only, so it renders in the terminal too.")

(defconst jmc-welcome--subtitle "· s u p r e m e ·"
  "Small tag line under the banner (nod to the repo name).")

;; =============================================================================
;; BUFFER-LOCAL RENDER STATE
;; =============================================================================

(defvar-local jmc-welcome--first-item nil
  "Marker at the first list item, where point parks after a render.")

(defvar-local jmc-welcome--last-dims nil
  "(WIDTH . HEIGHT) of the last render, guarding against redundant ones.")

;; =============================================================================
;; DATA SOURCES
;; =============================================================================

(defun jmc-welcome--recent-files ()
  "Return up to `jmc-welcome-recents-count' recent files that still exist.
Remote (TRAMP) entries are skipped WITHOUT an existence check — statting
them would block startup on the network.  The walk stops as soon as
enough survivors are found instead of filtering all of `recentf-list'."
  (let ((files nil)
        (tail (and (boundp 'recentf-list) recentf-list)))
    (while (and tail (< (length files) jmc-welcome-recents-count))
      (let ((file (pop tail)))
        (when (and (not (file-remote-p file))
                   (file-exists-p file)
                   (not (file-directory-p file)))
          (push file files))))
    (nreverse files)))

(defun jmc-welcome--projects ()
  "Return up to `jmc-welcome-projects-count' known projects, newest first.
`projectile-known-projects' is already recency-ordered; directories that
no longer exist are skipped (they stay in projectile's list until its
own cleanup runs)."
  (let ((projects nil)
        (tail (and (boundp 'projectile-known-projects)
                   projectile-known-projects)))
    (while (and tail (< (length projects) jmc-welcome-projects-count))
      (let ((project (pop tail)))
        (when (and (not (file-remote-p project))
                   (file-directory-p project)
                   ;; Belt and braces: forgetting already removes the
                   ;; known-projects entry, but a hand-edited blocklist
                   ;; must win over a stale known-projects file too.
                   (not (jmc-welcome-project-ignored-p project)))
          (push project projects))))
    (nreverse projects)))

;; =============================================================================
;; ICONS
;; =============================================================================
;; nerd-icons installs asynchronously (Elpaca), so every icon helper
;; degrades to nil until `require' succeeds — the screen renders without
;; icons on a fresh clone and picks them up on the next re-render.

(defun jmc-welcome--file-icon (file)
  "Language-aware nerd-icon for FILE, or nil while nerd-icons is missing."
  (when (require 'nerd-icons nil 'noerror)
    (nerd-icons-icon-for-file (file-name-nondirectory file))))

(defvar jmc-welcome-project-marker-files
  '("Cargo.toml" "go.mod" "package.json" "composer.json" "Gemfile"
    "pyproject.toml" "requirements.txt" "Pipfile" "setup.py"
    "pom.xml" "build.gradle" "mix.exs" "Package.swift" "CMakeLists.txt")
  "Marker files checked, in order, to guess a project's language for icons.")

(defvar jmc-welcome-project-marker-extensions
  '("\\.rs\\'" "\\.go\\'" "\\.py\\'" "\\.rb\\'" "\\.php\\'" "\\.sql\\'")
  "Fallback file-extension patterns for projects without a manifest file.
Only the project's top-level directory is scanned, to avoid recursing
into directories like `node_modules'.")

(defun jmc-welcome--project-icon (dir)
  "Icon reflecting DIR's tech stack, not its name.
Generic icon-for-dir functions match patterns against the DIRECTORY
NAME (any project containing \"test\" gets the same test-tube icon
regardless of language), so look for a well-known marker file instead
and borrow the language-aware FILE icon for it."
  (when (require 'nerd-icons nil 'noerror)
    (let* ((exact (seq-find (lambda (f)
                              (file-exists-p (expand-file-name f dir)))
                            jmc-welcome-project-marker-files))
           (by-ext (and (not exact)
                        (seq-find (lambda (re) (directory-files dir nil re t))
                                  jmc-welcome-project-marker-extensions)))
           (sample (and by-ext (car (directory-files dir nil by-ext t)))))
      (cond
       (exact (nerd-icons-icon-for-file exact))
       (sample (nerd-icons-icon-for-file sample))
       (t (nerd-icons-icon-for-dir dir))))))

;; =============================================================================
;; ACTIONS
;; =============================================================================

(defun jmc-welcome--open-project (dir)
  "Open DIR the same way `s-p p' does: in its own perspective.
Falls back to plain Dired when persp-projectile isn't loaded yet."
  (if (fboundp 'projectile-persp-switch-project)
      (projectile-persp-switch-project dir)
    (dired dir)))

;; -----------------------------------------------------------------------------
;; Forgetting Items (the `d' key)
;; -----------------------------------------------------------------------------
;; "Forget" is LIST bookkeeping only — nothing is ever deleted on disk.
;; Recent files simply leave `recentf-list'. Projects need more care:
;; removing one from `projectile-known-projects' is not enough when it
;; lives under `projectile-project-search-path', because the automatic
;; re-scan (projects.el idle timer, and projectile-mode on every launch)
;; would silently re-discover it. Those projects additionally go onto a
;; persistent blocklist consulted through
;; `projectile-ignored-project-function' (wired up in projects.el).
;;
;; Why not projectile's own `projectile-ignored-projects' option? Its
;; matching is broken for exactly this case: discovery offers candidates
;; as ABBREVIATED paths ("~/...") but compares them against the option's
;; entries mapped through `file-truename' (absolute paths) — the member
;; check can never succeed, so blocklisted projects come straight back.
;; Our predicate normalizes BOTH sides through `file-truename' instead.

(defcustom jmc-welcome-ignored-projects nil
  "Projects (in `file-truename' form) to keep off the welcome screen.
Managed by `jmc-welcome-forget-item' (`d' on a project item), which
persists it via customize into the machine-local custom.el. Also blocks
re-discovery, through `projectile-ignored-project-function'. To un-forget
a project, remove its entry here and visit the project again."
  :type '(repeat directory)
  :group 'jmc-welcome)

(defun jmc-welcome-project-ignored-p (project-root)
  "Non-nil when PROJECT-ROOT is on `jmc-welcome-ignored-projects'.
Robust against spelling differences: projectile hands this predicate
abbreviated paths from discovery and expanded paths from the find-file
auto-add, so both sides are normalized through `file-truename'."
  (member (file-truename project-root) jmc-welcome-ignored-projects))

(defun jmc-welcome--rediscoverable-p (project)
  "Non-nil when PROJECT sits under `projectile-project-search-path'.
Such projects would be re-added by the next automatic re-scan, so
forgetting them must also blocklist them. Search-path entries are
either DIR strings or (DIR . DEPTH) conses."
  (let ((expanded (expand-file-name project)))
    (seq-some (lambda (entry)
                (string-prefix-p
                 (file-name-as-directory
                  (expand-file-name (if (consp entry) (car entry) entry)))
                 expanded))
              (and (boundp 'projectile-project-search-path)
                   projectile-project-search-path))))

(defun jmc-welcome--forget-recent (file)
  "Drop FILE from `recentf-list' (the file itself stays) and re-render."
  (when (y-or-n-p (format "Forget recent file %s? "
                          (file-name-nondirectory file)))
    ;; FILE is the exact `recentf-list' member (the render harvests the
    ;; list verbatim), so plain `delete' matches it. recentf persists the
    ;; list on exit as usual.
    (setq recentf-list (delete file recentf-list))
    (jmc-welcome--render)
    (message "Forgot %s (the file itself is untouched)" file)))

(defun jmc-welcome--forget-project (project)
  "Remove PROJECT from projectile's known list and re-render.
When PROJECT would be re-discovered automatically, also blocklist it in
`jmc-welcome-ignored-projects' (persisted via customize)."
  (let ((rediscoverable (jmc-welcome--rediscoverable-p project)))
    (when (y-or-n-p (format "Forget project %s%s? "
                            (file-name-nondirectory
                             (directory-file-name project))
                            (if rediscoverable
                                " (and ignore it in future scans)"
                              "")))
      ;; Non-interactive call: removes the entry and persists the known
      ;; list immediately (`projectile-merge-known-projects').
      (projectile-remove-known-project project)
      (when rediscoverable
        (let ((resolved (file-truename project)))
          (unless (member resolved jmc-welcome-ignored-projects)
            (customize-save-variable
             'jmc-welcome-ignored-projects
             (cons resolved jmc-welcome-ignored-projects)))))
      (jmc-welcome--render)
      (message "Forgot project %s (nothing deleted on disk)" project))))

(defun jmc-welcome-forget-item ()
  "Forget the list item under point (action key: d).
Recent files leave recentf; projects leave projectile's known list (and
its auto-discovery, when applicable). Nothing is deleted on disk."
  (interactive)
  (let* ((button (button-at (point)))
         (forget-fn (and button (button-get button 'jmc-welcome-forget-fn))))
    (if forget-fn
        (funcall forget-fn)
      (user-error "No forgettable item at point"))))

(defun jmc-welcome-find-file ()
  "Prompt for a file to open (action key: f)."
  (interactive)
  (call-interactively #'find-file))

(defun jmc-welcome-recent-files ()
  "Search ALL recent files, not just the listed ones (action key: r)."
  (interactive)
  (if (fboundp 'consult-recent-file)
      (consult-recent-file)
    ;; Built-in fallback (Emacs 29+) while consult is still installing.
    (call-interactively #'recentf-open)))

(defun jmc-welcome-switch-project ()
  "Switch to ANY known project, in its own perspective (action key: p)."
  (interactive)
  (if (fboundp 'projectile-persp-switch-project)
      (call-interactively #'projectile-persp-switch-project)
    (user-error "Projectile is still loading — try again in a moment")))

(defun jmc-welcome-open-config ()
  "Open this Emacs configuration as a project (action key: e).
`user-emacs-directory' is a stow symlink into the dotfiles checkout, so
resolve the truename FIRST — projectile roots the real repository, not
the symlink."
  (interactive)
  (let ((root (and (fboundp 'projectile-project-root)
                   (projectile-project-root (file-truename user-emacs-directory)))))
    (if root
        (jmc-welcome--open-project root)
      (find-file (file-truename user-init-file)))))

(defun jmc-welcome-next-button ()
  "Move to the next button, wrapping around at the end."
  (interactive)
  (forward-button 1 t nil t))

(defun jmc-welcome-previous-button ()
  "Move to the previous button, wrapping around at the start."
  (interactive)
  (backward-button 1 t nil t))

(defun jmc-welcome-first-button ()
  "Move to the first list item (stands in for `beginning-of-buffer')."
  (interactive)
  (if jmc-welcome--first-item
      (goto-char jmc-welcome--first-item)
    (goto-char (point-min))
    (forward-button 1 t nil t)))

(defun jmc-welcome-last-button ()
  "Move to the last button (stands in for `end-of-buffer')."
  (interactive)
  (goto-char (point-max))
  (backward-button 1 t nil t))

;; =============================================================================
;; RENDERING
;; =============================================================================

(define-button-type 'jmc-welcome
  'follow-link t          ; mouse-1 activates (not just mouse-2)
  'mouse-face 'highlight
  'pointer 'hand          ; hand cursor over clickables, like treemacs
  'cursor-face 'jmc-welcome-focus-face ; row glow via cursor-face-highlight-mode
  'action (lambda (button) (funcall (button-get button 'jmc-welcome-fn))))

(defun jmc-welcome--center (str)
  "Return STR padded to sit centered inside the content block."
  (concat (make-string (max 0 (/ (- jmc-welcome-width (string-width str)) 2))
                       ?\s)
          str))

(defun jmc-welcome--truncate-middle (str width)
  "Fit STR into WIDTH columns, eliding the middle when too long.
For paths, the middle is the least informative part — the leading ~/
segment and the trailing component both survive."
  (if (<= (string-width str) width)
      str
    (let* ((head (max 1 (/ (- width 1) 2)))
           (tail (max 1 (- width 1 head))))
      (concat (truncate-string-to-width str head)
              "…"
              (substring str (- (length str) tail))))))

(defun jmc-welcome--insert-banner (pad)
  "Insert the banner block, each line prefixed with PAD."
  (dolist (line jmc-welcome--banner)
    (insert pad
            (propertize (jmc-welcome--center line) 'face 'jmc-welcome-banner-face)
            "\n"))
  (insert pad
          (propertize (jmc-welcome--center jmc-welcome--subtitle)
                      'face 'jmc-welcome-muted-face)
          "\n"))

(defun jmc-welcome--insert-heading (pad icon-name title hint)
  "Insert a section heading: octicon ICON-NAME + TITLE, HINT right-aligned.
PAD is the left margin of the content block."
  (let* ((icon (when (require 'nerd-icons nil 'noerror)
                 (nerd-icons-octicon icon-name :face 'jmc-welcome-heading-face)))
         (left (concat (if icon (concat icon " ") "")
                       (propertize title 'face 'jmc-welcome-heading-face)))
         (gap (max 2 (- jmc-welcome-width
                        (string-width left)
                        (string-width hint)))))
    (insert pad left (make-string gap ?\s)
            (propertize hint 'face 'jmc-welcome-muted-face)
            "\n")))

(defun jmc-welcome--insert-item (pad icon name path fn forget-fn)
  "Insert one clickable item row inside margin PAD.
ICON is an already-propertized glyph or nil, NAME the emphasized left
text, PATH the muted remainder, FN the parameterless open function and
FORGET-FN the parameterless de-listing function (the `d' key).
The 3-space indent stays OUTSIDE the button so the focus highlight
starts at the item itself."
  (let ((name-width 28)
        (start nil))
    (insert pad "   ")
    (setq start (point))
    (when icon
      (insert icon " "))
    (let ((shown (truncate-string-to-width name name-width nil nil "…")))
      (insert shown)
      ;; Pad NAME to a fixed column so the PATH column lines up.
      (insert (make-string (max 2 (- (+ name-width 2) (string-width shown)))
                           ?\s)))
    (let ((path-width (- jmc-welcome-width 3 (if icon 2 0) (+ 28 2))))
      (insert (propertize (jmc-welcome--truncate-middle path path-width)
                          'face 'jmc-welcome-muted-face)))
    (make-text-button start (point)
                      'type 'jmc-welcome
                      'jmc-welcome-fn fn
                      'jmc-welcome-forget-fn forget-fn
                      'help-echo (concat path "  —  RET opens · d forgets"))
    (insert "\n")
    (unless jmc-welcome--first-item
      (setq jmc-welcome--first-item (copy-marker start)))))

(defun jmc-welcome--insert-empty (pad text)
  "Insert the muted empty-section line TEXT inside margin PAD."
  (insert pad "   " (propertize text 'face 'jmc-welcome-muted-face) "\n"))

(defun jmc-welcome--actions-row ()
  "Return the quick-action row as a string with live buttons.
Built in a temp buffer so its width can be measured for centering —
button properties are plain text properties and survive the copy."
  (with-temp-buffer
    (dolist (spec '(("f" "find file" jmc-welcome-find-file)
                    ("r" "recents" jmc-welcome-recent-files)
                    ("p" "projects" jmc-welcome-switch-project)
                    ("e" "config" jmc-welcome-open-config)))
      (unless (bobp)
        (insert "    "))
      (let ((start (point)))
        (insert (propertize (format "[%s]" (nth 0 spec))
                            'face 'jmc-welcome-key-face)
                " " (nth 1 spec))
        (make-text-button start (point)
                          'type 'jmc-welcome
                          'jmc-welcome-fn (nth 2 spec)
                          'help-echo nil)))
    (buffer-string)))

(defun jmc-welcome--footer ()
  "Footer text: package count, startup time, Emacs version.
Segments whose source isn't available yet are simply dropped."
  (let* ((packages (when (fboundp 'elpaca--queued)
                     (length (elpaca--queued))))
         (seconds (when after-init-time
                    (float-time (time-subtract after-init-time
                                               before-init-time))))
         (parts (delq nil
                      (list (when packages (format "%d packages" packages))
                            (when seconds (format "ready in %.2fs" seconds))
                            (format "GNU Emacs %s" emacs-version)))))
    (mapconcat #'identity parts "  ·  ")))

(defun jmc-welcome--render (&optional window)
  "Draw (or redraw) the welcome screen, sized for WINDOW.
WINDOW defaults to the window currently showing the buffer, falling
back to the selected one — at startup the buffer isn't displayed yet
when `initial-buffer-choice' calls this, and the selected window is the
best available estimate (the relayout hook corrects any drift as soon
as the buffer IS shown)."
  (let* ((buffer (get-buffer-create "*welcome*"))
         (window (or window (get-buffer-window buffer) (selected-window)))
         (width (window-body-width window))
         (height (window-body-height window)))
    (with-current-buffer buffer
      (unless (derived-mode-p 'jmc-welcome-mode)
        (jmc-welcome-mode))
      (let ((inhibit-read-only t)
            (pad (make-string (max 0 (/ (- width jmc-welcome-width) 2)) ?\s)))
        (erase-buffer)
        (setq jmc-welcome--first-item nil)

        (jmc-welcome--insert-banner pad)
        (insert "\n" pad (jmc-welcome--center (jmc-welcome--actions-row)) "\n\n")

        ;; --- Recent files ---
        (jmc-welcome--insert-heading pad "nf-oct-history" "Recent Files"
                                     "r → search all · d → forget")
        (let ((files (jmc-welcome--recent-files)))
          (if (null files)
              (jmc-welcome--insert-empty pad "Files you visit will appear here")
            (dolist (file files)
              (let ((file file)) ; fresh binding per closure — dolist reuses its var
                (jmc-welcome--insert-item
                 pad
                 (jmc-welcome--file-icon file)
                 (file-name-nondirectory file)
                 (abbreviate-file-name (or (file-name-directory file) ""))
                 (lambda () (find-file file))
                 (lambda () (jmc-welcome--forget-recent file)))))))
        (insert "\n")

        ;; --- Projects ---
        (jmc-welcome--insert-heading pad "nf-oct-file_directory" "Projects"
                                     "p → open any · d → forget")
        (let ((projects (jmc-welcome--projects)))
          (if (null projects)
              (jmc-welcome--insert-empty
               pad (if (featurep 'projectile)
                       "No projects known yet — still scanning ~/Projects"
                     "Projectile is still loading…"))
            (dolist (project projects)
              (let ((project project))
                (jmc-welcome--insert-item
                 pad
                 (jmc-welcome--project-icon project)
                 (file-name-nondirectory (directory-file-name project))
                 (abbreviate-file-name project)
                 (lambda () (jmc-welcome--open-project project))
                 (lambda () (jmc-welcome--forget-project project)))))))

        (insert "\n" pad
                (propertize (jmc-welcome--center (jmc-welcome--footer))
                            'face 'jmc-welcome-muted-face)
                "\n")

        ;; Vertical centering: pad the top AFTER measuring the content.
        ;; (Markers — including `jmc-welcome--first-item' — shift along.)
        (goto-char (point-min))
        (insert (make-string
                 (max 0 (/ (- height (count-lines (point-min) (point-max))) 2))
                 ?\n))

        (setq jmc-welcome--last-dims (cons width height))
        (goto-char (or jmc-welcome--first-item (point-min)))))
    buffer))

;; =============================================================================
;; MODE
;; =============================================================================

(defvar jmc-welcome-mode-map
  (let ((map (make-sparse-keymap)))
    ;; Item navigation. There is no free-roaming cursor (it is hidden and
    ;; point is confined to buttons), so ALL movement keys hop between
    ;; items — the keyboard-first answer to the old dashboard's approach
    ;; of disabling these keys outright.
    (define-key map (kbd "TAB")       #'jmc-welcome-next-button)
    (define-key map (kbd "<backtab>") #'jmc-welcome-previous-button)
    (define-key map (kbd "<down>")    #'jmc-welcome-next-button)
    (define-key map (kbd "<up>")      #'jmc-welcome-previous-button)
    (define-key map (kbd "<right>")   #'jmc-welcome-next-button)
    (define-key map (kbd "<left>")    #'jmc-welcome-previous-button)
    (define-key map [remap next-line]     #'jmc-welcome-next-button)
    (define-key map [remap previous-line] #'jmc-welcome-previous-button)
    ;; RET works even if point somehow leaves a button (buttons also
    ;; carry their own RET via the standard button keymap).
    (define-key map (kbd "RET") #'push-button)
    ;; Quick actions.
    (define-key map (kbd "f") #'jmc-welcome-find-file)
    (define-key map (kbd "r") #'jmc-welcome-recent-files)
    (define-key map (kbd "p") #'jmc-welcome-switch-project)
    (define-key map (kbd "e") #'jmc-welcome-open-config)
    ;; Forget (de-list) the item under point. List-only: nothing on disk
    ;; is touched.
    (define-key map (kbd "d") #'jmc-welcome-forget-item)
    ;; --- Scroll lock (keys, wheel, trackpad) -------------------------
    ;; The layout centers itself against the window; scrolling only
    ;; breaks it. Suppression happens at the COMMAND level, via
    ;; remapping, because the triggering EVENT may be bound in a map
    ;; that outranks this one — pixel-scroll-precision-mode's global
    ;; minor-mode map claims the wheel events, and minor-mode maps beat
    ;; major-mode maps. Command remapping is resolved against the FULL
    ;; active-map stack at execution time, so these win regardless of
    ;; which map bound the event.
    (dolist (cmd '(scroll-up-command scroll-down-command ; C-v/M-v, SPC/DEL
                   scroll-up scroll-down
                   scroll-left scroll-right               ; C-x < / C-x >
                   mwheel-scroll                          ; classic wheel + tilt
                   pixel-scroll-precision                 ; trackpad (Emacs 29+)
                   pixel-scroll-start-momentum))
      (define-key map (vector 'remap cmd) #'ignore))
    ;; M-< / M-> hop to the extreme buttons instead of moving point into
    ;; the padding.
    (define-key map [remap beginning-of-buffer] #'jmc-welcome-first-button)
    (define-key map [remap end-of-buffer]       #'jmc-welcome-last-button)
    ;; Some scroll KEYS need neutralizing directly: cua-mode (editor.el)
    ;; remaps scroll-up/down-command to cua-scroll-up/down from its
    ;; EMULATION map, which outranks this map in the remap contest — and
    ;; remapping is single-step, so remapping cua-scroll-* here would
    ;; never be consulted. For plain KEY bindings the major mode still
    ;; beats the global/special-mode maps, so bind the scroll keys
    ;; themselves.
    (define-key map (kbd "SPC")     #'ignore) ; special-mode scroll keys
    (define-key map (kbd "S-SPC")   #'ignore)
    (define-key map (kbd "DEL")     #'ignore)
    (define-key map (kbd "<prior>") #'ignore) ; PageUp / PageDown
    (define-key map (kbd "<next>")  #'ignore)
    map)
  "Keymap for `jmc-welcome-mode'.
`q' (bury) and `g' (revert = re-render) come from `special-mode'.")

(define-derived-mode jmc-welcome-mode special-mode "Welcome"
  "Major mode for the bespoke startup screen.
\\{jmc-welcome-mode-map}"
  ;; The block cursor is noise on a screen made of buttons; the focused
  ;; item is shown by `jmc-welcome-focus-face' instead, which
  ;; `cursor-face-highlight-mode' (Emacs 29+) applies to the button under
  ;; point via its `cursor-face' property.
  (setq-local cursor-type nil)
  (cursor-face-highlight-mode 1)
  (setq-local truncate-lines t)
  (setq-local show-trailing-whitespace nil)
  ;; Renders are pure output; recording them for undo just leaks memory.
  (buffer-disable-undo)
  ;; `g' from special-mode lands here.
  (setq-local revert-buffer-function
              (lambda (_ignore-auto _noconfirm) (jmc-welcome--render)))
  ;; --- Scroll lock (window level) ---
  ;; Never auto-hscroll to chase point: content wider than a (too
  ;; narrow) window is simply truncated, it must not slide the layout.
  (setq-local auto-hscroll-mode nil)
  ;; Backstop for scroll vectors no keymap can reach: scroll-bar drags,
  ;; edge-of-window mouse drags, `scroll-other-window' issued from
  ;; another buffer, code calling `set-window-start'.
  (add-hook 'window-scroll-functions #'jmc-welcome--pin-scroll-h nil t)
  ;; Re-center when the geometry changes. The BUFFER-LOCAL variant of
  ;; this hook runs (with the window selected) whenever a window starts
  ;; showing the buffer or changes size — the dims guard inside the
  ;; handler stops the render->hook->render loop.
  (add-hook 'window-configuration-change-hook
            #'jmc-welcome--relayout-h nil t))

(defun jmc-welcome--pin-scroll-h (window _display-start)
  "Snap WINDOW back to its unscrolled state after anything scrolls it.
Vertical pinning applies only while the content FITS the window: in one
too small, normal scrolling has to win, or redisplay (which is obliged
to keep point visible) would fight this hook indefinitely. Re-entry
terminates — the second run sees an already-pinned window and changes
nothing."
  (set-window-hscroll window 0)
  (with-current-buffer (window-buffer window)
    (when (and (<= (count-lines (point-min) (point-max))
                   (window-body-height window))
               (/= (window-start window) (point-min)))
      (set-window-start window (point-min)))))

(defun jmc-welcome--relayout-h ()
  "Re-render iff the displaying window's geometry actually changed."
  ;; No scroll bars on the welcome window (ported from the old
  ;; dashboard lock): the layout cannot scroll, so a bar — macOS shows
  ;; its overlay one during trackpad gestures — would only advertise
  ;; movement this screen suppresses. Idempotent, so unconditional.
  (set-window-scroll-bars (selected-window) nil nil)
  (let ((dims (cons (window-body-width) (window-body-height))))
    (unless (equal dims jmc-welcome--last-dims)
      (jmc-welcome--render (selected-window)))))

;; =============================================================================
;; ENTRY POINTS & STARTUP WIRING
;; =============================================================================

(defun jmc-welcome-buffer ()
  "Return the welcome buffer, freshly rendered.
This is the `initial-buffer-choice' function; also usable any time."
  (jmc-welcome--render))

(defun jmc-welcome ()
  "Switch to the welcome screen (also on `s-p h', see projects.el)."
  (interactive)
  (switch-to-buffer (jmc-welcome-buffer)))

(defun jmc-welcome-refresh-visible ()
  "Re-render the welcome screen if it is currently displayed somewhere.
Called by projects.el after its idle project re-scan, and after
projectile first loads — both moments where the project list on an
already-visible screen has just become stale."
  (when-let* ((buffer (get-buffer "*welcome*"))
              (window (get-buffer-window buffer t)))
    (jmc-welcome--render window)))

;; Make the welcome screen the initial buffer — unless Emacs was started
;; with a file argument (e.g. `emacs file.txt'). Same guard the dashboard
;; used. emacsclient frames without a file honor this too.
(unless (> (length command-line-args) 1)
  (setq initial-buffer-choice #'jmc-welcome-buffer))

;; The *scratch* buffer is dead weight once a startup screen exists
;; (ported from the old dashboard-after-initialize-hook). Keyed on the
;; welcome BUFFER existing rather than on `initial-buffer-choice' still
;; being ours: on a fresh clone Elpaca temporarily REPLACES that variable
;; to show its build log (elpaca-log-initial-queues) — the buffer is the
;; reliable signal that the welcome screen actually rendered this
;; startup. A file-argument launch creates no welcome buffer and keeps
;; its scratch buffer.
(defun jmc-welcome--kill-scratch-h ()
  "Kill *scratch* when the welcome screen rendered during startup."
  (when (and (get-buffer "*welcome*")
             (get-buffer "*scratch*"))
    (kill-buffer "*scratch*")))

(add-hook 'emacs-startup-hook #'jmc-welcome--kill-scratch-h)

;; Elpaca installs projectile AFTER this module has rendered the initial
;; screen, so the Projects section usually starts life as the "still
;; loading" placeholder. Re-render the moment projectile-mode activates
;; (its known-projects list is loaded by then; the hook runs after the
;; mode body).
(add-hook 'projectile-mode-hook #'jmc-welcome-refresh-visible)

;; =============================================================================
;; FINALIZE
;; =============================================================================

(provide 'welcome)

;;; welcome.el ends here
