;;; init.el -*- lexical-binding: t; -*-

;; The GC can easily double startup time, so we suppress it at startup
;; by turning up gc-cons-threshold (and perhaps gc-cons-percentage)
;; temporarily.
(setq gc-cons-threshold most-positive-fixnum
      gc-cons-percentage 0.6)

;; However, it is important to reset it eventually. Not doing so will
;; cause garbage collection freezes during long-term interactive
;; use. Conversely, a gc-cons-threshold that is too small will cause
;; stuttering. We use 16mb as our default.
(add-hook 'emacs-startup-hook
  (lambda ()
    (setq gc-cons-threshold 16777216 ; 16mb
          gc-cons-percentage 0.1)))

;; It may also be wise to raise gc-cons-threshold while the minibuffer
;; is active, so the GC doesn’t slow down expensive commands (or
;; completion frameworks, like helm and ivy).
(defun felbit/defer-garbage-collection-h ()
  (setq gc-cons-threshold most-positive-fixnum))

(defun felbit/restore-garbage-collection-h ()
  ;; Defer it so that commands launched immediately after will enjoy the
  ;; benefits.
  (run-at-time
   1 nil (lambda () (setq gc-cons-threshold 16777216))))

(add-hook 'minibuffer-setup-hook #'felbit/defer-garbage-collection-h)
(add-hook 'minibuffer-exit-hook #'felbit/restore-garbage-collection-h)

;; Emacs consults this variable every time a file is read or library
;; loaded, or when certain functions in the file API are used (like
;; expand-file-name or file-truename).
;; Emacs does this to check if a special handler is needed to read
;; that file, but none of them are (typically) necessary at startup,
;; so we disable them (temporarily!):
(defvar felbit/file-name-handler-alist file-name-handler-alist)
(setq file-name-handler-alist nil)

;; Alternatively, restore it even later:
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq file-name-handler-alist felbit/file-name-handler-alist)))

;; Measure startup time:
(add-hook 'emacs-startup-hook
          (lambda ()
            (message "*** Emacs loaded in %s with %d garbage collections."
                     (format "%.2f seconds"
                             (float-time
                              (time-subtract after-init-time before-init-time)))
                     gcs-done)))

;; Lead `private.el` after init:
;; (add-hook
;;  'after-init-hook
;;  (lambda ()
;;    (let ((private-file (concat user-emacs-directory "private.el")))
;;      (when (file-exists-p private-file)
;;        (load-file private-file)))))

;; Keep backup files and auto-save files in the backups directory
(setq backup-directory-alist
      `(("." . ,(expand-file-name "backups" user-emacs-directory)))
      auto-save-file-name-transforms
      `((".*" ,(expand-file-name "auto-save-list/" user-emacs-directory) t)))

(setq custom-file (concat user-emacs-directory "custom.el"))
(load custom-file 'noerror)

;; `straight.el` for package management
(setq straight-use-package-by-default t
      straight-build-dir (format "build-%s" emacs-version))

(defvar bootstrap-version)
(let ((bootstrap-file
       (expand-file-name "straight/repos/straight.el/bootstrap.el" user-emacs-directory))
      (bootstrap-version 5))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-synchronously
         "https://raw.githubusercontent.com/raxod502/straight.el/develop/install.el"
         'silent 'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))

