;;; riece-identity.el --- an identity object
;; Copyright (C) 1998-2003 Daiki Ueno

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

;;; Code:

(require 'riece-globals)
(require 'riece-coding)
(require 'riece-compat)			;riece-set-case-syntax-pair

(defvar riece-abbrev-identity-string-function nil)
(defvar riece-expand-identity-string-function nil)

(defvar riece-identity-prefix-case-table
  (let ((table (copy-case-table (standard-case-table))))
    (riece-set-case-syntax-pair ?\[ ?{ table)
    (riece-set-case-syntax-pair ?\] ?} table)
    (riece-set-case-syntax-pair ?\\ ?| table)
    (riece-set-case-syntax-pair ?~ ?^ table)
    table))
    
(defun riece-identity-prefix (identity)
  "Return the component sans its server from IDENTITY."
  (aref identity 0))

(defun riece-identity-server (identity)
  "Return the server component in IDENTITY."
  (aref identity 1))

(defun riece-make-identity (prefix server)
  "Make an identity object from PREFIX and SERVER."
  (vector prefix server))

(defun riece-identity-equal (ident1 ident2)
  "Return t, if IDENT1 and IDENT2 is equal."
  (and (riece-identity-equal-no-server
	(riece-identity-prefix ident1)
	(riece-identity-prefix ident2))
       (equal
	(riece-identity-server ident1)
	(riece-identity-server ident2))))

(defun riece-identity-canonicalize-prefix (prefix)
  "Canonicalize identity PREFIX.
This function downcases PREFIX with Scandinavian alphabet rule.

RFC2812, 2.2 \"Character codes\" says:
   Because of IRC's Scandinavian origin, the characters {}|^ are
   considered to be the lower case equivalents of the characters []\~,
   respectively. This is a critical issue when determining the
   equivalence of two nicknames or channel names."
  (let ((old-table (current-case-table)))
    (unwind-protect
	(progn
	  (set-case-table riece-identity-prefix-case-table)
	  (downcase prefix))
      (set-case-table old-table))))

(defun riece-identity-equal-no-server (prefix1 prefix2)
  "Return t, if IDENT1 and IDENT2 is equal without server part."
  (equal (riece-identity-canonicalize-prefix prefix1)
	 (riece-identity-canonicalize-prefix prefix2)))

(defun riece-identity-member (elt list &optional no-server)
  "Return non-nil if an identity ELT is an element of LIST."
  (catch 'found
    (while list
      (if (and (car list)	;needed because riece-current-channels
				;contains nil.
	       (if no-server
		   (riece-identity-equal-no-server (car list) elt)
		 (riece-identity-equal (car list) elt)))
	  (throw 'found list)
	(setq list (cdr list))))))

(defun riece-identity-assoc (elt alist &optional no-server)
  "Return non-nil if an identity ELT matches the car of an element of ALIST."
  (catch 'found
    (while alist
      (if (if no-server
	      (riece-identity-equal-no-server (car (car alist)) elt)
	    (riece-identity-equal (car (car alist)) elt))
	  (throw 'found (car alist))
	(setq alist (cdr alist))))))

(defun riece-identity-assign-binding (item list binding)
  (let ((slot (riece-identity-member item binding))
	pointer)
    (unless list			;we need at least one room
      (setq list (list nil)))
    (setq pointer list)
    (if slot
	(while (not (eq binding slot))
	  (unless (cdr pointer)
	    (setcdr pointer (list nil)))
	  (setq pointer (cdr pointer)
		binding (cdr binding)))
      (while (or (car pointer) (car binding))
	(unless (cdr pointer)
	  (setcdr pointer (list nil)))
	(setq pointer (cdr pointer)
	      binding (cdr binding))))
    (setcar pointer item)
    list))

(defun riece-format-identity (identity &optional prefix-only)
  "Convert IDENTITY object to a string.
If the optional 2nd argument PREFIX-ONLY is non-nil, don't append
server part of the identity.

The returned string will be abbreviated by
`riece-abbrev-identity-string-function', and `riece-identity' property
will be added."
  (let ((string
	 (if (or prefix-only
		 (equal (riece-identity-server identity) ""))
	     (copy-sequence (riece-identity-prefix identity))
	   (concat (riece-identity-prefix identity) " "
		   (riece-identity-server identity)))))
    (if riece-abbrev-identity-string-function
	(setq string (funcall riece-abbrev-identity-string-function string)))
    (put-text-property 0 (length string) 'riece-identity identity string)
    string))

(defun riece-parse-identity (string)
  "Convert STRING to an identity object.
The string will be expanded by
`riece-expand-identity-string-function'."
  (if riece-expand-identity-string-function
      (setq string (funcall riece-expand-identity-string-function string)))
  (riece-make-identity (if (string-match " " string)
			   (substring string 0 (match-beginning 0))
			 string)
		       (if (string-match " " string)
			   (substring string (match-end 0))
			 "")))

(defun riece-completing-read-identity (prompt channels
					      &optional predicate require-match
					      initial history default)
  "Read an identity object in the minibuffer, with completion.
PROMPT is a string to prompt with; normally it ends in a colon and a space.
CHANNELS is a list of identity objects.
The rest of arguments are the same as `completing-read'."
  (let* ((string
	  (completing-read
	   prompt
	   (mapcar (lambda (channel)
		     (list (riece-format-identity channel)))
		   (delq nil (copy-sequence (or channels
						riece-current-channels))))
	   predicate require-match initial history default))
	 (identity
	  (riece-parse-identity string)))
    (unless (string-match (concat "^\\(" riece-channel-regexp "\\|"
				  riece-user-regexp "\\)")
			  (riece-identity-prefix identity))
      (error "Invalid channel name!"))
    identity))

(provide 'riece-identity)

;;; riece-identity.el ends here
