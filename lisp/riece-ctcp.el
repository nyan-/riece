;;; riece-ctcp.el --- CTCP add-on
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

(require 'riece-version)
(require 'riece-misc)

(defvar riece-ctcp-ping-time nil)

(defvar riece-dialogue-mode-map)

(defun riece-ctcp-insinuate ()
  (add-hook 'riece-privmsg-hook 'riece-handle-ctcp-request)
  (add-hook 'riece-notice-hook 'riece-handle-ctcp-response)
  (define-key riece-dialogue-mode-map "\C-cv" 'riece-command-ctcp-version)
  (define-key riece-dialogue-mode-map "\C-cp" 'riece-command-ctcp-ping))

(defun riece-handle-ctcp-request (prefix string)
  (when (and prefix string
	     (riece-prefix-nickname prefix))
    (let* ((parameters (riece-split-parameters string))
	   (targets (split-string (car parameters) ","))
	   (message (nth 1 parameters)))
      (if (string-match "\1\\([^ ]+\\)\\( .+\\)?\1" message)
	  (let ((request (downcase (match-string 1 message))))
	    (if (match-beginning 2)
		(setq message (substring (match-string 2 message) 1)))
	    (unless (run-hook-with-args-until-success
		     (intern (concat "riece-ctcp-" request "-request-hook"))
		     prefix (car targets) message)
	      (let ((function (intern-soft (concat "riece-handle-ctcp-"
						   request
						   "-request"))))
		(if function
		    (condition-case error
			(funcall function prefix (car targets) message)
		      (error
		       (if riece-debug
			   (message "Error occurred in `%S': %S"
				    function error))))))
	      (run-hook-with-args-until-success
	       (intern (concat "riece-ctcp-after-" request "-request-hook"))
	       prefix (car targets) message))
	    t)))))

(defun riece-handle-ctcp-version-request (prefix target string)
  (let ((buffer (if (riece-channel-p target)
		    (cdr (riece-identity-assoc-no-server
			  (riece-make-identity target)
			  riece-channel-buffer-alist))))
	(user (riece-prefix-nickname prefix)))
    (riece-send-string
     (format "NOTICE %s :\1VERSION %s\1\r\n" user (riece-extended-version)))
    (riece-insert-change buffer (format "CTCP VERSION from %s\n" user))
    (riece-insert-change
     (if (and riece-channel-buffer-mode
	      (not (eq buffer riece-channel-buffer)))
	 (list riece-dialogue-buffer riece-others-buffer)
       riece-dialogue-buffer)
     (concat
      (riece-concat-server-name
       (format "CTCP VERSION from %s (%s) to %s"
	       user
	       (riece-strip-user-at-host (riece-prefix-user-at-host prefix))
	       target))
      "\n"))))

(defun riece-handle-ctcp-ping-request (prefix target string)
  (let ((buffer (if (riece-channel-p target)
		    (cdr (riece-identity-assoc-no-server
			  (riece-make-identity target)
			  riece-channel-buffer-alist))))
	(user (riece-prefix-nickname prefix)))
    (riece-send-string
     (if string
	 (format "NOTICE %s :\1PING %s\1\r\n" user string)
       (format "NOTICE %s :\1PING\1\r\n" user string)))
    (riece-insert-change buffer (format "CTCP PING from %s\n" user))
    (riece-insert-change
     (if (and riece-channel-buffer-mode
	      (not (eq buffer riece-channel-buffer)))
	 (list riece-dialogue-buffer riece-others-buffer)
       riece-dialogue-buffer)
     (concat
      (riece-concat-server-name
       (format "CTCP PING from %s (%s) to %s"
	       user
	       (riece-strip-user-at-host (riece-prefix-user-at-host prefix))
	       target))
      "\n"))))

(defun riece-handle-ctcp-response (prefix string)
  (when (and prefix string
	     (riece-prefix-nickname prefix))
    (let* ((parameters (riece-split-parameters string))
	   (targets (split-string (car parameters) ","))
	   (message (nth 1 parameters)))
      (if (string-match "\1\\([^ ]+\\)\\( .+\\)?\1" message)
	  (let ((response (downcase (match-string 1 message))))
	    (if (match-beginning 2)
		(setq message (substring (match-string 2 message) 1)))
	    (unless (run-hook-with-args-until-success
		     (intern (concat "riece-ctcp-" response "-response-hook"))
		     prefix (car targets) message)
	      (let ((function (intern-soft (concat "riece-handle-ctcp-"
						   response
						   "-response"))))
		(if function
		    (condition-case error
			(funcall function prefix (car targets) message)
		      (error
		       (if riece-debug
			   (message "Error occurred in `%S': %S"
				    function error))))))
	      (run-hook-with-args-until-success
	       (intern (concat "riece-ctcp-after-" response "-response-hook"))
	       prefix (car targets) message))
	    t)))))

(defun riece-handle-ctcp-version-response (prefix target string)
  (riece-insert-change
   (list riece-dialogue-buffer riece-others-buffer)
   (concat
    (riece-concat-server-name
     (format "CTCP VERSION for %s (%s) = %s"
	     (riece-prefix-nickname prefix)
	     (riece-strip-user-at-host (riece-prefix-user-at-host prefix))
	     string))
    "\n")))

(defun riece-handle-ctcp-ping-response (prefix target string)
  (let* ((now (current-time))
	 (elapsed (+ (* 65536 (- (car now) (car riece-ctcp-ping-time)))
		     (- (nth 1 now) (nth 1 riece-ctcp-ping-time)))))
    (riece-insert-change
     (list riece-dialogue-buffer riece-others-buffer)
     (concat
      (riece-concat-server-name
       (format "CTCP PING for %s (%s) = %d sec"
	       (riece-prefix-nickname prefix)
	       (riece-strip-user-at-host (riece-prefix-user-at-host prefix))
	       elapsed))
      "\n"))))

(defun riece-command-ctcp-version (user)
  (interactive
   (let ((completion-ignore-case t))
     (list (completing-read
	    "Channel/User: "
	    (mapcar #'list (riece-get-users-on-server))))))
  (riece-send-string (format "PRIVMSG %s :\1VERSION\1\r\n" user)))

(defun riece-command-ctcp-ping (user)
  (interactive
   (let ((completion-ignore-case t))
     (list (completing-read
	    "Channel/User: "
	    (mapcar #'list (riece-get-users-on-server))))))
  (riece-send-string (format "PRIVMSG %s :\1PING\1\r\n" user))
  (setq riece-ctcp-ping-time (current-time)))

(provide 'riece-ctcp)

;;; riece-ctcp.el ends here