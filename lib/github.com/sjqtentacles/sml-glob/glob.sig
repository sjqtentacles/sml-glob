(* glob.sig

   Shell-style glob pattern matching for Standard ML.

   A glob pattern is compiled once into an abstract `pattern`, then matched
   against whole strings (matching is anchored: the entire string must match,
   as with filename globbing). Supported syntax:

     *        matches any run of characters, including the empty run
     ?        matches exactly one character
     [abc]    a character class: matches any one of a, b, c
     [a-z]    a range inside a class
     [!...]   a negated class (also [^...]); matches one char NOT listed
     \c       an escape: matches the literal character c (so \* matches '*')

   Inside a class, a leading `]` or `!`/`^` and `-` at the ends are treated as
   literals in the usual shell way. Any other character matches itself. *)

signature GLOB =
sig
  type pattern

  (* Compile a glob pattern. Always succeeds: a trailing backslash matches a
     literal backslash, and an unterminated `[` is treated as a literal `[`. *)
  val compile : string -> pattern

  (* Strict compilation: rejects malformed patterns (currently an unterminated
     character class). compileOpt returns NONE; validate returns an error
     message (SOME msg) or NONE if the pattern is well-formed. *)
  val compileOpt : string -> pattern option
  val validate   : string -> string option

  (* Does the pattern match the whole string? *)
  val matches : pattern -> string -> bool

  (* compile + match in one step. *)
  val matchString : string -> string -> bool

  (* Compile a pattern that matches case-insensitively. *)
  val caseInsensitive : string -> pattern

  (* Keep / split a list of strings by whether they match the pattern.
     partition returns (matching, non-matching), order preserved. *)
  val filter    : pattern -> string list -> string list
  val partition : pattern -> string list -> string list * string list

  (* Brace expansion. expand "{a,b}c" = ["ac","bc"]; nested braces and the
     cartesian product of multiple groups are supported. A string with no
     braces expands to itself. compileBrace compiles each expansion to a
     pattern (so a single brace pattern becomes several globs). *)
  val expand       : string -> string list
  val compileBrace : string -> pattern list

  (* Path-aware matching: '/' is a path separator that a single '*' or '?' will
     NOT cross, and '**' matches across separators (any number of segments,
     including zero). matchPath compiles and matches in one step. *)
  val matchPath : string -> string -> bool

  (* Introspection. literalPrefix returns the leading run of literal characters
     before the first wildcard (useful to prune a directory walk). isLiteral is
     true when the pattern has no wildcards at all. toRegexString renders an
     anchored POSIX-ish regular expression equivalent to the glob. *)
  val literalPrefix : pattern -> string
  val isLiteral     : pattern -> bool
  val toRegexString : pattern -> string
end
