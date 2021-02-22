# TODO:
#
# * credit pyrmont for tip on -?>
#
# * might be better if things like metadata-node? didn't just return true,
#   but rather the "ast" that was passed in

(import ./rewrite :as rw)

(defn forms
  [src]
  (-?>> (rw/ast src)
        (drop 1)))

(comment

  (forms "")
  # => '()

  (deep=
    #
    (forms
      ``
      ;; another form
      (+ 2 2)
      ``)
    #
    '((:comment ";; another form") (:whitespace "\n")
      (:list
        (:symbol "+") (:whitespace " ")
        (:number "2") (:whitespace " ")
        (:number "2")))
    ) # => true

  )

(defn first-form
  [src]
  (first (forms src)))

(comment

  (def some-src
    ``
    (def a 1)

    :b
    ``)

  (deep=
    #
    (first-form some-src)
    #
    '(:list
       (:symbol "def") (:whitespace " ")
       (:symbol "a") (:whitespace " ")
       (:number "1"))
    ) # => true

  )

(defn list-node?
  [ast]
  (-?> (first ast)
       (= :list)))

(comment

  (list-node? (first-form "(+ 1 1)"))
  # => true

  )

(defn whitespace?
  [ast]
  (-?> (first ast)
       (= :whitespace)))

(comment

  (whitespace? '(:whitespace "\n "))
  # => true

  )

(defn line-comment?
  [ast]
  (-?> (first ast)
       (= :comment)))

(comment

  (line-comment? '(:comment ";; hi there"))
  # => true

  )

(defn comment-symbol?
  [ast]
  (when-let [head-elt (first ast)]
    (when (= head-elt :symbol)
      (when-let [next-elt (in ast 1)]
        (= next-elt "comment")))))

(comment

  (comment-symbol? '(:symbol "comment"))
  # => true

  )

(defn comment-block?
  [ast]
  (when-let [head-elt (first ast)]
    (when (= head-elt :list)
      (comment-symbol? (in ast 1)))))

(comment

  (def a-comment-block
    '(:list (:symbol "comment")))

  (comment-block? a-comment-block)
  # => true

  (comment-block? '(:comment ";; => 2"))
  # => nil

  (def src-with-comment-and-def
    ``
    (comment

      (def b 2)

    )

    (def x 1)
    ``)

  (->> (rw/ast src-with-comment-and-def)
       (drop 1)
       (filter |(comment-block? $))
       length)
  # => 1

  )

(defn discard-with-form?
  [ast]
  (-?> (first ast)
       (= :discard)))

(comment

  (def src-with-discard
    "#_ {:a 1}")

  (deep=
    #
    (rw/ast src-with-discard)
    #
    '@[:code
       (:discard
         (:whitespace " ")
         (:map
           (:keyword ":a") (:whitespace " ")
           (:number "1")))]
    ) # => true

  (discard-with-form? (first-form src-with-discard))
  # => true

  (discard-with-form?
   '(:discard
     (:whitespace " ")
     (:map
      (:keyword ":a") (:whitespace " ")
      (:number "1"))))
  # => true

  )

# XXX: determine what else needs to be ignored
(defn list-head
  [ast]
  (assert (list-node? ast)
          (string "Not a list node: " ast))
  (->> (drop 1 ast)
       (drop-while (fn [node]
                     # XXX: other things to filter out?
                     (or (whitespace? node)
                         (line-comment? node)
                         (comment-block? node)
                         (discard-with-form? node))))
       first))

(comment

  (deep=
    #
    (first-form "(+ 1 1)")
    #
    '(:list
       (:symbol "+") (:whitespace " ")
       (:number "1") (:whitespace " ")
       (:number "1"))
    ) # => true

  (list-head (first-form "(+ 1 1)"))
  # => '(:symbol "+")

  (list-head (first-form "( + 1 1)"))
  # => '(:symbol "+")

  (list-head
    (first-form
      ``
      (;; hi
      + 1 1)
      ``))
  # => '(:symbol "+")

  (list-head
    (first-form
      ``
      ((comment :a)
      + 1 1)
      ``))
  # => '(:symbol "+")

  (list-head (first-form "(#_ - + 1 1)"))
  # => '(:symbol "+")

  )

(defn symbol-node?
  [ast]
  (-?> (first ast)
       (= :symbol)))

(comment

  (symbol-node? (first-form "hi"))
  # => true

  (symbol-node? (first-form ":hi"))
  # => false

  )

(defn symbol-name
  [ast]
  (assert (symbol-node? ast)
          (string "Not a symbol node: " ast))
  (in ast 1))

(comment

  (symbol-name (first-form "hi"))
  # => "hi"

  )

(defn ns-form?
  [ast]
  (when (and (list-node? ast)
             (symbol-node? (list-head ast))
             (= "ns" (symbol-name (list-head ast))))
    ast))

(comment

  (def src-with-just-ns
    "(ns fun-namespace.main)")

  (deep=
    #
    (first-form src-with-just-ns)
    #
    '(:list
       (:symbol "ns") (:whitespace " ")
       (:symbol "fun-namespace.main"))
    ) # => true

  (deep=
    #
    (ns-form? (first-form src-with-just-ns))
    #
    '(:list
       (:symbol "ns") (:whitespace " ")
       (:symbol "fun-namespace.main"))
    ) # => true

  (def src-with-ns
    ``
    ;; hi
    (ns my-ns.core)

    (defn a [] 1)

    (def b 2)
    ``)

  (deep=
    #
    (some ns-form? (forms src-with-ns))
    #
    '(:list
       (:symbol "ns") (:whitespace " ")
       (:symbol "my-ns.core"))
    ) # => true

  )

