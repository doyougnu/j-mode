;;; j-console.el -*- lexical-binding: t; -*-
;;; j-console.el --- Major mode for editing J programs


;; Copyright (C) 2021 Jeffrey Young
;; Copyright (C) 2012 Zachary Elliott
;;
;;
;; Authors: Jeffrey Young <youngjef@oregonstate.edu>
;; URL: http://github.com/doyougnu/j-mode
;; Version: 1.1.2
;;
;; Authors: Zachary Elliott <ZacharyElliott1@gmail.com>
;; URL: http://github.com/zellio/j-mode
;; Version: 1.1.1
;; Keywords: J, Languages

;; This file is not part of GNU Emacs.

;;; Commentary:

;;

;;; License:

;; This program is free software; you can redistribute it and/or modify it under
;; the terms of the GNU General Public License as published by the Free Software
;; Foundation; either version 3 of the License, or (at your option) any later
;; version.
;;
;; This program is distributed in the hope that it will be useful, but WITHOUT
;; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
;; FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
;; details.
;;
;; You should have received a copy of the GNU General Public License along with
;; GNU Emacs; see the file COPYING.  If not, write to the Free Software
;; Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301,
;; USA.

;;; Code:


(require 'comint)


;; (defconst j-console-version "1.1.2"
;;   "`j-console' version")

(defgroup j-console nil
  "REPL integration extention for `j-mode'"
  :group 'applications
  :group 'j
  :prefix "j-console-")

(defcustom j-console-cmd "ijconsole"
  "Name of the executable used for the J REPL session"
  :type 'string
  :group 'j-console)

(defcustom j-console-cmd-args '()
  "Arguments to be passed to the j-console-cmd on start"
  :type 'string
  :group 'j-console)

(defcustom j-console-cmd-init-file nil
  "Full path to the file who's contents are sent to the
  j-console-cmd on start

Should be NIL if there is no file not the empty string"
  :type 'string
  :group 'j-console)

(defcustom j-console-cmd-buffer-name "J"
  "Name of the buffer which contains the j-console-cmd session"
  :type 'string
  :group 'j-console)

(defvar-local j-console-previous-buffer nil
  "Records the buffer to which `j-console-switch-back' should jump.
   This is set by `j-console-create-session' or
   `j-console-switch', and should otherwise be nil.")

(defvar j-console-comint-input-filter-function nil
  "J mode specific mask for comint input filter function")

(defvar j-console-comint-output-filter-function nil
  "J mode specific mask for comint output filter function")

(defvar j-console-comint-preoutput-filter-function nil
  "J mode specific mask for comint preoutput filter function")

(defun j-console-create-session ()
  "Starts a comint session wrapped around the j-console-cmd"
  (setq comint-process-echoes t)
  (apply 'make-comint j-console-cmd-buffer-name
         j-console-cmd j-console-cmd-init-file j-console-cmd-args)
  (mapc
   (lambda ( comint-hook-sym )
     (let ((local-comint-hook-fn-sym
            (intern
             (replace-regexp-in-string
              "s$" "" (concat "j-console-" (symbol-name comint-hook-sym))))))
       (when (symbol-value local-comint-hook-fn-sym)
         (add-hook comint-hook-sym (symbol-value local-comint-hook-fn-sym)))))
   '(comint-input-filter-functions
     comint-output-filter-functions
     comint-preoutput-filter-functions)))

(defun j-console-ensure-session ()
  "Checks for a running j-console-cmd comint session and either
  returns it or starts a new session and returns that"
  (or (get-process j-console-cmd-buffer-name)
      (progn
        (j-console-create-session)
        (get-process j-console-cmd-buffer-name))))

(define-derived-mode inferior-j-mode comint-mode "Inferior J"
  "Major mode for J inferior process.")


;;;###autoload
(defun j-console ()
  "Ensures a running j-console-cmd session and switches focus to
the containing buffer"
  (interactive)
  (let ((initial-buffer (current-buffer)))
    (switch-to-buffer-other-window (process-buffer (j-console-ensure-session)))
    (inferior-j-mode)
    (setq j-console-previous-buffer initial-buffer)
    (j-console-switch-back)))


(defun j-flash-region (start end &optional timeout)
  "Temporarily highlight region from start to end."
  (let ((overlay (make-overlay start end)))
    (overlay-put overlay 'face 'secondary-selection)
    (run-with-timer (or timeout 0.2) nil 'delete-overlay overlay)))

(defun j-console-execute-region ( start end )
  "Sends current region to the j-console-cmd session and exectues it"
  (interactive "r")
  (when (= start end)
    (error "Region is empty"))
  (let ((region         (buffer-substring-no-properties start end))
        (session        (j-console-ensure-session))
        (initial-buffer (current-buffer))
        (text-prop      (get-text-property start end)))
    (j-flash-region start end)
    (pop-to-buffer (process-buffer session))
    (goto-char (point-max))
    (insert (format "\n%s\n" region))
    (comint-send-input)
    (switch-to-buffer-other-window initial-buffer)))

(defun j-console-execute-line ()
  "Sends current line to the j-console-cmd session and exectues it"
  (interactive)
  (j-console-execute-region (point-at-bol) (point-at-eol)))

(defun j-console-execute-buffer ()
  "Sends current buffer to the j-console-cmd session and exectues it"
  (interactive)
  (j-console-execute-region (point-min) (point-max)))

(defun j-console-switch-back ()
  "Switch back to the buffer from which this interactive buffer was reached."
  (interactive)
  (if j-console-previous-buffer
      (switch-to-buffer-other-window j-console-previous-buffer)
    (message "No previouS buffer.")))

(provide 'j-console)

;;; j-console.el ends here
