"""
    CutDelta

A representation of the change in a plan's cut edges resulting from a flip step.
The `cut_edges_before` set represents cut edges that were cut edges before the flip step,
but are not necessarily cut edges after the flip step; the `cut_edges_after` set represents
edges that were not necessarily cut edges before the flip step but are cut edges after the
flip step. Note that the union of these sets is not guaranteed to be {∅}, as it is possible
to have a cut edge that _stays_ a cut edge after a flip step, albeit with different
assignments. The `Δ` field stores the net change in the number of cut edges as a result
of the flip and is easily computable from the `cut_edges_before` and `cut_edges_after`
fields; it is included merely for convenience.

The `neighbors` field stores the neighbors of the node being flipped that shared a district
assignment with the node before the flip step, but not after the flip step. This is used
for contiguity checks.
"""
struct CutDelta{T<:Int}
    cut_edges_before::BitSet
    cut_edges_after::BitSet
    neighbors::BitSet
    Δ::T
end

"""
    Flip

Represents a single state change in a chain run. Flips are intended to be passed to
constraints to determine whether the proposal is valid. If the proposal is accepted,
the plan is updated and the flip step is stored for the purpose of computing statistics.

In general, chains have fairly tight population constraints in addition to the implicit
contiguity constraint and other constraints (e.g. maximum cut edges). It is computationally
cheaper to first compute _only_ the population delta for a proposed flip and abort the flip
if population constraints are not met, rather than also computing a cut edges delta
(necessary for contiguity checks) that is discarded if the population constraint is not met.
For this reason, the `cut_delta` field can be `Nothing`. The `add_cut_delta` function
should be called to generate an augmented `Flip` once population constraints have been
checked.
"""
abstract type AbstractFlip end

struct Flip <: AbstractFlip
    nodes::Array{Int}
    populations::Array{Int}
    left_district::Int
    right_district::Int
    left_pop::Int
    right_pop::Int
    old_assignments::Array{Int}
    new_assignments::Array{Int}
    cut_delta::Union{CutDelta, Missing}
    balanced_cuts::Int
    # TODO: weight/latency
end

struct DummyFlip <: AbstractFlip
    reason::AbstractString
end

function DummyFlip()::DummyFlip
    return DummyFlip("")
end

"""
    CutDelta(flip, plan, graph)

Return the `CutDelta` determined by a plan and a proposed flip step.
"""
function CutDelta(flip::Flip, plan::Plan, graph::IndexedGraph)::CutDelta
    altered_nodes = Dict{Int, Int}(node => index
                                   for (index, node) in enumerate(flip.nodes))
    cut_edges_before = BitSet(Int[])
    cut_edges_after = BitSet(Int[])
    neighbors = BitSet(Int[])
    for node in union(plan.district_nodes[flip.left_district],
                      plan.district_nodes[flip.right_district])
        @inbounds for index in 1:graph.neighbors_per_node[node]
            neighbor = graph.node_neighbors[index, node]
            edge_index = graph.src_dst_to_edge[node, neighbor]
            if ((plan.assignment[node] == flip.left_district &&
                 plan.assignment[neighbor] == flip.right_district) ||
                (plan.assignment[node] == flip.right_district &&
                 plan.assignment[neighbor] == flip.left_district))
                push!(cut_edges_before, edge_index)
            end

            if node in keys(altered_nodes)
                node_index = altered_nodes[node]
                if neighbor in keys(altered_nodes)
                    neighbor_index = altered_nodes[neighbor]
                    if (flip.new_assignments[node_index] !=
                        flip.new_assignments[neighbor_index])
                        push!(cut_edges_after, edge_index)
                    end
                else
                    if flip.new_assignments[node_index] != plan.assignment[neighbor]
                        push!(cut_edges_after, edge_index)
                    end
                end
            end
        end
    end
    Δ = length(cut_edges_after) - length(cut_edges_before)
    return CutDelta(cut_edges_before, cut_edges_after, neighbors, Δ)
end

"""
    add_cut_delta(flip, graph, plan)

Return an augmented version of a `Flip` with the `cut_delta` field populated.
"""
function add_cut_delta(flip::Flip, graph::IndexedGraph, plan::Plan)::Flip
    cut_delta = CutDelta(flip, plan, graph)
    return Flip(flip.nodes, flip.populations, flip.left_district,
                flip.right_district, flip.left_pop, flip.right_pop,
                flip.old_assignments, flip.new_assignments, cut_delta,
                flip.balanced_cuts)
end
