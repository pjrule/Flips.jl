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
    cut_edges::BitSet
    n_cut_edges::Int
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
    n_districts = maximum(assignment) - minimum(assignment) + 1
    district_populations = zeros(Int, n_districts)
    for (index, node_pop) in enumerate(graph.population)
        district_populations[assignment[index]] += node_pop
    end
    cut_edges = BitSet(Int[])
    for index in 1:graph.n_edges
        left_assignment = assignment[graph.edges[1, index]]
        right_assignment = assignment[graph.edges[2, index]]
        if left_assignment != right_assignment
            push!(cut_edges, index)
        end
    end
    return Plan(n_districts, assignment, district_populations,
                cut_edges, length(cut_edges))
end
