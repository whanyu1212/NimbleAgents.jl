###############################################################################
# builtins/http.jl — built-in HTTP tools
###############################################################################

const http_get_tool = NimbleTool(
    name        = "http_get",
    description = "Fetch a URL with an HTTP GET request and return the response body as a string.",
    parameters  = Dict{String,Any}(
        "type"       => "object",
        "properties" => Dict{String,Any}(
            "url" => Dict{String,Any}(
                "type"        => "string",
                "description" => "URL to fetch.",
            ),
            "headers" => Dict{String,Any}(
                "type"        => "string",
                "description" => "Optional JSON object of request headers, e.g. '{\"Accept\": \"application/json\"}'.",
            ),
        ),
        "required" => ["url"],
    ),
    callable = (args::Dict{Symbol,<:Any}) -> begin
        url     = get(args, :url,     "")
        headers = get(args, :headers, "{}")
        parsed_headers = try
            h = JSON3.read(headers, Dict{String,String})
            [k => v for (k, v) in h]
        catch
            return "Error: invalid headers JSON: $(headers)"
        end
        try
            resp = HTTP.get(url, parsed_headers)
            body = String(resp.body)
            # Truncate very large responses
            length(body) > 20_000 ?
                body[1:20_000] * "\n... (truncated at 20000 chars)" :
                body
        catch e
            "Error: $(sprint(showerror, e))"
        end
    end,
)

const http_post_tool = NimbleTool(
    name        = "http_post",
    description = "Send an HTTP POST request with a JSON body and return the response.",
    parameters  = Dict{String,Any}(
        "type"       => "object",
        "properties" => Dict{String,Any}(
            "url" => Dict{String,Any}(
                "type"        => "string",
                "description" => "URL to POST to.",
            ),
            "body" => Dict{String,Any}(
                "type"        => "string",
                "description" => "JSON string to send as the request body.",
            ),
            "headers" => Dict{String,Any}(
                "type"        => "string",
                "description" => "Optional JSON object of additional request headers.",
            ),
        ),
        "required" => ["url", "body"],
    ),
    callable = (args::Dict{Symbol,<:Any}) -> begin
        url     = get(args, :url,     "")
        body    = get(args, :body,    "")
        headers = get(args, :headers, "{}")
        extra_headers = try
            h = JSON3.read(headers, Dict{String,String})
            [k => v for (k, v) in h]
        catch
            return "Error: invalid headers JSON: $(headers)"
        end
        all_headers = vcat(["Content-Type" => "application/json"], extra_headers)
        try
            resp = HTTP.post(url, all_headers, body)
            result = String(resp.body)
            length(result) > 20_000 ?
                result[1:20_000] * "\n... (truncated at 20000 chars)" :
                result
        catch e
            "Error: $(sprint(showerror, e))"
        end
    end,
)
