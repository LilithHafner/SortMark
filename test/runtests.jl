using SortMark

df = make_df()

skip = (df.Type .<: Union{UInt64,UInt128}) .&
    (df.source_key .== :small_positive)
compute!(df[(!).(skip), :])
stat!(df)
SortMark
