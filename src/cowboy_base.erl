-module (cowboy_base).

-export([execute/2]).
-export([init/0]).
-export([init/1]).

-export([resolve/2]).

execute(Req, Env) ->
  Fun = init([]),
  Fun(Req, Env).

init() ->
  init([]).

init(Options) ->
  ProtoHeader = fast_key:get(proto, Options, <<"x-orig-proto">>),
  HostHeader = fast_key:get(host, Options, <<"x-orig-host">>),
  PortHeader = fast_key:get(port, Options, <<"x-orig-port">>),
  PathHeader = fast_key:get(path, Options, <<"x-orig-path">>),
  fun (Req, Env) ->
    {Port, Req} = cowboy_req:port(Req),
    PortBin = list_to_binary(integer_to_list(Port)),
    ForwardedProto = choose(cowboy_req:header(ProtoHeader, Req), {<<"http">>, Req}),
    ForwardedHost = choose(cowboy_req:header(HostHeader, Req), cowboy_req:host(Req)),
    ForwardedPort = choose(cowboy_req:header(PortHeader, Req), {PortBin, Req}),
    ForwardedPath = choose(cowboy_req:header(PathHeader, Req), {<<"">>, Req}),
    Req2 = cowboy_req:set_meta(base, format(ForwardedProto, ForwardedHost, ForwardedPort, ForwardedPath), Req),
    {ok, Req2, Env}
  end.

choose({undefined, _}, {B, _}) -> B;
choose({A, _}, _) -> A.

format(Proto, Host, Port, <<"/">>) ->
  format(Proto, Host, Port, <<>>);
format(<<"http">>, Host, <<"80">>, Path) ->
  <<"http://",Host/binary,Path/binary>>;
format(<<"https">>, Host, <<"443">>, Path) ->
  <<"https://",Host/binary,Path/binary>>;
format(Proto, Host, Port, Path) ->
  <<Proto/binary,"://",Host/binary,":",Port/binary,Path/binary>>.

resolve(Parts, Req) when is_list(Parts) ->
  resolve(binary_join(Parts, <<"/">>), Req);
resolve(<<"/",Path/binary>>, Req) ->
  resolve(Path, Req);
resolve(Path, Req) ->
  {Base, Req} = cowboy_req:meta(base, Req),
  join_with_base(Base, Path).

join_with_base(Base, <<"/">>) ->
  join_with_base(Base, <<>>);
join_with_base(Base, Path) ->
  case binary:last(Base) of
    47 -> %% <<"/">>
      <<Base/binary, Path/binary>>;
    _ ->
      <<Base/binary, "/", Path/binary>>
  end.

binary_join([], _Sep) ->
  <<>>;
binary_join([H], _Sep) ->
  << H/binary >>;
binary_join([H | T], Sep) ->
  << H/binary, Sep/binary, (binary_join(T, Sep))/binary >>.
