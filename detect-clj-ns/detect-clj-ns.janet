(import ./ast)

(defn main
  [& args]
  (try
    (do
      # XXX: stdin support?
      (assert (< 0 (length args))
              (string "Please specify a file path"))
      (let [file-path (in args 1)
            mode ((os/stat file-path) :mode)
            _ (assert (= mode :file)
                      (string "Not a file:" file-path))
            source (slurp file-path)]
      (print (ast/detect-ns source))))
    ([err]
     (print err))))
