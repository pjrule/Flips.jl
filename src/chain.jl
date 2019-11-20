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
        #Threads.@threads for batch_index in 1:Threads.nthreads()
        # TODO: determine when multithreading is worth it!
        for batch_index in 1:1
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
            update!(plan, graph, flip)
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

function update!(plan::Plan, graph::IndexedGraph, flip::Flip)
    assignment_map = Dict{Int, Int}(node => flip.new_assignments[index]
                                    for (index, node) in enumerate(flip.nodes))
    @inbounds for (index, node) in enumerate(flip.nodes)
        old_assignment = flip.old_assignments[index]
        new_assignment = flip.new_assignments[index]
        for neighbor_index in 1:graph.neighbors_per_node[node]
            # Fix the assignments of the edges connected to flipped nodes.
            # For each edge connected to a node in the set of flipped nodes,
            # verify that the assignment on both sides of the edge is the same
            # pre-flip and post-flip. Otherwise, adjust accordingly by removing
            # the edge from the appropriate set in `district_edges`.
            dst = graph.node_neighbors[neighbor_index, node]
            edge_index = graph.src_dst_to_edge[node, dst]
            old_dst_assignment = plan.assignment[dst]
            if dst in keys(assignment_map)
                new_dst_assignment = assignment_map[dst]
            else
                new_dst_assignment = plan.assignment[dst]
            end
            if old_assignment != new_assignment
                if new_dst_assignment != old_assignment
                    delete!(plan.district_edges[old_assignment], edge_index)
                end
                union!(plan.district_edges[new_assignment], edge_index)
            end
            if old_dst_assignment != new_dst_assignment
                if old_dst_assignment != new_assignment
                    delete!(plan.district_edges[old_dst_assignment], edge_index)
                end
                union!(plan.district_edges[new_dst_assignment], edge_index)
            end
        end
        plan.assignment[node] = new_assignment
        delete!(plan.district_nodes[old_assignment], node)
        union!(plan.district_nodes[new_assignment], node)
    end
    setdiff!(plan.cut_edges, flip.cut_delta.cut_edges_before)
    union!(plan.cut_edges, flip.cut_delta.cut_edges_after)
    @inbounds plan.district_populations[flip.left_district] = flip.left_pop
    @inbounds plan.district_populations[flip.right_district] = flip.right_pop
    # Recompute district-level adjacency (district outer boundaries are changed!)
    district_adj = zeros(Int, plan.n_districts, plan.n_districts)
    for edge_index in 1:graph.n_edges
        src, dst = graph.edges[:, edge_index]
        left_district = plan.assignment[src]
        right_district = plan.assignment[dst]
        if left_district != right_district
            district_adj[left_district, right_district] += 1
            district_adj[right_district, left_district] += 1
        end
    end
    plan.district_adj = district_adj
    plan.n_cut_edges += flip.cut_delta.Δ
end
