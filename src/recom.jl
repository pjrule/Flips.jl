function recom(graph::IndexedGraph, plan::Plan, min_pop::Int, max_pop::Int,
               twister::MersenneTwister)::Union{Flip, DummyFlip}
    # Step 1: Choose a random district pairing.
    # IIRC, Sarah said that a non-adjacent district pairing counts as a step.
    # (I would like to understand precisely why.)
    left_district = rand(twister, 1:plan.n_districts)
    right_district = rand(twister, 1:plan.n_districts)
    if plan.district_adj[left_district, right_district] == 0
        return DummyFlip("non-adjacent district pair")
    end
    # Step 2: Sample a spanning tree.
    mst_edges = random_mst(graph, plan, left_district, right_district, twister)
    # Step 3: Find the set of ϵ-balanced cuts.
    cuts = balanced_cuts(graph, plan, left_district, right_district,
                         mst_edges, min_pop, max_pop)
    # If the spanning tree does not induce any ϵ-balanced cuts, return a dummy step.
    if isempty(cuts)
        return DummyFlip("no balanced cut")
    end
    # Otherwise, accept an edge with probability 1/E(A, B), where E(A, B) is the seam
    # length (number of cut edges) between the two districts formed.
    mst_cut_edge = rand(twister, cuts)
    new_assignment = cut_assignment(graph, plan, left_district, right_district,
                                    mst_edges, mst_cut_edge)
    # Generate a new Flip from the assignment.
    n_flipped = length(new_assignment)
    nodes = Array{Int}(undef, n_flipped)
    populations = Array{Int}(undef, n_flipped)
    old_assignments = Array{Int}(undef, n_flipped)
    new_assignments = Array{Int}(undef, n_flipped)
    @inbounds for (index, (node, assignment)) in enumerate(new_assignment)
        nodes[index] = node
        populations[index] = graph.population[node]
        old_assignments[index] = plan.assignment[node]
        new_assignments[index] = assignment
    end
    left_pop = plan.district_populations[left_district]
    right_pop = plan.district_populations[right_district]
    for index in 1:n_flipped
        if new_assignments[index] == left_district
            left_pop += populations[index]
            right_pop -= populations[index]
        else
            right_pop += populations[index]
            left_pop -= populations[index]
        end
    end
    return add_cut_delta(Flip(nodes, populations, left_district, right_district,
                              left_pop, right_pop, old_assignments,
                              new_assignments, missing, length(cuts)), graph, plan)
end

function reversible_recom(graph::IndexedGraph, plan::Plan, min_pop::Int, max_pop::Int,
                          twister::MersenneTwister)::Union{Flip, DummyFlip}
    flip = recom(graph, plan, min_pop, max_pop, twister)
    if flip isa Flip
        left = flip.left_district
        right = flip.right_district
        seam_length = plan.district_adj[left, right] + flip.cut_delta.Δ
        if rand(twister) < 1 / seam_length
            return flip  # accept with probability 1 / seam_length
        else
            return DummyFlip("seam length rejection")
        end
    end
    return flip  # DummyFlip with reason
end

function until_step(graph::IndexedGraph, plan::Plan, proposal::Function,
                    min_pop::Int, max_pop::Int,
                    twister::MersenneTwister)::Tuple{Flip, Int, Dict{AbstractString, Int}}
    self_loops = 0
    flip = proposal(graph, plan, min_pop, max_pop, twister)
    reasons = DefaultDict{AbstractString, Int}(0)
    while flip isa DummyFlip
        self_loops += 1
        reasons[flip.reason] += 1
        flip = proposal(graph, plan, min_pop, max_pop, twister)
    end
    return flip, self_loops, Dict(reasons)
end

function recom_until_step(graph::IndexedGraph, plan::Plan, 
                          min_pop::Int, max_pop::Int,
                          twister::MersenneTwister)::Tuple{Flip, Int,
                                                           Dict{AbstractString, Int}}
    return until_step(graph, plan, recom, min_pop, max_pop, twister)
end

function reversible_recom_until_step(graph::IndexedGraph, plan::Plan,
                                     min_pop::Int, max_pop::Int,
                                     twister::MersenneTwister)::Tuple{Flip, Int,
                                                                      Dict{AbstractString,
                                                                           Int}}
    return until_step(graph, plan, reversible_recom, min_pop, max_pop, twister)
end

function cut_assignment(graph::IndexedGraph, plan::Plan, left_district::Int,
                        right_district::Int, mst_edges::BitSet,
                        mst_cut_edge::Int)::Dict{Int, Int}
    # Traverse both halves of the MST.
    left_start_node, right_start_node = graph.edges[:, mst_cut_edge]
    left_nodes = traverse_mst(graph, mst_edges, left_start_node, right_start_node)
    right_nodes = traverse_mst(graph, mst_edges, right_start_node, left_start_node)
    # Find the best assignment based on the current plan.
    # (We want to minimize the number of reassigned nodes, which cuts down
    #  on computation and, as a nice side effect, usually results in better
    #  animations.)
    left_overlap_count = 0
    right_overlap_count = 0
    for node in left_nodes
        if plan.assignment[node] == left_district
            left_overlap_count += 1
        end
    end
    for node in right_nodes
        if plan.assignment[node] == right_district
            right_overlap_count += 1
        end
    end
    same_labeling_count = left_overlap_count + right_overlap_count
    swapped_labeling_count = (length(mst_edges) + 1) - same_labeling_count
    if same_labeling_count >= swapped_labeling_count
        left_label = left_district
        right_label = right_district
    else
        left_label = right_district
        right_label = left_district
    end
    # Form the new assignment dictionary, leaving out nodes with unchanged labels.
    assignment = Dict{Int, Int}()
    for node in left_nodes
        if plan.assignment[node] != left_label
            assignment[node] = left_label
        end
    end
    for node in right_nodes
        if plan.assignment[node] != right_label
            assignment[node] = right_label
        end
    end
    return assignment
