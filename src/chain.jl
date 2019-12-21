"""
    run_chain!(graph, plan, config)

Run the chain specified by `config`.
"""
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
