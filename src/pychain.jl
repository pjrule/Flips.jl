"""Wrapper for Python calls."""
function pychain(graph::IndexedGraph, plan::Plan, n_steps::Int, reversible::Bool,
                 min_pop::Int, max_pop::Int, twister::MersenneTwister)::Array{Dict}
    if reversible
        proposal = reversible_recom_until_step
    else
        proposal = recom_until_step
    end
    steps = Array{Dict}(undef, 0)
    step_count = 0
    while step_count < n_steps
        flip, self_loops, reasons = proposal(graph, plan, min_pop, max_pop, twister)
        update!(plan, graph, flip)
        # Use Python indexing
        pyflip = Dict(node - 1 => assignment for (node, assignment)
                      in zip(flip.nodes, flip.new_assignments))
        push!(steps, Dict("flip" => pyflip,
                          "self_loops" => self_loops,
                          "reasons" => reasons,
                          "district_adj" => plan.district_adj))
        step_count += (self_loops + 1)
    end
    return steps
end
