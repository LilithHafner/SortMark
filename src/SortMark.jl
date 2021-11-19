module SortMark

export make_df, compute!, reproduce, stat!

using DataFrames: DataFrame, DataFrameRow
using Random: shuffle, shuffle!
using Base.Order
using Base.Sort: Algorithm
using Statistics
using HypothesisTests
using ProgressMeter
include("print.jl")

## Types
const Ints = [Int64, Int8, Int32, Int16, Int128]
const UInts = unsigned.(Ints)
const Floats = [Float64, Float32, Float16]
const BitTypes = vcat(Ints, Floats, UInts, Char, Bool)

matched_UInt(::Type{Float64}) = UInt64
matched_UInt(::Type{Float32}) = UInt32
matched_UInt(::Type{Float16}) = UInt16
matched_UInt(T::Type{<:Signed}) = unsigned(T)
matched_UInt(T::Type{<:Unsigned}) = T
matched_UInt(::Type{Char}) = UInt32


## Special Values
special_values(T) = T
function special_values(T::Type{<:AbstractFloat})
    U = matched_UInt(T)
    T[-π, -1.0, -1/π, 1/π, 1.0, π, -0.0, 0.0, Inf, -Inf, NaN, -NaN,
        prevfloat(T(0)), nextfloat(T(0)), prevfloat(T(Inf)), nextfloat(T(-Inf)),
        reinterpret(T, reinterpret(U, T(NaN)) | 0x73), reinterpret(T, reinterpret(U, -T(NaN)) | 0x37)]
end
function special_values(T::Type{<:Union{Signed, Unsigned}})
    T[17, -T(17), 0, -one(T), 1, typemax(T), typemin(T), typemax(T)-1, typemin(T)+1]
end
special_values(T::Type{Bool}) = [true, false]

bit_random(T::Type{Bool}, len::Integer) = rand(T, len)
bit_random(T::Type, len::Integer) = reinterpret.(T, rand(matched_UInt(T), len))

## Sources (perhaps chagne this to a module-level function with dispatch by symbol)
const sources = Dict(
    :simple => (T, len) -> rand(T, len),
    :special => (T, len) -> rand(special_values(T), len),
    :tricky => (T, len) -> vcat(
        rand(special_values(T), len-2*(len÷3)),
        rand(T, len÷3),
        bit_random(T, len÷3)),
    :small_positive => (T::Type{<:Real}, len) -> rand(T.(1:min(1_000, typemax(T))), len)
)


## Lengths
function lengths(min=1, max=100_000, spacing=3)
    length = 1+round(Integer, (log(max)-log(min))/log(spacing))
    source = exp.(range(log(min), log(max), length=length))
    sort!(collect(Set(round.(Integer, source))))
end

## Orders
const orders = [Forward, Reverse]


