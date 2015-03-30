-module(server).
-define(CLIENTS, 'clients.txt').
-define(UPDATE, 'needupdate.txt').
-export([start/0,loop/0,refresh/0,update/0,clientupdate/3,programupdate/6]).
-vsn(1.80).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

start() ->

    Pid = spawn(?MODULE,loop,[]),
    register(server, Pid).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

refresh() ->

    io:format("*** SERVER *** Current nodes alive:~n"),
        lists:foreach(fun(Noodi) ->
        io:format("~p~n",[Noodi])
        end,
        nodes()),
    io:format("~n"),
    os:cmd("updateclients").
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

update() ->

    code:purge(?MODULE),
    code:load_file(?MODULE).
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%	

clientupdate(N,V,S) ->
    
    {ok,{client,[C]}} = beam_lib:version(client),
    case string:equal(V,C) of
        false ->
            {ok, F} = file:open("clients.txt", [append]),
            io:format(F,"~p~n",[N]),
            file:close(F),
            io:format("*** SERVER (~p)*** Updating client.beam on ~p~n",[S,N]),
            os:cmd("clientupdate");
        true ->
            io:format("*** SERVER (~p)*** No update needed for client.beam on ~p~n",[S,N])
    end.
            
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

programupdate(From,Node,V,L,Cl,S) ->
	
	case string:equal(V,L) of 
        false ->
            From ! {{ok,{hello,[L]}},{ok,{client,[Cl]}}},
            io:format("*** SERVER (~p)*** ~p ~p needs an update~n", [S,From,Node]),
            {ok,F} = file:open(?UPDATE, [append]),
            io:format(F,"~p~n",[Node]),
            file:close(F),
            io:format("*** SERVER (~p)*** Updating ~p~n",[S,Node]),
            os:cmd("updateclients");
        true ->
            From ! {{ok,{hello,[L]}},{ok,{client,[Cl]}}},
            io:format("*** SERVER (~p)*** ~p ~p is up to date~n", [S,From,Node])
    end.
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

loop() ->

    ?MODULE:update(),
    {ok,{server,[S]}} = beam_lib:version(server),
    
	lists:foreach(fun(Noodi) ->
		{client, Noodi} ! {"request_version"},
			receive 
				{From, Node, {ok,{hello,[V]}},{ok,{client,[C]}}} ->
		            io:format("*** SERVER (~p)*** Hello.beam: ~p~n Client.beam: ~p~n from ~p~n",[S,V,C,Node]),
					{ok,{hello,[L]}} = beam_lib:version(hello),
					{ok,{client,[Cl]}} = beam_lib:version(client),
					io:format("Server: ~p Node: ~p~n", [L,V]),
            
					?MODULE:programupdate(From,Node,V,L,Cl,S),
            
					?MODULE:clientupdate(Node,C,S)
			after
				10000 ->
					io:format("*** SERVER (~p)*** No response from ~p~n",[S,Noodi])
			end		
	end,
	nodes()),
    ?MODULE:refresh(),
    ?MODULE:loop().