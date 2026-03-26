###############################################################################
# builtins/http/get.jl — http_get_tool
###############################################################################

"""
    http_get_tool

Built-in `NimbleTool` that performs HTTP GET requests and returns response text.
"""
const http_get_tool = NimbleTool(;
    name="http_get",
    description="Fetch a URL with an HTTP GET request and return the response body as a string.",
    parameters=Dict{String,Any}(
        "type" => "object",
        "properties" => Dict{String,Any}(
            "url" =>
                Dict{String,Any}("type" => "string", "description" => "URL to fetch."),
            "headers" => Dict{String,Any}(
                "type" => "string",
                "description" => "Optional JSON object of request headers, e.g. '{\"Accept\": \"application/json\"}'.",
            ),
        ),
        "required" => ["url"],
    ),
    callable=(args::Dict{Symbol,<:Any}) -> begin
        url = get(args, :url, "")
        headers_json = get(args, :headers, "{}")
        parsed_headers = _parse_headers_json(headers_json)
        isnothing(parsed_headers) &&
            return "Error: invalid headers JSON: $(headers_json)"

        try
            resp = HTTP.get(url, parsed_headers)
            _truncate_text(String(resp.body), 20_000)
        catch e
            "Error: $(sprint(showerror, e))"
        end
    end,
)