##Data frame (this could be much faster if it constructed by column instead of row)
"""
    make_df(algs = [MergeSort, QuickSort]; ...)

Make a dataframe where each row is a sorting task specified by the cartesian product of
keyword arguments.

# Arguments

- `algs::AbstractVector{<:Base.Sort.Algorithm} = [MergeSort, QuickSort]`:
    sorting algorithms to test
- `unstable::AbstractVector{<:Base.Sort.Algorithm} = [QuickSort]`:
    which of the algorithms are allowed to be unstable

Axes of the cartesian product
- `Types::AbstractVector{<:Type} = SortMark.BitTypes`:
    element type
- `lens::AbstractVector{<:Integer} = SortMark.lengths()`:
    number of elements to be sorted
- `orders::AbstractVector{<:Ordering} = SortMark.orders`:
    orders to sort by
- `sources::AbstractDict{<:Any, <:Function} = SortMark.sources`:
    generation procedures to create input data

Benchmarking time
- `seconds::Union{Real, Nothing} = .005`:
    maximum benchmarking time for each row. Compute sum(df.seconds) for an estimated
    benchmarking runtime
- `samples::Union{Nothing, Integer} = nothing`:
    maximum number of samples for each row. Compute sum(df.seconds) for an estimated
    benchmarking runtime

Setting `seconds` or `samples` to `nothing` removes that limit.
"""
function make_df(algs::AbstractVector{Algorithm} = [MergeSort, QuickSort];
    Types::AbstractVector{<:Type} = BitTypes,
    lens::AbstractVector{<:Integer} = lengths(),
    orders::AbstractVector{<:Ordering} = orders,
    sources::AbstractDict{<:Any, <:Function} = sources, unstable = [QuickSort],
    seconds::Union{Real, Nothing} = .005,
    samples::Union{Integer, Nothing} = seconds==nothing ? 1 : nothing)

    df = DataFrame(ContainerType=Type{<:AbstractVector}[], Type=Type[], len=Int[],
        order=Ordering[], source_key=Symbol[], source=Function[], algs=Vector{<:Algorithm}[], unstable=Vector{<:Algorithm}[],
        evals=Int[], samples=Union{Nothing, Int}[], seconds=Union{Nothing, Float64}[], data=DataFrame[],
        errors=Dict[])

    for Type in Types, len in lens, order in orders, (source_key, source) in pairs(sources)
        if source_key == :small_positive && !(Type <: Real); continue; end
        push!(df, (Vector, Type, len, order, source_key, source, algs, unstable,
                   max(1, 1_000 ÷ max(len, 1)), samples, seconds, DataFrame([Float64[] for _ in algs], Symbol.(algs)),
                   Dict()))
    end
    df
end

##Compute data
function target!(vec, alg, order)
    sort!(vec, alg=alg, order=order)
end

const PASSED_TESTS = Ref(0)

"""
    compute!(df::DataFrame; verbose=true, fail_fast=true)

Test and run benchmarks for every row in `df`.

Benchmark results are saved in df.data.
"""
function compute!(df::DataFrame; verbose=true, fail_fast=true)
    start_time = time()
    benchmark_start_time = sum(sum(sum.(eachcol(d))) for d in df.data)
    start_passed_tests = PASSED_TESTS[]
    empty!.(df.errors)

    rows = shuffle(eachrow(df))#TODO make this appear immediately
    nominal_runtime = sum([s==nothing ? .001 : s for s in df.seconds])

    if nominal_runtime > 1
        dt = max(.1, min(1, nominal_runtime/100))
        message = "$(round(Integer, nominal_runtime))s, Progress: "
        printstyled(message, "    ", color=:green)

        try
            @showprogress dt message for row in rows
                compute!(row, fail_fast)
            end
        catch
            printstyled("\nFailed test set stored as SortMark.fail. Reproduce it's error with reproduce().\n", color=Base.debug_color())
            rethrow()
        end
    else
        for row in rows
            compute!(row, fail_fast)
        end
    end


    np, nf, ne = PASSED_TESTS[]-start_passed_tests, 0, 0
    for dict in df.errors, vect in values(dict), err in vect
        if err isa AssertionError
            nf += 1
        else
            ne += 1
        end
    end

    end_time = time()
    benchmark_end_time = sum(sum(sum.(eachcol(d))) for d in df.data)

    if !all(isempty.(df.errors))
        global fail = deepcopy(df[findfirst((!).(isempty.(df.errors))), :])

        color = Base.error_color()
        printstyled("ERROR: Some tests did not pass: $np passed, $nf failed, $ne errored.\n", color=color)
        verbose && Print._print(df, np, end_time-start_time, benchmark_end_time-benchmark_start_time, color)
        printstyled("SortMark.fail is an example of a failed set of tests. Reproduce it's error with reproduce().\n", color=Base.debug_color())
    elseif verbose
        Print._print(df, np, end_time-start_time, benchmark_end_time-benchmark_start_time, :normal)
    end

    df
