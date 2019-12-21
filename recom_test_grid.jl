using JSON
using Profile
using Random
using Distributed
using StatProfilerHTML
include("src/Flips.jl")
using .Flips 

function main()
    graph_data = JSON.parsefile("horizontal.json")
    graph = IndexedGraph(graph_data, "population");
    plan = Plan(graph, "district")
    t = MersenneTwister(0);
    n = 8
    unique_plans = 1
    for i in 1:10000
        println("--- ", i, " ---")
        flip, _, reasons = recom_until_step(graph, plan, 355, 365, t)
        update!(plan, graph, flip)
        unique_plans += 1
        println(reasons)
        if unique_plans % 100 == 0
            println(plan.assignment)
        end
    end
end

main()
