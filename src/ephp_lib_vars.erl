-module(ephp_lib_vars).

-author('manuel@altenwald.com').

-behaviour(ephp_lib).

-export([init_func/0, init_config/0, init_const/0, php_is_array/3, php_is_bool/3,
         php_is_integer/3, php_is_float/3, php_is_numeric/3, php_is_null/3, php_is_object/3,
         php_is_string/3, php_is_resource/3, print_r/3, print_r/4, var_dump/3, isset/3, empty/3,
         gettype/3, unset/3]).

-include("ephp.hrl").
-include("ephp_array.hrl").

-define(SPACES, "    ").
-define(SPACES_VD, "  ").

-spec init_func() -> ephp_lib:php_function_results().
init_func() ->
    [{php_is_array, [{alias, <<"is_array">>}]},
     {php_is_bool, [{alias, <<"is_bool">>}]},
     {php_is_integer, [{alias, <<"is_long">>}]},
     {php_is_integer, [{alias, <<"is_int">>}]},
     {php_is_integer, [{alias, <<"is_integer">>}]},
     {php_is_float, [{alias, <<"is_float">>}]},
     {php_is_float, [{alias, <<"is_double">>}]},
     {php_is_numeric, [{alias, <<"is_numeric">>}]},
     {php_is_null, [{alias, <<"is_null">>}]},
     {php_is_object, [{alias, <<"is_object">>}]},
     {php_is_string, [{alias, <<"is_string">>}]},
     {php_is_resource, [{alias, <<"is_resource">>}]},
     print_r,
     {isset, [{args, [raw]}]},
     {empty, [{args, [raw]}]},
     gettype,
     {unset, [{args, [raw]}]},
     {var_dump, [pack_args]}].

-spec init_config() -> ephp_lib:php_config_results().
init_config() ->
    [].

-spec init_const() -> ephp_lib:php_const_results().
init_const() ->
    [].

-spec php_is_array(ephp:context_id(), line(), var_value()) -> boolean().
php_is_array(_Context, _Line, {_, Value}) ->
    ?IS_ARRAY(Value).

-spec php_is_bool(ephp:context_id(), line(), var_value()) -> boolean().
php_is_bool(_Context, _Line, {_, Value}) ->
    erlang:is_boolean(Value).

-spec php_is_integer(ephp:context_id(), line(), var_value()) -> boolean().
php_is_integer(_Context, _Line, {_, Value}) ->
    erlang:is_integer(Value).

-spec php_is_numeric(ephp:context_id(), line(), var_value()) -> boolean().
php_is_numeric(_Context, _Line, {_, Value}) ->
    erlang:is_number(Value).

-spec php_is_float(ephp:context_id(), line(), var_value()) -> boolean().
php_is_float(_Context, _Line, {_, Value}) ->
    erlang:is_float(Value).

-spec php_is_null(ephp:context_id(), line(), var_value()) -> boolean().
php_is_null(_Context, _Line, {_, undefined}) ->
    true;
php_is_null(_Context, _Line, _Var) ->
    false.

-spec php_is_string(ephp:context_id(), line(), var_value()) -> boolean().
php_is_string(_Context, _Line, {_, Value}) ->
    erlang:is_binary(Value).

-spec php_is_object(ephp:context_id(), line(), var_value()) -> boolean().
php_is_object(_Context, _Line, {_, Value}) ->
    ?IS_OBJECT(Value).

-spec php_is_resource(ephp:context_id(), line(), var_value()) -> boolean().
php_is_resource(_Context, _Line, {_, Value}) ->
    ?IS_RESOURCE(Value).

-spec print_r(ephp:context_id(), line(), var_value()) -> true | binary().
print_r(Context, Line, Vars) ->
    print_r(Context, Line, Vars, {false, false}).

-spec var_dump(ephp:context_id(), line(), [var_value()] | var_value()) -> undefined.
var_dump(Context, Line, Values) when is_list(Values) ->
    lists:foreach(fun(Value) -> var_dump(Context, Line, Value) end, Values),
    undefined;
