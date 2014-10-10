%% ----------------------------------------------------------------------------
%% Copyright 2012-2014 (c) Trifork A/S.  All Rights Reserved.
%% http://trifork.com/ info@trifork.com
%%
%% This file is provided to you under the Apache License, Version 2.0 (the
%% "License"); you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
%% WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
%% License for the specific language governing permissions and limitations
%% under the License.
%%
%% ----------------------------------------------------------------------------
-module(vbisect_SUITE).
-author('jay@duomark.com').

-export([
         all/0, groups/0,
         init_per_suite/1, end_per_suite/1,
         init_per_group/1, end_per_group/1
        ]).

%% Actual tests
-export([
         check_make_vbisect/1,
         check_find_1_vbisect/1,
         check_find_n_vbisect/1,
         check_fetch_1_vbisect/1,
         check_fold_vbisect/1,
         check_filter_vbisect/1,
         check_map_vbisect/1,
         check_lookup_speed/1
        ]).

-include("vbisect_common_test.hrl").

all() -> [{group, functionality}, {group, performance}].

groups() -> [
             {functionality, [sequence],
              [{vbisect, [sequence],
                [
                 check_make_vbisect,
                 check_find_1_vbisect,
                 check_find_n_vbisect,
                 check_fetch_1_vbisect,
                 check_fold_vbisect,
                 check_filter_vbisect,
                 check_map_vbisect
                ]
               }]
             },

             {performance,   [sequence],
              [{vbisect, [sequence], [check_lookup_speed]}]
             }
            ].

init_per_suite(Config) -> Config.
end_per_suite(_Config) -> ok.

init_per_group(Config) -> Config.
end_per_group(_Config) -> ok.
     

%% Test Module is ?TM
-define(TM, vbisect).

-spec check_make_vbisect(config()) -> ok.
check_make_vbisect(_Config) ->

    ct:log("Non-binary is not a vbisect, nor can one be made from non-binaries"),
    Test_Non_Binary
        = ?FORALL({Key, Value}, {any(), any()},
                  ?IMPLIES(not is_binary(Key) orelse not is_binary(Value),
                           begin
                               false = ?TM:is_vbisect(Key),
                               false = ?TM:is_vbisect(Value),
                               error = ?TM:data_version(Key),
                               error = ?TM:data_version(Value),
                               true = try ?TM:from_orddict([{Key, Value}])
                                      catch error:function_clause -> true
                                      end
                           end
                          )),
    true = proper:quickcheck(Test_Non_Binary, ?PQ_NUM(10)),

    ct:log("Make a vbisect and verify it is the right type"),
    Test_Make
        = ?FORALL({Key, Value}, {?TM:key(), ?TM:value()},
                  begin
                      Bin_Dict = vbisect:from_orddict([{Key, Value}]),
                      true  = ?TM:is_vbisect(Bin_Dict),
                      true  = ?TM:is_vbisect(Bin_Dict, 1),
                      false = ?TM:is_vbisect(Bin_Dict, 2),
                      1 = ?TM:data_version(Bin_Dict),
                      1 =:= ?TM:size(Bin_Dict)
                  end),
    true = proper:quickcheck(Test_Make, ?PQ_NUM(10)),
    ok.
    

-spec check_find_1_vbisect(config()) -> ok.
check_find_1_vbisect(_Config) ->

    ct:log("Find from an empty vbisect should always fail"),
    VB_Empty = ?TM:from_orddict([]),
    0  = ?TM:size(VB_Empty),
    8  = ?TM:dictionary_size_in_bytes(VB_Empty),
    [] = ?TM:fetch_keys(VB_Empty),
    [] = ?TM:values(VB_Empty),
    [] = ?TM:foldl(fun(Key, Value, Acc) -> [{Key, Value} | Acc] end, [], VB_Empty),
    [] = ?TM:foldr(fun(Key, Value, Acc) -> [{Key, Value} | Acc] end, [], VB_Empty),
    
    Test_Empty
        = ?FORALL(Key, ?TM:key(),
                  (error =:= ?TM:find(Key, VB_Empty)
                    andalso none =:= ?TM:find_geq (Key, VB_Empty))),
    true = proper:quickcheck(Test_Empty, ?PQ_NUM(10)),
    
    ct:log("Find should return any field that is stored in a vbisect"),
    Test_Make
        = ?FORALL({Key, Value}, {?TM:key(), ?TM:value()},
                  begin
                      Bin_Dict = vbisect:from_orddict([{Key, Value}]),
                      true  = ?TM:is_vbisect(Bin_Dict),
                      false = ?TM:is_key(list_to_binary([Key, <<"-A">>]), Bin_Dict),
                      true  = ?TM:is_key(Key, Bin_Dict),
                      ?TM:find(Key, Bin_Dict) =:= {ok, Value}
                  end),
    true = proper:quickcheck(Test_Make, ?PQ_NUM(10)),
    ok.

