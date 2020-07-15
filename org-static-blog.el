;;; org-static-blog.el --- a simple org-mode based static blog generator

;; Author: Bastian Bechtold
;; Contrib: Shmavon Gazanchyan, Rafał -rsm- Marek, neeasade,
;; Michael Cardell Widerkrantz, Matthew Bauer, Winny, Yauhen Makei,
;; luhuaei, zngguvnf, Qiantan Hong, Jonas Bernoulli, Théo Jacquin,
;; K. Scarlet, zsxh
;; URL: https://github.com/bastibe/org-static-blog
;; Version: 1.3.0
;; Package-Requires: ((emacs "24.3"))

;;; Commentary:

;; Static blog generators are a dime a dozen. This is one more, which
;; focuses on being simple. All files are simple org-mode files in a
;; directory. The only requirement is that every org file must have a
;; #+TITLE and a #+DATE, and optionally, #+FILETAGS.

;; This file is also available from marmalade and melpa-stable.

;; Set up your blog by customizing org-static-blog's parameters, then
;; call M-x org-static-blog-publish to render the whole blog or
;; M-x org-static-blog-publish-file filename.org to render only only
;; the file filename.org.

;; Above all, I tried to make org-static-blog as simple as possible.
;; There are no magic tricks, and all of the source code is meant to
;; be easy to read, understand and modify.

;; If you have questions, if you find bugs, or if you would like to
;; contribute something to org-static-blog, please open an issue or
;; pull request on Github.

;; Finally, I would like to remind you that I am developing this
;; project for free, and in my spare time. While I try to be as
;; accomodating as possible, I can not guarantee a timely response to
;; issues. Publishing Open Source Software on Github does not imply an
;; obligation to *fix your problem right now*. Please be civil.

;;; Code:

(require 'org)
(require 'ox-html)

(defgroup org-static-blog nil
  "Settings for a static blog generator using org-mode"
  :version "1.3.0"
  :group 'applications)

(defcustom org-static-blog-publish-url "https://example.com/"
  "URL of the blog."
  :type '(string)
  :safe t)

(defcustom org-static-blog-publish-title "Example.com"
  "Title of the blog."
  :type '(string)
  :safe t)

(defcustom org-static-blog-publish-directory "~/blog/"
  "Directory where published HTML files are stored."
  :type '(directory))

(defcustom org-static-blog-posts-directory "~/blog/posts/"
  "Directory where published ORG files are stored.
When publishing, posts are rendered as HTML, and included in the
index, archive, tags, and RSS feed."
  :type '(directory))

(defcustom org-static-blog-drafts-directory "~/blog/drafts/"
  "Directory where unpublished ORG files are stored.
When publishing, draft are rendered as HTML, but not included in
the index, archive, tags, or RSS feed."
  :type '(directory))

(defcustom org-static-blog-index-file "index.html"
  "File name of the blog landing page.
The index page contains the most recent
`org-static-blog-index-length` full-text posts."
  :type '(string)
  :safe t)

(defcustom org-static-blog-index-length 5
  "Number of articles to include on index page."
  :type '(integer)
  :safe t)

(defcustom org-static-blog-archive-file "archive.html"
  "File name of the list of all blog posts.
The archive page lists all posts as headlines."
  :type '(string)
  :safe t)

(defcustom org-static-blog-tags-file "tags.html"
  "File name of the list of all blog posts by tag.
The tags page lists all posts as headlines."
  :type '(string)
  :safe t)

(defcustom org-static-blog-enable-tags nil
  "Show tags below posts, and generate tag pages."
  :group 'org-static-blog
  :type '(boolean)
  :safe t)

(defcustom org-static-blog-use-semantic-html nil
  "Use semantic HTML tags instead of div."
  :group 'org-static-blog)

(defcustom org-static-blog-enable-deprecation-warning t
  "Show deprecation warnings."
  :type '(boolean))

(defcustom org-static-blog-rss-file "rss.xml"
  "File name of the RSS feed."
  :type '(string)
  :safe t)

(defcustom org-static-blog-rss-extra ""
  "Extra information for the RSS feed header.
This information is placed right before the sequence of posts.
You can add an icon for the feed, or advertise that you built
your blog with emacs, org-mode and org-static-blog.
"
  :type '(string)
  :safe t)


(defcustom org-static-blog-page-header ""
  "HTML to put in the <head> of each page."
  :type '(string)
  :safe t)

(defcustom org-static-blog-page-preamble ""
  "HTML to put before the content of each page."
  :type '(string)
  :safe t)

(defcustom org-static-blog-page-postamble ""
  "HTML to put after the content of each page."
  :type '(string)
  :safe t)

(defcustom org-static-blog-post-comments ""
  "HTML code for comments to put after each blog post."
  :type '(string)
  :safe t)

(defcustom org-static-blog-langcode "en"
  "Language code for the blog content."
  :type '(string)
  :safe t)

(defcustom org-static-blog-use-preview nil
  "Use preview versions of posts on multipost pages.

See also `org-static-blog-preview-ellipsis' and
`org-static-blog-preview-link-p'."
  :type '(boolean)
  :safe t)

(defcustom org-static-blog-preview-convert-titles t
  "When preview is enabled, convert <h1> to <h2> for the previews."
  :type '(boolean)
  :safe t)

(defcustom org-static-blog-preview-ellipsis "(...)"
  "The HTML appended to the preview if some part of the post is hidden."
  :type '(string)
  :safe t)

(defcustom org-static-blog-preview-link-p nil
  "Whether to make the preview ellipsis a link to the article's page."
  :type '(boolean)
  :safe t)

;; localization support
(defconst org-static-blog-texts
  '((other-posts
     ("en" . "Other posts")
     ("pl" . "Pozostałe wpisy")
     ("ru" . "Другие публикации")
     ("by" . "Іншыя публікацыі")
     ("it" . "Altri articoli")
     ("es" . "Otros artículos")
     ("fr" . "Autres articles"))
    (date-format
     ("en" . "%d %b %Y")
     ("pl" . "%Y-%m-%d")
     ("ru" . "%d.%m.%Y")
     ("by" . "%d.%m.%Y")
     ("it" . "%d/%m/%Y")
     ("es" . "%d/%m/%Y")
     ("fr" . "%d-%m-%Y"))
    (tags
     ("en" . "Tags")
     ("pl" . "Tagi")
     ("ru" . "Ярлыки")
     ("by" . "Ярлыкі")
     ("it" . "Categorie")
     ("es" . "Categoría")
     ("fr" . "Tags"))
    (archive
     ("en" . "Archive")
     ("pl" . "Archiwum")
     ("ru" . "Архив")
     ("by" . "Архіў")
     ("it" . "Archivio")
     ("es" . "Archivo")
     ("fr" . "Archive"))
    (posts-tagged
     ("en" . "Posts tagged")
     ("pl" . "Wpisy z tagiem")
     ("ru" . "Публикации с ярлыками")
     ("by" . "Публікацыі")
     ("it" . "Articoli nella categoria")
     ("es" . "Artículos de la categoría")
     ("fr" . "Articles tagués"))
    (no-prev-post
     ("en" . "There is no previous post")
     ("pl" . "Poprzedni wpis nie istnieje")
     ("ru" . "Нет предыдущей публикации")
     ("by" . "Няма папярэдняй публікацыі")
     ("it" . "Non c'è nessun articolo precedente")
     ("es" . "No existe un artículo precedente")
     ("fr" . "Il n'y a pas d'article précédent"))
    (no-next-post
     ("en" . "There is no next post")
     ("pl" . "Następny wpis nie istnieje")
     ("ru" . "Нет следующей публикации")
     ("by" . "Няма наступнай публікацыі")
     ("it" . "Non c'è nessun articolo successivo")
     ("es" . "No hay artículo siguiente")
     ("fr" . "Il n'y a pas d'article suivants"))
    (title
     ("en" . "Title: ")
     ("pl" . "Tytuł: ")
     ("ru" . "Заголовок: ")
     ("by" . "Загаловак: ")
     ("it" . "Titolo: ")
     ("es" . "Título: ")
     ("fr" . "Titre : "))
    (filename
     ("en" . "Filename: ")
     ("pl" . "Nazwa pliku: ")
     ("ru" . "Имя файла: ")
     ("by" . "Імя файла: ")
     ("it" . "Nome del file: ")
     ("es" . "Nombre del archivo: ")
     ("fr" . "Nom du fichier :"))))

(defun org-static-blog-gettext (text-id)
  "Return localized text.
Depends on org-static-blog-langcode and org-static-blog-texts."
  (let* ((text-node (assoc text-id org-static-blog-texts))
         (text-lang-node (if text-node
                             (assoc org-static-blog-langcode text-node)
                           nil)))
    (if text-lang-node
        (cdr text-lang-node)
      (concat "[" (symbol-name text-id) ":" org-static-blog-langcode "]"))))


;;;###autoload
(defun org-static-blog-publish (&optional force-render)
  "Render all blog posts, the index, archive, tags, and RSS feed.
Only blog posts that changed since the HTML was created are
re-rendered.

With a prefix argument, all blog posts are re-rendered
unconditionally."
  (interactive "P")
  (dolist (file (append (org-static-blog-get-post-filenames)
                        (org-static-blog-get-draft-filenames)))
    (when (or force-render (org-static-blog-needs-publishing-p file))
      (org-static-blog-publish-file file)))
  ;; don't spam too many deprecation warnings:
  (let ((org-static-blog-enable-deprecation-warning nil))
    (org-static-blog-assemble-index)
    (org-static-blog-assemble-rss)
    (org-static-blog-assemble-archive)
    (if org-static-blog-enable-tags
        (org-static-blog-assemble-tags))))

(defun org-static-blog-needs-publishing-p (post-filename)
  "Check whether POST-FILENAME was changed since last render."
  (let ((pub-filename
         (org-static-blog-matching-publish-filename post-filename)))
    (not (and (file-exists-p pub-filename)
              (file-newer-than-file-p pub-filename post-filename)))))

(defun org-static-blog-matching-publish-filename (post-filename)
  "Generate HTML file name for POST-FILENAME."
  (concat org-static-blog-publish-directory
          (org-static-blog-get-post-public-path post-filename)))

(defun org-static-blog-get-post-filenames ()
  "Returns a list of all posts."
  (directory-files-recursively
   org-static-blog-posts-directory ".*\\.org$"))

(defun org-static-blog-get-draft-filenames ()
  "Returns a list of all drafts."
  (directory-files-recursively
   org-static-blog-drafts-directory ".*\\.org$"))

(defun org-static-blog-file-buffer (file)
  "Return the buffer open with a full filepath, or nil."
  (require 'seq)
  (make-directory (file-name-directory file) t)
  (car (seq-filter
        (lambda (buf)
          (string= (with-current-buffer buf buffer-file-name) file))
        (buffer-list))))

;; This macro is needed for many of the following functions.
(defmacro org-static-blog-with-find-file (file contents &rest body)
  "Executes BODY in FILE. Use this to insert text into FILE.
The buffer is disposed after the macro exits (unless it already
existed before)."
  `(save-excursion
     (let ((current-buffer (current-buffer))
           (buffer-exists (org-static-blog-file-buffer ,file))
           (result nil)
           (contents ,contents))
       (if buffer-exists
           (switch-to-buffer buffer-exists)
         (find-file ,file))
       (erase-buffer)
       (insert contents)
       (setq result (progn ,@body))
       (basic-save-buffer)
       (unless buffer-exists
         (kill-buffer))
       (switch-to-buffer current-buffer)
       result)))

(defun org-static-blog-get-date (post-filename)
  "Extract the `#+date:` from POST-FILENAME as date-time."
  (let ((case-fold-search t))
    (with-temp-buffer
      (insert-file-contents post-filename)
      (goto-char (point-min))
      (if (search-forward-regexp "^\\#\\+date:[ ]*<\\([^]>]+\\)>$" nil t)
          (date-to-time (match-string 1))
        (time-since 0)))))

(defun org-static-blog-get-title (post-filename)
  "Extract the `#+title:` from POST-FILENAME."
  (let ((case-fold-search t))
    (with-temp-buffer
      (insert-file-contents post-filename)
      (goto-char (point-min))
      (search-forward-regexp "^\\#\\+title:[ ]*\\(.+\\)$")
      (match-string 1))))

(defun org-static-blog-get-tags (post-filename)
  "Extract the `#+filetags:` from POST-FILENAME as list of strings."
  (let ((case-fold-search t))
    (with-temp-buffer
      (insert-file-contents post-filename)
      (goto-char (point-min))
      (if (search-forward-regexp "^\\#\\+filetags:[ ]*:\\(.*\\):$" nil t)
          (split-string (match-string 1) ":")
        (if (search-forward-regexp "^\\#\\+filetags:[ ]*\\(.+\\)$" nil t)
            (split-string (match-string 1))
          )))))

(defun org-static-blog-get-tag-tree ()
  "Return an association list of tags to filenames.
e.g. `(('foo' 'file1.org' 'file2.org') ('bar' 'file2.org'))`"
  (let ((tag-tree '()))
    (dolist (post-filename (org-static-blog-get-post-filenames))
      (let ((tags (org-static-blog-get-tags post-filename)))
        (dolist (tag tags)
          (if (assoc-string tag tag-tree t)
              (push post-filename (cdr (assoc-string tag tag-tree t)))
            (push (cons tag (list post-filename)) tag-tree)))))
    tag-tree))

(defun org-static-blog-get-preview (post-filename)
  "Get title, date, tags from POST-FILENAME and get the first paragraph from the rendered HTML.
If the HTML body contains multiple paragraphs, include only the first paragraph,
and display an ellipsis.
Preamble and Postamble are excluded, too."
  (with-temp-buffer
    (insert-file-contents (org-static-blog-matching-publish-filename post-filename))
    (let ((post-title)
          (post-date)
          (post-taglist)
          (post-ellipsis "")
          (first-paragraph-start)
          (first-paragraph-end))
      (setq post-title (org-static-blog-get-title post-filename))
      (setq post-date (org-static-blog-get-date post-filename))
      (setq post-taglist (org-static-blog-post-taglist post-filename))
      ;; Find where the first paragraph ends and starts
      (goto-char (point-min))
      (when (search-forward "<p>" nil t)
        (search-forward "</p>")
        (setq first-paragraph-end (point))
        (search-backward "<p>")
        (setq first-paragraph-start (point))
        (goto-char first-paragraph-end)
        (when (search-forward "<p>" nil t)
          (setq post-ellipsis (concat (when org-static-blog-preview-link-p
                                        (format "<a href=\"%s\">" (org-static-blog-get-post-url post-filename)))
                                      org-static-blog-preview-ellipsis
                                      (when org-static-blog-preview-link-p "</a>\n")))))
      ;; Put the substrings together.
      (concat
       (format "<h2 class=\"post-title\"><a href=\"%s\">%s</a></h2>" (org-static-blog-get-post-url post-filename) post-title)
       (format-time-string (concat "<div class=\"post-date\">" (org-static-blog-gettext 'date-format) "</div>") post-date)
       (buffer-substring-no-properties first-paragraph-start first-paragraph-end)
       post-ellipsis
       (format "<div class=\"taglist\">%s</div>" post-taglist)))))


(defun org-static-blog-get-body (post-filename &optional exclude-title)
  "Get the rendered HTML body without headers from POST-FILENAME.
Preamble and Postamble are excluded, too."
  (with-temp-buffer
    (insert-file-contents (org-static-blog-matching-publish-filename post-filename))
    (buffer-substring-no-properties
     (progn
       (goto-char (point-min))
       (if exclude-title
           (progn (search-forward "<h1 class=\"post-title\">")
                  (search-forward "</h1>"))
         (search-forward
          (if org-static-blog-use-semantic-html "<main>" "<div id=\"content\">" )))
       (point))
     (progn
       (goto-char (point-max))
       (search-backward
        (if org-static-blog-use-semantic-html "<footer>" "<div id=\"postamble\" class=\"status\">" ))
       (search-backward
        (if org-static-blog-use-semantic-html "</main>" "</div>" ))
       (point)))))

(defun org-static-blog-get-absolute-url (relative-url)
  "Returns absolute URL based on the RELATIVE-URL passed to the function.

For example, when `org-static-blog-publish-url` is set to 'https://example.com/'
and `relative-url` is passed as 'archive.html' then the function
will return 'https://example.com/archive.html'."
  (concat org-static-blog-publish-url relative-url))

(defun org-static-blog-get-post-url (post-filename)
  "Returns absolute URL to the published POST-FILENAME.

This function concatenates publish URL and generated custom filepath to the
published HTML version of the post."
  (org-static-blog-get-absolute-url
   (org-static-blog-get-post-public-path post-filename)))

(defun org-static-blog-get-post-public-path (post-filename)
  "Returns post filepath in public directory.

This function retrieves relative path to the post file in posts or drafts
directories, the date of the post from its contents and then passes it to
`org-static-blog-generate-post-path` to generate custom filepath for the published
HTML version of the post."
  (org-static-blog-generate-post-path
   (org-static-blog-get-relative-path post-filename)
   (org-static-blog-get-date post-filename)))

(defun org-static-blog-get-relative-path (post-filename)
  "Removes absolute directory path from POST-FILENAME and changes file extention
from `.org` to `.html`. Returns filepath to HTML file relative to posts or drafts directories.

Works with both posts and drafts directories.

For example, when `org-static-blog-posts-directory` is set to '~/blog/posts'
and `post-filename` is passed as '~/blog/posts/my-life-update.org' then the function
will return 'my-life-update.html'."
  (replace-regexp-in-string ".org$" ".html"
                            (replace-regexp-in-string
                             (concat "^\\("
                                     (file-truename org-static-blog-posts-directory)
                                     "\\|"
                                     (file-truename org-static-blog-drafts-directory)
                                     "\\)")
                             ""
                             (file-truename post-filename))))

(defun org-static-blog-generate-post-path (post-filename post-datetime)
  "Returns post public path based on POST-FILENAME and POST-DATETIME.

By default, this function returns post filepath unmodified, so script will
replicate file and directory structure of posts and drafts directories.

Override this function if you want to generate custom post URLs different
from how they are stored in posts and drafts directories.

For example, there is a post in posts directory with the
file path `hobby/charity-coding.org` and dated `<2019-08-20 Tue>`.

In this case, the function will receive following argument values:
- post-filename: 'hobby/charity-coding'
- post-datetime: datetime of <2019-08-20 Tue>

and by default will return 'hobby/charity-coding', so that the path
to HTML file in publish directory will be 'hobby/charity-coding.html'.

If this function is overriden with something like this:

(defun org-static-blog-generate-post-path (post-filename post-datetime)
  (concat (format-time-string \"%Y/%m/%d\" post-datetime)
          \"/\"
          (file-name-nondirectory post-filename)))

Then the output will be '2019/08/20/charity-coding' and this will be
the path to the HTML file in publish directory and the url for the post."
  post-filename)

;;;###autoload
(defun org-static-blog-publish-file (post-filename)
  "Publish a single POST-FILENAME.
The index, archive, tags, and RSS feed are not updated."
  (interactive "f")
  (org-static-blog-with-find-file
   (org-static-blog-matching-publish-filename post-filename)
   (concat
    "<!DOCTYPE html>\n"
    "<html lang=\"" org-static-blog-langcode "\">\n"
    "<head>\n"
    "<meta charset=\"UTF-8\">\n"
    "<link rel=\"alternate\"\n"
    "      type=\"application/rss+xml\"\n"
    "      href=\"" (org-static-blog-get-absolute-url org-static-blog-rss-file) "\"\n"
    "      title=\"RSS feed for " org-static-blog-publish-url "\"/>\n"
    "<title>" (org-static-blog-get-title post-filename) "</title>\n"
    org-static-blog-page-header
    "</head>\n"
    "<body>\n"
    (if org-static-blog-use-semantic-html "<header>\n" "<div id=\"preamble\" class=\"status\">\n")
    org-static-blog-page-preamble
    (if org-static-blog-use-semantic-html "</header>\n" "</div>\n")
    (if org-static-blog-use-semantic-html "<main>\n" "<div id=\"content\">\n" )
    (org-static-blog-post-preamble post-filename)
    (org-static-blog-render-post-content post-filename)
    (org-static-blog-post-postamble post-filename)
    (if org-static-blog-use-semantic-html "</main>\n" "</div>\n" )
    (if org-static-blog-use-semantic-html "<footer>" "<div id=\"postamble\" class=\"status\">" )
    org-static-blog-page-postamble
    (if org-static-blog-use-semantic-html "</footer>\n" "</div>\n")
    "</body>\n"
    "</html>\n")))

(defun org-static-blog-render-post-content (post-filename)
  "Render blog content as bare HTML without header."
  (let ((org-html-doctype "html5")
        (org-html-html5-fancy t))
    (save-excursion
      (let ((current-buffer (current-buffer))
            (buffer-exists (org-static-blog-file-buffer post-filename))
            (result nil))
        (if buffer-exists
            (switch-to-buffer buffer-exists)
          (find-file post-filename))
        (setq result
              (org-export-as 'org-static-blog-post-bare nil nil nil nil))
        (basic-save-buffer)
        (unless buffer-exists
          (kill-buffer))
        (switch-to-buffer current-buffer)
        result))))

(org-export-define-derived-backend 'org-static-blog-post-bare 'html
  :translate-alist '((template . (lambda (contents info) contents))))

(defun org-static-blog-assemble-index ()
  "Assemble the blog index page.
The index page contains the last `org-static-blog-index-length`
posts as full text posts."
  (let ((post-filenames (org-static-blog-get-post-filenames)))
    ;; reverse-sort, so that the later `last` will grab the newest posts
    (setq post-filenames (sort post-filenames (lambda (x y) (time-less-p (org-static-blog-get-date x)
                                                                         (org-static-blog-get-date y)))))
    (org-static-blog-assemble-multipost-page
     (concat org-static-blog-publish-directory org-static-blog-index-file)
     (last post-filenames org-static-blog-index-length))))

(defun org-static-blog-assemble-multipost-page (pub-filename post-filenames &optional front-matter)
  "Assemble a page that contains multiple posts one after another.
Posts are sorted in descending time."
  (setq post-filenames (sort post-filenames (lambda (x y) (time-less-p (org-static-blog-get-date y)
                                                                       (org-static-blog-get-date x)))))
  (org-static-blog-with-find-file
   pub-filename
   (concat
    "<!DOCTYPE html>\n"
    "<html lang=\"" org-static-blog-langcode "\">\n"
    "<head>\n"
    "<meta charset=\"UTF-8\">\n"
    "<link rel=\"alternate\"\n"
    "      type=\"application/rss+xml\"\n"
    "      href=\"" (org-static-blog-get-absolute-url org-static-blog-rss-file) "\"\n"
    "      title=\"RSS feed for " org-static-blog-publish-url "\"/>\n"
    "<title>" org-static-blog-publish-title "</title>\n"
    org-static-blog-page-header
    "</head>\n"
    "<body>\n"
    (if org-static-blog-use-semantic-html "<header>\n" "<div id=\"preamble\" class=\"status\">\n" )
    org-static-blog-page-preamble
    (if org-static-blog-use-semantic-html "</header>\n" "</div>\n" )
    (if org-static-blog-use-semantic-html "<main>\n" "<div id=\"content\">\n" ))
   (if front-matter
       (insert front-matter))
   (setq post-filenames (sort post-filenames (lambda (x y) (time-less-p (org-static-blog-get-date y)
                                                                        (org-static-blog-get-date x)))))
   (dolist (post-filename post-filenames)
     (insert "<article>" (org-static-blog-get-body post-filename) "</article>"))
   (insert
    "<div id=\"archive\">\n"
    "<a href=\"" org-static-blog-archive-file "\">Other posts</a>\n"
    (if org-static-blog-use-semantic-html "</main>\n" "</div>\n")
    "</div>\n"
    "</body>\n"
    "</html>\n")))



(defun org-static-blog-post-preamble (post-filename)
  "Returns the formatted date and headline of the post.
This function is called for every post and prepended to the post body.
Modify this function if you want to change a posts headline."
  (concat
   "<header>\n"
   (if org-static-blog-use-semantic-html "<time>" "<div class=\"post-date\">")
   (format-time-string "%d %b %Y" (org-static-blog-get-date post-filename))
   (if org-static-blog-use-semantic-html "</time>" "</div>")
   "<h1 class=\"post-title\">"
   "<a href=\"" (org-static-blog-get-post-url post-filename) "\">" (org-static-blog-get-title post-filename) "</a>"
   "</h1>\n</header>\n"))


(defun org-static-blog-post-taglist (post-filename)
  "Returns the tag list of the post.
This part will be attached at the end of the post, after
the taglist, in a <div id=\"taglist\">...</div> block."
  (let ((taglist-content ""))
    (when (and (org-static-blog-get-tags post-filename) org-static-blog-enable-tags)
      (setq taglist-content (concat "<a href=\""
                                    (org-static-blog-get-absolute-url org-static-blog-tags-file)
                                    "\">" (org-static-blog-gettext 'tags) "</a>: "))
      (dolist (tag (org-static-blog-get-tags post-filename))
        (setq taglist-content (concat taglist-content "<a href=\""
                                      (org-static-blog-get-absolute-url (concat "tag-" (downcase tag) ".html"))
                                      "\">" tag "</a> "))))
    taglist-content))


(defun org-static-blog-post-postamble (post-filename)
  "Returns the tag list and comment box at the end of a post.
This function is called for every post and the returned string is
appended to the post body, and includes the tag list generated by
followed by the HTML code for comments."
  (concat "<div class=\"taglist\">"
          (org-static-blog-post-taglist post-filename)
          "</div>"
          (if (string= org-static-blog-post-comments "")
              ""
            (concat "\n<div id=\"comments\">"
                    org-static-blog-post-comments
                    "</div>"))))

(defun org-static-blog-assemble-rss ()
  "Assemble the blog RSS feed.
The RSS-feed is an XML file that contains every blog post in a
machine-readable format."
  (let ((rss-filename (concat org-static-blog-publish-directory org-static-blog-rss-file))
        (rss-items nil))
    (dolist (post-filename (org-static-blog-get-post-filenames))
      (let ((rss-date (org-static-blog-get-date post-filename))
            (rss-text (org-static-blog-get-rss-item post-filename)))
        (add-to-list 'rss-items (cons rss-date rss-text))))
    (setq rss-items (sort rss-items (lambda (x y) (time-less-p (car y) (car x)))))
    (org-static-blog-with-find-file
     rss-filename
     (concat "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n"
             "<rss version=\"2.0\">\n"
             "<channel>\n"
             "<title><![CDATA[" org-static-blog-publish-title "]]></title>\n"
             "<description><![CDATA[" org-static-blog-publish-title "]]></description>\n"
             "<link>" org-static-blog-publish-url "</link>\n"
             "<lastBuildDate>" (format-time-string "%a, %d %b %Y %H:%M:%S %z" (current-time)) "</lastBuildDate>\n"
             org-static-blog-rss-extra
             (apply 'concat (mapcar 'cdr rss-items))
             "</channel>\n"
             "</rss>\n"))))

(defun org-static-blog-get-rss-item (post-filename)
  "Assemble RSS item from post-filename.
The HTML content is taken from the rendered HTML post."
  (concat
   "<item>\n"
   "  <title><![CDATA[" (org-static-blog-get-title post-filename) "]]></title>\n"
   "  <description><![CDATA["
   (org-static-blog-get-body post-filename t) ; exclude headline!
   "]]></description>\n"
   (let ((categories ""))
     (when (and (org-static-blog-get-tags post-filename) org-static-blog-enable-tags)
       (dolist (tag (org-static-blog-get-tags post-filename))
         (setq categories (concat categories
                                  "  <category><![CDATA[" tag "]]></category>\n"))))
     categories)
   "  <link>"
   (org-static-blog-get-post-url post-filename)
   "</link>\n"
   "  <pubDate>"
   (format-time-string "%a, %d %b %Y %H:%M:%S %z" (org-static-blog-get-date post-filename))
   "</pubDate>\n"
   "</item>\n"))

(defun org-static-blog-assemble-archive ()
  "Re-render the blog archive page.
The archive page contains single-line links and dates for every
blog post, but no post body."
  (let ((archive-filename (concat org-static-blog-publish-directory org-static-blog-archive-file))
        (archive-entries nil)
        (post-filenames (org-static-blog-get-post-filenames)))
    (setq post-filenames (sort post-filenames (lambda (x y) (time-less-p
                                                             (org-static-blog-get-date y)
                                                             (org-static-blog-get-date x)))))
    (org-static-blog-with-find-file
     archive-filename
     (concat
      "<!DOCTYPE html>\n"
      "<html lang=\"" org-static-blog-langcode "\">\n"
      "<head>\n"
      "<meta charset=\"UTF-8\">\n"
      "<link rel=\"alternate\"\n"
      "      type=\"application/rss+xml\"\n"
      "      href=\"" (org-static-blog-get-absolute-url org-static-blog-rss-file) "\"\n"
      "      title=\"RSS feed for " org-static-blog-publish-url "\">\n"
      "<title>" org-static-blog-publish-title "</title>\n"
      org-static-blog-page-header
      "</head>\n"
      "<body>\n"
      (if org-static-blog-use-semantic-html "<header>\n" "<div id=\"preamble\" class=\"status\">\n")
      org-static-blog-page-preamble
      (if org-static-blog-use-semantic-html "</header>\n" "</div>\n")
      (if org-static-blog-use-semantic-html "<main>\n" "<div id=\"content\">\n" )
      "<h1 class=\"title\">Archive</h1>\n")
     (dolist (post-filename (sort post-filenames (lambda (x y) (time-less-p
                                                                (org-static-blog-get-date y)
                                                                (org-static-blog-get-date x)))))
       (insert (org-static-blog-get-post-summary post-filename)))
     (insert
      (if org-static-blog-use-semantic-html "</main>\n" "</div>\n" )
      "</body>\n </html>"))))

(defun org-static-blog-get-post-summary (post-filename)
  "Assemble post summary for an archive page.
This function is called for every post on the archive and
tags-archive page. Modify this function if you want to change an
archive headline."
  (concat
   (if org-static-blog-use-semantic-html "<time>" "<div class=\"post-date\">" )
   (format-time-string "%d %b %Y" (org-static-blog-get-date post-filename))
   (if org-static-blog-use-semantic-html "</time>" "</div>" )
   "<h2 class=\"post-title\">"
   "<a href=\"" (org-static-blog-get-post-url post-filename) "\">" (org-static-blog-get-title post-filename) "</a>"
   "</h2>\n"))

(defun org-static-blog-assemble-tags ()
  "Render the tag archive and tag pages."
  (org-static-blog-assemble-tags-archive)
  (dolist (tag (org-static-blog-get-tag-tree))
    (org-static-blog-assemble-multipost-page
     (concat org-static-blog-publish-directory "tag-" (downcase (car tag)) ".html")
     (cdr tag)
     (concat "<h1 class=\"title\">" (org-static-blog-gettext 'posts-tagged) " \"" (car tag) "\":</h1>"))))

(defun org-static-blog-assemble-tags-archive-tag (tag)
  "Assemble single TAG for all filenames."
  (let ((post-filenames (cdr tag)))
    (setq post-filenames
          (sort post-filenames (lambda (x y) (time-less-p (org-static-blog-get-date x)
                                                          (org-static-blog-get-date y)))))
    (concat "<h1 class=\"tags-title\">" (org-static-blog-gettext 'posts-tagged) " \"" (downcase (car tag)) "\":</h1>\n"
            (apply 'concat (mapcar 'org-static-blog-get-post-summary post-filenames)))))

(defun org-static-blog-assemble-tags-archive ()
  "Assemble the blog tag archive page.
The archive page contains single-line links and dates for every
blog post, sorted by tags, but no post body."
  (let ((tags-archive-filename (concat org-static-blog-publish-directory org-static-blog-tags-file))
        (tag-tree (org-static-blog-get-tag-tree)))
    (setq tag-tree (sort tag-tree (lambda (x y) (string-greaterp (car y) (car x)))))
    (org-static-blog-with-find-file
     tags-archive-filename
     (concat
      "<!DOCTYPE html>\n"
      "<html lang=\"" org-static-blog-langcode "\">\n"
      "<head>\n"
      "<meta charset=\"UTF-8\">\n"
      "<link rel=\"alternate\"\n"
      "      type=\"application/rss+xml\"\n"
      "      href=\"" (org-static-blog-get-absolute-url org-static-blog-rss-file) "\"\n"
      "      title=\"RSS feed for " org-static-blog-publish-url "\">\n"
      "<title>" org-static-blog-publish-title "</title>\n"
      org-static-blog-page-header
      "</head>\n"
      "<body>\n"
      (if org-static-blog-use-semantic-html "<header>\n" "<div id=\"preamble\" class=\"status\">\n")
      org-static-blog-page-preamble
      (if org-static-blog-use-semantic-html "</header>\n" "</div>\n")
      (if org-static-blog-use-semantic-html "<main>\n" "<div id=\"content\">\n")
      "<h1 class=\"title\">Tags</h1>\n")
     (dolist (tag (sort tag-tree (lambda (x y) (string-greaterp (car y) (car x)))))
       (insert "<h1 class=\"tags-title\">Posts tagged \"" (downcase (car tag)) "\":</h1>\n")
       (dolist (post-filename (sort (cdr tag) (lambda (x y) (time-less-p (org-static-blog-get-date x)
                                                                         (org-static-blog-get-date y)))))
         (insert (org-static-blog-get-post-summary post-filename))))
     (insert
      (if org-static-blog-use-semantic-html "</main>" "</div>")
      "</body>\n"
      "</html>\n"))))

(defun org-static-blog-open-previous-post ()
  "Opens previous blog post."
  (interactive)
  (let ((posts (sort (org-static-blog-get-post-filenames)
                     (lambda (x y)
                       (time-less-p (org-static-blog-get-date y)
                                    (org-static-blog-get-date x)))))
        (current-post (buffer-file-name)))
    (while (and posts
                (not (string-equal
                      (file-name-nondirectory current-post)
                      (file-name-nondirectory (car posts)))))
      (setq posts (cdr posts)))
    (if (> (list-length posts) 1)
        (find-file (cadr posts))
      (message (org-static-blog-gettext 'no-prev-post)))))

(defun org-static-blog-open-next-post ()
  "Opens next blog post."
  (interactive)
  (let ((posts (sort (org-static-blog-get-post-filenames)
                     (lambda (x y)
                       (time-less-p (org-static-blog-get-date x)
                                    (org-static-blog-get-date y)))))
        (current-post (buffer-file-name)))
    (while (and posts
                (not (string-equal
                      (file-name-nondirectory current-post)
                      (file-name-nondirectory (car posts)))))
      (setq posts (cdr posts)))
    (if (> (list-length posts) 1)
        (find-file (cadr posts))
      (message (org-static-blog-gettext 'no-next-post)))))

(defun org-static-blog-open-matching-publish-file ()
  "Opens HTML for post."
  (interactive)
  (find-file (org-static-blog-matching-publish-filename (buffer-file-name))))

;;;###autoload
(defun org-static-blog-create-new-post (&optional draft)
  "Creates a new blog post.
Prompts for a title and proposes a file name. The file name is
only a suggestion; You can choose any other file name if you so
choose."
  (interactive)
  (let ((title (read-string (org-static-blog-gettext 'title))))
    (find-file (concat
                (if draft
                    org-static-blog-drafts-directory
                  org-static-blog-posts-directory)
                (read-string (org-static-blog-gettext 'filename)
                             (concat (format-time-string "%Y-%m-%d-" (current-time))
                                     (replace-regexp-in-string "\s" "-" (downcase title))
                                     ".org"))))
    (insert "#+title: " title "\n"
            "#+date: " (format-time-string "<%Y-%m-%d %H:%M>") "\n"
            "#+filetags: ")))

;;;###autoload
(defun org-static-blog-create-new-draft ()
  "Creates a new blog draft.
Prompts for a title and proposes a file name. The file name is
only a suggestion; You can choose any other file name if you so
choose."
  (interactive)
  (org-static-blog-create-new-post 't))


;;;###autoload
(define-derived-mode org-static-blog-mode org-mode "OSB"
  "Blogging with org-mode and emacs."
  (run-mode-hooks)
  :group 'org-static-blog)

;; Key bindings
(define-key org-static-blog-mode-map (kbd "C-c C-f") 'org-static-blog-open-next-post)
(define-key org-static-blog-mode-map (kbd "C-c C-b") 'org-static-blog-open-previous-post)
(define-key org-static-blog-mode-map (kbd "C-c C-p") 'org-static-blog-open-matching-publish-file)
(define-key org-static-blog-mode-map (kbd "C-c C-n") 'org-static-blog-create-new-post)
(define-key org-static-blog-mode-map (kbd "C-c C-d") 'org-static-blog-create-new-draft)

(provide 'org-static-blog)

;;; org-static-blog.el ends here
