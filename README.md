vbisect
=======

Vbisect is a variable-sized binary ordered dictionary implemented
in erlang. All keys and values in the dictionary have been converted
to binaries, then encoded in a single large binary as a breadth-first
traversal of the tree's leaves represented as an array with
variable-sized elements.

### Data representation

An encoded vbisect dictionary can contain 2^32 entries, each
of which has a key of not more than 2^16 bytes and a value of
not more than 2^32 bytes, and the entire dictionary must fit
in your available RAM. In general, they have been optimized
for a 32-bit architecture but should work well on 64-bit
environments.

Vbisect binaries are defined with the following fields in
order (the key and value pairs are repeated as many times
as are defined by the number of entries):

```
Id:                 <<"vbs">>
Version:            <<1:8/unsigned>>
Number of entries:  <<Count:32/unsigned>>

Key Size:           <<Key_Size:16>>
Key:                <<Key/binary>>

Value Size:         <<Value_Size:32>>
Value:              <<Value/binary>>

```

There is currently only 1 internal format definition, but the
internal implementation allows 254 new versions so that it is
possible for the library to be upgraded and your application
to run with more than one internal implementation version at
the same time. This allows you to run with old code, or to use
live update to migrate your data to a new library implementation.

### Interface

The main usage is to convert orddicts and gb_trees to vbisects
and subsequently to access the data values using find and fold.
Ensure that all keys and values are binaries in any source
orddict or gb_tree:

```
from_orddict(Orddict) -> Vbisect.
to_orddict(Vbisect)   -> Orddict.

from_gb_tree(Tree)    -> Vbisect.
to_gb_tree(Vbisect)   -> Tree.

find(Key, Vbisect)    -> {ok, Value} | error.
find_geq(Key, Vbisect) -> {ok, Key, Value} | none.

foldl(fun(Key, Value, Accum) -> Accum1), Accum0, Vbisect0) -> Vbisect1.
foldr(fun(Key, Value, Accum) -> Accum1), Accum0, Vbisect0) -> Vbisect1.

merge(Compare_Fn, Orddict1, Orddict2) -> Orddict3.

```

### Quick start

To play around with the code after cloning from github:

```
$ cd vbisect
$ make
$ erl
1> cd(ebin).

2> vbisect:module_info().
     ... info about exports ...

3> Props = [{<<"name">>, <<"joe">>}, {<<"age">>, <<"28">>}, {<<"sex">>, <<"M">>}].
[{<<"name">>,<<"joe">>},
 {<<"age">>,<<"28">>},
 {<<"sex">>,<<"M">>}]

4> orddict:from_list(v(3)).
[{<<"age">>,<<"28">>},
 {<<"name">>,<<"joe">>},
 {<<"sex">>,<<"M">>}]

5> vbisect:from_orddict(v(4)).
<<118,98,105,115,0,0,0,3,0,4,110,97,109,101,0,0,0,15,0,3,
  97,103,101,0,0,0,0,0,0,...>>

6> iolist_to_binary(vbisect:log_summary(v(5), [<<"name">>])).
<<"VBS1: 3 entries (54 bytes) [ name: joe ]">>

```

### Testing

To run tests, you need to install PropEr. You can clone it from
https://github.com/manopapad/proper and then update the Makefile
for vbisect with ERL_LIBS set to the full pathname to your PropEr
installation. Once that is set up, do the following:

```
jay$ pwd
/Users/jay/Git/vbisect

jay$ make
 APP    vbisect.app.src

jay$ make clean
 GEN    clean

jay$ make
 ERLC   vbisect.erl
Old inliner: threshold=0 functions=[{skip_to_smaller_node,1},
                                    {skip_to_bigger_node,3}]
 APP    vbisect.app.src

jay$ make dialyze
  Checking whether the PLT /Users/jay/Git/vbisect/.vbisect.plt is up-to-date... yes
  Proceeding with analysis... done in 0m0.79s
done (passed successfully)

jay$ make tests
 GEN    clean
 ERLC   vbisect.erl
Old inliner: threshold=0 functions=[{skip_to_smaller_node,1},
                                    {skip_to_bigger_node,3}]
 APP    vbisect.app.src
 GEN    build-tests


Common Test v1.7.4 starting (cwd is /Users/jay/Git/vbisect)



CWD set to: "/Users/jay/Git/vbisect/logs/ct_run.ct@yon.2014-03-19_11.43.51"

TEST INFO: 1 test(s), 3 case(s) in 1 suite(s)

Cover compiling 1 modules - this may take some time... done

Testing Git.vbisect.vbisect_SUITE: Starting test, 3 test cases

=INFO REPORT==== 19-Mar-2014::11:43:54 ===
Average over 20 runs, 100000 keys in dict
Average fetch 1000 keys: 38566.0 us, max: 45261 us
Average fetch 1 key: 38.566 us
Theoretical sequential RPS: 25929
Testing Git.vbisect.vbisect_SUITE: TEST COMPLETE, 3 ok, 0 failed of 3 test cases

Cover analysing...
Updating /Users/jay/Git/vbisect/logs/index.html... done
Updating /Users/jay/Git/vbisect/logs/all_runs.html... done

 GEN    tests

yon:vbisect jay$ 
```

### Building with your own application

To include this code in your own erlang application, add the
following to your *.app.src* file:

```
{application, myapp,
 [
  {id, ...},
   ...,
  {included_applications, [vbisect]
]}
```

Then add this to your erlang.mk Makefile:

```
DEPS = vbisect
dep_vbisect = https://github.com/krestenkrab/vbisect.git 0.1.0
```

or this to your rebar.config:

```
  {vbisect, "0.1.0", {git, "git@github.com:krestenkrab/vbisect.git", {tag, "0.1.0"}}}
```


### Contributors

Based on original work at https://github.com/knutin/bisect

- Kresten Krab Thorup @krestenkrab
- Jay Nelson @duomark