-spec check_find_n_vbisect(config()) -> ok.
check_find_n_vbisect(_Config) ->

    ct:log("Retrieve keys / values from real random dictionaries"),
    Test_Random
        = ?FORALL({Keys, Values}, random_pairs(non_empty(?TM:key()), ?TM:value()),
                  ?IMPLIES(length(lists:usort(Keys)) =:= length(Keys),
                           begin
                               Len = length(Keys),
                               KVs = lists:zip(Keys, Values),
                               Bin_Dict = ?TM:from_orddict(orddict:from_list(KVs)),
                               Fetched_Values = [Fetched_Value
                                                 || {Key, Value} <- KVs,
                                                    begin
                                                        {ok, Fetched_Value} = ?TM:find(Key, Bin_Dict),
                                                        Fetched_Value =:= Value
                                                    end],
                               Len =:= length(?TM:fetch_keys(Bin_Dict))
                                   andalso Len =:= length(?TM:values(Bin_Dict))
                                   andalso Len =:= length(Fetched_Values)
                           end)),
    true = proper:quickcheck(Test_Random),
    ok.

-spec check_fetch_1_vbisect(config()) -> ok.
check_fetch_1_vbisect(_Config) ->

    ct:log("Fetch from an empty vbisect should always crash"),
    VB_Empty = ?TM:from_orddict([]),
    0  = ?TM:size(VB_Empty),
    
    Test_Empty
        = ?FORALL(Key, ?TM:key(),
                  (error =:= try ?TM:fetch(Key, VB_Empty)
                             catch error:badarg -> error
                             end)),
    true = proper:quickcheck(Test_Empty, ?PQ_NUM(10)),
    
    ct:log("Fetch should return any field that is stored in a vbisect"),
    Test_Make
        = ?FORALL({Key, Value}, {?TM:key(), ?TM:value()},
                  begin
                      Bin_Dict = vbisect:from_orddict([{Key, Value}]),
                      true  = ?TM:is_vbisect(Bin_Dict),
                      false = ?TM:is_key(list_to_binary([Key, <<"-A">>]), Bin_Dict),
                      true  = ?TM:is_key(Key, Bin_Dict),
                      ?TM:fetch(Key, Bin_Dict) =:= Value
                  end),
    true = proper:quickcheck(Test_Make, ?PQ_NUM(10)),
    ok.

-spec check_fold_vbisect(config()) -> ok.
check_fold_vbisect(_Config) ->

    ct:log("Fold across keys / values in real random dictionaries"),
    Test_Random
        = ?FORALL({Keys, Values}, random_pairs(non_empty(?TM:key()), ?TM:value()),
                  ?IMPLIES(length(lists:usort(Keys)) =:= length(Keys),
                           begin
                               KVs = lists:zip(Keys, Values),
                               KV_Lens = [{byte_size(Key), byte_size(Value)}
                                          || {Key, Value} <- lists:sort(KVs)],
                               Bin_Dict = ?TM:from_orddict(orddict:from_list(KVs)),
                               KV_Lens = ?TM:foldr(fun(K, V, Acc) ->
                                                           [{byte_size(K), byte_size(V)} | Acc]
                                                   end, [], Bin_Dict),
                               KV_Lens_Rev = lists:reverse(KV_Lens),
                               KV_Lens_Rev = ?TM:foldl(fun(K, V, Acc) ->
                                                           [{byte_size(K), byte_size(V)} | Acc]
                                                   end, [], Bin_Dict),
                               true
                           end)),
    true = proper:quickcheck(Test_Random),
    ok.

