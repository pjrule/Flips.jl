"""
   Plan

Stores core elements of the state of the current districting plan: the assignment
of each node, the population of each district, and the set of cut edges (the edges
of the plan's graph that define the district boundaries). Intended to be updated
whenever a step of a chain is accepted.
"""
mutable struct Plan
    n_districts::Int
    assignment::Array{Int}
    district_populations::Array{Int}
    district_nodes::Array{BitSet}
    district_edges::Array{BitSet}  # per-district edge lists
    district_adj::Array{Int, 2}    # cut edge count (seam length) between districts
    cut_edges::BitSet
    n_cut_edges::Int
end

function Plan(graph::IndexedGraph, assignment::Array{Int})::Plan
    n_districts = maximum(assignment) - minimum(assignment) + 1
    district_populations = zeros(Int, n_districts)
    for (index, node_pop) in enumerate(graph.population)
        district_populations[assignment[index]] += node_pop
    end
    cut_edges = BitSet(Int[])
    district_adj = zeros(Int,  n_districts, n_districts)
    district_edges = [BitSet() for _ in 1:n_districts]
    district_nodes = [BitSet() for _ in 1:n_districts]
    for index in 1:graph.n_edges
        left_assignment = assignment[graph.edges[1, index]]
        right_assignment = assignment[graph.edges[2, index]]
        if left_assignment != right_assignment
            push!(cut_edges, index)
            district_adj[left_assignment, right_assignment] += 1
            district_adj[right_assignment, left_assignment] += 1
        end
        push!(district_edges[left_assignment], index)
        push!(district_edges[right_assignment], index)
        push!(district_nodes[left_assignment], graph.edges[1, index])
        push!(district_nodes[right_assignment], graph.edges[2, index])
    end
    return Plan(n_districts, assignment, district_populations,
                district_nodes, district_edges, district_adj,
                cut_edges, length(cut_edges))
end

"""
    Plan(graph, assignment_col)

Create a new plan using data stored in `graph`. The assignment of each node
is loaded from the column `assignment_col` in the metadata of `graph`.
"""
function Plan(graph::IndexedGraph, assignment_col::AbstractString)::Plan
    assignment = zeros(Int, graph.n_nodes)
    for index in 1:graph.n_nodes
        assignment[index] = graph.attributes[index][assignment_col]
    end
    return Plan(graph, assignment)
end
