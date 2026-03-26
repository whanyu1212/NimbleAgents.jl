###############################################################################
# builtins/http/github_trending.jl — github_trending_tool
###############################################################################

"""
    github_trending_tool

Built-in `NimbleTool` that queries GitHub Search API for trending repositories.
"""
const github_trending_tool = NimbleTool(;
    name="github_trending",
    description="Return today's trending GitHub repositories using the GitHub Search API. " *
                "Results are sorted by stars gained recently and include name, URL, description, " *
                "language, and star count. Uses GITHUB_TOKEN from the environment if available.",
    parameters=Dict{String,Any}(
        "type" => "object",
        "properties" => Dict{String,Any}(
            "language" => Dict{String,Any}(
                "type" => "string",
                "description" =>
                    "Filter by programming language, e.g. \"julia\", \"python\". " *
                    "Omit for all languages.",
            ),
            "since" => Dict{String,Any}(
                "type" => "string",
                "description" => "Time window: \"daily\" (default), \"weekly\", or \"monthly\".",
            ),
            "limit" => Dict{String,Any}(
                "type" => "integer",
                "description" => "Number of repositories to return (default 10, max 30).",
            ),
        ),
        "required" => [],
    ),
    callable=(args::Dict{Symbol,<:Any}) -> begin
        language = get(args, :language, "")
        since = get(args, :since, "daily")
        limit = min(get(args, :limit, 10), 30)

        # Map "since" to a date cutoff
        days = if since == "weekly"
            7
        elseif since == "monthly"
            30
        else
            1
        end
        cutoff = string(today() - Day(days))

        # Build query
        q = "created:>$(cutoff)"
        isempty(language) || (q *= " language:$(language)")

        url =
            "https://api.github.com/search/repositories" *
            "?q=$(HTTP.URIs.escapeuri(q))&sort=stars&order=desc&per_page=$(limit)"

        headers = [
            "Accept" => "application/vnd.github+json",
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

        data = JSON3.read(resp.body)
        items = get(data, :items, [])
        isempty(items) &&
            return "No trending repositories found for the given filters."

        buf = IOBuffer()
        println(
            buf,
            "GitHub Trending ($(since), $(isempty(language) ? "all languages" : language)) — $(today())\n",
        )
        for (i, repo) in enumerate(items)
            println(buf, "$(i). $(repo.full_name)")
            println(buf, "   $(repo.html_url)")
            desc = something(get(repo, :description, nothing), "")
            isempty(desc) || println(buf, "   $(desc)")
            println(
                buf,
                "   ★ $(repo.stargazers_count)  |  $(something(get(repo, :language, nothing), ""))",
            )
        end
        String(take!(buf))
    end,
)
