"""Wrapper for Python calls."""
function pychain(graph::IndexedGraph,
                 plan::Plan,
                 n_steps::Int,
                 reversible::Bool,
                 min_pop::Int,
                 max_pop::Int,
                 twister::MersenneTwister,
                 params::Dict)::Dict
    if reversible
        proposal = reversible_recom_until_step
    else
        proposal = recom_until_step
    end
    steps = Array{Dict}(undef, 0)
    step_count = 0
    initial_assignment = Dict(node - 1 => assignment for (node, assignment)
                              in enumerate(plan.assignment))
    max_balanced_cuts = 0
    proposal_args = Dict(Symbol(k) => v for (k, v) in params)
    while step_count < n_steps
        flip, self_loops, reasons = proposal(graph, plan, min_pop, max_pop, twister;
                                             (; proposal_args...)...)
        max_balanced_cuts = maximum([max_balanced_cuts, flip.balanced_cuts])
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
    return Dict("initial_assignment" => initial_assignment,
                "steps" => steps,
                "max_balanced_cuts" => max_balanced_cuts)
end
