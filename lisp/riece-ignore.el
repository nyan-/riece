;;; riece-ignore.el --- ignore user
;; Copyright (C) 1998-2004 Daiki Ueno

;; Author: Daiki Ueno <ueno@unixuser.org>
;; Created: 1998-09-28
;; Keywords: IRC, riece

;; This file is part of Riece.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:

;; To use, add the following line to your ~/.riece/init.el:
;; (add-to-list 'riece-addons 'riece-ignore)

;;; Code:

(require 'riece-signal)
(require 'riece-identity)
(require 'riece-message)

(defgroup riece-ignore nil
  "Ignore messages in IRC buffers."
  :group 'riece)

(defcustom riece-ignore-discard-message t
  "If non-nil, messages from ignored user are completely discarded.
Otherwise, they are left there but not visible."
  :group 'riece-ignore
  :type 'boolean)

(defvar riece-ignored-user-list nil)

(defun riece-ignore-user-rename-signal-function (signal handback)
  (let ((pointer (riece-identity-member (car (riece-signal-args signal))
					riece-ignored-user-list)))
    (if pointer
	(setcar pointer (nth 1 (riece-signal-args signal))))))

(defun riece-ignore-user (user toggle)
  (interactive
   (let ((completion-ignore-case t))
     (list (if current-prefix-arg
	       (riece-completing-read-identity
		"Unignore user: "
		riece-ignored-user-list)
	     (riece-completing-read-identity
	      "Ignore user: "
	      (riece-get-users-on-server (riece-current-server-name))
	      (lambda (user)
		(not (riece-identity-member
		      (riece-parse-identity user)
		      riece-ignored-user-list)))))
	   (not current-prefix-arg))))
  (if toggle
      (progn
	(setq riece-ignored-user-list (cons user riece-ignored-user-list))
	(riece-connect-signal
	 'user-renamed
	 #'riece-ignore-user-rename-signal-function))
    (let ((pointer (riece-identity-member user riece-ignored-user-list)))
      (setq riece-ignored-user-list (delq (car pointer)
					  riece-ignored-user-list))
      (riece-disconnect-signal
       'user-renamed
       #'riece-ignore-user-rename-signal-function))))

(defun riece-ignore-message-filter (message)
  (if (riece-identity-member (riece-message-speaker message)
			     riece-ignored-user-list)
      (unless riece-ignore-discard-message
	(put-text-property 0 (length (riece-message-text message))
			   'invisible 'riece-ignore
			   (riece-message-text message))
	message)
    message))

(defvar riece-command-mode-map)
(defun riece-ignore-insinuate ()
  (add-hook 'riece-message-filter-functions 'riece-ignore-message-filter)
  (define-key riece-command-mode-map
    "\C-ck" 'riece-ignore-user))

(provide 'riece-ignore)

;;; riece-ignore.el ends here