-spec check_filter_vbisect(config()) -> ok.
check_filter_vbisect(_Config) ->

    ct:log("Filter keys / values in real random dictionaries"),
    Test_Random
        = ?FORALL({Keys, Values}, random_pairs(non_empty(?TM:key()), ?TM:value()),
                  ?IMPLIES(length(lists:usort(Keys)) =:= length(Keys),
                           begin
                               KVs = lists:zip(Keys, Values),
                               KV_Lens = [KV || KV = {_Key, Value} <- lists:sort(KVs),
                                                byte_size(Value) > 4],
                               Bin_Dict1 = ?TM:from_orddict(orddict:from_list(KVs)),
                               Bin_Dict2 = ?TM:filter(fun(_K, V) -> byte_size(V) > 4 end, Bin_Dict1),
                               KV_Lens = ?TM:to_orddict(Bin_Dict2),
                               true
                           end)),
    true = proper:quickcheck(Test_Random),
    ok.

-spec check_map_vbisect(config()) -> ok.
check_map_vbisect(_Config) ->

    ct:log("Map across keys / values in real random dictionaries"),
    Test_Random
        = ?FORALL({Keys, Values}, random_pairs(non_empty(?TM:key()), ?TM:value()),
                  ?IMPLIES(length(lists:usort(Keys)) =:= length(Keys),
                           begin
                               KVs = lists:zip(Keys, Values),
                               KV_Lens = [{Key, integer_to_binary(byte_size(Value))}
                                           || {Key, Value} <- lists:sort(KVs)],
                               Bin_Dict1 = ?TM:from_orddict(orddict:from_list(KVs)),
                               Bin_Dict2 = ?TM:map(fun(_K, V) ->
                                                           integer_to_binary(byte_size(V))
                                                   end, Bin_Dict1),
                               KV_Lens = ?TM:to_orddict(Bin_Dict2),
                               true
                           end)),
    true = proper:quickcheck(Test_Random),
    ok.

random_pairs(Type1, Type2) ->
    ?SIZED(S, ?LET(Pair, {vector(S, Type1), vector(S, Type2)}, Pair)).

-spec check_lookup_speed(config()) -> ok.
check_lookup_speed(_Config) ->
    Start = 100000000000000,
    N = 100000,
    Keys = lists:seq(Start, Start+N),
    KeyValuePairs = lists:map(fun (I) -> {<<I:64/integer>>, <<255:8/integer>>} end, Keys),

    %% Will mostly be unique, if N is bigger than 10000
    ReadKeys = [<<(lists:nth(random:uniform(N), Keys)):64/integer>> || _ <- lists:seq(1, 1000)],
    B = ?TM:from_orddict(KeyValuePairs),
    erlang:garbage_collect(),
    time_reads(B, N, ReadKeys),
    ok.

time_reads(B, Size, ReadKeys) ->
    Parent = self(),
    spawn(
      fun() ->
              Runs = 20,
              Timings =
                  lists:map(
                    fun (_) ->
                            StartTime = now(),
                            _ = find_many(B, ReadKeys),
                            timer:now_diff(now(), StartTime)
                    end, lists:seq(1, Runs)),

              Rps = 1000000 / ((lists:sum(Timings) / length(Timings)) / 1000),
              error_logger:info_msg("Average over ~p runs, ~p keys in dict~n"
                                    "Average fetch ~p keys: ~p us, max: ~p us~n"
                                    "Average fetch 1 key: ~p us~n"
                                    "Theoretical sequential RPS: ~w~n",
                                    [Runs, Size, length(ReadKeys),
                                     lists:sum(Timings) / length(Timings),
                                     lists:max(Timings),
                                     (lists:sum(Timings) / length(Timings)) / length(ReadKeys),
                                     trunc(Rps)]),

              Parent ! done
      end),
    receive done -> ok after 1000 -> ok end.

-spec find_many(?TM:bindict(), [?TM:key()]) -> [{ok, ?TM:value()} | not_found].
find_many(B, Keys) ->
    lists:map(fun (K) -> ?TM:find(K, B) end, Keys).

