###############################################################################
# builtins/http.jl — built-in HTTP tools
###############################################################################

using Dates: today, Day

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

const fetch_webpage_tool = NimbleTool(
    name        = "fetch_webpage",
    description = "Fetch a webpage and return its readable text content with HTML tags stripped. " *
                  "Useful for reading articles, documentation, or any public webpage. " *
                  "Prefer this over http_get when you need human-readable content rather than raw HTML.",
    parameters  = Dict{String,Any}(
        "type"       => "object",
        "properties" => Dict{String,Any}(
            "url" => Dict{String,Any}(
                "type"        => "string",
                "description" => "The URL of the webpage to fetch.",
            ),
            "max_chars" => Dict{String,Any}(
                "type"        => "integer",
                "description" => "Maximum characters to return (default 8000).",
            ),
        ),
        "required" => ["url"],
    ),
    callable = (args::Dict{Symbol,<:Any}) -> begin
        url       = get(args, :url,       "")
        max_chars = get(args, :max_chars, 8_000)

        resp = try
            HTTP.get(url, ["User-Agent" => "Mozilla/5.0 (compatible; NimbleAgents/0.1)"];
                     redirect=true, status_exception=false)
        catch e
            return "Error fetching $(url): $(sprint(showerror, e))"
        end

        resp.status != 200 && return "Error: HTTP $(resp.status) for $(url)"

        html = String(resp.body)

        # Strip <script> and <style> blocks entirely
        text = replace(html, r"<script[^>]*>.*?</script>"si => "")
        text = replace(text, r"<style[^>]*>.*?</style>"si  => "")
        # Replace block-level tags with newlines to preserve structure
        text = replace(text, r"<(br|p|div|h[1-6]|li|tr|blockquote)[^>]*/?>"i => "\n")
        # Strip all remaining tags
        text = replace(text, r"<[^>]+>" => "")
        # Decode common HTML entities
        text = replace(text, "&amp;"  => "&")
        text = replace(text, "&lt;"   => "<")
        text = replace(text, "&gt;"   => ">")
        text = replace(text, "&quot;" => "\"")
        text = replace(text, "&#39;"  => "'")
        text = replace(text, "&nbsp;" => " ")
        # Collapse runs of blank lines and leading/trailing whitespace per line
        lines = [strip(l) for l in split(text, "\n")]
        lines = filter(!isempty, lines)
        # Collapse consecutive duplicate lines (nav menus repeat a lot)
        deduped = String[]
        for l in lines
            (isempty(deduped) || deduped[end] != l) && push!(deduped, l)
        end
        text = join(deduped, "\n")

        if length(text) > max_chars
            text[1:max_chars] * "\n... (truncated at $(max_chars) chars)"
        else
            text
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

const github_trending_tool = NimbleTool(
    name        = "github_trending",
    description = "Return today's trending GitHub repositories using the GitHub Search API. " *
                  "Results are sorted by stars gained recently and include name, URL, description, " *
                  "language, and star count. Uses GITHUB_TOKEN from the environment if available.",
    parameters  = Dict{String,Any}(
        "type"       => "object",
        "properties" => Dict{String,Any}(
            "language" => Dict{String,Any}(
                "type"        => "string",
                "description" => "Filter by programming language, e.g. \"julia\", \"python\". " *
                                 "Omit for all languages.",
            ),
            "since" => Dict{String,Any}(
                "type"        => "string",
                "description" => "Time window: \"daily\" (default), \"weekly\", or \"monthly\".",
            ),
            "limit" => Dict{String,Any}(
                "type"        => "integer",
                "description" => "Number of repositories to return (default 10, max 30).",
            ),
        ),
        "required" => [],
    ),
    callable = (args::Dict{Symbol,<:Any}) -> begin
        language = get(args, :language, "")
        since    = get(args, :since,    "daily")
        limit    = min(get(args, :limit, 10), 30)

        # Map "since" to a date cutoff
        days   = since == "weekly" ? 7 : since == "monthly" ? 30 : 1
        cutoff = string(today() - Day(days))

        # Build query
        q = "created:>$(cutoff)"
        isempty(language) || (q *= " language:$(language)")

        url = "https://api.github.com/search/repositories" *
              "?q=$(HTTP.URIs.escapeuri(q))&sort=stars&order=desc&per_page=$(limit)"

        headers = [
            "Accept"     => "application/vnd.github+json",
            "User-Agent" => "NimbleAgents/0.1",
        ]
        token = get(ENV, "GITHUB_TOKEN", "")
        isempty(token) || push!(headers, "Authorization" => "Bearer $(token)")

        resp = try
            HTTP.get(url, headers; status_exception=false)
        catch e
            return "Error contacting GitHub API: $(sprint(showerror, e))"
        end

        if resp.status == 403
            return "GitHub API rate limit exceeded. Set GITHUB_TOKEN in .env for higher limits."
        end
        resp.status != 200 &&
            return "GitHub API error (HTTP $(resp.status)): $(String(resp.body))"

        data  = JSON3.read(resp.body)
        items = get(data, :items, [])
        isempty(items) && return "No trending repositories found for the given filters."

        buf = IOBuffer()
        println(buf, "GitHub Trending ($(since), $(isempty(language) ? "all languages" : language)) — $(today())\n")
        for (i, repo) in enumerate(items)
            println(buf, "$(i). $(repo.full_name)")
            println(buf, "   $(repo.html_url)")
            desc = something(get(repo, :description, nothing), "")
            isempty(desc) || println(buf, "   $(desc)")
            println(buf, "   ★ $(repo.stargazers_count)  |  $(something(get(repo, :language, nothing), ""))")
        end
        String(take!(buf))
    end,
)