end

function compute!(row::DataFrameRow, fail_fast=true)
    Base.require_one_based_indexing(row.algs)

    gen() = row.ContainerType(row.source(row.Type, row.len))

    if row.samples == nothing && row.seconds == nothing
        println("WARNING: row=$row has unbounded samples=$samples and seconds=$seconds.
Because of this absence of an end condition it will hang.")
    end

    sample = 1

    start_time = time()
    while (row.samples == nothing || sample <= row.samples) &&
          (row.seconds == nothing || time() < start_time+row.seconds)

        perm = shuffle!(collect(axes(row.algs, 1)))

        times = trial(row, row.algs[perm], [gen() for _ in 1:row.evals], fail_fast)

        push!(row.data, times[invperm(perm)])

        sample += 1
    end

    row
end
function trial(row, algs, inputs, fail_fast)
    Base.require_one_based_indexing(algs)

    stable_output = nothing
    test_index = rand(eachindex(inputs))

    times = []
    order = row.order
    for alg in algs
        cinputs = copy.(inputs)
        outputs = similar(inputs)
        t = @elapsed for i in eachindex(inputs, cinputs, outputs)
            try
                outputs[i] = target!(cinputs[i], alg, order)
            catch x
                log_error!(row, x, alg, copy(inputs[i]), fail_fast)
            end
        end
        push!(times, t/length(inputs))

        try
            test_sorted(outputs[test_index], cinputs[test_index], inputs[test_index], row.order)
            if alg ∉ row.unstable
                if stable_output == nothing
                    stable_output = outputs[test_index]
                else
                    test_matched(stable_output, outputs[test_index])
                end
            end
        catch x
            log_error!(row, x, alg, copy(inputs[test_index]), fail_fast)
        end
    end

    times
end

function test_sorted(output, cinput, input, order)
    @assert cinput === output
    PASSED_TESTS[] += 1
    @assert issorted(output, order=order)
    PASSED_TESTS[] += 1
    @assert typeof(input) == typeof(output)
    PASSED_TESTS[] += 1
    @assert axes(input) == axes(output)
    PASSED_TESTS[] += 1
    nothing
end

function test_matched(a, b)
    @assert all(a .=== b)
    PASSED_TESTS[] += 1
    nothing
end

function log_error!(row, exception, alg, input, fail_fast)
    entry = (exception, input)
    if alg ∉ keys(row.errors)
        row.errors[alg] = []
    end
    push!(row.errors[alg], entry)
    if fail_fast
        global fail = row
        throw(exception)
    end
end

fail = nothing
function reproduce(row=fail, alg=nothing)
    if fail == nothing || isempty(row.errors)
        return "no errors"
    end
    if alg == nothing
        alg = first(keys(row.errors))
    end

    x, input = first(row.errors[alg])
    cinput = copy(input)
    println("sort!($cinput, "* (row.order != Forward ? "order=$(row.order), " : "")*"alg=$alg)")
    output = target!(cinput, alg, row.order)
    test_sorted(output, cinput, input, row.order)
    test_matched(output, sort!(input, alg=MergeSort))

    "no errors"
end

##Statistics
"""
    function stat!(df, a=1, b=2)

Compute comparative stats for the `a`th and `b`th algorithm tested in `df`.

Returns the 95% confidence interval for the ratio of runtimes a/b for each row.
"""
function stat!(df, a=1, b=2)
    df.log_test = [length(eachrow(d)) <= 1 ? missing : OneSampleTTest(d[!,1]-d[!,2]) for d in [log.(frame) for frame in df.data]]
    df.pvalue = [ismissing(t) ? missing : pvalue(t) for t in df.log_test]
    df.point_estimate = [ismissing(t) ? missing : exp(mean(confint(t))) for t in df.log_test]
    df.confint = [ismissing(t) ? missing : exp.(confint(t)) for t in df.log_test]
end

end #module
