;;; lin.el --- Make `hl-line-mode' more suitable for selection UIs -*- lexical-binding: t -*-

;; Copyright (C) 2021-2024  Free Software Foundation, Inc.

;; Author: Protesilaos Stavrou <info@protesilaos.com>
;; Maintainer: Protesilaos Stavrou <info@protesilaos.com>
;; URL: https://github.com/protesilaos/lin
;; Version: 1.1.0
;; Package-Requires: ((emacs "27.1"))
;; Keywords: convenience, faces, theme

;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or (at
;; your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; Lin is a stylistic enhancement for Emacs' built-in `hl-line-mode'.
;; It remaps the `hl-line' face (or equivalent) buffer-locally to a
;; style that is optimal for major modes where line selection is the
;; primary mode of interaction.
;;
;; The idea is that `hl-line-mode' cannot work equally well for contexts
;; with competing priorities: (i) line selection, or (ii) simple line
;; highlight.  In the former case, the current line needs to be made
;; prominent because it carries a specific meaning of some significance
;; in the given context: the user has to select a line.  Whereas in the
;; latter case, the primary mode of interaction does not revolve around
;; the line highlight itself: it may be because the focus is on editing
;; text or reading through the buffer's contents, so the current line
;; highlight is more of a reminder of the point's location on the
;; vertical axis.
;;
;; `lin-mode' enables `hl-line-mode' in the current buffer and remaps
;; the appropriate face to the `lin-face'.  The `lin-global-mode'
;; follows the same principle, though it applies to all hooks specified
;; in the user option `lin-mode-hooks'.
;;
;; Users can select their preferred style by customizing the user option
;; `lin-face'.  Options include the faces `lin-red', `lin-green',
;; `lin-yellow', `lin-blue' (default), `lin-magenta', `lin-cyan',
;; `lin-mac', `lin-red-override-fg', `lin-green-override-fg',
;; `lin-yellow-override-fg', `lin-blue-override-fg',
;; `lin-magenta-override-fg', `lin-cyan-override-fg',
;; `lin-mac-override-fg', or any other face that preferably has a
;; background attribute.  The Lin faces with the "-override-fg" suffix
;; set a foreground value which replaces that of the underlying text.
;; Whereas the others only specify a background attribute.
;;
;; Consult the manual for further details.  Or visit the documentation's
;; web page: <https://protesilaos.com/emacs/lin>.

;;; Code:

(require 'face-remap)
(require 'hl-line)

(defgroup lin ()
  "Make `hl-line' appropriate for selection UIs."
  :group 'convenience
  :link '(info-link "(lin) Top"))

(defcustom lin-mode-hooks
  '(archive-mode-hook
    bongo-mode-hook
    dired-mode-hook
    elfeed-search-mode-hook
    git-rebase-mode-hook
    grep-mode-hook
    ibuffer-mode-hook
    ilist-mode-hook
    ledger-report-mode-hook
    log-view-mode-hook
    magit-log-mode-hook
    mu4e-headers-mode-hook
    notmuch-search-mode-hook
    notmuch-tree-mode-hook
    occur-mode-hook
    org-agenda-mode-hook
    pdf-outline-buffer-mode-hook
    proced-mode-hook
    tabulated-list-mode-hook
    tar-mode-hook)
  "List of hooks that should be used by the `lin-global-mode'.
Lin activates `hl-line-mode' and remaps its face to `lin-face'.
This makes it possible to tweak the `lin-face' in order to
distinguish between the two use-cases of permanent line
highlighting: (i) gentle reminder of where the point is while
editing, and (ii) current selection."
  :type '(repeat variable)
  :initialize #'custom-initialize-default
  :set (lambda (symbol value)
         (if (eq value (default-value symbol))
             (set-default symbol value)
           (lin--setup 'reverse)
           (set-default symbol value)
           (lin--setup)))
  :package-version '(lin . "1.0.0")
  :group 'lin)

(defcustom lin-face 'lin-blue
  "Face to use for the highlighted line.
Users can select one among `lin-red', `lin-green', `lin-yellow',
`lin-blue' (default), `lin-magenta', `lin-cyan', `lin-mac',
`lin-red-override-fg', `lin-green-override-fg',
`lin-yellow-override-fg', `lin-blue-override-fg',
`lin-magenta-override-fg', `lin-cyan-override-fg',
`lin-mac-override-fg', or any other face that preferably has a
background attribute.

Set this user option with `customize-set-variable', the Custom
UI, or equivalent.  It has a custom setter function which live
updates the face.  Users who prefer to use `setq' must run
`lin-enable-mode-in-buffers' manually.  Consult its doc string."
  :type '(radio (face :tag "Red style" lin-red)
                (face :tag "Green style" lin-green)
                (face :tag "Yellow style" lin-yellow)
                (face :tag "Blue style (default)" lin-blue)
                (face :tag "Magenta style" lin-magenta)
                (face :tag "Cyan style" lin-cyan)
                (face :tag "macOS style" lin-mac)
                (face :tag "Red style that also overrides the underlying foreground" lin-red-override-fg)
                (face :tag "Green style that also overrides the underlying foreground" lin-green-override-fg)
                (face :tag "Yellow style that also overrides the underlying foreground" lin-yellow-override-fg)
                (face :tag "Blue style that also overrides the underlying foreground" lin-blue-override-fg)
                (face :tag "Magenta style that also overrides the underlying foreground" lin-magenta-override-fg)
                (face :tag "Cyan style that also overrides the underlying foreground" lin-cyan-override-fg)
                (face :tag "macOS style that also overrides the underlying foreground" lin-mac-override-fg)
                (face :tag "Other face (must have a background)"))
  :initialize #'custom-initialize-default
  :set (lambda (symbol value)
         (set-default symbol value)
         (lin-enable-mode-in-buffers))
  :package-version '(lin . "0.3.0")
  :group 'lin)

