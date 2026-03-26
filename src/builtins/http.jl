###############################################################################
# builtins/http.jl — built-in HTTP tools
###############################################################################

using Dates: today, Day

include("http/common.jl")
include("http/get.jl")
include("http/fetch_webpage.jl")
include("http/post.jl")
include("http/github_trending.jl")
