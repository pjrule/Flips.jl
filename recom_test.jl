using JSON
using Profile
using Random
using Distributed
using StatProfilerHTML
include("src/Flips.jl")
using .Flips 

function main()
    graph_data = JSON.parsefile("PA_VTD.json")
    graph = IndexedGraph(graph_data, "TOTPOP");
    plan = Plan(graph, "CD_2011")
    t = MersenneTwister(0);
    n = 8
    unique_plans = 1
    for i in 1:10000
        println("--- ", i, " ---")
        flip, _, reasons = recom_until_step(graph, plan, 698631, 712744, t)
        update!(plan, graph, flip)
        unique_plans += 1
        println(reasons)
        #for (node, assignment) in zip(flip.nodes, flip.new_assignments)
        #    println("\t ", node - 1, " -> ", assignment)
        #end
        if unique_plans % 100 == 0
            println(plan.assignment)
        end
    end
    #println(unique_plans, " unique plans")
end

main()
