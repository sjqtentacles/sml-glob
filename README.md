# sml-glob

[![CI](https://github.com/sjqtentacles/sml-glob/actions/workflows/ci.yml/badge.svg)](https://github.com/sjqtentacles/sml-glob/actions/workflows/ci.yml)

Shell-style glob pattern matching for Standard ML.

`sml-glob` compiles a glob pattern once and matches it against whole strings
(matching is anchored, as with filename globbing). It is a pure backtracking
matcher with no regex dependency.

## Syntax

| Pattern | Matches |
| --- | --- |
| `*` | any run of characters, including empty |
| `?` | exactly one character |
| `[abc]` | one of the listed characters |
| `[a-z]` | one character in the range |
| `[!...]` / `[^...]` | one character *not* listed (negation) |
| `\c` | the literal character `c` (escape) |

## Portability

Pure Standard ML using only the Basis library -- no FFI, no threads. Verified
on **MLton** and **Poly/ML**.

## Building and testing

```sh
make test        # build + run the suite under MLton (default)
make test-poly   # run the suite under Poly/ML
make all-tests   # run under both
make clean
```

## Installing with smlpkg

```sh
smlpkg add github.com/sjqtentacles/sml-glob
smlpkg sync
```

Then reference the library basis from your own `.mlb`:

```
lib/github.com/sjqtentacles/sml-glob/glob.mlb
```

For Poly/ML, `use` the `glob.sig` and `glob.sml` sources in order.

## Usage

```sml
val ok  = Glob.matchString "*.sml" "foo.sml"     (* true  *)
val no  = Glob.matchString "*.sml" "foo.txt"     (* false *)
val c   = Glob.matchString "src/*.[ch]" "src/main.c"  (* true *)

(* compile once, match many *)
val p = Glob.compile "data_???"
val a = Glob.matches p "data_001"                (* true  *)
val b = Glob.matches p "data_1"                  (* false *)

(* case-insensitive *)
val ci = Glob.caseInsensitive "Hello*World"
val d = Glob.matches ci "HELLO, WORLD"           (* true *)
```

Escapes make special characters literal:

```sml
Glob.matchString "a\\*b" "a*b"     (* true:  the * is literal  *)
Glob.matchString "a\\*b" "axxb"    (* false: not a wildcard    *)
```

### Filtering lists

```sml
val p = Glob.compile "*.sml"
val srcs = Glob.filter p ["a.sml","b.txt","c.sml"]      (* ["a.sml","c.sml"] *)
val (yes, no) = Glob.partition p ["a.sml","b.txt"]      (* (["a.sml"], ["b.txt"]) *)
```

### Brace expansion

`expand` produces every literal alternative (the cartesian product across
groups, with nesting); `compileBrace` compiles each one to a pattern.

```sml
Glob.expand "{a,b}c"         (* ["ac","bc"] *)
Glob.expand "{a,b}{x,y}"     (* ["ax","ay","bx","by"] *)
Glob.expand "foo.{c,h}"      (* ["foo.c","foo.h"] *)
val ps = Glob.compileBrace "{a,b}.sml"   (* two patterns *)
```

### Path-aware matching

`matchPath` treats `/` as a separator: a single `*`/`?` will not cross it, and
`**` (globstar) matches across separators, including zero segments.

```sml
Glob.matchPath "src/*.sml"    "src/x.sml"      (* true  *)
Glob.matchPath "src/*.sml"    "src/sub/x.sml"  (* false: * stops at /  *)
Glob.matchPath "src/**/*.sml" "src/a/b/x.sml"  (* true  *)
Glob.matchPath "src/**/x.sml" "src/x.sml"      (* true: ** matches zero dirs *)
```

### Strict compilation & introspection

```sml
Glob.compileOpt "a[bc"          (* NONE: unterminated class *)
Glob.validate   "a[bc"          (* SOME "unterminated '[' character class" *)
Glob.isLiteral     (Glob.compile "abc")       (* true  *)
Glob.literalPrefix (Glob.compile "src/*.sml") (* "src/" — prune a dir walk *)
Glob.toRegexString (Glob.compile "a*b?.sml")  (* "^a.*b.\\.sml$" *)
```

## API summary

| Function | Description |
| --- | --- |
| `compile : string -> pattern` | Compile a glob pattern (lenient). |
| `compileOpt : string -> pattern option` | Strict compile; `NONE` on malformed. |
| `validate : string -> string option` | `SOME msg` on malformed, else `NONE`. |
| `matches : pattern -> string -> bool` | Match a compiled pattern (anchored). |
| `matchString : string -> string -> bool` | Compile + match in one step. |
| `matchPath : string -> string -> bool` | Path-aware match (`/`-respecting, `**`). |
| `caseInsensitive : string -> pattern` | Compile a case-insensitive pattern. |
| `filter : pattern -> string list -> string list` | Keep matching strings. |
| `partition : pattern -> string list -> string list * string list` | Split by match. |
| `expand : string -> string list` | Brace expansion to literal alternatives. |
| `compileBrace : string -> pattern list` | Compile each brace expansion. |
| `literalPrefix : pattern -> string` | Leading literal run before first wildcard. |
| `isLiteral : pattern -> bool` | True if the pattern has no wildcards. |
| `toRegexString : pattern -> string` | Anchored regex equivalent. |

## Example

`make example` builds and runs [`examples/demo.sml`](examples/demo.sml), which
compiles and matches globs, partitions a file list, expands brace patterns,
matches path-aware `**` patterns, and inspects a compiled pattern (output is
byte-identical under MLton and Poly/ML):

```
Glob demo
matches "notes.txt" = true
matches "notes.md"  = false
matchString "[Hh]ello" "Hello" = true
caseInsensitive *.TXT matches "a.txt" = true
partition *.txt over [a.txt,b.md,c.txt,readme]
  matching     = [a.txt,c.txt]
  non-matching = [b.md,readme]
expand "file{1,2,3}.txt" = [file1.txt,file2.txt,file3.txt]
compileBrace "a{x,y}b" pattern count = 2
matchPath "src/**/*.sml" "src/lib/a.sml" = true
matchPath "src/*.sml"    "src/lib/a.sml" = false
literalPrefix "foo/bar*.txt" = foo/bar
isLiteral "plain.txt"        = true
toRegexString "a?c"          = ^a.c$
compileOpt "[abc" (unterminated class) = NONE
validate "[abc"                          = Err unterminated '[' character class
```

## License

MIT. See [LICENSE](LICENSE).
