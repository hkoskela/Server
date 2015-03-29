-module(server).
-define(KEY, 'h3mpp4').
-define(CLIENTS, 'clients.txt').
-define(UPDATE, 'needupdate.txt').
-export([start/0,loop/0,refresh/0,update/0]).
-vsn(1.3).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

start() ->

    os:cmd("export PATH=~/hello:$PATH"),
	Pid = spawn(?MODULE,loop,[]),
	register(server, Pid).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

refresh() ->

	{ok,F} = file:open(?CLIENTS,write),
	io:format("*** SERVER *** Current nodes alive:~n"),
		lists:foreach(fun(Noodi) ->
		io:format("~p~n",[Noodi]),
		io:format(F,"~p~n",[Noodi])
		end,
		nodes()),
	io:format("~n"),
	file:close(F).
	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

update() ->

	code:purge(?MODULE),
	code:load_file(?MODULE).
	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%	

loop() ->

    ?MODULE:update(),
	{ok,{server,[S]}} = beam_lib:version(server),
	receive
        {From, Node, {ok,{hello,[V]}}} ->
            io:format("*** SERVER (~p)*** got ~p from ~p~n",[S,V,Node]),
			{ok,{hello,[L]}} = beam_lib:version(hello),
			case string:equal(V,L) of 
				false ->
					From ! {L},
					io:format("*** SERVER (~p)*** client needs an update~n", [S]),
					{ok,F} = file:open(?UPDATE, [append]),
					io:format(F,"~p~n",[Node]),
				    file:close(F),
					os:cmd("updateclients");
				true ->
					From ! {L}
			end,
			From ! beam_lib:version(hello),
			?MODULE:refresh(),
			?MODULE:loop();
		Msg ->
			io:format("*** SERVER (~p)*** Received ~p~n~n",[S,Msg]),
			?MODULE:loop()
		
	after 
        10000 ->
            io:format("*** SERVER (~p)*** No key received~n~n",[S]),
			io:format("*** SERVER (~p)*** Refreshing nodes~n",[S]),
			?MODULE:refresh(),
			?MODULE:loop()
	end.
            