end

function traverse_mst(graph::IndexedGraph, mst_edges::BitSet,
                      start_node::Int, avoid_node::Int)::BitSet
    traversed_nodes = BitSet([start_node])
    queue = Queue{Int}()
    enqueue!(queue, start_node)
    while !isempty(queue)
        next_node = dequeue!(queue)
        for neighbor_index in 1:graph.neighbors_per_node[next_node]
            neighbor = graph.node_neighbors[neighbor_index, next_node]
            neighbor_edge = graph.src_dst_to_edge[neighbor, next_node]
            if (neighbor_edge in mst_edges && !(neighbor in traversed_nodes)
                && neighbor != avoid_node)
                enqueue!(queue, neighbor)
                push!(traversed_nodes, neighbor)
            end
        end
    end
    return traversed_nodes
end

function random_mst(graph::IndexedGraph, plan::Plan,
                    left_district::Int, right_district::Int,
                    twister::MersenneTwister)::BitSet
    # Modified version of the Kruskal's algorithm implementation in LightGraphs.
    edges = BitSet([])
    for edge in union(plan.district_edges[left_district],
                      plan.district_edges[right_district])
        src, dst = graph.edges[:, edge]
        if (plan.assignment[src] == left_district ||
            plan.assignment[src] == right_district) &&
           (plan.assignment[dst] == left_district ||
            plan.assignment[dst] == right_district)
           push!(edges, edge)
       end
    end
    nodes = union(plan.district_nodes[left_district],
                  plan.district_nodes[right_district])
    n_edges = length(edges)
    mst_size = length(nodes) - 1
    edge_indices::Array{Int} = [edge for edge in edges]
    weights = rand(twister, n_edges)
    
    connected = IntDisjointSets(graph.n_nodes)  # TODO: make this more efficient?
    mst = BitSet([])
    mst_index = 0
    for edge in edge_indices[sortperm(weights)]
        src, dst = graph.edges[:, edge]
        if !in_same_set(connected, src, dst)
            union!(connected, src, dst)
            push!(mst, edge)
            mst_index += 1
            if mst_index == mst_size
                break
            end
        end
    end
    @assert length(mst) == mst_size
    return mst
end

function balanced_cuts(graph::IndexedGraph, plan::Plan, left_district::Int,
                       right_district::Int, mst_edges::BitSet,
                       min_pop::Int, max_pop::Int)::BitSet
    mst_pop = (plan.district_populations[left_district] +
               plan.district_populations[right_district])
    pops = all_pops(graph, mst_edges, mst_pop)
    ϵ_balanced = BitSet([])
    for (edge, pop) in pops
        inv_pop = mst_pop - pop
        if pop >= min_pop && pop <= max_pop && inv_pop >= min_pop && inv_pop <= max_pop
            push!(ϵ_balanced, edge)
        end
    end
    return ϵ_balanced
end

function all_pops(graph::IndexedGraph, mst_edges::BitSet, mst_pop::Int)
    cache = Dict{Tuple{Int, Int}, Int}()
    return Dict{Int, Int}(edge => pop(graph, mst_edges, mst_pop, edge, 1, cache)
                          for edge in mst_edges)
end

function pop(graph::IndexedGraph, mst_edges::BitSet, mst_pop::Int,
             start_edge::Int, side::Int, cache::Dict{Tuple{Int, Int}, Int})::Int
    if (start_edge, side) in keys(cache)
        return cache[(start_edge, side)]
    end
    next_node = graph.edges[side, start_edge]
    avoid = graph.edges[3 - side, start_edge]
    neighbors = BitSet([])
    for neighbor_index in 1:graph.neighbors_per_node[next_node]
        neighbor = graph.node_neighbors[neighbor_index, next_node] 
        edge_index = graph.src_dst_to_edge[next_node, neighbor]
        if edge_index in mst_edges && neighbor != avoid
            push!(neighbors, neighbor)
        end
    end

    if length(neighbors) > 0
        sub_pop = graph.population[next_node]
        for neighbor in neighbors
            neighbor_edge = [next_node, neighbor]
            sort!(neighbor_edge)
            neighbor_side = 1
            if neighbor_edge[1] == next_node
                neighbor_side = 2
            end
            if (start_edge, side) in keys(cache)
                sub_pop += cache[(start_edge, side)]
            else
                sub_pop += pop(graph, mst_edges, mst_pop,
                               graph.src_dst_to_edge[next_node, neighbor],
                               neighbor_side, cache)
            end
        end
        cache[(start_edge, side)] = sub_pop
        cache[(start_edge, 3 - side)] = mst_pop - sub_pop
        return sub_pop
    else  # Leaf node
        cache[(start_edge, side)] = graph.population[next_node]
        cache[(start_edge, 3 - side)] = mst_pop - graph.population[next_node]
        return graph.population[next_node]
    end
end
