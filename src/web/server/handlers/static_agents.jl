###############################################################################
# web/server/handlers/static_agents.jl — static UI and agent listing handlers
###############################################################################

function _handle_static(req::HTTP.Request)
    ui_path = joinpath(@__DIR__, "..", "..", "ui.html")
    isfile(ui_path) || return HTTP.Response(404, "ui.html not found")
    HTTP.Response(200, ["Content-Type" => "text/html; charset=utf-8"]; body=read(ui_path))
end

function _handle_agents(req::HTTP.Request)
    list = [Dict("id" => name, "name" => name) for name in keys(_agents)]
    HTTP.Response(200, ["Content-Type" => "application/json"]; body=JSON3.write(list))
end
