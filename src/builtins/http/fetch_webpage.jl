###############################################################################
# builtins/http/fetch_webpage.jl — fetch_webpage_tool
###############################################################################

"""
    fetch_webpage_tool

Built-in `NimbleTool` that fetches a webpage and returns cleaned readable text.
"""
const fetch_webpage_tool = NimbleTool(;
    name="fetch_webpage",
    description="Fetch a webpage and return its readable text content with HTML tags stripped. " *
                "Useful for reading articles, documentation, or any public webpage. " *
                "Prefer this over http_get when you need human-readable content rather than raw HTML.",
    parameters=Dict{String,Any}(
        "type" => "object",
        "properties" => Dict{String,Any}(
            "url" => Dict{String,Any}(
                "type" => "string",
                "description" => "The URL of the webpage to fetch.",
            ),
            "max_chars" => Dict{String,Any}(
                "type" => "integer",
                "description" => "Maximum characters to return (default 8000).",
            ),
        ),
        "required" => ["url"],
    ),
    callable=(args::Dict{Symbol,<:Any}) -> begin
        url = get(args, :url, "")
        max_chars = get(args, :max_chars, 8_000)

        resp = try
            HTTP.get(
                url,
                ["User-Agent" => "Mozilla/5.0 (compatible; NimbleAgents/0.1)"];
                redirect=true,
                status_exception=false,
            )
        catch e
            return "Error fetching $(url): $(sprint(showerror, e))"
        end

        resp.status != 200 && return "Error: HTTP $(resp.status) for $(url)"

        html = String(resp.body)

        # Strip <script> and <style> blocks entirely
        text = replace(html, r"<script[^>]*>.*?</script>"si => "")
        text = replace(text, r"<style[^>]*>.*?</style>"si => "")
        # Replace block-level tags with newlines to preserve structure
        text = replace(text, r"<(br|p|div|h[1-6]|li|tr|blockquote)[^>]*/?>"i => "\n")
        # Strip all remaining tags
        text = replace(text, r"<[^>]+>" => "")
        # Decode common HTML entities
        text = replace(text, "&amp;" => "&")
        text = replace(text, "&lt;" => "<")
        text = replace(text, "&gt;" => ">")
        text = replace(text, "&quot;" => "\"")
        text = replace(text, "&#39;" => "'")
        text = replace(text, "&nbsp;" => " ")
        # Collapse runs of blank lines and leading/trailing whitespace per line
        lines = [strip(l) for l in split(text, "\n")]
        lines = filter(!isempty, lines)
        # Collapse consecutive duplicate lines (nav menus repeat a lot)
        deduped = String[]
        for l in lines
            (isempty(deduped) || deduped[end] != l) && push!(deduped, l)
        end
        _truncate_text(join(deduped, "\n"), Int(max_chars))
    end,
)
