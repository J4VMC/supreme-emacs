;;; docs.el --- Headless Offline Documentation -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; This module provides lightning-fast, offline documentation lookup right inside Emacs.
;;
;; It replicates the functionality of the popular macOS app "Dash", but without
;; requiring the app to be installed. It downloads official Dash docsets and
;; uses `consult` to fuzzy-search them, rendering the results in Emacs's built-in
;; web browser (`eww`).
;;
;; Usage:
;; 1. `M-x my/install-missing-docsets`   -> Downloads all mapped docsets.
;; 2. `M-x my/install-docsets-for-mode`  -> Downloads docsets ONLY for the current language.
;; 3. `M-x my/list-installed-docsets`    -> View what is currently installed.
;; 4. `M-s d`                            -> Search docs for the word under the cursor.
;;
;;; Code:

;; Ensure required libraries are loaded for downloading and parsing XML feeds.
(require 'url)
(require 'seq)
(require 'subr-x)

;; =============================================================================
;; COMPILER DECLARATIONS (SILENCE WARNINGS)
;; =============================================================================

(defvar dash-docs-docsets-path)
(defvar dash-docs-browser-func)
(defvar embark-general-map)
(defvar embark-keymap-alist)

(declare-function consult-dash "consult-dash")
(declare-function dash-docs-installed-docsets "dash-docs")

;; =============================================================================
;; 1. CONFIGURATION & DATA MAPPING
;; =============================================================================

;; This mapping tells Emacs which docsets are relevant for which programming language.
;; -> When you press `M-s d` in a Python file, it will only search Python, Django, etc.
(defvar jmc-docset-map
  '((php-mode            . ("PHP" "Symfony" "Laravel" "PHPUnit" "Composer" "WordPress"))
    (php-ts-mode         . ("PHP" "Symfony" "Laravel" "PHPUnit" "Composer" "WordPress"))
    
    (python-mode         . ("Python 3" "Django" "Flask" "FastAPI" "NumPy" "Pandas"))
    (python-ts-mode      . ("Python 3" "Django" "Flask" "FastAPI" "NumPy" "Pandas"))
    
    (js-mode             . ("JavaScript" "NodeJS" "Express"))
    (js-ts-mode          . ("JavaScript" "NodeJS" "Express"))
    (typescript-mode     . ("TypeScript" "NodeJS"))
    (typescript-ts-mode  . ("TypeScript" "NodeJS"))
    (tsx-ts-mode         . ("TypeScript" "React" "NodeJS"))
    (vue-mode            . ("VueJS" "JavaScript" "NodeJS"))
    
    (go-mode             . ("Go" "Gin"))
    (go-ts-mode          . ("Go" "Gin"))
    
    (rustic-mode         . ("Rust" "Cargo"))
    (rust-mode           . ("Rust" "Cargo"))
    (rust-ts-mode        . ("Rust" "Cargo"))
    
    (web-mode            . ("HTML" "CSS" "JavaScript" "Bootstrap" "Tailwind_CSS"))
    (html-mode           . ("HTML" "CSS" "JavaScript"))
    (css-mode            . ("CSS" "Bootstrap" "Tailwind_CSS"))
    (css-ts-mode         . ("CSS" "Bootstrap" "Tailwind_CSS"))
    
    (dockerfile-mode     . ("Docker" "Kubernetes"))
    (docker-compose-mode . ("Docker" "Kubernetes"))
    (terraform-mode      . ("Terraform"))
    
    (sql-mode            . ("PostgreSQL" "SQL"))
    (sql-ts-mode         . ("PostgreSQL" "SQL"))
    
    (emacs-lisp-mode       . ("Emacs Lisp"))
    (lisp-interaction-mode . ("Emacs Lisp")))
  "Mapping of Emacs major modes to their relevant Dash docset names.")

;; =============================================================================
;; 2. THE BACKEND (DASH-DOCS)
;; =============================================================================

;; `dash-docs` is the library that understands the internal structure of
;; Dash `.docset` folders (it reads the SQLite index inside them).
(use-package dash-docs
  :ensure t
  :config
  ;; Define where the downloaded docsets will live on your hard drive.
  (setq dash-docs-docsets-path (expand-file-name "~/.docsets"))
  
  ;; Create the directory automatically if it is a fresh install.
  (unless (file-exists-p dash-docs-docsets-path)
    (make-directory dash-docs-docsets-path t))
  
  ;; Tell dash-docs to render HTML pages using Emacs's built-in web browser (eww).
  (setq dash-docs-browser-func 'eww))

;; =============================================================================
;; 3. CUSTOM INSTALLER LOGIC
;; =============================================================================
;;
;; These functions handle fetching the raw `.tgz` files from Kapeli's
;; (the creator of Dash) official GitHub repository.

(defun jmc-docset-install (name)
  "Manually download, extract, and install a Dash docset by NAME.
For example, you can pass \"Python 3\" as the NAME."
  (let* ((underscored-name (replace-regexp-in-string " " "_" name))
         (feed-url (format "https://raw.githubusercontent.com/Kapeli/feeds/master/%s.xml" underscored-name)))
    (condition-case err
        (let ((xml-buffer (url-retrieve-synchronously feed-url nil nil 10)))
          (if (not xml-buffer)
              (message "❌ Failed to fetch feed for %s (timeout or network error)" name)
            (with-current-buffer xml-buffer
              ;; Verify we got a successful 200 OK response.
              (goto-char (point-min))
              (when (re-search-forward "HTTP/[0-9.]+ \\([0-9]+\\)" nil t)
                (let ((status-code (string-to-number (match-string 1))))
                  (unless (= status-code 200)
                    (kill-buffer xml-buffer)
                    (error "HTTP %d error for %s" status-code name))))
              
              ;; Parse the XML to find the actual `<url>` of the `.tgz` archive.
              (goto-char (point-min))
              (if (not (search-forward "<url>" nil t))
                  (progn
                    (message "❌ Could not find download URL for %s. Check spelling or feed format." name)
                    (kill-buffer xml-buffer))
                
                (let* ((start (point))
                       (end (search-forward "</url>" nil t))
                       (tgz-url (string-trim (buffer-substring-no-properties start (- end 6))))
                       (dest-file (expand-file-name (format "%s.tgz" underscored-name) dash-docs-docsets-path)))
                  
                  (kill-buffer xml-buffer)
                  
                  ;; Download the archive.
                  (message "⬇️  Downloading %s..." name)
                  (url-copy-file tgz-url dest-file t)
                  
                  ;; Extract the archive using the system `tar` command.
                  (message "📦 Extracting %s..." name)
                  (let ((default-directory dash-docs-docsets-path))
                    (unless (zerop (call-process "tar" nil nil nil "-xzf" dest-file))
                      (error "Extraction failed for %s" name)))
                  
                  ;; Cleanup the `.tgz` file after extraction.
                  (delete-file dest-file)
                  (message "✅ Installed %s" name))))))
      (error (message "❌ Error installing %s: %s" name (error-message-string err))))))

(defun jmc-docset--installed-list ()
  "Return a list of docset names currently present in `~/.docsets`."
  (mapcar (lambda (d)
            (replace-regexp-in-string
             "_" " "
             (replace-regexp-in-string "\\.docset$" "" d)))
          (directory-files dash-docs-docsets-path nil "\\.docset$")))

(defun jmc-docset--missing-list ()
  "Return a list of docsets mapped in `jmc-docset-map` but not installed."
  (let ((all-referenced (delete-dups
                         (apply #'append
                                (mapcar #'cdr jmc-docset-map)))))
    (seq-difference all-referenced (jmc-docset--installed-list))))

(defun jmc-docset-list ()
  "Display all currently installed docsets in the echo area."
  (interactive)
  (let ((installed (jmc-docset--installed-list)))
    (if installed
        (message "📚 Installed docsets (%d):\n%s"
                 (length installed)
                 (mapconcat (lambda (d) (format "  • %s" d))
                            installed
                            "\n"))
      (message "⚠️  No docsets installed. Run M-x jmc-docset-install-missing"))))

(defun jmc-docset-install-missing ()
  "Install all missing docsets defined in your mapping automatically."
  (interactive)
  (let ((missing (jmc-docset--missing-list)))
    (if missing
        (if (yes-or-no-p (format "Install %d docsets?"
                                 (length missing)))
            (progn
              (message "📥 Installing %d docsets..." (length missing))
              (let ((total (length missing))
                    (current 0)
                    (failed nil))
                (dolist (d missing)
                  (setq current (1+ current))
                  (message "[%d/%d] Installing %s..." current total d)
                  (condition-case _err
                      (jmc-docset-install d)
                    (error (push d failed))))
                (if failed
                    (message "⚠️  Completed with %d failures: %s"
                             (length failed) (string-join (reverse failed) ", "))
                  (message "✅ Done! All %d docsets installed." total))))
          (message "Installation cancelled."))
      (message "✅ Nothing to install."))))

(defun jmc-docset-install-for-mode ()
  "Install only the docsets mapped to the current active major mode."
  (interactive)
  (let* ((docsets (alist-get major-mode jmc-docset-map))
         (missing (seq-difference docsets (jmc-docset--installed-list))))
    (cond
     ((null docsets)
      (message "⚠️  No docsets configured for %s" major-mode))
     ((null missing)
      (message "✅ All docsets for %s already installed." major-mode))
     (t
      (if (yes-or-no-p (format "Install %d docsets for %s? "
                               (length missing) major-mode))
          (progn
            (message "📥 Installing %d docsets for %s..."
                     (length missing) major-mode)
            (let ((total (length missing))
                  (current 0)
                  (failed nil))
              (dolist (d missing)
                (setq current (1+ current))
                (message "[%d/%d] Installing %s..." current total d)
                (condition-case _err
                    (jmc-docset-install d)
                  (error (push d failed))))
              (if failed
                  (message "⚠️  Completed with %d failures: %s"
                           (length failed) (string-join (reverse failed) ", "))
                (message "✅ Done! All docsets for %s installed." major-mode))))
        (message "Installation cancelled."))))))

;; =============================================================================
;; 4. THE FRONTEND (CONSULT-DASH)
;; =============================================================================

;; `consult-dash` provides the fast, live-filtering interface for the minibuffer.
(use-package consult-dash
  :ensure (:host codeberg :repo "ravi/consult-dash")
  :bind (("M-s d" . jmc-consult-dash-at-point))
  :config
  ;; Disable live HTML previews while scrolling through results.
  ;; -> EWW previews can be slow and disruptive to the layout while searching rapidly.
  (consult-customize consult-dash :preview-key nil)

  ;; Point consult-dash to the folder where our custom installer puts the files.
  (setq consult-dash-docsets-path dash-docs-docsets-path)

  ;; Force consult-dash to use Emacs's internal web browser.
  (setq consult-dash-browse-function #'eww)

  ;; --- Wrapper Function for Context-Aware Searching ---
  (defun jmc-consult-dash-at-point ()
    "Search docsets intelligently based on the current word and file type."
    (interactive)
    
    ;; 1. Ensure the backend has indexed the `~/.docsets` folder.
    (require 'dash-docs)
    (dash-docs-installed-docsets)
    
    ;; 2. Dynamically set the active docsets based on the current file's language.
    ;; -> e.g., only search Python docs if we are in a Python file.
    (let ((docsets (alist-get major-mode jmc-docset-map)))
      (when docsets
        (setq-local consult-dash-docsets docsets)))
    
    ;; 3. Grab the word directly under the cursor.
    (let ((word (thing-at-point 'symbol t)))
      (if word
          ;; If a word was found, seed the search query with it asynchronously (the `#`).
          (consult-dash (format "#%s " word))
        ;; Otherwise, open an empty search prompt.
        (consult-dash)))))

;; --- Window Management Tweaks ---
;; Prevent EWW from taking over your code window when you open a documentation page.
;; -> Forces any buffer named `*eww*` to open in a dedicated split to the right.
(add-to-list 'display-buffer-alist
             '("^\\*eww\\*"
               (display-buffer-reuse-window display-buffer-in-direction)
               (direction . right)  ;; Change to 'bottom if you prefer a horizontal split.
               (window-width . 0.5) ;; Restrict the doc window to 50% of the screen width.
               (reusable-frames . visible)))

;; =============================================================================
;; 5. INTEGRATIONS (EMBARK & LSP)
;; =============================================================================

;; Custom actions for `embark`.
(defun jmc-consult-dash-insert (candidate)
  "Insert the title of the docset CANDIDATE text at point."
  (insert candidate))

(defun jmc-consult-dash-copy (candidate)
  "Copy the title of the docset CANDIDATE to the clipboard."
  (kill-new candidate)
  (message "Copied: %s" candidate))

;; Wire up the custom actions so they appear when you press `C-.` on a search result.
(with-eval-after-load 'embark
  (defvar-keymap embark-dash-map
    :doc "Keymap for Embark actions on Dash docset entries"
    :parent embark-general-map
    "i" #'jmc-consult-dash-insert
    "w" #'jmc-consult-dash-copy)
  (add-to-list 'embark-keymap-alist '(consult-dash . embark-dash-map)))

;; Add a convenient shortcut to LSP-mode's command map.
;; -> Allows you to press `s-l d` (or however you invoke the LSP map) to search docs.
(with-eval-after-load 'lsp-mode
  (when (boundp 'lsp-command-map)
    (define-key lsp-command-map (kbd "d") #'consult-dash)))

;; =============================================================================
;; FINALIZE
;; =============================================================================

(provide 'docs)
;;; docs.el ends here
