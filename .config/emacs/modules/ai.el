;;; ai.el --- Agentic AI coding (Cursor-style composer flow) -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; This module adds a Cursor-style *agent/composer* workflow on top of the
;; `claude-code.el' setup, plus a second, vendor-independent agent lane.
;;
;; Division of labor:
;;
;; 1. claude-code.el (prefix `C-c c`):
;;    Quick terminal-style sessions. "Chat with Claude in a drawer."
;;
;; 2. claude-code-ide.el (prefix `C-c i`):
;;    The deep agent loop. It opens a bidirectional MCP bridge so Claude:
;;    * Knows which file/selection you're looking at (like Cursor's context).
;;    * Can query LSP (xref), tree-sitter, and diagnostics from your buffers.
;;    * Presents its edits through *ediff* for review/accept — the closest
;;      Emacs equivalent to Cursor's composer diff-review flow.
;;
;; 3. agent-shell (prefix `C-c g` -> Gemini):
;;    ACP-based, agent-AGNOSTIC lane. ACP (Agent Client Protocol) is "LSP
;;    for agents": one native Emacs comint buffer that can drive any
;;    ACP-speaking agent — Gemini CLI here, but Claude Code, Codex, Goose,
;;    etc. are one function away. The conversation is plain Emacs text
;;    (search/yank/CUA all work; no TUI escape-code wrangling); proposed
;;    edits render as inline diffs with approve/deny prompts — coarser
;;    review than the `C-c i' ediff flow, but a genuinely different agent.
;;
;; Both Claude packages share the same underlying Claude Code CLI sessions,
;; so you can `claude-code-ide-resume' a conversation you started elsewhere.
;;
;;; Code:

;; =============================================================================
;; COMPILER DECLARATIONS (SILENCE WARNINGS)
;; =============================================================================

(defvar jmc-jump-map)

(declare-function claude-code-ide-emacs-tools-setup "claude-code-ide-emacs-tools")
(declare-function agent-shell-google-make-authentication "agent-shell-google")

;; =============================================================================
;; CLAUDE CODE (AI ASSISTANT)
;; =============================================================================

(use-package claude-code
  :ensure (:host github :repo "stevemolitor/claude-code.el")
  :defer t
  :custom
  (claude-code-terminal-backend 'ghostel)
  :bind (("C-c c m" . claude-code-transient)
	 ("C-c c c" . claude-code)
	 ("C-c c r" . claude-code-send-region)
	 ("C-c c e" . claude-code-fix-error-at-point)
	 ("C-c c b" . claude-code-switch-to-buffer)))

;; =============================================================================
;; CLAUDE CODE IDE (THE AGENT / COMPOSER)
;; =============================================================================

(use-package claude-code-ide
  :ensure (:host github :repo "manzaltu/claude-code-ide.el")
  :defer t
  :commands (claude-code-ide
	     claude-code-ide-menu
	     claude-code-ide-resume
	     claude-code-ide-continue
	     claude-code-ide-stop
	     claude-code-ide-list-sessions
	     claude-code-ide-toggle-recent
	     claude-code-ide-insert-at-mentioned)
  :bind (;; `C-c i i`: Start (or toggle) the agent for the current project.
	 ("C-c i i" . claude-code-ide)
	 ;; `C-c i m`: Transient menu with every available action.
	 ("C-c i m" . claude-code-ide-menu)
	 ;; `C-c i r`: Resume a previous conversation (uses --resume).
	 ("C-c i r" . claude-code-ide-resume)
	 ;; `C-c i c`: Continue the most recent conversation.
	 ("C-c i c" . claude-code-ide-continue)
	 ;; `C-c i l`: List and switch between active sessions (one per project).
	 ("C-c i l" . claude-code-ide-list-sessions)
	 ;; `C-c i t`: Toggle the most recent Claude window from anywhere.
	 ("C-c i t" . claude-code-ide-toggle-recent))
  :custom
  ;; Reuse the libghostty terminal you already run for claude-code.el.
  ;; -> If your checkout predates ghostel support and this symbol is
  ;;    rejected, fall back to 'vterm or 'eat and update the repo.
  (claude-code-ide-terminal-backend 'ghostel)

  ;; The Cursor-like part: show Claude's edits in an ediff session so you
  ;; review and accept/reject hunks instead of watching a TUI stream.
  (claude-code-ide-use-ide-diff t)

  ;; Match the ghostel drawer geometry from terminal.el (right side, half).
  (claude-code-ide-window-side 'right)
  (claude-code-ide-window-width 0.5)

  :config
  ;; Expose Emacs itself to the agent over MCP: xref/LSP navigation,
  ;; tree-sitter structure, project info, and buffer diagnostics.
  ;; -> This is the piece Cursor cannot replicate: the agent can *use* your
  ;;    editor (lsp-mode, projectile, even custom elisp) as tools.
  (claude-code-ide-emacs-tools-setup))

;; =============================================================================
;; AGENT-SHELL (ACP) — GEMINI AND OTHER NON-CLAUDE AGENTS
;; =============================================================================
;;
;; REQUIREMENTS: the Gemini CLI binary — `npm install -g @google/gemini-cli`.
;; First `C-c g` prompts for Google authentication in the shell buffer.
;;
;; All three packages (shell-maker, acp, agent-shell) come from MELPA via
;; the normal Elpaca dependency resolution — no GitHub recipes needed.

;; acp.el: the Agent Client Protocol implementation agent-shell is built on.
;; Declared explicitly (it's also a hard dependency) so it's easy to pin.
(use-package acp
  :defer t)

(use-package agent-shell
  :defer t
  ;; `agent-shell.el' requires all its agent modules (including
  ;; agent-shell-google), so autoloading the start command through the main
  ;; package works even though the google file has no autoload cookies.
  :commands (agent-shell-google-start-gemini)
  :bind ("C-c g" . agent-shell-google-start-gemini)
  :config
  ;; OAuth via personal Google account (the package default, made explicit).
  ;; Free-tier quota, no API key to manage. Set in `:config', not `:custom':
  ;; the value calls a function the package defines, so it can only be
  ;; evaluated AFTER the package loads.
  ;;
  ;; Per-project API keys instead? Two changes:
  ;;   1. Put GEMINI_API_KEY in the project's .envrc (envrc.el + the
  ;;      inheritenv advice in init.el carry it into the agent process).
  ;;   2. Swap :login for
  ;;      :api-key (lambda () (getenv "GEMINI_API_KEY"))
  (setopt agent-shell-google-authentication
          (agent-shell-google-make-authentication :login t)))

;; =============================================================================
;; JUMP MAP INTEGRATION (SUPER-P)
;; =============================================================================
;;
;; `s-p a` already launches the plain claude-code terminal (projects.el).
;; `s-p A` launches the full agent for the current project.

(with-eval-after-load 'projects
  (when (boundp 'jmc-jump-map)
    (define-key jmc-jump-map (kbd "A") #'claude-code-ide)))

;; =============================================================================
;; FINALIZE
;; =============================================================================

(provide 'ai)

;;; ai.el ends here
