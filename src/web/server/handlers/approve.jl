###############################################################################
# web/server/handlers/approve.jl — run approval handler
###############################################################################

function _handle_approve(req::HTTP.Request, run_id::String)
    haskey(_runs, run_id) || return HTTP.Response(404, "Run not found: $(run_id)")

    run = _runs[run_id]
    run.status == :interrupted ||
        return HTTP.Response(400, "Run is not awaiting approval (status: $(run.status))")

    body = JSON3.read(String(req.body), Dict{String,Any})
    response = get(body, "response", "approve")

    put!(run.approval_channel, response)
    run.status = :running

    HTTP.Response(
        200, ["Content-Type" => "application/json"]; body=JSON3.write(Dict("ok" => true))
    )
end
