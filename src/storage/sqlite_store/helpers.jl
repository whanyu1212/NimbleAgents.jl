###############################################################################
# storage/sqlite_store/helpers.jl — row materialization helper
###############################################################################

# SQLite.jl 1.8 Row objects become stale after the query iterator advances,
# so `collect(result)` yields rows whose fields are all `missing`.
# Work around this by materialising each row into a NamedTuple during iteration.
function _collect_rows(result)
    rows = NamedTuple[]
    for row in result
        names = propertynames(row)
        vals = Tuple(getproperty(row, n) for n in names)
        push!(rows, NamedTuple{Tuple(names)}(vals))
    end
    rows
end
