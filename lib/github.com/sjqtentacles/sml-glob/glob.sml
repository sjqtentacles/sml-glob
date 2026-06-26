(* glob.sml

   Implementation of GLOB.

   A pattern compiles to a list of tokens. Matching walks the token list and
   the input characters together; `Star` is handled by backtracking (try to
   match the rest of the pattern at each suffix), which is simple and correct.
   To avoid exponential blow-up on patterns with many stars, consecutive stars
   collapse during compilation and `Star` matching advances greedily with
   backtracking only as needed.

   Matching is anchored: the whole string must be consumed. *)

structure Glob :> GLOB =
struct
  (* A class item is a single char or an inclusive range. *)
  datatype classItem = One of char | Range of char * char

  datatype token =
      Lit of char
    | AnyChar            (* ? *)
    | Star               (* * *)
    | Class of bool * classItem list   (* negated?, items *)

  (* fold-case for case-insensitive matching *)
  type pattern = { toks : token list, fold : char -> char }

  fun idChar c = c
  fun lowerChar c = Char.toLower c

  (* ---- compilation ---- *)

  fun compileWith fold s =
      let
        val n = String.size s
        fun peek i = if i < n then SOME (String.sub (s, i)) else NONE

        (* parse a [...] class starting just after the '['. Returns
           (token, nextIndex) or, if malformed/unterminated, treats '[' as a
           literal: (Lit #"[", startIndex). *)
        fun parseClass start =
            let
              (* a leading ! or ^ negates *)
              val (neg, i0) =
                  case peek start of
                      SOME #"!" => (true, start + 1)
                    | SOME #"^" => (true, start + 1)
                    | _ => (false, start)
              (* a ']' immediately after the (optional) negation is a literal *)
              fun loop (i, acc) =
                  case peek i of
                      NONE => NONE   (* unterminated *)
                    | SOME #"]" =>
                        if i = i0 then
                          (* literal ']' as first class member *)
                          loop2 (i + 1, One #"]" :: acc)
                        else SOME (List.rev acc, i + 1)
                    | SOME _ => loop2 (i, acc)
              and loop2 (i, acc) =
                  (* parse one class item (char or range) at i *)
                  case peek i of
                      NONE => NONE
                    | SOME c =>
                        (* range? c '-' d  where d is not ']' *)
                        (case (peek (i + 1), peek (i + 2)) of
                             (SOME #"-", SOME d) =>
                               if d <> #"]" then
                                 loop (i + 3, Range (c, d) :: acc)
                               else loop (i + 1, One c :: acc)
                           | _ => loop (i + 1, One c :: acc))
            in
              case loop (i0, []) of
                  SOME (items, next) => (Class (neg, items), next)
                | NONE => (Lit #"[", start)  (* unterminated: literal '[' *)
            end

        fun go i acc =
            case peek i of
                NONE => List.rev acc
              | SOME #"*" =>
                  (* collapse consecutive stars *)
                  (case acc of
                       Star :: _ => go (i + 1) acc
                     | _ => go (i + 1) (Star :: acc))
              | SOME #"?" => go (i + 1) (AnyChar :: acc)
              | SOME #"\\" =>
                  (case peek (i + 1) of
                       SOME c => go (i + 2) (Lit c :: acc)
                     | NONE => go (i + 1) (Lit #"\\" :: acc))
              | SOME #"[" =>
                  let val (tok, next) = parseClass (i + 1)
                  in go next (tok :: acc) end
              | SOME c => go (i + 1) (Lit c :: acc)
      in
        { toks = go 0 [], fold = fold }
      end

  fun compile s = compileWith idChar s
  fun caseInsensitive s = compileWith lowerChar s

  (* ---- matching ---- *)

  fun classMatch fold (neg, items) c =
      let
        val c' = fold c
        fun itemHit (One x) = fold x = c'
          | itemHit (Range (lo, hi)) =
              let val l = fold lo and h = fold hi
              in l <= c' andalso c' <= h end
        val hit = List.exists itemHit items
      in
        if neg then not hit else hit
      end

  (* cs is the remaining input as a char list *)
  fun matchToks fold toks cs =
      case (toks, cs) of
          ([], []) => true
        | ([], _ :: _) => false
        | (Star :: ts, _) =>
            (* match rest here, or consume one char and retry *)
            matchToks fold ts cs
            orelse (case cs of [] => false | _ :: rest => matchToks fold (Star :: ts) rest)
        | (_ :: _, []) =>
            (* only an all-stars remainder can match the empty input *)
            List.all (fn Star => true | _ => false) toks
        | (Lit x :: ts, c :: rest) =>
            fold x = fold c andalso matchToks fold ts rest
        | (AnyChar :: ts, _ :: rest) => matchToks fold ts rest
        | (Class cl :: ts, c :: rest) =>
            classMatch fold cl c andalso matchToks fold ts rest

  fun matches ({ toks, fold } : pattern) s =
      matchToks fold toks (String.explode s)

  fun matchString pat s = matches (compile pat) s

  (* ---- strict compilation ---- *)

  (* Scan for the first structural error. Currently the only malformed case is
     an unterminated character class. Returns SOME message on error. *)
  fun scanError s =
      let
        val n = String.size s
        fun peek i = if i < n then SOME (String.sub (s, i)) else NONE
        (* Returns next index after a class, or raises Fail on unterminated. *)
        fun classEnd start =
            let
              val i0 = case peek start of
                           SOME #"!" => start + 1
                         | SOME #"^" => start + 1
                         | _ => start
              fun loop i =
                  case peek i of
                      NONE => raise Fail "unterminated '[' character class"
                    | SOME #"]" => if i = i0 then loop (i + 1) else i + 1
                    | SOME #"\\" => loop (i + 2)
                    | SOME _ => loop (i + 1)
            in loop i0 end
        fun go i =
            case peek i of
                NONE => NONE
              | SOME #"\\" => (case peek (i + 1) of SOME _ => go (i + 2) | NONE => go (i + 1))
              | SOME #"[" => go (classEnd (i + 1))
              | SOME _ => go (i + 1)
      in
        go 0 handle Fail m => SOME m
      end

  fun validate s = scanError s

  fun compileOpt s =
      case scanError s of NONE => SOME (compile s) | SOME _ => NONE

  (* ---- list helpers ---- *)

  fun filter pat xs = List.filter (matches pat) xs

  fun partition pat xs = List.partition (matches pat) xs

  (* ---- brace expansion ---- *)

  (* Split the top-level comma-separated alternatives inside a brace group,
     respecting nesting. Returns the list of alternative strings. *)
  fun expand s =
      let
        val cs = String.explode s
        (* find a top-level '{' ... '}' group; expand it, recurse. *)
        fun findOpen (i, []) = NONE
          | findOpen (i, #"\\" :: _ :: rest) = findOpen (i + 2, rest)  (* skip escape *)
          | findOpen (i, #"{" :: _) = SOME i
          | findOpen (i, _ :: rest) = findOpen (i + 1, rest)
      in
        case findOpen (0, cs) of
            NONE => [s]
          | SOME openIdx =>
              let
                val n = String.size s
                (* scan from openIdx+1 collecting alternatives and tracking depth *)
                fun scan (i, depth, curStart, alts) =
                    if i >= n then (i, List.rev alts)  (* unterminated: handled below *)
                    else
                      let val c = String.sub (s, i) in
                        case c of
                            #"\\" => scan (i + 2, depth, curStart, alts)
                          | #"{" => scan (i + 1, depth + 1, curStart, alts)
                          | #"}" =>
                              if depth = 0
                              then (i, List.rev (String.substring (s, curStart, i - curStart) :: alts))
                              else scan (i + 1, depth - 1, curStart, alts)
                          | #"," =>
                              if depth = 0
                              then scan (i + 1, depth, i + 1,
                                         String.substring (s, curStart, i - curStart) :: alts)
                              else scan (i + 1, depth, curStart, alts)
                          | _ => scan (i + 1, depth, curStart, alts)
                      end
                val (closeIdx, alts) = scan (openIdx + 1, 0, openIdx + 1, [])
              in
                if closeIdx >= n then [s]  (* no closing brace: treat literally *)
                else
                  let
                    val prefix = String.substring (s, 0, openIdx)
                    val suffix = String.extract (s, closeIdx + 1, NONE)
                    (* each alternative may itself contain braces; recurse *)
                    val pieces =
                      List.concat
                        (List.map (fn alt => expand (prefix ^ alt ^ suffix)) alts)
                  in
                    pieces
                  end
              end
      end

  fun compileBrace s = List.map compile (expand s)

  (* ---- path-aware matching ---- *)

  (* Tokens for path matching: '/' is a literal separator; '**' is a globstar
     crossing separators; '*'/'?' do not cross '/'. We reuse the existing token
     parse but add a Sep and DoubleStar. *)
  datatype ptok =
      PLit of char
    | PAny               (* ? : one non-separator char *)
    | PStar              (* * : run of non-separator chars *)
    | PSep               (* / *)
    | PDouble            (* ** : any, crossing separators *)
    | PClass of bool * classItem list

  fun parsePath s =
      let
        val n = String.size s
        fun peek i = if i < n then SOME (String.sub (s, i)) else NONE
        fun parseClass start =
            let
              val (neg, i0) = case peek start of
                                  SOME #"!" => (true, start + 1)
                                | SOME #"^" => (true, start + 1)
                                | _ => (false, start)
              fun loop (i, acc) =
                  case peek i of
                      NONE => NONE
                    | SOME #"]" => if i = i0 then loop2 (i + 1, One #"]" :: acc)
                                   else SOME (List.rev acc, i + 1)
                    | SOME _ => loop2 (i, acc)
              and loop2 (i, acc) =
                  case peek i of
                      NONE => NONE
                    | SOME c =>
                        (case (peek (i + 1), peek (i + 2)) of
                             (SOME #"-", SOME d) =>
                               if d <> #"]" then loop (i + 3, Range (c, d) :: acc)
                               else loop (i + 1, One c :: acc)
                           | _ => loop (i + 1, One c :: acc))
            in
              case loop (i0, []) of
                  SOME (items, next) => (PClass (neg, items), next)
                | NONE => (PLit #"[", start)
            end
        fun go i acc =
            case peek i of
                NONE => List.rev acc
              | SOME #"*" =>
                  (case peek (i + 1) of
                       SOME #"*" => go (i + 2) (PDouble :: acc)
                     | _ => go (i + 1) (PStar :: acc))
              | SOME #"?" => go (i + 1) (PAny :: acc)
              | SOME #"/" => go (i + 1) (PSep :: acc)
              | SOME #"\\" => (case peek (i + 1) of
                                   SOME c => go (i + 2) (PLit c :: acc)
                                 | NONE => go (i + 1) (PLit #"\\" :: acc))
              | SOME #"[" => let val (tok, next) = parseClass (i + 1)
                             in go next (tok :: acc) end
              | SOME c => go (i + 1) (PLit c :: acc)
      in go 0 [] end

  fun matchPathToks toks cs =
      case (toks, cs) of
          ([], []) => true
        | ([], _ :: _) => false
        | (PDouble :: PSep :: ts, _) =>
            (* "**/" matches zero or more leading path segments *)
            matchPathToks ts cs
            orelse matchPathToks (PDouble :: ts) cs
            orelse (case cs of [] => false | _ :: rest => matchPathToks (PDouble :: PSep :: ts) rest)
        | (PDouble :: ts, _) =>
            matchPathToks ts cs
            orelse (case cs of [] => false | _ :: rest => matchPathToks (PDouble :: ts) rest)
        | (PStar :: ts, _) =>
            matchPathToks ts cs
            orelse (case cs of
                        [] => false
                      | c :: rest => if c = #"/" then false
                                     else matchPathToks (PStar :: ts) rest)
        | (_ :: _, []) =>
            List.all (fn PDouble => true | PStar => true | _ => false) toks
        | (PLit x :: ts, c :: rest) => x = c andalso matchPathToks ts rest
        | (PSep :: ts, c :: rest) => c = #"/" andalso matchPathToks ts rest
        | (PAny :: ts, c :: rest) => c <> #"/" andalso matchPathToks ts rest
        | (PClass cl :: ts, c :: rest) =>
            c <> #"/" andalso classMatch idChar cl c andalso matchPathToks ts rest

  fun matchPath pat s = matchPathToks (parsePath pat) (String.explode s)

  (* ---- introspection ---- *)

  fun isLiteral ({ toks, ... } : pattern) =
      List.all (fn Lit _ => true | _ => false) toks

  fun literalPrefix ({ toks, ... } : pattern) =
      let
        fun go (Lit c :: rest) acc = go rest (c :: acc)
          | go _ acc = String.implode (List.rev acc)
      in go toks [] end

  fun toRegexString ({ toks, ... } : pattern) =
      let
        fun escRe c =
            if Char.contains ".^$*+?()[]{}|\\" c
            then "\\" ^ String.str c
            else String.str c
        fun classItemStr (One c) = escClassChar c
          | classItemStr (Range (lo, hi)) = escClassChar lo ^ "-" ^ escClassChar hi
        and escClassChar c =
            if Char.contains "]\\^-" c then "\\" ^ String.str c else String.str c
        fun tokStr (Lit c) = escRe c
          | tokStr AnyChar = "."
          | tokStr Star = ".*"
          | tokStr (Class (neg, items)) =
              "[" ^ (if neg then "^" else "")
              ^ String.concat (List.map classItemStr items) ^ "]"
      in
        "^" ^ String.concat (List.map tokStr toks) ^ "$"
      end
end
