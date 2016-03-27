;;; core.el --- The heart of the beast
;;
;;; Naming conventions:
;;
;;   narf-...     A public variable/constant or function
;;   narf--...    An internal variable or function (non-interactive)
;;   narf/...     An autoloaded interactive function
;;   narf:...     An ex command
;;   narf|...     A hook
;;   narf*...     An advising function
;;   narf....     Custom prefix commands
;;   ...!         Macro
;;
;;  You will find all autoloaded function in {core,modules}/defuns/defuns-*.el
;;
;;;

(setq-default
 ad-redefinition-action            'accept      ; silence the advised function warnings
 echo-keystrokes                    0.02        ; show me what I type
 history-length                     1000
 ring-bell-function                'ignore      ; silence of the bells!
 save-interprogram-paste-before-kill nil
 sentence-end-double-space          nil
 enable-recursive-minibuffers       nil         ; no minibufferception
 compilation-always-kill            t           ; kill compilation process before spawning another
 compilation-ask-about-save         nil         ; save all buffers before compiling
 compilation-scroll-output          t           ; scroll with output while compiling
 ediff-diff-options                 "-w"
 ediff-split-window-function       'split-window-horizontally   ; side-by-side diffs
 ediff-window-setup-function       'ediff-setup-windows-plain   ; no extra frames
 inhibit-startup-echo-area-message  "hlissner"  ; username shuts up emacs
 inhibit-startup-screen             t           ; don't show emacs start screen
 initial-scratch-message            nil
 initial-major-mode                'text-mode   ; initial scratch buffer mode
 major-mode                        'text-mode

 ;; http://ergoemacs.org/emacs/emacs_stop_cursor_enter_prompt.html
 minibuffer-prompt-properties '(read-only t point-entered minibuffer-avoid-prompt face minibuffer-prompt)

 ;; remove annoying ellipsis when printing sexp in message buffer
 eval-expression-print-length       nil
 eval-expression-print-level        nil

 bookmark-save-flag                 t
 bookmark-default-file              (concat narf-temp-dir "/bookmarks")

 ;; Disable all backups (that's what git/dropbox are for)
 auto-save-default                  nil
 auto-save-list-file-name           (concat narf-temp-dir "/autosave")
 make-backup-files                  nil
 create-lockfiles                   nil
 backup-directory-alist            `((".*" . ,(concat narf-temp-dir "/backup/")))

 ;; Remember undo history
 undo-tree-auto-save-history        nil
 undo-tree-history-directory-alist `(("." . ,(concat narf-temp-dir "/undo/"))))

;; UTF-8 please
(setq locale-coding-system    'utf-8)   ; pretty
(set-terminal-coding-system   'utf-8)   ; pretty
(set-keyboard-coding-system   'utf-8)   ; pretty
(set-selection-coding-system  'utf-8)   ; please
(prefer-coding-system         'utf-8)   ; with sugar on top
(set-charset-priority 'unicode)
(setq default-process-coding-system '(utf-8-unix . utf-8-unix))

(fset 'yes-or-no-p 'y-or-n-p)           ; y/n instead of yes/no

;; Ask for confirmation on exit only if there are real buffers left
(when window-system
  (setq confirm-kill-emacs
        (lambda (_)
          (if (narf/get-real-buffers)
              (y-or-n-p ">> Gee, I dunno Brain... Are you sure?")
            t))))


;;
;; Bootstrap
;;

(autoload 'use-package "use-package" "" nil 'macro)
(unless (require 'autoloads nil t)
  (load (concat narf-emacs-dir "/scripts/generate-autoloads.el"))
  (require 'autoloads))
(require 'core-vars)
(require 'core-defuns)

(eval-when-compile
  (setq use-package-verbose nil)

  ;; Make any folders needed
  (dolist (file '("" "/undo" "/backup"))
    (let ((path (concat narf-temp-dir file)))
      (unless (file-exists-p path)
        (make-directory path t)))))

;; Save history across sessions
(require 'savehist)
(setq savehist-file (concat narf-temp-dir "/savehist")
      savehist-save-minibuffer-history t
      savehist-additional-variables
      '(kill-ring search-ring regexp-search-ring))
(savehist-mode 1)

;; text properties severely bloat the history so delete them (courtesy of PythonNut)
(defun unpropertize-savehist ()
  (mapc (lambda (list)
          (with-demoted-errors
              (when (boundp list)
                (set list (mapcar #'substring-no-properties (eval list))))))
        '(kill-ring minibuffer-history helm-grep-history helm-ff-history file-name-history
          read-expression-history extended-command-history evil-ex-history)))
(add-hook 'kill-emacs-hook    #'unpropertize-savehist)
(add-hook 'savehist-save-hook #'unpropertize-savehist)

(require 'recentf)
(setq recentf-save-file (concat narf-temp-dir "/recentf")
      recentf-exclude '("/tmp/" "/ssh:" "\\.?ido\\.last$" "\\.revive$" "/TAGS$"
                        "emacs\\.d/private/cache/.+" "emacs\\.d/workgroups/.+$" "wg-default"
                        "/company-statistics-cache.el$")
      recentf-max-menu-items 0
      recentf-max-saved-items 250
      recentf-auto-cleanup 600)
(recentf-mode 1)

(use-package persistent-soft
  :commands (persistent-soft-store
             persistent-soft-fetch
             persistent-soft-exists-p
             persistent-soft-flush
             persistent-soft-location-readable
             persistent-soft-location-destroy)
  :init (defvar pcache-directory (concat narf-temp-dir "/pcache/")))

(use-package async
  :commands (async-start
             async-start-process
             async-get
             async-wait
             async-inject-variables))


;;
(require (cond (IS-MAC      'core-os-osx)
               (IS-LINUX    'core-os-linux)
               (IS-WINDOWS  'core-os-win32)))


;;
;; We add this to `after-init-hook' to allow errors to stop this advice
(add-hook! after-init
  (defadvice save-buffers-kill-emacs (around no-query-kill-emacs activate)
    "Prevent annoying \"Active processes exist\" query when you quit Emacs."
    (cl-flet ((process-list ())) ad-do-it)))

(when (display-graphic-p)
  (require 'server)
  (unless (server-running-p)
    (server-start)))

(defun display-startup-echo-area-message ()
  (message ":: Loaded in %s" (emacs-init-time)))

(provide 'core)
;;; core.el ends here