var_dump(Context, Line, {_, Value}) ->
    RecCtl = gb_sets:new(),
    Result =
        case var_dump_fmt(Context, Line, Value, <<?SPACES_VD>>, RecCtl) of
            Elements when is_list(Elements) ->
                case Value of
                    Value when ?IS_ARRAY(Value) ->
                        iolist_to_binary(var_dump_array(<<>>,
                                                        Context,
                                                        Line,
                                                        Value,
                                                        Elements,
                                                        <<>>));
                    Value when ?IS_OBJECT(Value) ->
                        iolist_to_binary(var_dump_object(<<>>, Value, Elements, <<>>))
                end;
            Element ->
                Element
        end,
    ephp_context:set_output(Context, Result),
    undefined.

-spec print_r(ephp:context_id(), line(), var_value(), Output :: var_value()) ->
                 true | binary().
print_r(Context, Line, {_, ObjRef}, {_, true}) when ?IS_OBJECT(ObjRef) ->
    case ephp_object:get(ObjRef) of
        #ephp_object{class = Class, context = Ctx} ->
            RecCtl = gb_sets:new(),
            Data =
                lists:foldl(fun(#class_attr{name = Name}, Output) ->
                               Value = ephp_context:get(Ctx, #variable{name = Name}),
                               %% FIXME: print_r with arrays inside of objects isn't working this way
                               ValDumped = print_r_fmt(Ctx, Value, <<?SPACES>>, RecCtl),
                               <<Output/binary,
                                 ?SPACES,
                                 "[",
                                 Name/binary,
                                 "] => ",
                                 ValDumped/binary>>
                            end,
                            <<>>,
                            Class#class.attrs),
            <<(Class#class.name)/binary, " Object\n(\n", Data/binary, ")\n">>;
        undefined ->
            ephp_data:to_bin(Context, Line, undefined)
    end;
print_r(Context, _Line, {_, ObjRef}, {_, false}) when ?IS_OBJECT(ObjRef) ->
    #ephp_object{class = Class, context = Ctx} = ephp_object:get(ObjRef),
    RecCtl = gb_sets:new(),
    Data =
        lists:foldl(fun(#class_attr{name = Name}, Output) ->
                       Value = ephp_context:get(Ctx, #variable{name = Name}),
                       %% FIXME: print_r with arrays inside of objects isn't working this way
                       ValDumped = print_r_fmt(Ctx, Value, <<?SPACES>>, RecCtl),
                       <<Output/binary, ?SPACES, "[", Name/binary, "] => ", ValDumped/binary>>
                    end,
                    <<>>,
                    Class#class.attrs),
    Out = <<(Class#class.name)/binary, " Object\n(\n", Data/binary, ")\n">>,
    ephp_context:set_output(Context, Out),
    true;
print_r(Context, _Line, {_, Value}, {_, true}) when ?IS_ARRAY(Value) ->
    RecCtl = gb_sets:new(),
    Data = iolist_to_binary(print_r_fmt(Context, Value, <<?SPACES>>, RecCtl)),
    <<"Array\n(\n", Data/binary, ")\n">>;
print_r(Context, _Line, {_, Value}, {_, false}) when ?IS_ARRAY(Value) ->
    RecCtl = gb_sets:new(),
    Data = iolist_to_binary(print_r_fmt(Context, Value, <<?SPACES>>, RecCtl)),
    ephp_context:set_output(Context, <<"Array\n(\n", Data/binary, ")\n">>),
    true;
print_r(Context, Line, {Var, MemRef}, Output) when ?IS_MEM(MemRef) ->
    print_r(Context, Line, {Var, ephp_mem:get(MemRef)}, Output);
print_r(Context, Line, {_, Value}, {_, true}) ->
    ephp_data:to_bin(Context, Line, Value);
print_r(Context, Line, {_, Value}, {_, false}) ->
    ephp_context:set_output(Context, ephp_data:to_bin(Context, Line, Value)),
    true.

-spec isset(ephp:context_id(), line(), {variable(), variable()}) -> boolean().
isset(Context, _Line, {_, Var}) ->
    ephp_context:isset(Context, Var).

-spec empty(ephp:context_id(), line(), var_value()) -> boolean().
empty(Context, _Line, {_, Var}) ->
    ephp_context:empty(Context, Var).

-spec gettype(ephp:context_id(), line(), var_value()) -> binary().
gettype(_Context, _Line, {_, Value}) ->
    case ephp_data:gettype(Value) of
        <<"float">> ->
            <<"double">>;
        Other ->
            Other
    end.

-spec unset(ephp:context_id(), line(), {variable(), variable()}) -> undefined.
unset(Context, _Line, {#variable{}, #variable{} = Var}) ->
    ephp_context:del(Context, Var),
    undefined.

%% ----------------------------------------------------------------------------
%% Internal functions
%% ----------------------------------------------------------------------------

var_dump_fmt(Context, Line, #var_ref{pid = VarPID, ref = VarRef}, Spaces, RecCtl) ->
    case gb_sets:is_element(VarRef, RecCtl) of
        true ->
            <<"*RECURSION*\n">>;
        false ->
            NewRecCtl = gb_sets:add(VarRef, RecCtl),
            Var = ephp_vars:get(VarPID, VarRef, Context),
            case var_dump_fmt(Context, Line, Var, Spaces, NewRecCtl) of
                Res when is_list(Res) ->
                    Size = integer_to_binary(length(Res)),
                    LessSize = byte_size(<<?SPACES_VD>>),
                    <<_:LessSize/binary, PrevSpace/binary>> = Spaces,
                    <<"&array(",
                      Size/binary,
                      ") {\n",
                      (iolist_to_binary(Res))/binary,
                      PrevSpace/binary,
                      "}\n">>;
                Res ->
                    <<"&", Res/binary>>
            end
    end;
var_dump_fmt(Context, Line, #mem_ref{} = MemRef, <<?SPACES_VD>> = Spaces, RecCtl) ->
    case gb_sets:is_element(MemRef, RecCtl) of
        true ->
            <<"*RECURSION*\n">>;
        false ->
            case ephp_mem:get_with_links(MemRef) of
                {Var, 1} ->
                    var_dump_fmt(Context, Line, Var, Spaces, RecCtl);
                {Var, _} ->
                    case var_dump_fmt(Context, Line, Var, Spaces, RecCtl) of
                        Res when is_list(Res) ->
                            Size = integer_to_binary(length(Res)),
                            LessSize = byte_size(<<?SPACES_VD>>),
                            <<_:LessSize/binary, PrevSpace/binary>> = Spaces,
                            <<"array(",
                              Size/binary,
                              ") {\n",
                              (iolist_to_binary(Res))/binary,
                              PrevSpace/binary,
                              "}\n">>;
                        Res ->
                            Res
                    end
            end
    end;
var_dump_fmt(Context, Line, #mem_ref{} = MemRef, Spaces, RecCtl) ->
    case gb_sets:is_element(MemRef, RecCtl) of
        true ->
            <<"*RECURSION*\n">>;
        false ->
            NewRecCtl = gb_sets:add(MemRef, RecCtl),
            case ephp_mem:get_with_links(MemRef) of
                {Var, 1} ->
                    var_dump_fmt(Context, Line, Var, Spaces, NewRecCtl);
                {Var, _} ->
                    case var_dump_fmt(Context, Line, Var, Spaces, NewRecCtl) of
                        Res when is_list(Res) ->
                            Size = integer_to_binary(length(Res)),
                            LessSize = byte_size(<<?SPACES_VD>>),
                            <<_:LessSize/binary, PrevSpace/binary>> = Spaces,
                            <<"&array(",
                              Size/binary,
                              ") {\n",
                              (iolist_to_binary(Res))/binary,
                              PrevSpace/binary,
                              "}\n">>;
                        Res ->
                            <<"&", Res/binary>>
                    end
            end
    end;
var_dump_fmt(_Context, _Line, true, _Spaces, _RecCtl) ->
    <<"bool(true)\n">>;
var_dump_fmt(_Context, _Line, false, _Spaces, _RecCtl) ->
    <<"bool(false)\n">>;
var_dump_fmt(_Context, _Line, Value, _Spaces, _RecCtl) when is_integer(Value) ->
    <<"int(", (ephp_data:to_bin(Value))/binary, ")\n">>;
var_dump_fmt(_Context, _Line, Value, _Spaces, _RecCtl) when is_float(Value) ->
    <<"float(", (ephp_data:to_bin(Value))/binary, ")\n">>;
var_dump_fmt(_Context, _Line, Value, _Spaces, _RecCtl) when is_binary(Value) ->
    Size = ephp_data:to_bin(byte_size(Value)),
    <<"string(", Size/binary, ") \"", Value/binary, "\"\n">>;
var_dump_fmt(_Context, _Line, Resource, _Spaces, _RecCtl) when ?IS_RESOURCE(Resource) ->
    DesNum = integer_to_binary(ephp_stream:get_res_id(Resource)),
    <<"resource(", DesNum/binary, ") of type (stream)\n">>;
var_dump_fmt(Context, Line, ObjRef, Spaces, RecCtl) when ?IS_OBJECT(ObjRef) ->
    IsLambda =
        ephp_context:get_meta(
            ephp_object:get_context(ObjRef), is_lambda),
    case ephp_object:get(ObjRef) of
        #ephp_object{class = #class{name = <<"Closure">>}} when IsLambda ->
            Id = integer_to_binary(ObjRef#obj_ref.ref),
            Name = <<"lambda_", Id/binary>>,
            var_dump_fmt(Context, Line, Name, Spaces, RecCtl);
        #ephp_object{class = Class, context = Ctx} ->
            #class{name = ClassName, attrs = Attrs} = Class,
            VisAttrs = [Attr || Attr = #class_attr{type = normal} <- Attrs],
            lists:foldl(fun(#class_attr{name = RawName, access = Access} = CA, Output) ->
                           Variable =
                               case Access of
                                   private ->
                                       #class_attr{class_name = AttrClassName, namespace = AttrNS} =
                                           CA,
                                       #variable{name = {private, RawName, AttrNS, AttrClassName}};
                                   _ ->
                                       #variable{name = RawName}
                               end,
                           Value = ephp_context:get(Ctx, Variable),
                           ValDumped =
                               var_dump_fmt(Context,
                                            Line,
                                            Value,
                                            <<Spaces/binary, ?SPACES_VD>>,
                                            RecCtl),
                           Name =
                               if is_binary(RawName) ->
                                      <<"\"", RawName/binary, "\"">>;
                                  true ->
                                      ephp_data:to_bin(RawName)
                               end,
                           CompleteName =
                               case Access of
                                   public ->
                                       Name;
                                   protected ->
                                       <<Name/binary, ":protected">>;
                                   private ->
                                       %% TODO check what's the correct class where is the attribute
                                       %%      came from.
                                       <<Name/binary, ":\"", ClassName/binary, "\":private">>
                               end,
                           Output
                           ++ if is_list(ValDumped) andalso ?IS_ARRAY(Value) ->
                                     Prefix = <<Spaces/binary, "[", CompleteName/binary, "]=>\n">>,
                                     var_dump_array(Prefix,
                                                    Context,
                                                    Line,
                                                    Value,
                                                    ValDumped,
                                                    Spaces);
                                 is_list(ValDumped) andalso ?IS_OBJECT(Value) ->
                                     Prefix = <<Spaces/binary, "[", CompleteName/binary, "]=>\n">>,
                                     var_dump_object(Prefix, Value, ValDumped, Spaces);
                                 true ->
                                     [<<Spaces/binary,
                                        "[",
                                        CompleteName/binary,
                                        "]=>\n",
                                        Spaces/binary,
                                        ValDumped/binary>>]
                              end
                        end,
                        [],
                        VisAttrs);
        undefined ->
            <<"NULL\n">>
    end;
var_dump_fmt(_Context, _Line, undefined, _Spaces, _RecCtl) ->
    <<"NULL\n">>;
var_dump_fmt(_Context, _Line, infinity, _Spaces, _RecCtl) ->
    <<"float(INF)\n">>;
var_dump_fmt(_Context, _Line, nan, _Spaces, _RecCtl) ->
    <<"float(NAN)\n">>;
var_dump_fmt(Context, Line, Value, Spaces, RecCtl) when ?IS_ARRAY(Value) ->
    ephp_array:fold(fun(Key, Val, Res) ->
                       KeyBin =
                           if not is_binary(Key) ->
                                  ephp_data:to_bin(Context, Line, Key);
                              true ->
                                  <<"\"", Key/binary, "\"">>
                           end,
                       Res
                       ++ case var_dump_fmt(Context,
                                            Line,
                                            Val,
                                            <<Spaces/binary, ?SPACES_VD>>,
                                            RecCtl)
                          of
                              V when is_binary(V) ->
                                  [<<Spaces/binary,
                                     "[",
                                     KeyBin/binary,
                                     "]=>\n",
                                     Spaces/binary,
                                     V/binary>>];
                              V when is_list(V) andalso ?IS_MEM(Val) ->
                                  {Data, 1} = ephp_mem:get_with_links(Val),
                                  %% FIXME: should we still use here the assert? better info?
                                  true = ?IS_ARRAY(Data),
                                  Prefix = <<Spaces/binary, "[", KeyBin/binary, "]=>\n">>,
                                  var_dump_array(Prefix, Context, Line, Data, V, Spaces);
                              V when is_list(V) andalso ?IS_ARRAY(Val) ->
                                  Prefix = <<Spaces/binary, "[", KeyBin/binary, "]=>\n">>,
                                  var_dump_array(Prefix, Context, Line, Val, V, Spaces);
                              V when is_list(V) andalso ?IS_OBJECT(Val) ->
                                  Prefix = <<Spaces/binary, "[", KeyBin/binary, "]=>\n">>,
                                  var_dump_object(Prefix, Val, V, Spaces)
                          end
                    end,
                    [],
                    Value).

var_dump_array(Prefix, Context, Line, Value, SubValues, Spaces) ->
    Elements = ephp_data:to_bin(Context, Line, ephp_array:size(Value)),
    [<<Prefix/binary,
       Spaces/binary,
       "array(",
       Elements/binary,
       ") {\n",
       (iolist_to_binary(SubValues))/binary,
       Spaces/binary,
       "}\n">>].

var_dump_object(Prefix, Value, SubValues, Spaces) ->
    #ephp_object{id = InstanceID, class = Class} = ephp_object:get(Value),
    #class{attrs = Attrs} = Class,
    VisAttrs = [Attr || Attr = #class_attr{type = normal} <- Attrs],
    Size = ephp_data:to_bin(length(VisAttrs)),
    ID = integer_to_binary(InstanceID),
    [<<Prefix/binary,
       Spaces/binary,
       "object(",
       (Class#class.name)/binary,
       ")#",
       ID/binary,
       " (",
       Size/binary,
       ") {\n">>]
    ++ SubValues
    ++ [<<Spaces/binary, "}\n">>].

print_r_fmt(Context, #var_ref{pid = VarPID, ref = VarRef}, Spaces, RecCtl) ->
    case gb_sets:is_member(VarRef, RecCtl) of
        true ->
            <<"Array\n *RECURSION*\n">>;
        false ->
            NewRecCtl = gb_sets:add(VarRef, RecCtl),
            Var = ephp_vars:get(VarPID, VarRef, Context),
            print_r_fmt(Context, Var, Spaces, NewRecCtl)
    end;
print_r_fmt(Context, #mem_ref{} = MemRef, Spaces, RecCtl) ->
    case gb_sets:is_member(MemRef, RecCtl) of
        true ->
            <<"Array\n *RECURSION*\n">>;
        false ->
            NewRecCtl = gb_sets:add(MemRef, RecCtl),
            Var = ephp_mem:get(MemRef),
            print_r_fmt(Context, Var, Spaces, NewRecCtl)
    end;
print_r_fmt(Context, Value, Spaces, RecCtl) when ?IS_ARRAY(Value) ->
    ephp_array:fold(fun(Key, Val, Res) ->
                       KeyBin = ephp_data:to_bin(Key),
                       Res
                       ++ case print_r_fmt(Context, Val, Spaces, RecCtl) of
                              V when is_binary(V) ->
                                  [<<Spaces/binary, "[", KeyBin/binary, "] => ", V/binary>>];
                              V when is_list(V) ->
                                  Content =
                                      lists:map(fun(Element) ->
                                                   <<?SPACES, Spaces/binary, Element/binary>>
                                                end,
                                                V),
                                  [<<Spaces/binary, "[", KeyBin/binary, "] => Array\n">>,
                                   <<Spaces/binary, "    (\n">>]
                                  ++ Content
                                  ++ [<<Spaces/binary, "    )\n\n">>]
                          end
                    end,
                    [],
                    Value);
print_r_fmt(_Context, Value, _Spaces, _RecCtl) ->
    <<(ephp_data:to_bin(Value))/binary, "\n">>.
