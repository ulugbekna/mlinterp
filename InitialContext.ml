open Batteries

(** The raise function raises the exception given as argument. *)
let raise_func = Value.Function (fun v -> raise @@ Interpreter.ExceptionRaised v)

(** Function that raises an Invalid_argument exception. *)
let invalid_arg_func = Value.Function (fun s -> raise @@ Interpreter.ExceptionRaised (Value.Sumtype ("Invalid_argument", Some s)))

(** Function that raises a Failure exception. *)
let failwith_func = Value.Function (fun s -> raise @@ Interpreter.ExceptionRaised (Value.Sumtype ("Failure", Some s)))

(* The identity function that returns its argument. *)
let id x = x

(** A function that takes a function and returns the corresponding Value.Function. *)
let wrap_function unwrap_val wrap_val op = Value.Function (wrap_val % op % unwrap_val)

(** This function is the same as wrap_function but for functions that take two arguments. *)
let wrap_function2 unwrap1 unwrap2 wrap op =
  let inner v1 = wrap_function unwrap2 wrap (op v1) in
  let outer wv1 = inner (unwrap1 wv1) in
  Value.from_function outer

let int_int_function = wrap_function Value.to_int Value.from_int
let float_float_function = wrap_function Value.to_float Value.from_float

let int_binary_operator = wrap_function2 Value.to_int Value.to_int Value.from_int
let float_binary_operator = wrap_function2 Value.to_float Value.to_float Value.from_float
let string_binary_operator = wrap_function2 Value.to_string Value.to_string Value.from_string

let value_not v =
  if ValueUtils.value_eq v Value.true_val then
    Value.false_val
  else if ValueUtils.value_eq v Value.false_val then
    Value.true_val
  else
    raise Value.TypeError

let bool_binary_operator op =
  let bool_of_string = function
  | "true" -> true
  | "false" -> false
  | _ -> false in

  let string_of_bool = function
  | true -> "true"
  | false -> "false" in

  let outer = function
  | Value.Sumtype ("true" as b1s, None)
  | Value.Sumtype ("false" as b1s, None) ->
    let inner = function
    | Value.Sumtype ("true" as b2s, None)
    | Value.Sumtype ("false" as b2s, None) ->
      let b1 = bool_of_string b1s in
      let b2 = bool_of_string b2s in
      Value.Sumtype (string_of_bool @@ op b1 b2, None)
    | _ -> raise Value.TypeError in
    Value.Function inner
  | _ -> raise Value.TypeError in
  Value.Function outer

let equal = wrap_function2 id id Value.from_bool ValueUtils.value_eq
let not_equal = wrap_function2 id id Value.from_bool (fun a b -> not @@ ValueUtils.value_eq a b)
let lesser_than = wrap_function2 id id Value.from_bool ValueUtils.value_lt
let lesser_or_equal = wrap_function2 id id Value.from_bool (fun a b -> ValueUtils.value_eq a b || ValueUtils.value_lt a b)
let greater_than = wrap_function2 id id Value.from_bool (fun a b -> not (ValueUtils.value_eq a b || ValueUtils.value_lt a b))
let greater_or_equal = wrap_function2 id id Value.from_bool (fun a b -> not @@ ValueUtils.value_lt a b)

let min =
  let aux a b = match (a, b) with
  | (Value.Int i1, Value.Int i2) -> Value.Int (Pervasives.min i1 i2)
  | (Value.Float f1, Value.Float f2) -> Value.Float (Pervasives.min f1 f2)
  | (Value.Char c1, Value.Char c2) -> Value.Char (Pervasives.min c1 c2)
  | _ -> raise Value.TypeError in
  wrap_function2 id id id aux

let max =
  let aux a b = match (a, b) with
  | (Value.Int i1, Value.Int i2) -> Value.Int (Pervasives.max i1 i2)
  | (Value.Float f1, Value.Float f2) -> Value.Float (Pervasives.max f1 f2)
  | (Value.Char c1, Value.Char c2) -> Value.Char (Pervasives.max c1 c2)
  | _ -> raise Value.TypeError in
  wrap_function2 id id id aux

let compare =
  let aux a b = match (a, b) with
  | (Value.Int i1, Value.Int i2) -> Value.Int (Pervasives.compare i1 i2)
  | (Value.Float f1, Value.Float f2) -> Value.Int (Pervasives.compare f1 f2)
  | (Value.Char c1, Value.Char c2) -> Value.Int (Pervasives.compare c1 c2)
  | _ -> raise Value.TypeError in
  wrap_function2 id id id aux

