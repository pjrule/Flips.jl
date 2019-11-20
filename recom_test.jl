using JSON
using Profile
using Random
include("src/Flips.jl")
using .Flips 

function main()
    graph_data = JSON.parsefile("test/horizontal.json");
    graph = IndexedGraph(graph_data, "population");
    plan = Plan(graph, "district");
    t = MersenneTwister(1);
    unique_plans = 1
    for i in 1:1000
        flip = reversible_recom(graph, plan, 357, 363, t)
        if flip isa Flip
            println("cut edge delta: ", flip.cut_delta.Δ)
            update!(plan, graph, flip)
            unique_plans += 1
            println("unique plans: ", unique_plans)
            println(plan.assignment)
            println()
        end
    end
end

@profile main()
