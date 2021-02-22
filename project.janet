(import ./detect-clj-ns/vendor/path)

(declare-project
 :name "detect-clj-ns"
 :url "https://github.com/sogaiu/detect-clj-ns"
 :repo "git+https://github.com/sogaiu/detect-clj-ns.git")

(def proj-root
  (os/cwd))

(def proj-dir-name
  "detect-clj-ns")

(def src-root
  (path/join proj-root proj-dir-name))

(declare-source
 :source [src-root])

(declare-executable
 :name "detect-clj-ns"
 :entry (path/join src-root "detect-clj-ns.janet")
 # XXX: uncomment this and set the env var CC to musl-gcc to build statically
 #:cflags [;default-cflags "--static"]
 :install true)