(straight-use-package 'use-package)
(setq use-package-verbose t)

;;;; OSX

;; Both command keys are 'Super'
(setq mac-right-command-modifier 'super)
(setq mac-command-modifier 'super)

;; Option or Alt is naturally 'Meta'
(setq mac-option-modifier 'meta)
;; Keep right option key 
(setq mac-right-option-modifier nil)

;; Make keybindings feel natural on mac
(global-set-key (kbd "s-s") 'save-buffer)             ;; save
(global-set-key (kbd "s-S") 'write-file)              ;; save as
(global-set-key (kbd "s-q") 'save-buffers-kill-emacs) ;; quit
(global-set-key (kbd "s-a") 'mark-whole-buffer)       ;; select all
(global-set-key (kbd "s-k") 'kill-this-buffer)
(global-set-key (kbd "s-v") 'yank)
(global-set-key (kbd "s-c") 'kill-ring-save)
(global-set-key (kbd "s-z") 'undo)
(global-set-key (kbd "s-=") 'text-scale-adjust)
(global-set-key (kbd "s-+") 'text-scale-increase)


;;;; UI

(use-package blackout
  :straight (:host github :repo "raxod502/blackout"))

(use-package autorevert
  :defer t
  :blackout auto-revert-mode)

(use-package which-key
  :blackout t
  :hook (after-init . which-key-mode)
  :diminish which-key-mode
  :config
  (setq which-key-idle-delay 1))

(setq inhibit-startup-message t)

(setq frame-inhibit-implied-resize t)

(setq default-frame-alist
      (append (list
               '(font . "Monolisa-14")
               '(min-height . 1) '(height     . 45)
               '(min-width  . 1) '(width      . 81)
               )))

;; No beeping nor visible bell
(setq ring-bell-function #'ignore
      visible-bell nil)

(blink-cursor-mode 0)

(setq-default fill-column 80)
(setq-default line-spacing 1)

;; Scratch Buffer
(defvar scratch-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c c") 'lisp-interaction-mode)
    (define-key map (kbd "C-c C-c") 'lisp-interaction-mode)
    map)
  "Keymap for `scratch-mode'.")

(define-derived-mode scratch-mode
  fundamental-mode
  "Scratch"
  "Major mode for the *scratch* buffer.\\{scratch-mode-map}"
  (setq-local indent-line-function 'indent-relative))

(setq initial-major-mode 'scratch-mode)
(setq initial-scratch-message nil)

(defun jump-to-scratch-buffer ()
  "Jump to the existing *scratch* buffer or create a new one."
  (interactive)
  (let ((scratch-buffer (get-buffer-create "*scratch*")))
    (unless (derived-mode-p 'scratch-mode)
      (with-current-buffer scratch-buffer
        (scratch-mode)))
    (switch-to-buffer scratch-buffer)))

(global-set-key (kbd "s-t") #'jump-to-scratch-buffer)

(column-number-mode)

;; Enable line numbers for prog modes only
(add-hook 'prog-mode-hook (lambda () (display-line-numbers-mode 1)))

(use-package hl-line
  :disabled t
  :hook
  (prog-mode . hl-line-mode))

(use-package idle-highlight-mode
  :blackout t
  :hook
  (prog-mode . idle-highlight-mode))

(add-to-list 'custom-theme-load-path "~/.config/emacs/themes")
(use-package sketch-themes
  :straight (:host github :repo "dawranliou/sketch-themes"))
(load-theme 'oil6)

;; Set the fixed pitch face
(set-face-attribute 'default nil :font "Fira Code" :height 150)

;;;; Mode line

;; The following code customizes the mode line to something like:
;; [*] radian.el   18% (18,0)     [radian:develop*]  (Emacs-Lisp)

(defun my/mode-line-buffer-modified-status ()
  "Return a mode line construct indicating buffer modification status.
  This is [*] if the buffer has been modified and whitespace
  otherwise. (Non-file-visiting buffers are never considered to be
  modified.) It is shown in the same color as the buffer name, i.e.
  `mode-line-buffer-id'."
  (propertize
   (if (and (buffer-modified-p)
            (buffer-file-name))
       "[*]"
     "   ")
   'face 'mode-line-buffer-id))

;; Normally the buffer name is right-padded with whitespace until it
;; is at least 12 characters. This is a waste of space, so we
;; eliminate the padding here. Check the docstrings for more
;; information.
(setq-default mode-line-buffer-identification
              (propertized-buffer-identification "%b"))

;; Make `mode-line-position' show the column, not just the row.
(column-number-mode +1)

;; https://emacs.stackexchange.com/a/7542/12534
(defun my/mode-line-align (left right)
  "Render a left/right aligned string for the mode line.
  LEFT and RIGHT are strings, and the return value is a string that
  displays them left- and right-aligned respectively, separated by
  spaces."
  (let ((width (- (window-total-width) (length left))))
    (format (format "%%s%%%ds" width) left right)))

(defcustom my/mode-line-left
  '(;; Show [*] if the buffer is modified.
    (:eval (my/mode-line-buffer-modified-status))
    " "
    ;; Show the name of the current buffer.
    mode-line-buffer-identification
    " "
    ;; Show the row and column of point.
    mode-line-position)
  "Composite mode line construct to be shown left-aligned."
  :type 'sexp)

(defcustom my/mode-line-right
  '(""
    mode-line-modes)
  "Composite mode line construct to be shown right-aligned."
  :type 'sexp)

;; Actually reset the mode line format to show all the things we just
;; defined.
(setq-default mode-line-format
              '(:eval (replace-regexp-in-string
                       "%" "%%"
                       (my/mode-line-align
                        (format-mode-line my/mode-line-left)
                        (format-mode-line my/mode-line-right))
                       'fixedcase 'literal)))

;; Highlight matching parens
(use-package paren
  :hook (prog-mode . show-paren-mode))

(use-package paren-face
  :hook
  (lispy-mode . paren-face-mode))

(use-package hl-fill-column
  :hook (prog-mode . hl-fill-column-mode))

;; Unicode Support
(use-package unicode-fonts
  :defer t
  :config
  (unicode-fonts-setup))

;; Native Titlebar
(use-package ns-auto-titlebar
  :hook (after-init . ns-auto-titlebar-mode))

(setq ns-use-proxy-icon nil
      frame-title-format nil)

;; Rainbow Mode
(use-package rainbow-mode
  :commands rainbow-mode)

(setq enable-recursive-minibuffers t)

;;;; Completion

;; Package `selectrum' is an incremental completion and narrowing
;; framework. Like Ivy and Helm, which it improves on, Selectrum
;; provides a user interface for choosing from a list of options by
;; typing a query to narrow the list, and then selecting one of the
;; remaining candidates. This offers a significant improvement over
;; the default Emacs interface for candidate selection.
(use-package selectrum
  :straight (:host github :repo "raxod502/selectrum")
  :custom
  (selectrum-count-style 'current/matches)
  ;; The default 10 seem to cutoff the last line for my screen
  (selectrum-max-window-height 12)
  :init
  ;; This doesn't actually load Selectrum.
  (selectrum-mode +1))

;; Package `prescient' is a library for intelligent sorting and
;; filtering in various contexts.
(use-package prescient
  :config
  ;; Remember usage statistics across Emacs sessions.
  (prescient-persist-mode +1)
  ;; The default settings seem a little forgetful to me. Let's try
  ;; this out.
  (setq prescient-history-length 1000))

;; Package `selectrum-prescient' provides intelligent sorting and
;; filtering for candidates in Selectrum menus.
(use-package selectrum-prescient
  :straight (:host github :repo "raxod502/prescient.el"
                   :files ("selectrum-prescient.el"))
  :after selectrum
  :config
  (selectrum-prescient-mode +1))

(use-package marginalia
  :bind (:map minibuffer-local-map
              ("C-M-a" . marginalia-cycle))
  :init
  (marginalia-mode)
  ;; When using Selectrum, ensure that Selectrum is refreshed when cycling annotations.
  (advice-add #'marginalia-cycle :after
              (lambda () (when (bound-and-true-p selectrum-mode) (selectrum-exhibit))))
  (setq marginalia-annotators '(marginalia-annotators-heavy
                                marginalia-annotators-light nil)))

;; Package `ctrlf' provides a replacement for `isearch' that is more
;; similar to the tried-and-true text search interfaces in web
;; browsers and other programs (think of what happens when you type
;; ctrl+F).
(use-package ctrlf
  :straight (:host github :repo "raxod502/ctrlf")
  :bind
  ("s-f" . ctrlf-forward-fuzzy)

  :init
  (ctrlf-mode +1)

  :config
  (defun ctrlf-toggle-fuzzy ()
    "Toggle CTRLF style to `fuzzy' or back to `literal'."
    (interactive)
    (setq ctrlf--style
          (if (eq ctrlf--style 'fuzzy) 'literal 'fuzzy)))

  (add-to-list 'ctrlf-minibuffer-bindings
               '("s-f" . ctrlf-toggle-fuzzy)))

;; Embark
(use-package embark
  :bind
  ("C-S-a" . embark-act)

  :config
  ;; For Selectrum users:
  (defun current-candidate+category ()
    (when selectrum-active-p
      (cons (selectrum--get-meta 'category)
            (selectrum-get-current-candidate))))

  (add-hook 'embark-target-finders #'current-candidate+category)

  (defun current-candidates+category ()
    (when selectrum-active-p
      (cons (selectrum--get-meta 'category)
            (selectrum-get-current-candidates
             ;; Pass relative file names for dired.
             minibuffer-completing-file-name))))

  (add-hook 'embark-candidate-collectors #'current-candidates+category)

  ;; No unnecessary computation delay after injection.
  (add-hook 'embark-setup-hook 'selectrum-set-selected-candidate)

  :custom
  (embark-action-indicator
   (lambda (map)
     (which-key--show-keymap "Embark" map nil nil 'no-paging)
     #'which-key--hide-popup-ignore-command)
   embark-become-indicator embark-action-indicator))

;; Helpful adds a lot of very helpful (get it?) information to Emacs’ describe-
;; command buffers. For example, if you use describe-function, you will not only
;; get the documentation about the function, you will also see the source code
;; of the function and where it gets used in other places in the Emacs
;; configuration. It is very useful for figuring out how things work in Emacs.
(use-package helpful
  :bind (;; Remap standard commands.
         ([remap describe-function] . #'helpful-callable)
         ([remap describe-variable] . #'helpful-variable)
         ([remap describe-key]      . #'helpful-key)
         ([remap describe-symbol]   . #'helpful-symbol)
         ("C-c C-d" . #'helpful-at-point)
         ("C-h C"   . #'helpful-command)
         ("C-h F"   . #'describe-face)))

;; Persist Scratch
(use-package persistent-scratch
  :custom
  (persistent-scratch-autosave-interval 60)
  :config
  (persistent-scratch-setup-default))

;; Recent Files
(use-package recentf
  :defer 1
  :custom
  ;; Increase recent entries list from default (20)
  (recentf-max-saved-items 100)
  :config
  (recentf-mode +1))

;; Tabs
(setq-default tab-width 2)
(setq-default indent-tabs-mode nil)

;; Clean Whitespace
(use-package ws-butler
  :blackout t
  :hook ((text-mode . ws-butler-mode)
         (prog-mode . ws-butler-mode))
  :custom
  ;; ws-butler normally preserves whitespace in the buffer (but strips it from
  ;; the written file). While sometimes convenient, this behavior is not
  ;; intuitive. To the average user it looks like whitespace cleanup is failing,
  ;; which causes folks to redundantly install their own.
  (ws-butler-keep-whitespace-before-point nil))

;; Automaticall close everything
(use-package elec-pair
  :straight nil
  :hook (prog-mode . electric-pair-mode))

;; Expand Region
(use-package expand-region
  :bind
  ("s-'" .  er/expand-region)
  ("s-\"" .  er/contract-region)
  :hook
  (prog-mode . my/greedy-expansion-list)
  :config
  (defun my/greedy-expansion-list ()
    "Skip marking words or inside quotes and pairs"
    (setq-local er/try-expand-list
                (cl-set-difference er/try-expand-list
                                   '(er/mark-word
                                     er/mark-inside-quotes
                                     er/mark-inside-pairs)))))

;; Remember history of things across launches (ie. kill ring).
(use-package savehist
  :hook (after-init . savehist-mode)
  :custom
  (savehist-file "~/.emacs.d/savehist")
  (savehist-save-minibuffer-history t)
  (savehist-additional-variables
   '(kill-ring
     mark-ring global-mark-ring
     search-ring regexp-search-ring))
  (history-length 20000))

;; When you visit a file, point goes to the last place where it was when you
;; previously visited the same file.
(use-package saveplace
  :config
  (save-place-mode t))

(use-package dired
  :straight nil
  :commands (dired)
  :hook (dired-mode . dired-hide-details-mode)
  :bind ("C-x C-j" . dired-jump)
  :custom
  (dired-auto-revert-buffer t)
  (dired-dwim-target t)
  (dired-recursive-copies 'always)
  (dired-recursive-deletes 'always)
  (dired-listing-switches "-AFhlv --group-directories-first")
  :init
  (setq insert-directory-program "gls"))

(use-package dired-x
  :after dired
  :straight nil
  :init (setq-default dired-omit-files-p t)
  :config
  (add-to-list 'dired-omit-extensions ".DS_Store"))

(use-package dired-single
  :after dired)

(use-package dired-hide-dotfiles
  :hook (dired-mode . dired-hide-dotfiles-mode))

(use-package dired-ranger
  :after dired)

(use-package dired-subtree
  :after dired)

;;;; ORG

(defun felbit/org-setup ()
  (org-indent-mode)
  (blackout 'org-indent-mode)

  (blackout 'buffer-face-mode)
  (visual-line-mode 1)
  (blackout 'visual-line-mode))

(use-package org
  :hook (org-mode . felbit/org-setup)
  :config
  (setq org-ellipsis " ▾"
        org-hide-emphasis-markers t
        org-src-fontify-natively t
        org-src-tab-acts-natively t
        org-edit-src-content-indentation 2
        org-hide-block-startup nil
        org-src-preserve-indentation nil
        ;; org-startup-folded 'content
        org-cycle-separator-lines 2)

  (setq org-log-done 'time)
  (setq org-log-into-drawer t))

(use-package org-bullets
  :hook (org-mode . org-bullets-mode)
  :custom
  (org-bullets-bullet-list '("◉" "○" "●" "○" "●" "○" "●")))

(use-package org-make-toc
  :hook (org-mode . org-make-toc-mode))

(use-package org-journal
  :commands (org-journal-new-entry org-journal-open-current-journal-file)
  :custom
  (org-journal-date-format "%A, %d/%m/%Y")
  (org-journal-date-prefix "* ")
  (org-journal-file-format "%F.org")
  (org-journal-dir "~/org/journal/")
  (org-journal-file-type 'weekly)
  (org-journal-find-file #'find-file))

;; TODO: Look into org-roam!


;;;; SHELL

(setq exec-path (append exec-path '("/usr/local/bin")))

(use-package vterm
  :commands vterm
  :config
  (setq vterm-max-scrollback 10000))

;;; eshell

(defun felbit/eshell-history ()
  "Browse eshell history."
  (interactive)
  (let ((candidates (cl-remove-duplicates
                     (ring-elements eshell-history-ring)
                     :test #'equal :from-end t))
        (input (let ((input-start (save-excursion (eshell-bol)))
                     (input-end (save-excursion (end-of-line) (point))))
                 (buffer-substring-no-properties input-start input-end))))
    (let ((selected (completing-read "Eshell history:"
                                     candidates nil nil input)))
      (end-of-line)
      (eshell-kill-input)
      (insert (string-trim selected)))))

(defun felbit/configure-eshell ()
  ;; Save command history when commands are entered
  (add-hook 'eshell-pre-command-hook 'eshell-save-some-history)

  ;; Truncate buffer for performance
  (add-to-list 'eshell-output-filter-functions 'eshell-truncate-buffer)

  ;; Use Ivy to provide completions in eshell
  (define-key eshell-mode-map (kbd "<tab>") 'completion-at-point)

  (setq eshell-history-size          10000
        eshell-buffer-maximum-lines  10000
        eshell-hist-ignoredups           t
        eshell-highlight-prompt          t
        eshell-scroll-to-bottom-on-input t))

(use-package eshell
  :hook (eshell-first-time-mode . felbit/configure-eshell))

(use-package exec-path-from-shell
  :defer 1
  :init
  (setq exec-path-from-shell-check-startup-files nil)
  :config
  (when (memq window-system '(mac ns x))
    (exec-path-from-shell-initialize)))

(with-eval-after-load 'esh-opt
  (setq eshell-destroy-buffer-when-process-dies t))

;;;; DEVELOPMENT

(use-package project
  :commands project-root
  :bind
  (("s-p" . project-find-file)
   ("s-P" . project-switch-project))
  :init
  (defun project-magit-status+ ()
    ""
    (interactive)
    (magit-status (project-root (project-current t))))
  :custom
  (project-switch-commands '((project-find-file "Find file")
                             (project-find-regexp "Find regexp")
                             (project-dired "Dired")
                             (project-magit-status+ "Magit" ?m)
                             (project-eshell "Eshell"))))

(use-package magit
  :custom
  (magit-diff-refine-hunk 'all)
  (magit-display-buffer-function #'magit-display-buffer-same-window-except-diff-v1))

(use-package rg
  :bind ("s-F" . rg-project)
  :config
  (rg-enable-default-bindings))

(use-package lsp-mode
  :hook ((clojure-mode . lsp)
         (clojurec-mode . lsp)
         (clojurescript-mode . lsp)
         (lsp-mode . (lambda () (setq-local idle-highlight-mode nil))))
  :custom
  (lsp-enable-file-watchers nil)
  (lsp-headerline-breadcrumb-enable nil)
  (lsp-keymap-prefix "s-l")
  (lsp-enable-indentation nil)
  (lsp-clojure-custom-server-command '("bash" "-c" "/usr/local/bin/clojure-lsp"))
  :config
  (lsp-enable-which-key-integration t))

;; Clojure
(use-package clojure-mode
  :defer t
  :custom
  (cljr-magic-requires nil)
  :config
  ;; (require 'flycheck-clj-kondo)
  (setq clojure-indent-style 'align-arguments
        clojure-align-forms-automatically t))

(use-package clj-refactor
  :defer t
  :blackout t)

(use-package cider
  :commands cider
  :custom
  (cider-repl-display-help-banner nil)
  (cider-repl-display-in-current-window nil)
  (cider-repl-pop-to-buffer-on-connect nil)
  (cider-repl-use-pretty-printing t)
  (cider-repl-buffer-size-limit 100000)
  (cider-repl-result-prefix ";; => "))

(use-package clj-refactor
  :hook (clojure-mode . clj-refactor-mode))
