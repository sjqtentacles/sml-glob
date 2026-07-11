(* demo.sml - shell-style glob compilation and matching: wildcards, classes,
   case-insensitive matching, brace expansion, path-aware "**", and
   introspection. Deterministic: identical output on every run and both
   compilers. *)

structure G = Glob

val () = print "Glob demo\n"

val p = G.compile "*.txt"
val () = print ("matches \"notes.txt\" = " ^ Bool.toString (G.matches p "notes.txt") ^ "\n")
val () = print ("matches \"notes.md\"  = " ^ Bool.toString (G.matches p "notes.md") ^ "\n")

val () = print ("matchString \"[Hh]ello\" \"Hello\" = "
                ^ Bool.toString (G.matchString "[Hh]ello" "Hello") ^ "\n")

val ci = G.caseInsensitive "*.TXT"
val () = print ("caseInsensitive *.TXT matches \"a.txt\" = " ^ Bool.toString (G.matches ci "a.txt") ^ "\n")

val files = ["a.txt", "b.md", "c.txt", "readme"]
val (matching, rest) = G.partition p files
val () = print ("partition *.txt over [" ^ String.concatWith "," files ^ "]\n")
val () = print ("  matching     = [" ^ String.concatWith "," matching ^ "]\n")
val () = print ("  non-matching = [" ^ String.concatWith "," rest ^ "]\n")

val () = print ("expand \"file{1,2,3}.txt\" = ["
                ^ String.concatWith "," (G.expand "file{1,2,3}.txt") ^ "]\n")
val () = print ("compileBrace \"a{x,y}b\" pattern count = "
                ^ Int.toString (List.length (G.compileBrace "a{x,y}b")) ^ "\n")

val () = print ("matchPath \"src/**/*.sml\" \"src/lib/a.sml\" = "
                ^ Bool.toString (G.matchPath "src/**/*.sml" "src/lib/a.sml") ^ "\n")
val () = print ("matchPath \"src/*.sml\"    \"src/lib/a.sml\" = "
                ^ Bool.toString (G.matchPath "src/*.sml" "src/lib/a.sml") ^ "\n")

val () = print ("literalPrefix \"foo/bar*.txt\" = " ^ G.literalPrefix (G.compile "foo/bar*.txt") ^ "\n")
val () = print ("isLiteral \"plain.txt\"        = " ^ Bool.toString (G.isLiteral (G.compile "plain.txt")) ^ "\n")
val () = print ("toRegexString \"a?c\"          = " ^ G.toRegexString (G.compile "a?c") ^ "\n")

val () = print ("compileOpt \"[abc\" (unterminated class) = "
                ^ (case G.compileOpt "[abc" of NONE => "NONE" | SOME _ => "SOME") ^ "\n")
val () = print ("validate \"[abc\"                          = "
                ^ (case G.validate "[abc" of NONE => "ok" | SOME msg => "Err " ^ msg) ^ "\n")
