open Batteries

let raise_func = Value.Function (fun v -> raise @@ Interpreter.ExceptionRaised v)
let invalid_arg_func = Value.Function (fun s -> raise @@ Interpreter.ExceptionRaised (Value.Sumtype ("Invalid_argument", Some s)))
let failwith_func = Value.Function (fun s -> raise @@ Interpreter.ExceptionRaised (Value.Sumtype ("Failure", Some s)))

let wrap_function unwrap_val wrap_val op = Value.Function (wrap_val % op % unwrap_val)

let int_int_function op =
  let wrap i = Value.Int i in
  let unwrap = function
  | Value.Int i -> i
  | _ -> raise Value.TypeError in
  wrap_function unwrap wrap op

let int_binary_operator op =
  let outer = function
  | Value.Int i1 ->
    let inner = function
    | Value.Int i2 -> Value.Int (op i1 i2)
    | _ -> raise Value.TypeError in
    Value.Function inner
  | _ -> raise Value.TypeError in
  Value.Function outer

let float_binary_operator op =
  let outer = function
  | Value.Float f1 ->
    let inner = function
    | Value.Float f2 -> Value.Float (op f1 f2)
    | _ -> raise Value.TypeError in
    Value.Function inner
  | _ -> raise Value.TypeError in
  Value.Function outer

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

let equal =
  let outer v1 =
    let inner v2 = Value.Sumtype (string_of_bool @@ ValueUtils.value_eq v1 v2, None) in
    Value.Function inner in
  Value.Function outer

let not_equal =
  let outer v1 =
    let inner v2 = Value.Sumtype (string_of_bool @@ not @@ ValueUtils.value_eq v1 v2, None) in
    Value.Function inner in
  Value.Function outer

(*let int_int_function op =
  let inner = function
  | Value.Int i -> Value.Int (op i)
  | _ -> raise Value.TypeError in
  Value.Function inner*)

let float_float_function op =
  let inner = function
  | Value.Float f -> Value.Float (op f)
  | _ -> raise Value.TypeError in
  Value.Function inner

let initial_context = [
  ("raise", raise_func) ;
  ("raise_notrace", raise_func) ;
  ("invalid_arg", invalid_arg_func) ;
  ("failwith", failwith_func) ;

  ("=", equal) ;
  ("<>", not_equal) ;

  ("+", int_binary_operator ( + )) ;
  ("-", int_binary_operator ( - )) ;
  ("*", int_binary_operator ( * )) ;
  ("/", int_binary_operator ( / )) ;
  ("mod", int_binary_operator ( mod ));

  ("abs", int_int_function abs) ;
  ("succ", int_int_function succ) ;
  ("pred", int_int_function pred) ;
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

  ("&&", bool_binary_operator ( && )) ;
  ("||", bool_binary_operator ( || ))
]

let populate state =
  let func ctx (name, value) =
    let idx = State.add state (State.Normal value) in
    Context.add name idx ctx in
  let map = Context.to_map @@ BatList.fold_left func Context.empty initial_context in
  let idx = State.add state (State.Normal (Value.Module map)) in
  let ctx = Context.add "Pervasives" idx Context.empty in
  Context.open_module map ctx
