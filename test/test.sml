(* Dependency-free test runner for the Glob structure.
 * Prints one line per assertion and exits non-zero if any assertion fails. *)

val passed = ref 0
val failed = ref 0

fun check (name : string) (cond : bool) : unit =
    if cond
    then (passed := !passed + 1; print ("ok   - " ^ name ^ "\n"))
    else (failed := !failed + 1; print ("FAIL - " ^ name ^ "\n"))

structure G = Glob

(* m pat s = does pat match s *)
val m = G.matchString

fun run () =
  let
    (* ---- literals ---- *)
    val () = check "literal exact" (m "abc" "abc")
    val () = check "literal no match" (not (m "abc" "abd"))
    val () = check "literal anchored (no suffix)" (not (m "abc" "abcd"))
    val () = check "literal anchored (no prefix)" (not (m "abc" "xabc"))
    val () = check "empty matches empty" (m "" "")
    val () = check "empty no match nonempty" (not (m "" "a"))

    (* ---- ? ---- *)
    val () = check "? one char" (m "a?c" "abc")
    val () = check "? any one char" (m "a?c" "axc")
    val () = check "? requires a char" (not (m "a?c" "ac"))
    val () = check "? not two chars" (not (m "a?c" "axxc"))
    val () = check "??? three" (m "???" "xyz")

    (* ---- * ---- *)
    val () = check "* matches all" (m "*" "anything at all")
    val () = check "* matches empty" (m "*" "")
    val () = check "prefix*" (m "abc*" "abcdef")
    val () = check "prefix* matches exact" (m "abc*" "abc")
    val () = check "*suffix" (m "*.sml" "foo.sml")
    val () = check "*suffix no match" (not (m "*.sml" "foo.txt"))
    val () = check "*mid*" (m "*test*" "my test case")
    val () = check "a*b*c" (m "a*b*c" "axxbyyc")
    val () = check "a*b*c no final c" (not (m "a*b*c" "axxbyy"))

    (* ---- pathological * runs (collapse / backtracking) ---- *)
    val () = check "many stars match" (m "a*a*a*b" "aaaaab")
    val () = check "many stars no match" (not (m "a*a*a*b" "aaaaa"))
    val () = check "**** collapses" (m "a****b" "aXYZb")
    val () = check "star-heavy long input"
                   (m "*a*a*a*a*a*" "xxaxxaxxaxxaxxaxx")

    (* ---- character classes ---- *)
    val () = check "class member" (m "[abc]" "b")
    val () = check "class non-member" (not (m "[abc]" "d"))
    val () = check "class in context" (m "f[aeiou]o" "foo")
    val () = check "range a-z" (m "[a-z]" "m")
    val () = check "range a-z reject" (not (m "[a-z]" "M"))
    val () = check "range 0-9" (m "file[0-9].txt" "file7.txt")
    val () = check "range 0-9 reject" (not (m "file[0-9].txt" "fileX.txt"))
    val () = check "multi-range [a-zA-Z]" (m "[a-zA-Z]" "Q")

    (* ---- negated classes ---- *)
    val () = check "negated [!abc] match" (m "[!abc]" "d")
    val () = check "negated [!abc] reject" (not (m "[!abc]" "a"))
    val () = check "negated [^abc] match" (m "[^abc]" "z")
    val () = check "negated range [!0-9]" (m "[!0-9]" "a")
    val () = check "negated range [!0-9] reject" (not (m "[!0-9]" "5"))

    (* ---- escapes ---- *)
    val () = check "escaped star literal" (m "a\\*b" "a*b")
    val () = check "escaped star not wildcard" (not (m "a\\*b" "axxb"))
    val () = check "escaped question literal" (m "a\\?b" "a?b")
    val () = check "escaped bracket literal" (m "\\[x\\]" "[x]")
    val () = check "escaped backslash" (m "a\\\\b" "a\\b")

    (* ---- combined ---- *)
    val () = check "complex pattern"
                   (m "src/*.[ch]" "src/main.c")
    val () = check "complex pattern h" (m "src/*.[ch]" "src/util.h")
    val () = check "complex pattern reject" (not (m "src/*.[ch]" "src/main.cpp"))
    val () = check "leading and trailing star" (m "*foo*" "afoob")

    (* ---- case-insensitive ---- *)
    val ci = G.caseInsensitive "Hello*World"
    val () = check "ci match exact case" (G.matches ci "Hello, World")
    val () = check "ci match different case" (G.matches ci "HELLO, WORLD")
    val () = check "ci match lower" (G.matches ci "hello, world")
    val () = check "ci class case-insensitive"
                   (G.matches (G.caseInsensitive "[a-z]") "M")
    val () = check "case-sensitive rejects different case" (not (m "abc" "ABC"))

    (* ---- a consistency batch ---- *)
    val cases =
        [ ("*.txt",      "readme.txt", true)
        , ("*.txt",      "readme.md",  false)
        , ("data_???",   "data_001",   true)
        , ("data_???",   "data_1",     false)
        , ("[A-Z]*",     "Hello",      true)
        , ("[A-Z]*",     "hello",      false)
        , ("a?c*z",      "abcxyz",     true)
        , ("",           "",           true)
        ]
    val allOk = List.all (fn (p, s, e) => m p s = e) cases
    val () = check "all consistency cases" allOk
  in
    print ("\n" ^ Int.toString (!passed) ^ " passed, "
           ^ Int.toString (!failed) ^ " failed\n");
    OS.Process.exit (if !failed = 0 then OS.Process.success else OS.Process.failure)
  end

val () = run ()