(defn in-ns-form?
  [ast]
  (when (and (list-node? ast)
             (symbol-node? (list-head ast))
             (= "in-ns" (symbol-name (list-head ast))))
    ast))

(comment

  (def in-ns-expr
    "(in-ns 'clojure.core)")

  (deep=
    #
    (first-form in-ns-expr)
    #
    '(:list
       (:symbol "in-ns") (:whitespace " ")
       (:quote
         (:symbol "clojure.core")))
    ) # => true

  (deep=
    #
    (in-ns-form? (first-form in-ns-expr))
    #
    '(:list
       (:symbol "in-ns") (:whitespace " ")
       (:quote
         (:symbol "clojure.core")))
    ) # => true

  )

(defn metadata-node?
  [ast]
  (-?> (first ast)
       (= :metadata)))

(comment

  (metadata-node? (first-form "^:a [:x]"))
  # => true

  (metadata-node? (first-form "^:a ^:b {:x 2}"))
  # => true

  (metadata-node? (first-form ":a"))
  # => false

  )

(defn metadata-entry-node?
  [ast]
  (-?> (first ast)
       (= :metadata-entry)))

(comment

  (metadata-entry-node? (in (first-form "^:a [:x]") 1))
  # => true

  (metadata-entry-node? (in (first-form "^:a ^:b {:x 2}") 1))
  # => true

  (metadata-entry-node? (first-form ":a"))
  # => false

  )

# XXX: likely not perfect
(defn metadatee
  [ast]
  (when (metadata-node? ast)
    (->> ast
         (drop-while (fn [node]
                       # XXX: probably missed some things
                       (or (not (indexed? node))
                           (whitespace? node)
                           (line-comment? node)
                           (discard-with-form? node)
                           (metadata-entry-node? node))))
         first)))

(comment

  (metadatee (first-form "^:a [:x]"))
  # => '(:vector (:keyword ":x"))

  (metadatee (first-form "^:a ^{:b 2} [:y]"))
  # => '(:vector (:keyword ":y"))

  )

(defn name-of-ns
  [ns-ast]
  (when (ns-form? ns-ast)
    (in (keep (fn [node]
                 (when (indexed? node)
                   (cond
                     (= (first node) :symbol)
                     (in node 1)
                     #
                     (= (first node) :metadata)
                     (in (metadatee node) 1)
                     #
                     :else
                     nil)))
              ns-ast)
         1)))

(comment

  (def some-src-with-ns
    ``
    ;; hi

    "random string"

    (ns your-ns.core)

    (defn x [] 8)

    (def c [])
    ``)

  (name-of-ns (some ns-form? (forms some-src-with-ns)))
  # => "your-ns.core"

  (def ns-with-meta
    ``
    (ns ^{:doc "some doc string"
          :author "some author"}
      tricky-ns.here)``)

  (name-of-ns (some ns-form? (forms ns-with-meta)))
  # => "tricky-ns.here"

  )


# XXX: quick and dirty
(defn name-of-in-ns
  [in-ns-ast]
  (when (in-ns-form? in-ns-ast)
    (when-let [quote-form
               (first (filter (fn [node]
                                (when (indexed? node)
                                  (= (first node) :quote)))
                              in-ns-ast))]
      (in (in quote-form 1) 1))))

(comment

  (name-of-in-ns (first-form "(in-ns 'hello.person)"))
  # => "hello.person"

  )

(defn detect-ns
  [source]
  (let [source-forms (forms source)]
    (if-let [name-try
             (->> source-forms
                  (some ns-form?)
                  name-of-ns)]
      name-try
      (if-let [name-try-2
               (->> source-forms
                    (some in-ns-form?)
                    name-of-in-ns)]
        name-try-2
        nil))))

(comment

  (def sample-src-with-ns
    ``
    ;; nice comment
    ;; another nice comment

    #_ putting-a-symbol-here-should-be-fin

    (ns target-ns.main)

    (comment

      ;; hey mate

    )

    (defn repl
      []
      :fun)

    ``)

  (detect-ns sample-src-with-ns)
  # => "target-ns.main"

  (def src-with-ns-in-meta-node
    ``
    (ns ^{:doc "some doc string"
          :author "some author"}
        funname.here
        (:refer-clojure :exclude (replace remove next)))``)

  (deep=
    #
    (forms src-with-ns-in-meta-node)
    #
    '((:list
        (:symbol "ns") (:whitespace " ")
        (:metadata
          (:metadata-entry
            (:map
              (:keyword ":doc") (:whitespace " ")
              (:string "\"some doc string\"") (:whitespace "\n      ")
              (:keyword ":author") (:whitespace " ")
              (:string "\"some author\""))) (:whitespace "\n    ")
          (:symbol "funname.here"))
        (:whitespace "\n    ")
        (:list
          (:keyword ":refer-clojure") (:whitespace " ")
          (:keyword ":exclude") (:whitespace " ")
          (:list (:symbol "replace") (:whitespace " ")
                 (:symbol "remove") (:whitespace " ")
                 (:symbol "next")))))
    ) # => true

  (detect-ns src-with-ns-in-meta-node)
  # => "funname.here"

  (def src-with-in-ns
    "(in-ns 'clojure.core)")

  (detect-ns src-with-in-ns)
  # => "clojure.core"

  )

(comment

  (import ./vendor/path)

  (let [source
        (slurp (path/join (os/getenv "HOME")
                 "src/alc.detect-ns/src/alc/detect_ns/main.clj"))]
    (detect-ns source))

  (let [source
        (slurp (path/join (os/getenv "HOME")
                 "src/clojure/src/clj/clojure/core.clj"))]
    (detect-ns source))

  # for i in `find . | grep clj`; do echo $i; detect-clj-ns $i; echo; done

  )
