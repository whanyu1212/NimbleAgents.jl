###############################################################################
# builtins/http/post.jl — http_post_tool
###############################################################################

"""
    http_post_tool

Built-in `NimbleTool` that sends JSON POST requests and returns response text.
"""
const http_post_tool = NimbleTool(;
    name="http_post",
    description="Send an HTTP POST request with a JSON body and return the response.",
    parameters=Dict{String,Any}(
        "type" => "object",
        "properties" => Dict{String,Any}(
            "url" => Dict{String,Any}(
                "type" => "string", "description" => "URL to POST to."
            ),
            "body" => Dict{String,Any}(
                "type" => "string",
                "description" => "JSON string to send as the request body.",
            ),
            "headers" => Dict{String,Any}(
                "type" => "string",
                "description" => "Optional JSON object of additional request headers.",
            ),
        ),
        "required" => ["url", "body"],
    ),
    callable=(args::Dict{Symbol,<:Any}) -> begin
        url = get(args, :url, "")
        body = get(args, :body, "")
        headers_json = get(args, :headers, "{}")
        extra_headers = _parse_headers_json(headers_json)
        isnothing(extra_headers) && return "Error: invalid headers JSON: $(headers_json)"

        all_headers = vcat(["Content-Type" => "application/json"], extra_headers)
        try
            resp = HTTP.post(url, all_headers, body)
            _truncate_text(String(resp.body), 20_000)
        catch e
            "Error: $(sprint(showerror, e))"
        end
    end,
)
