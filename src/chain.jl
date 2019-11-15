"""
    run_chain!(graph, plan, config)

Run the chain specified by `config`.
"""
function run_chain!(graph::IndexedGraph, plan::Plan, config::ChainConfig,
                    snapshot_dir::AbstractString)
    accepted = 0
    # TODO: handle first step properly (empty flip)
    flips_buffer = Array{Flip}(undef, config.snapshot_interval)
    buffer_index = 1
    snapshot_index = 1
    twister = MersenneTwister(config.seed)
    initial_plan = deepcopy(plan)

    while accepted < config.steps
        proposed_flips = Set{Flip}()
        Threads.@threads for batch_index in 1:Threads.nthreads()
            flip = random_flip(graph, plan, twister)
            flip_valid = true
            for constraint in config.constraints
                if flip.cut_delta === missing && (constraint isa CutEdgesConstraint ||
                                                  constraint isa ContiguityConstraint)
                    flip = add_cut_delta(flip, graph, plan)
                end
                if !valid(constraint, graph, plan, flip)
                    flip_valid = false
                    break
                end
            end
            if flip_valid
                push!(proposed_flips, flip)
            end
        end
        if !isempty(proposed_flips)
            flip = rand(twister, proposed_flips)
            update!(plan, flip)
            accepted += 1
            flips_buffer[buffer_index] = flip
            buffer_index += 1
            if buffer_index > config.snapshot_interval
                dump_stats(graph, initial_plan, config, flips_buffer,
                           snapshot_dir, snapshot_index)
                buffer_index = 1
                snapshot_index += 1
                initial_plan = deepcopy(plan)
            end
        end
    end
end

function update!(plan::Plan, flip::Flip)
    @inbounds plan.assignment[flip.node] = flip.new_assignment
    setdiff!(plan.cut_edges, flip.cut_delta.cut_edges_before)
    union!(plan.cut_edges, flip.cut_delta.cut_edges_after)
    @inbounds plan.district_populations[flip.old_assignment] -= flip.population
    @inbounds plan.district_populations[flip.new_assignment] += flip.population
    plan.n_cut_edges += flip.cut_delta.Δ
end