(defcustom lin-remap-current-line-number t
  "When non-nil, apply `lin-face' also to the current line number.
Line numbers come from the `display-line-numbers-mode'."
  :type 'boolean
  :package-version '(lin . "1.1.0")
  :group 'lin)

;;;; Faces

(defgroup lin-faces ()
  "Faces for `lin.el'."
  :group 'lin)

(defface lin-red
  '((default :foreground unspecified :underline nil :extend t)
    (((class color) (min-colors 88) (background light))
     :background "#ffcfbf")
    (((class color) (min-colors 88) (background dark))
     :background "#620f2a")
    (t :background "red"))
  "Alternative red face for `lin-face'."
  :package-version '(lin . "1.1.0")
  :group 'lin-faces)

(defface lin-red-override-fg
  '((default :inherit lin-red)
    (((background light))
     :foreground "black")
    (((background dark))
     :foreground "white"))
  "Like `lin-red' but also sets a foreground."
  :package-version '(lin . "0.2.0")
  :group 'lin-faces)

(defface lin-green
  '((default :foreground unspecified :underline nil :extend t)
    (((class color) (min-colors 88) (background light))
     :background "#b3fabf")
    (((class color) (min-colors 88) (background dark))
     :background "#00422a")
    (t :background "green"))
  "Alternative green face for `lin-face'."
  :package-version '(lin . "1.1.0")
  :group 'lin-faces)

(defface lin-green-override-fg
  '((default :inherit lin-green)
    (((background light))
     :foreground "black")
    (((background dark))
     :foreground "white"))
  "Like `lin-green' but also sets a foreground."
  :package-version '(lin . "0.2.0")
  :group 'lin-faces)

(defface lin-yellow
  '((default :foreground unspecified :underline nil :extend t)
    (((class color) (min-colors 88) (background light))
     :background "#fff576")
    (((class color) (min-colors 88) (background dark))
     :background "#4a4000")
    (t :background "yellow"))
  "Alternative yellow face for `lin-face'."
  :package-version '(lin . "1.1.0")
  :group 'lin-faces)

(defface lin-yellow-override-fg
  '((default :inherit lin-yellow)
    (((background light))
     :foreground "black")
    (((background dark))
     :foreground "white"))
  "Like `lin-yellow' but also sets a foreground."
  :package-version '(lin . "0.2.0")
  :group 'lin-faces)

(defface lin-blue
  '((default :foreground unspecified :underline nil :extend t)
    (((class color) (min-colors 88) (background light))
     :background "#ccdfff")
    (((class color) (min-colors 88) (background dark))
     :background "#242679")
    (t :background "blue"))
  "Alternative blue face for `lin-face'."
  :package-version '(lin . "1.1.0")
  :group 'lin-faces)

(defface lin-blue-override-fg
  '((default :inherit lin-blue)
    (((background light))
     :foreground "black")
    (((background dark))
     :foreground "white"))
  "Like `lin-blue' but also sets a foreground."
  :package-version '(lin . "0.2.0")
  :group 'lin-faces)

(defface lin-magenta
  '((default :foreground unspecified :underline nil :extend t)
    (((class color) (min-colors 88) (background light))
     :background "#ffddff")
    (((class color) (min-colors 88) (background dark))
     :background "#552f5f")
    (t :background "magenta"))
  "Alternative magenta face for `lin-face'."
  :package-version '(lin . "1.1.0")
  :group 'lin-faces)

(defface lin-magenta-override-fg
  '((default :inherit lin-magenta)
    (((background light))
     :foreground "black")
    (((background dark))
     :foreground "white"))
  "Like `lin-magenta' but also sets a foreground."
  :package-version '(lin . "0.2.0")
  :group 'lin-faces)

(defface lin-cyan
  '((default :foreground unspecified :underline nil :extend t)
    (((class color) (min-colors 88) (background light))
     :background "#bfefff")
    (((class color) (min-colors 88) (background dark))
     :background "#004065")
    (t :background "cyan"))
  "Alternative cyan face for `lin-face'."
  :package-version '(lin . "1.1.0")
  :group 'lin-faces)

(defface lin-cyan-override-fg
  '((default :inherit lin-cyan)
    (((background light))
     :foreground "black")
    (((background dark))
     :foreground "white"))
  "Like `lin-cyan' but also sets a foreground."
  :package-version '(lin . "0.2.0")
  :group 'lin-faces)

;; TODO 2022-03-18: Can we find all system styles?  Then we can rename
;; this to `lin-system'.
(defface lin-mac
  '((((type ns))
     ;; <https://developer.apple.com/design/human-interface-guidelines/macos/visual-design/color/>.
     :background "selectedContentBackgroundColor" :extend t)
    (((type mac))
     :background "mac:selectedContentBackgroundColor" :extend t)
    (t :inherit lin-blue))
  "Alternative macOS-style face for `lin-face'."
  :package-version '(lin . "0.4.0")
  :group 'lin-faces)

(defface lin-mac-override-fg
  '((((type ns)) :inherit lin-mac :foreground "alternateSelectedControlTextColor")
    (((type mac)) :inherit lin-mac :foreground "mac:alternateSelectedControlTextColor"))
  "Like `lin-mac' but also sets a foreground."
  :package-version '(lin . "0.4.0")
  :group 'lin-faces)

;;;; Lin setup

(defvar-local lin--hl-line-cookie nil
  "Cookie returned by `face-remap-add-relative' for `hl-line' face.")

(defvar-local lin--line-number-current-line-cookie nil
  "Cookie of `face-remap-add-relative' for `line-number-current-line' face.")

(defun lin--hl-line-source-face ()
  "Determine the source face: what to remap."
  (cond
   ((derived-mode-p 'mu4e-headers-mode)
    'mu4e-header-highlight-face)
   ((derived-mode-p 'magit-mode)
    'magit-section-highlight)
   ;; Do not target `hl-line' directly, as it can be changed by
   ;; `hl-line-face'.
   ((bound-and-true-p hl-line-face)
    hl-line-face)
   (t
    'hl-line)))

;;;###autoload
(define-minor-mode lin-mode
  "Enable `hl-line-mode' and remap its face to `lin-face'."
  :global nil
  :init-value nil
  (if lin-mode
      (progn
        (setq lin--hl-line-cookie (face-remap-add-relative (lin--hl-line-source-face) lin-face))
        (when lin-remap-current-line-number
          (setq lin--line-number-current-line-cookie (face-remap-add-relative 'line-number-current-line lin-face)))
        (hl-line-mode 1))
    (face-remap-remove-relative lin--hl-line-cookie)
    (face-remap-remove-relative lin--line-number-current-line-cookie)
    (hl-line-mode -1)))

;;;###autoload
(define-minor-mode lin-global-mode
  "Like `lin-mode' but sets things up for all `lin-mode-hooks'."
  :global t
  :init-value nil
  (if lin-global-mode
      (progn
        (lin--setup)
        (lin-enable-mode-in-buffers))
    (lin--setup :reverse)
    (lin-disable-mode-in-buffers)))

(defun lin--setup-add-hooks ()
  "Add `lin-mode-hooks'."
  (dolist (hook lin-mode-hooks)
    (add-hook hook #'lin-mode)))

(defun lin--setup-remove-hooks (&optional hooks)
  "Remove `lin-mode-hooks' or, optionally, HOOKS."
  (dolist (hook (or hooks lin-mode-hooks))
    (remove-hook hook #'lin-mode)))

(defvar lin--setup-hooks nil
  "Last value used by `lin--setup'.")

(defun lin--setup (&optional reverse)
  "Set up Lin for select mode hooks.

This adds `lin-mode' and `hl-line-mode' to every hook in
`lin-mode-hooks'.

With optional non-nil REVERSE argument, remove those hooks."
  (cond
   (reverse
    (lin--setup-remove-hooks))
   (t
    (lin--setup-remove-hooks lin--setup-hooks)
    (lin--setup-add-hooks)))
  (setq lin--setup-hooks lin-mode-hooks))

(defun lin--mode-enable (buffer)
  "Enable `lin-mode' in BUFFER if appropriate."
  (with-current-buffer buffer
    (when (or lin-mode
              (memq (intern (format "%s-hook" major-mode)) lin-mode-hooks))
      (lin-mode 1))))

(defun lin--mode-disable (buffer)
  "Disable `lin-mode' if already enabled in BUFFER."
  (with-current-buffer buffer
    (when lin-mode
      (lin-mode -1))))

(defun lin-enable-mode-in-buffers ()
  "Enable (restart) `lin-mode' if already enabled in any buffer.
Do so by checking the `buffer-list'."
  (mapc #'lin--mode-enable (buffer-list)))

(defun lin-disable-mode-in-buffers ()
  "Restart `lin-mode' if already enabled in any buffer.
Do so by checking the `buffer-list'."
  (mapc #'lin--mode-disable (buffer-list)))

(provide 'lin)

;;; lin.el ends here
