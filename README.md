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

## API summary

| Function | Description |
| --- | --- |
| `compile : string -> pattern` | Compile a glob pattern. |
| `matches : pattern -> string -> bool` | Match a compiled pattern (anchored). |
| `matchString : string -> string -> bool` | Compile + match in one step. |
| `caseInsensitive : string -> pattern` | Compile a case-insensitive pattern. |

## License

MIT. See [LICENSE](LICENSE).