let ignore_func = Value.Function (fun _ -> Value.nil)

let rec concat va vb =
  let empty = Value.Sumtype ("[]", None) in
  let cons t = Value.Sumtype ("::", Some (Value.Tuple t)) in
  let cons_do lst f = match lst with
  | Value.Sumtype ("::", Some (Value.Tuple l)) -> f l
  | _ -> raise Value.TypeError in

  let aux l1 l2 =
    match l1 with
    | x :: [xs] when xs = empty -> cons (x :: [vb])
    | x :: [xs] ->
      let cc = concat xs vb in
      cons_do cc (fun _ -> cons (x :: [cc]))
    | _ -> raise Value.TypeError in
      
  match va with
  | t when t = empty -> vb
  | _ -> cons_do va (fun l1 ->
    match vb with
    | t when t = empty -> va
    | _ -> cons_do vb (aux l1))

let initial_context = [
  ("raise", raise_func) ;
  ("raise_notrace", raise_func) ;
  ("invalid_arg", invalid_arg_func) ;
  ("failwith", failwith_func) ;

  ("not", Value.from_function value_not) ;
  ("=", equal) ;
  ("<>", not_equal) ;
  ("<", lesser_than) ;
  ("<=", lesser_or_equal) ;
  (">", greater_than) ;
  (">=", greater_or_equal) ;
  ("compare", compare) ;
  ("min", min) ;
  ("max", max) ;
  
  ("|>", wrap_function2 id Value.to_function id ( |> )) ;
  ("@@", wrap_function2 Value.to_function id id ( @@ )) ;

  ("+", int_binary_operator ( + )) ;
  ("-", int_binary_operator ( - )) ;
  ("*", int_binary_operator ( * )) ;
  ("/", int_binary_operator ( / )) ;
  ("mod", int_binary_operator ( mod ));

  ("abs", int_int_function abs) ;
  ("succ", int_int_function succ) ;
  ("pred", int_int_function pred) ;
  ("min_int", Value.Int Pervasives.min_int) ;
  ("max_int", Value.Int Pervasives.max_int) ;
  ("~-", int_int_function (~-)) ;
  ("~+", int_int_function (~-)) ;

  ("land", int_binary_operator (land)) ;
  ("lor", int_binary_operator (lor)) ;
  ("lxor", int_binary_operator (lxor)) ;
  ("lsl", int_binary_operator (lsl)) ;
  ("lsr", int_binary_operator (lsr)) ;
  ("asr", int_binary_operator (asr)) ;
  ("lnot", int_int_function lnot) ;

  ("+.", float_binary_operator ( +. )) ;
  ("-.", float_binary_operator ( -. )) ;
  ("*.", float_binary_operator ( *. )) ;
  ("/.", float_binary_operator ( /. )) ;
  ("**", float_binary_operator ( ** )) ;
  ("~-.", float_float_function (~-.)) ;
  ("~+.", float_float_function (~-.)) ;

  ("sqrt", float_float_function ( sqrt )) ;
  ("exp", float_float_function ( exp )) ;
  ("log", float_float_function ( log )) ;
  ("log10", float_float_function ( log10 )) ;
  ("expm1", float_float_function ( expm1 )) ;
  ("log1p", float_float_function ( log1p )) ;
  ("cos", float_float_function ( cos )) ;
  ("sin", float_float_function ( sin )) ;
  ("tan", float_float_function ( tan )) ;
  ("acos", float_float_function ( acos )) ;
  ("asin", float_float_function ( asin )) ;
  ("atan", float_float_function ( atan )) ;
  ("atan2", float_binary_operator ( atan2 )) ;
  ("cosh", float_float_function ( cosh )) ;
  ("sinh", float_float_function ( sinh )) ;
  ("tanh", float_float_function ( tanh )) ;
  ("ceil", float_float_function ( ceil )) ;
  ("floor", float_float_function ( floor )) ;
  ("abs_float", float_float_function ( abs_float )) ;
  ("hypot", float_binary_operator ( hypot )) ;
  ("copysign", float_binary_operator ( hypot )) ;
  ("mod_float", float_binary_operator ( mod_float )) ;
  ("ldexp", wrap_function2 Value.to_float Value.to_int Value.from_float ( ldexp )) ;
  ("float_of_int", wrap_function Value.to_int Value.from_float ( float_of_int )) ;
  ("truncate", wrap_function Value.to_float Value.from_int ( truncate )) ;
  ("int_of_float", wrap_function Value.to_float Value.from_int ( int_of_float )) ;
  ("infinity", Value.Float infinity) ;
  ("neg_infinity", Value.Float neg_infinity) ;
  ("nan", Value.Float nan) ;
  ("max_float", Value.Float max_float) ;
  ("min_float", Value.Float min_float) ;
  ("epsilon_float", Value.Float epsilon_float) ;

  ("&&", bool_binary_operator ( && )) ;
  ("||", bool_binary_operator ( || )) ;

  ("^", string_binary_operator ( ^ )) ;

  ("int_of_char", wrap_function Value.to_char Value.from_int int_of_char) ;
  ("char_of_int", wrap_function Value.to_int Value.from_char char_of_int) ;
  ("ignore", ignore_func) ;

  ("string_of_bool", wrap_function Value.to_bool Value.from_string string_of_bool) ;
  ("bool_of_string", wrap_function Value.to_string Value.from_bool bool_of_string) ;
  ("string_of_int", wrap_function Value.to_int Value.from_string string_of_int) ;
  ("int_of_string", wrap_function Value.to_string Value.from_int int_of_string) ;
  ("string_of_float", wrap_function Value.to_float Value.from_string string_of_float) ;
  ("float_of_string", wrap_function Value.to_string Value.from_float float_of_string) ;

  ("fst", wrap_function Value.to_tuple id List.hd) ;
  ("snd", wrap_function Value.to_tuple id (List.hd % List.tl) ) ;

  ("@", wrap_function2 id id id concat) ;

  ("stdin", Value.stdin_chan) ;
  ("stdout", Value.stdout_chan) ;
  ("stderr", Value.stderr_chan) ;

  ("open_out", wrap_function Value.to_string Value.from_output Pervasives.open_out) ;
  ("open_out_bin", wrap_function Value.to_string Value.from_output Pervasives.open_out_bin) ;
  ("flush", wrap_function Value.to_output Value.from_nil Pervasives.flush) ;
  ("flush_all", wrap_function Value.to_nil Value.from_nil Pervasives.flush_all) ;

  ("output_char", wrap_function2 Value.to_output Value.to_char Value.from_nil Pervasives.output_char) ;
  ("output_string", wrap_function2 Value.to_output Value.to_string Value.from_nil Pervasives.output_string) ;

  ("seek_out", wrap_function2 Value.to_output Value.to_int Value.from_nil Pervasives.seek_out) ;
  ("pos_out", wrap_function Value.to_output Value.from_int Pervasives.pos_out) ;
  ("out_channel_length", wrap_function Value.to_output Value.from_int Pervasives.out_channel_length) ;
  ("close_out", wrap_function Value.to_output Value.from_nil Pervasives.close_out) ;
  ("close_out_noerr", wrap_function Value.to_output Value.from_nil Pervasives.close_out_noerr) ;
  ("set_binary_node_out", wrap_function2 Value.to_output Value.to_bool Value.from_nil Pervasives.set_binary_mode_out) ;

  ("open_in", wrap_function Value.to_string Value.from_input Pervasives.open_in) ;
  ("open_in_bin", wrap_function Value.to_string Value.from_input Pervasives.open_in_bin) ;
  ("input_char", wrap_function Value.to_input Value.from_char Pervasives.input_char) ;

  ("seek_in", wrap_function2 Value.to_input Value.to_int Value.from_nil Pervasives.seek_in) ;
  ("pos_in", wrap_function Value.to_input Value.from_int Pervasives.pos_in) ;
  ("in_channel_length", wrap_function Value.to_input Value.from_int Pervasives.in_channel_length) ;
  ("close_in_noerr", wrap_function Value.to_input Value.from_nil Pervasives.close_in_noerr) ;
  ("set_binary_node_in", wrap_function2 Value.to_input Value.to_bool Value.from_nil Pervasives.set_binary_mode_in) ;
]

let populate state =
  let func ctx (name, value) =
    let idx = State.add state (State.Normal value) in
    Context.add name idx ctx in
  let map = Context.to_map @@ BatList.fold_left func Context.empty initial_context in
  let idx = State.add state (State.Normal (Value.Module map)) in
  let ctx = Context.add "Pervasives" idx Context.empty in
  Context.open_module map ctx
