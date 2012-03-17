%% @author Arjan Scherpenisse <arjan@scherpenisse.net>
%% @copyright 2012 Arjan Scherpenisse <arjan@scherpenisse.net>
%% Date: 2012-03-16

%% @doc Zotonic: admin menu

%% Copyright 2012 Arjan Scherpenisse
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%% 
%%     http://www.apache.org/licenses/LICENSE-2.0
%% 
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.

-module(m_admin_menu).
-author("Arjan Scherpenisse <arjan@scherpenisse.net>").

-include_lib("include/zotonic.hrl").

-export([test/0]).


%% interface functions
-export([
    m_find_value/3,
    m_to_list/2,
    m_value/2
]).


%% @spec m_find_value(Key, Source, Context) -> term()
m_find_value(user, #m{value=undefined}, Context) ->
    z_acl:user(Context);
m_find_value(is_admin, #m{value=undefined}, Context) ->
    z_acl:is_allowed(use, mod_admin_config, Context);
m_find_value(Action, #m{value=undefined} = M, _Context) 
    when Action == use orelse Action == admin orelse Action == view
    orelse Action == delete orelse Action == update orelse Action == insert ->
    M#m{value={is_allowed, Action}};
m_find_value(is_allowed, #m{value=undefined} = M, _Context) ->
    M#m{value=is_allowed};
m_find_value(Action, #m{value=is_allowed} = M, _Context) ->
    M#m{value={is_allowed, Action}};
m_find_value(Object, #m{value={is_allowed, Action}}, Context) when is_binary(Object) ->
    z_acl:is_allowed(Action, z_convert:to_atom(Object), Context);
m_find_value(Object, #m{value={is_allowed, Action}}, Context) ->
    z_acl:is_allowed(Action, Object, Context).

%% @spec m_to_list(Source, Context) -> List
m_to_list(_, Context) ->
    menu(Context).

%% @spec m_value(Source, Context) -> term()
m_value(#m{value=undefined}, _Context) ->
    undefined.


menu(Context) ->
    F = fun() ->
                Menu = z_notifier:foldr(admin_menu, [], Context),
                hierarchize(Menu, Context)
        end,
    z_depcache:memo(F, {admin_menu, z_acl:user(Context), z_context:language(Context)},
                    Context).



hierarchize(Items, Context) ->
    hierarchize(undefined, Items, Context).

hierarchize(Id, All, Context) ->
    {Matches, Rest} = partition(Id, All),
    Matches1 = [mixin(C, Rest, Context) || C <- Matches],
    lists:filter(fun(I) -> item_visible(I, Context) end, Matches1).
    

partition(Key, Items) ->
    lists:partition(fun({_, {K, _, _}}) when K =:= Key ->
                            true;
                       (_) ->
                            false end, Items).

mixin({Id, {_Parent, Label, UrlDef}}, All, Context) ->
    Url = item_url(UrlDef, Context),
    {Id, [{url, Url},
          {label, Label},
          {items, hierarchize(Id, All, Context)}]};
mixin({Id, {_Parent, Label, UrlDef, VisibleCheck}}, All, Context) ->
    Url = item_url(UrlDef, Context),
    {Id, [{url, Url},
          {label, Label},
          {visiblecheck, VisibleCheck},
          {items, hierarchize(Id, All, Context)}]}.

item_url({url, Rule}, Context) ->
    z_dispatcher:url_for(Rule, Context);
item_url({url, Rule, Args}, Context) ->
    z_dispatcher:url_for(Rule, Args, Context);
item_url(X, _) ->
    X.

item_visible({_Key, ItemProps}, Context) ->
    case proplists:get_value(url, ItemProps) =/= undefined orelse
        proplists:get_value(items, ItemProps) =/= [] of
        false ->
            false;
        true ->
            case proplists:get_value(visiblecheck, ItemProps) of
                undefined ->
                    true;
                F when is_function(F) ->
                    F();
                {acl, Action, Object} ->
                    z_acl:is_allowed(Action, Object, Context)
            end
    end.
                     


test() ->
    C = z:c(zotonic_status),
    
    %% simple test
    Items1 = [
              {top1, {undefined, "Label", "/"}}],
    [{top1, [{url, "/"},
             {label, "Label"},
             {items, []}]}] = hierarchize(Items1, C),

    %% simple test with empty children
    Items1a = [
              {top1, {undefined, "Label", "/"}},
              {top2, {undefined, "Label2", undefined}}
             ],
    [{top1, [{url, "/"},
             {label, "Label"},
             {items, []}]}] = hierarchize(Items1a, C),

    %% test w/ 1 child
    Items2 = [
              {top1, {undefined, "Label", "/"}},
              {sub1, {top1, "Label1", "/xx"}}
             ],
    [{top1, [{url, "/"},
             {label, "Label"},
             {items, [
                      {sub1, [{url, "/xx"}, {label, "Label1"}, {items, []}]}
                     ]}]}] = hierarchize(Items2, C),


    %% test w/ 1 child
    Items2a = [
              {top1, {undefined, "Label", "/"}},
              {sub1, {top1, "Label1", "/xx"}},
              {sub2, {top1, "Label2", "/yy"}}
             ],
    [{top1, [{url, "/"},
             {label, "Label"},
             {items, [
                      {sub1, [{url, "/xx"}, {label, "Label1"}, {items, []}]},
                      {sub2, [{url, "/yy"}, {label, "Label2"}, {items, []}]}
                     ]}]}] = hierarchize(Items2a, C),
    
    %% test w/ callback
    Items3 = [
              {top1, {undefined, "Label", "/"}},
              {sub1, {top1, "Label1", "/xx", fun() -> false end}}
             ],
    [{top1, [{url, "/"},
             {label, "Label"},
             {items, []}]}] = hierarchize(Items3, C),
    ok.
       