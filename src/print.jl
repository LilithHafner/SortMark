module Print

pluralize(n::Real, name, plural="s", singular="") = "$n $(name)$(n != 1 ? plural : singular)"

function and_join(strs::AbstractVector)
    if length(strs) == 0
        "nothing"
    elseif length(strs) == 1
        strs[1]
    elseif length(strs) == 2
        join(strs, " and ")
    else
        join(strs[1:end-1], ", ") * ", and " * last(strs)
    end
end

function algs(df)
    algs = union(df.algs...)
    unstable = union(df.unstable...)
    and_join([alg ∈ unstable ? "$alg (unstable)" : "$alg" for alg in algs])
end

function domain(df)
    and_join(collect(pluralize(length(unique(a)), n) * z for (a,n,z) in [
        (df.ContainerType, "container type", ""),
        (df.Type, "element type", ""),
        (df.len, "length", " up to $(maximum(df.len))"),
        (df.order, "order", ""),
        (df.source, "distribution", ""),
    ]))
end

function silly_split(str::AbstractString, width=last(displaysize(stdout)))
    last_break=0
    v = collect(str)
    while true
        i = last_break+width
        if i > length(v)
            return typeof(str)(v)
        end
        while true
            if i <= last_break
                return typeof(str)(v)
            end
            if v[i] == ' '
                break
            end
            i -= 1
        end
        v[i] = '\n'
        last_break = i
    end
end

function _print(df, passed_tests, time, benchmark_time, color)
    printstyled(silly_split("$(algs(df)) passed $(pluralize(passed_tests, "test")) spanning"*
    " $(domain(df)) in $(round(Integer, time))s. $(round(Integer, benchmark_time))s"*
    " ($(round(Integer, benchmark_time/time*100))%) spent in benchmarks.\n"), color=color)
end

end
