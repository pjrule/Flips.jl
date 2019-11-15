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

Represents a single flip proposal in a chain run. Flips are intended to be passed to
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
struct Flip
    node::Int
    population::Int
    old_assignment::Int
    new_assignment::Int
    cut_delta::Union{CutDelta, Missing}
    # TODO: weight
end

"""
    CutDelta(flip, plan, graph)

Return the `CutDelta` determined by a plan and a proposed flip step.
"""
function CutDelta(flip::Flip, plan::Plan, graph::IndexedGraph)::CutDelta
    cut_edges_before = BitSet(Int[])
    cut_edges_after = BitSet(Int[])
    neighbors = BitSet(Int[])
    @inbounds for index in 1:graph.neighbors_per_node[flip.node]
        neighbor = graph.node_neighbors[index, flip.node]
        if plan.assignment[neighbor] != flip.old_assignment
            edge_index = graph.src_dst_to_edge[flip.node, neighbor]
            push!(cut_edges_before, edge_index)
        end
        if plan.assignment[neighbor] != flip.new_assignment
            edge_index = graph.src_dst_to_edge[flip.node, neighbor]
            push!(cut_edges_after, edge_index)
        end
        if plan.assignment[neighbor] == flip.old_assignment
            push!(neighbors, neighbor)
        end
    end
    Δ = length(cut_edges_after) - length(cut_edges_before)
    return CutDelta(cut_edges_before, cut_edges_after, neighbors, Δ)
end



"""
    random_flip(graph, plan)

Propose a random flip of a node from one district to another by randomly selecting
a cut edge. This is equivalent to `propose_random_flip` in GerryChain. The `cut_delta`
field is not populated.
"""
function random_flip(graph::IndexedGraph, plan::Plan, twister::MersenneTwister)::Flip
    edge_index = rand(twister, plan.cut_edges)
    edge_side = rand(Int[1, 2])
    @inbounds node = graph.edges[edge_side, edge_index]
    @inbounds node_pop = graph.population[node]
    @inbounds old_assignment = plan.assignment[node]
    @inbounds adj_node = graph.edges[3 - edge_side, edge_index]
    @inbounds new_assignment = plan.assignment[adj_node]
    return Flip(node, node_pop, old_assignment, new_assignment, Missing())
end

"""
    add_cut_delta(flip, graph, plan)

Return an augmented version of a `Flip` with the `cut_delta` field populated.
"""
function add_cut_delta(flip::Flip, graph::IndexedGraph, plan::Plan)::Flip
    cut_delta = CutDelta(flip, plan, graph)
    return Flip(flip.node, flip.population, flip.old_assignment,
                flip.new_assignment, cut_delta)
end
