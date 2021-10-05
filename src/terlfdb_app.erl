-module(terlfdb_app).

-behaviour(application).

%% Application callbacks
-export([start/2, stop/1]).

%% ===================================================================
%% Application callbacks
%% ===================================================================

loopC(Count) ->                            
    receive                                   
        { incr } -> 
            loopC(Count + 1);              
        { report, To } ->          
            io:format("Counter: ~p ~n", [Count]),
            To ! { count, Count },            
            loopC(Count)                           
    end.                                      

incr(Counter) ->
    Counter ! { incr }.

get_count(Counter) ->    
    Counter ! { report, self() },
    receive
        { count, Count } -> Count
    end.


for(0,_) -> 
   []; 
for(N,F) when N > 0 -> 
   F(),
   for(N-1,F).

timestamp() ->
    {M, S, _} = os:timestamp(),
    M * 1000000 + S.


loop(Db, End, Counter) ->
    _ = erlfdb:set(Db, <<"foo">>, <<"xxx">>),
    Now = timestamp(),
    incr(Counter),
    if
        Now < End ->
            loop(Db, End, Counter);
        true ->
            io:fwrite("Finished")
    end.

start(_StartType, _StartArgs) ->
    Db = erlfdb:open(<<"/etc/foundationdb/fdb.cluster">>),
    End = timestamp() + 10,
    Counter = spawn(fun() ->  loopC(0) end),

    L = for(50, fun() -> spawn( fun() -> loop(Db, End, Counter) end) end ),

    timer:sleep(10 * 1000),

    io:format("~p~n", [L]),
    io:fwrite("Finished All \n"),

    C = get_count(Counter),
    io:format("Counter: ~p~n", [C]),

    terlfdb_sup:start_link().

stop(_State) ->
    ok.
