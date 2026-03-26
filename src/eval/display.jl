###############################################################################
# eval/display.jl — terminal-friendly eval report rendering
###############################################################################

"""
    print_eval(report; io=stdout)

Print a human-readable summary of an `EvalReport`.
"""
function print_eval(report::EvalReport; io::IO=stdout)
    bar = "━" ^ 50
    println(io, bar)
    println(io, "  Eval Report")
    println(io, "  Cases      : $(length(report.results))")
    if !isempty(report.results)
        println(io, "  Pass rate  : $(round(report.pass_rate * 100; digits=1))%")
    end
    if report.total_cost > 0
        println(io, "  Total cost : \$$(round(report.total_cost; digits=4))")
    end
    println(io, "  Duration   : $(round(report.total_duration; digits=2))s")

    if !isempty(report.mean_scores)
        println(io)
        println(io, "  Mean scores:")
        for (k, v) in sort(collect(report.mean_scores); by=first)
            println(io, "    $(k) : $(round(v; digits=3))")
        end
    end

    for (i, r) in enumerate(report.results)
        status = if !isnothing(r.error)
            "ERR"
        elseif r.passed
            "PASS"
        else
            "FAIL"
        end

        println(io)
        input_short = length(r.case.input) > 60 ? r.case.input[1:60] * "…" : r.case.input
        println(io, "  Case $(i) [$(status)] — $(input_short)")

        if !isnothing(r.error)
            err_short = length(r.error) > 80 ? r.error[1:80] * "…" : r.error
            println(io, "    error  : $(err_short)")
        else
            out_str = string(something(r.output, "(nothing)"))
            out_short = length(out_str) > 80 ? out_str[1:80] * "…" : out_str
            println(io, "    output : $(out_short)")
        end

        for (k, v) in sort(collect(r.scores); by=first)
            println(io, "    $(k) : $(round(v; digits=3))")
        end
    end

    println(io)
    println(io, bar)
end
