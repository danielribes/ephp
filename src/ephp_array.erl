%% @doc The PHP Array is a collection that could be used as a simple array
%%      or a hash. This module helps to create an structure to handle the
%%      PHP Array.
%%
%%      An example for the use of this module:
%%
%%      <pre lang="erlang"><![CDATA[
%%      Array0 = ephp_array:new().
%%      Array1 = ephp_array:store(auto, <<"hello world!">>).
%%      Array2 = ephp_array:store(auto, <<"bye!">>).
%%      ArrayN = ephp_array:from_list([1, 2, 3, 4, 5]).
%%      ]]></pre>
%% @end
-module(ephp_array).
-author('manuel@altenwald.com').
-compile([warnings_as_errors]).

-include("ephp.hrl").

-export([
    new/0,
    size/1,
    find/2,
    find/3,
    store/3,
    erase/2,
    map/2,
    fold/3,
    from_list/1,
    to_list/1,
    first/1,
    last/1,
    next/1,
    prev/1,
    current/1,
    cursor/2
]).


-spec new() -> ephp_array().
%% @doc creates an empty PHP Array structure.
new() -> #ephp_array{}.


-spec size(ephp_array()) -> non_neg_integer().
%% @doc retrieve the size of the array.
size(#ephp_array{size=Size}) -> Size.


-spec find(mixed(), ephp_array()) -> {ok, mixed()} | error.
%% @doc finds an element by the key passed as a param.
find(Key, #ephp_array{values=Values}) ->
    case lists:keyfind(Key, 1, Values) of
        {Key, Value} -> {ok, Value};
        false -> error
    end.


-spec find(mixed(), ephp_array(), mixed()) -> mixed().
%% @doc finds an element by the passed as a param. If the value isn't found the
%%      default value passed as param is returned.
%% @end
find(Key, Array, Default) ->
    case find(Key, Array) of
        {ok, Value} -> Value;
        error -> Default
    end.


-spec store(auto | mixed(), mixed(), ephp_array()) -> ephp_array().
%% @doc stores a new element given a key and a value. If the key passed is
%%       `auto' the key is autogenerated based on the last numeric index
%%       used.
%% @end
store(auto, Value,
      #ephp_array{last_num_index = Key, values = Values} = Array) ->
    Array#ephp_array{
        last_num_index = Key + 1,
        values = Values ++ [{Key, Value}],
        size = Array#ephp_array.size + 1
    };

store(Key, Value, #ephp_array{last_num_index = Last, values = Values} = Array)
        when is_integer(Key) andalso Key >= 0
        andalso Last =< Key ->
    Array#ephp_array{
        last_num_index = Key + 1,
        values = Values ++ [{Key, Value}],
        size = Array#ephp_array.size + 1
    };

store(Key, Value, #ephp_array{values = Values} = Array) ->
    case lists:keyfind(Key, 1, Values) =/= false of
        true ->
            NewValues = lists:keyreplace(Key, 1, Values, {Key, Value}),
            Size = Array#ephp_array.size;
        false ->
            NewValues = Values ++ [{Key, Value}],
            Size = Array#ephp_array.size + 1
    end,
    Array#ephp_array{values = NewValues, size = Size}.


-spec erase(mixed(), ephp_array()) -> ephp_array().
%% @doc removes an element from the array given the index.
erase(Key, #ephp_array{values=Values}=Array) ->
    NewValues = lists:keydelete(Key, 1, Values),
    Array#ephp_array{
        values = NewValues,
        size = length(NewValues)
    }.


-spec map(function(), ephp_array()) -> ephp_array().
%% @doc performs a map action on all of the elemnts in the array.
map(Fun, #ephp_array{values = Values} = Array) ->
    NewValues = lists:map(fun({K, V}) -> Fun(K, V) end, Values),
    Array#ephp_array{values = NewValues}.


-spec fold(function(), mixed(), ephp_array()) -> mixed().
%% @doc performs a fold on all of the elements in the array given an initial
%%      value and changing that value in each element.
%% @end
fold(Fun, Initial, #ephp_array{values = Values}) ->
    lists:foldl(fun({K, V}, Acc) -> Fun(K, V, Acc) end, Initial, Values).


-spec from_list([mixed()]) -> ephp_array().
%% @doc transform the list passed as param in a PHP Array.
from_list(List) when is_list(List) ->
    lists:foldl(fun
        ({K,_}=E, #ephp_array{values = V, size = S} = A) when is_binary(K)
                                                       orelse is_number(K) ->
            A#ephp_array{size = S + 1, values = V ++ [E]};
        (E, #ephp_array{values = V, last_num_index = K, size = S} = A) ->
            A#ephp_array{size = S + 1, values = V ++ [{K,E}],
                         last_num_index = K + 1}
    end, #ephp_array{}, List).


-spec to_list(ephp_array()) -> [mixed()].
%% @doc transform a PHP Array to a property list.
to_list(#ephp_array{values = Values}) ->
    Values.


-spec first(ephp_array()) -> {ok, mixed(), ephp_array()} | {error, empty}.
%% @doc moves the cursor to the begin of the array and retrieves that element.
first(#ephp_array{size = 0}) ->
    {error, empty};

first(#ephp_array{values = Values} = Array) ->
    {ok, lists:nth(1, Values), Array#ephp_array{cursor = 1}}.


-spec last(ephp_array()) -> {ok, mixed(), ephp_array()} | {error, empty}.
%% @doc moves the cursor to the end of the array and retrieves that element.
last(#ephp_array{size = 0}) ->
    {error, empty};

last(#ephp_array{size = Size, values = Values} = Array) ->
    {ok, lists:last(Values), Array#ephp_array{cursor = Size}}.


-spec next(ephp_array()) -> {ok, mixed(), ephp_array()} |
                            {error, eof | empty | enocursor}.
%% @doc moves the cursor the to next element and retrieves that element.
next(#ephp_array{size = 0}) ->
    {error, empty};

next(#ephp_array{cursor = false}) ->
    {error, enocursor};

next(#ephp_array{cursor = Cursor, size = Size}) when Size =:= Cursor ->
    {error, eof};

next(#ephp_array{cursor = Cursor, values = Values} = Array) ->
    {ok, lists:nth(Cursor + 1, Values), Array#ephp_array{cursor = Cursor + 1}}.


-spec prev(ephp_array()) -> {ok, mixed(), ephp_array()} |
                            {error, bof | empty | enocursor}.
%% @doc moves the cursor to the previous element and retrieves that element.
prev(#ephp_array{size = 0}) ->
    {error, empty};

prev(#ephp_array{cursor = 1}) ->
    {error, bof};

prev(#ephp_array{cursor = false}) ->
    {error, enocursor};

prev(#ephp_array{cursor = Cursor, values = Values} = Array) ->
    {ok, lists:nth(Cursor - 1, Values), Array#ephp_array{cursor = Cursor - 1}}.


-spec current(ephp_array()) -> {ok, mixed()} | {error, empty | enocursor}.
%% @doc retrieves the element under the cursor.
current(#ephp_array{size = 0}) ->
    {error, empty};

current(#ephp_array{cursor = false}) ->
    {error, enocursor};

current(#ephp_array{cursor = Cursor, values = Values}) ->
    {ok, lists:nth(Cursor, Values)}.


-spec cursor(ephp_array(), pos_integer() | false) -> ephp_array().
%% @doc set the cursor for an array.
cursor(#ephp_array{} = Array, Cursor) ->
    Array#ephp_array{cursor = Cursor}.
