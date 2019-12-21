using JSON
using Profile
using Random
using Distributed
using StatProfilerHTML
include("src/Flips.jl")
using .Flips 

#const graph_data = JSON.parsefile("PA_VTD.json")
#const graph = IndexedGraph(graph_data, "TOTPOP");
#plan = Plan(graph, "CD_2011")
const graph_data = JSON.parsefile("horizontal_100.json")
const graph = IndexedGraph(graph_data, "population");
plan = Plan(graph, "district")
const t = MersenneTwister(getpid());  # TODO: make this better

function flip_batch(size::Int)::Array{AbstractFlip}
    # Pennsylvania bounds: (702159, 716273)
    return [reversible_recom(graph, plan, 990, 1010, t)
            for _ in 1:size]
end

function local_update(flip::Flip)
    update!(plan, graph, flip)
end
