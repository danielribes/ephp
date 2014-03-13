-module(ephp_output).
-behaviour(gen_server).
-define(SERVER, ?MODULE).

-compile([warnings_as_errors]).

-include("ephp.hrl").

-type flush_handler() ::
    stdout | {io, io:device()} | function().

-record(state, {
    output = <<>> :: binary(),
    flush = true :: boolean(),
    flush_handler = stdout :: flush_handler()
}).

%% ------------------------------------------------------------------
%% API Function Exports
%% ------------------------------------------------------------------

-export([
    start_link/0,
    start_link/1,
    start_link/2,
    get/1,
    push/2,
    pop/1,
    size/1,
    flush/1,
    set_flush/2,
    destroy/1
]).

%% ------------------------------------------------------------------
%% gen_server Function Exports
%% ------------------------------------------------------------------

-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

%% ------------------------------------------------------------------
%% API Function Definitions
%% ------------------------------------------------------------------

start_link() ->
    start_link(true, stdout).

start_link(Flush) ->
    start_link(Flush, stdout).

start_link(Flush, FlushHandler) ->
    gen_server:start_link(?MODULE, [Flush, FlushHandler], []).

pop(Output) ->
    gen_server:call(Output, pop_output).

push(Output, Text) ->
    gen_server:cast(Output, {output, Text}).

get(Output) ->
    gen_server:call(Output, output).

set_flush(Output, Flush) ->
    gen_server:cast(Output, {set_flush, Flush}).

size(Output) ->
    gen_server:call(Output, get_size).

flush(Output) ->
    gen_server:cast(Output, flush).

destroy(Output) ->
    gen_server:cast(Output, stop).

%% ------------------------------------------------------------------
%% gen_server Function Definitions
%% ------------------------------------------------------------------

init([Flush, FlushHandler]) ->
    {ok, #state{
        flush = Flush,
        flush_handler = FlushHandler
    }}.

handle_call(pop_output, _From, #state{output=Output}=State) ->
    {reply, Output, State#state{output = <<>>}};

handle_call(output, _From, #state{output=Output}=State) ->
    {reply, Output, State};

handle_call(get_size, _From, #state{output=Output}=State) ->
    {reply, byte_size(Output), State};

handle_call(_Request, _From, State) ->
    {reply, ok, State}.


handle_cast({output, Text}, #state{flush=true, flush_handler=FH}=State) ->
    flush_handler(Text, FH),
    {noreply, State};

handle_cast({output, Text}, #state{flush=false, output=Output}=State) ->
    NewState = State#state{output = <<Output/binary, Text/binary>>},
    {noreply, NewState};

handle_cast(flush, #state{flush=false, 
        output=Output, flush_handler=FH}=State) ->
    flush_handler(Output, FH),
    {noreply, State#state{output = <<>>}};

handle_cast({set_flush, Flush}, State) ->
    {noreply, State#state{flush=Flush}};

handle_cast(stop, State) ->
    {stop, normal, State};

handle_cast(_Msg, State) ->
    {noreply, State}.


handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{flush=false, flush_handler=FH, output=Output}) ->
    flush_handler(Output, FH),
    ok;

terminate(_Reason, _State) ->
    ok.


code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% ------------------------------------------------------------------
%% Internal Function Definitions
%% ------------------------------------------------------------------

flush_handler(Text, stdout) ->
    io:fwrite("~s", [Text]),
    ok;

flush_handler(Text, {io, FH}) ->
    io:fwrite(FH, "~s", [Text]),
    ok;

flush_handler(Text, FH) when is_function(FH) ->
    FH(Text),
    ok.