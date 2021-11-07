# SortMark

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://LilithHafner.github.io/SortMark.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://LilithHafner.github.io/SortMark.jl/dev)
[![Build Status](https://github.com/LilithHafner/SortMark.jl/workflows/CI/badge.svg)](https://github.com/LilithHafner/SortMark.jl/actions)
[![Coverage](https://codecov.io/gh/LilithHafner/SortMark.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/LilithHafner/SortMark.jl)

A package for efficiently benchmarking and testing sorting algorithms under a wide variety of conditions.

Example usage:

```jl
]add https://github.com/LilithHafner/SortMark.jl
using SortMark

df = make_df(); #wow, what's goin on here? I whish this package were better documented.
compute!(df); #this errors... what gives?
#=
6s, Progress:   7%|███▉                                                  |  ETA: 0:00:11
Failed test set stored as SortMark.fail. Reproduce it's error with reproduce().
ERROR: AssertionError: issorted(output, order = order)
Stacktrace:
 [1] log_error!(row::DataFrames.DataFrameRow{DataFrames.DataFrame, DataFrames.Index}, exception::AssertionError, alg::Base.Sort.QuickSortAlg, input::Vector{UInt128}, fail_fast::Bool)
   @ SortMark ~/.julia/dev/SortMark/src/SortMark.jl:238
 [2] trial(row::DataFrames.DataFrameRow{DataFrames.DataFrame, DataFrames.Index}, algs::Vector{Base.Sort.Algorithm}, inputs::Vector{Vector{UInt128}}, fail_fast::Bool)
   @ SortMark ~/.julia/dev/SortMark/src/SortMark.jl:205
 [3] compute!(row::DataFrames.DataFrameRow{DataFrames.DataFrame, DataFrames.Index}, fail_fast::Bool)
   @ SortMark ~/.julia/dev/SortMark/src/SortMark.jl:166
 [4] macro expansion
   @ ~/.julia/dev/SortMark/src/SortMark.jl:109 [inlined]
 [5] macro expansion
   @ ~/.julia/packages/ProgressMeter/Vf8un/src/ProgressMeter.jl:940 [inlined]
 [6] compute!(df::DataFrames.DataFrame; verbose::Bool, fail_fast::Bool)
   @ SortMark ~/.julia/dev/SortMark/src/SortMark.jl:108
 [7] compute!(df::DataFrames.DataFrame)
   @ SortMark ~/.julia/dev/SortMark/src/SortMark.jl:94
 [8] top-level scope
   @ none:1
=#
# And what's that fancily colored text above the error message?
# hmm... "Failed test set stored as SortMark.fail"
SortMark.fail
#=
DataFrameRow
 Row │ ContainerType      Type    len    order                              source_key     ⋯
     │ Type…              Type    Int64  Ordering…                          Symbol         ⋯
─────┼──────────────────────────────────────────────────────────────────────────────────────
 765 │ Vector{T} where T  UInt64   3162  ReverseOrdering{ForwardOrdering}…  small_positive ⋯
                                                                           8 columns omitted
=#
#So... I see we've got a problem for sorting arrays of 3162 small_positive unsigned 64-bit 
#integers into reverse order, whatever that means... Seems highly unlikely. Here, look:
sort(rand(UInt64(0):UInt64(10), 3162), rev=true)
#=
3162-element Vector{UInt64}:
 0x0000000000000004
 0x0000000000000002
 0x0000000000000005
 0x0000000000000007
 0x0000000000000005
 0x0000000000000003
 0x0000000000000003
 0x0000000000000007
                  ⋮
 0x0000000000000006
 0x000000000000000a
 0x0000000000000001
 0x0000000000000000
 0x0000000000000006
 0x0000000000000007
 0x0000000000000005
=#
#wait a second, what the *** is happening??
#turns out this specific corner case for sorting is broken in julia. See https://github.com/JuliaLang/julia/pull/42718.

#coolbeans, wow. It runs tests. But I don't care about this edge case, let me start benchmarking!
compute!(df, fail_fast=false);
julia> compute!(df, fail_fast=false);
#=
6s, Progress: 100%|█████████████████████████████████████████████████| Time: 0:00:08
ERROR: Some tests did not pass: 237880 passed, 0 failed, 64 errored.
Base.Sort.MergeSortAlg() and Base.Sort.QuickSortAlg() (unstable) passed 237880 tests
spanning 1 container type, 15 element types, 11 lengths up to 100000, 2 orders, and 4
distributions in 9s. 3s (37%) spent in benchmarks.
SortMark.fail is an example of a failed set of tests. Reproduce it's error with reproduce().
=#
# Great! Errors. I love errors. Let's ignore them. Moving on...
stat!(df); #what a generic name, what is going on here?
df.pvalue
#=
1298-element Vector{Union{Missing, Float64}}:
 0.07382948536988579
 0.08300533865888364
 0.17255705413564795
 0.043603017750311335
 ⋮
 0.1296444186512252
 0.2606328408111021
 0.13892181597945655
 0.21527141177932066
 =#
#we are comparing the runtime of two different soring algorithms:
df.algs[1]
#=
2-element Vector{Base.Sort.Algorithm}:
 Base.Sort.MergeSortAlg()
 Base.Sort.QuickSortAlg()
=#
#and those are the p-values indicating wheather we have a statistically significant difference.
#those pvalues are too high for my analysis. Let's get more data.
df.seconds .*= 10; #This will also make it take longer, oh well; more time to oggle at the beautiful loading bar courtesy of ProgressMeter.jl
compute!(df, fail_fast=false); # fun fact, the old data is still here. We just add more! If you want to clear the data, make a new df! (later there might be a better way)
#=
65s, Progress: 100%|██████████████████████████████████████████████████████████████████████████████████████████████████████████████| Time: 0:01:08
ERROR: Some tests did not pass: 2874132 passed, 0 failed, 780 errored.
Base.Sort.MergeSortAlg() and Base.Sort.QuickSortAlg() (unstable) passed 2874132 tests spanning 1 container type, 15 element types, 11 lengths up to
100000, 2 orders, and 4 distributions in 69s. 23s (33%) spent in benchmarks.
SortMark.fail is an example of a failed set of tests. Reproduce it's error with reproduce().
=#
#Can we take a moment to look at the numbers that just printed, that's alot of tests running! and over quite a range of inputs. Only 33% of time spent benchmarking, that doesn't sound good. When I tried this with BenchmarkTools, though, t = @timed @benchmark sort(x) setup=(x=rand(10_000)); sum(t.value.times*1e-9)/t.time gives me a similar 37%.
#Back to the data. We have to recompute stats
stat!(df);
df.pvalue
#=
1298-element Vector{Float64}:
 1.038512836886463e-6
 1.4407708601335978e-12
 0.00031705574988325153
 2.1261920179458133e-25
 ⋮
 0.16674400469382414
 0.2926325656250292
 0.2092427712164047
 0.25919129227369314
=#
# Okay some of those p-values are quite low.
mean(df.pvalue .< .05)
# 0.8828967642526965
# and most of them are significant. What is the speed ratio?
df.point_estimate
#=
1298-element Vector{Float64}:
 1.520647201551295
 1.4571719750761662
 1.3179061226433113
 1.436741386153265
 ⋮
 1.012936243595496
 1.0125157172530284
 0.9624269936973555
 1.0199318692241786
 =#
 #looks like that ratio is either 1.5 or 1? who knows? and what's the certianty?
 df.confint
 #=
 1298-element Vector{Tuple{Float64, Float64}}:
 (1.4132192824122347, 1.636241410206905)
 (1.4028173986436836, 1.513632613197085)
 (1.1469008134953327, 1.5144086809105701)
 (1.400298646448291, 1.4741325473114575)
 ⋮
 (0.994382971723014, 1.0318356838024756)
 (0.9889886111508599, 1.036602511015198)
 (0.9052958042424497, 1.0231636044888415)
 (0.9849999662469475, 1.0561025923916885)
 =#
 #Better. Is MergeSort ever faster?
minimum(last.(df.confint))
# 0.975616697789511 Apparently, but probably not by a huge amount. Let's investigate.
df[minimum(last.(df.confint)) .== last.(df.confint), :]
#=
 1×17 DataFrame
 Row │ ContainerType      Type  len    order              source_key  source    algs                            ⋯
     │ Type…              Type  Int64  Ordering…          Symbol      Function  Array…                          ⋯
─────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ Vector{T} where T  Bool     10  ForwardOrdering()  simple      #1        Base.Sort.Algorithm[MergeSortAl ⋯
                                                                                               11 columns omitted
=#
#Sorting 10 Bools... this is incredibly bizzare. Why would anyone do this? Why would we use comparison sorting?
#What even is the p-value?
findfirst(minimum(last.(df.confint)) .== last.(df.confint))
#1229
df.pvalues
#0.009056184456237987
#See, that's only .01, and we were p-hacking. We'll just repeat a more fucused study with fresh data:
empty!(df.data[1229]);
df.seconds[1229] = 1
compute!(df[1229, :]);
df.confint[1229]
#(0.97468593850494, 0.9843292697105394)
df.pvalue[1229]
#1.971128265512963e-16
#Hmm... something is afoot...
#etc. etc.
```
