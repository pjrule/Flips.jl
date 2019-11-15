using JSON
using Profile
include("src/Flips.jl")
using .Flips 

function main()
    graph_data = JSON.parsefile("test/horizontal.json")
    graph = IndexedGraph(graph_data, "population")
    initial_plan = Plan(graph, "district")
    config_data = JSON.parsefile("unconstrained_flip_2bil.json")
    config = ChainConfig(graph, initial_plan, config_data)
    @profile run_chain!(graph, initial_plan, config, "stats")
end

main()
