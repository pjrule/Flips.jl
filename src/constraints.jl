"""
    AbstractConstraint

A generic constraint. Constraints are used to determine if proposed flips are valid with
respect to a plan. Generally, a chain run will have a population constraint and a contiguity
constraint at a minimum. Constraints should implement the `valid` function, which takes a
plan, its underlying graph, and a proposed flip and determines if the flip is valid under
the constraint.
"""
abstract type AbstractConstraint end
valid(constraint::AbstractConstraint, graph::IndexedGraph, plan::Plan, flip::Flip) = false

"""
    PopulationConstraint

A constraint on district populations. Adding a `PopulationConstraint` to a chain run
ensures that no district can have a population less than `min_pop` or greater than
`max_pop`.
"""
struct PopulationConstraint <: AbstractConstraint
    min_pop::Int
    max_pop::Int
end

"""
    PopulationConstraint(graph, initial_plan, params)

Initialize a population constraint based on `graph` and `plan`. Population constraints are
parametrized by the `params` dictionary in terms of absolute population 
(via the `min` and `max` fields) or in terms of relative tolerance with respect to
the average district population of the plan (via the `tolerance` field).
"""
function PopulationConstraint(graph::IndexedGraph, initial_plan::Plan, params::Dict)
    if haskey(params, "min") && haskey(params, "max")
        return PopulationConstraint(params["min"], params["max"])
    elseif haskey(params, "tolerance")
        tolerance = params["tolerance"]
        avg_pop = sum(initial_plan.district_populations) / (1.0 * initial_plan.n_districts)
        min_pop = Int(ceil((1 - tolerance) * avg_pop))
        max_pop = Int(floor((1 + tolerance) * avg_pop))
        # TODO: more sophisticated error checking here?
        return PopulationConstraint(min_pop, max_pop)
    else
        throw(InvalidConstraintError("Invalid population constraint. Specify the " *
                                     "constraint using the `min` and `max` parameters " *
                                     "(absolute) or the `tolerance` parameter (relative)."))
    end
end

"""
    valid(constraint, graph, plan, flip)

Determine if a flip proposal is valid with respect to a population constraint.
"""
function valid(constraint::PopulationConstraint, graph::IndexedGraph,
               plan::Plan, flip::Flip)::Bool
    @inbounds old_delta = plan.district_populations[flip.old_assignment] - flip.population
    @inbounds new_delta = plan.district_populations[flip.new_assignment] + flip.population 
    @inbounds return old_delta >= constraint.min_pop && new_delta <= constraint.max_pop
end

"""
    CutEdgesConstraint

A constraint specifying an upper bound on the number of cut edges in a plan.
"""
struct CutEdgesConstraint <: AbstractConstraint
    max_cut_edges::Int
end

"""
    CutEdgesConstraint(graph, initial_plan, params)

Initialize a cut edges constraint based on `graph` and `plan`. Cut edges constraints are
parametrized with the `rel` field, which specifies the maximum number of cut edges as a
multiple of the number of cut edges in the initial plan; or the `abs` field, which
specifies an absolute maximum number of cut edges.
"""
function CutEdgesConstraint(graph::IndexedGraph, initial_plan::Plan, params::Dict)
    if haskey(params, "rel")
        return CutEdgesConstraint(Int(params["rel"] * length(initial_plan.cut_edges)))
    elseif haskey(params, "abs")
        return CutEdgesConstraint(params["abs"])
    else
        throw(InvalidConstraintError("Invalid cut edges constraint. Specify a maximum " *
                                     "number of cut edges relative to the initial plan " *
                                     "in the 'rel' column or an absolute number of cut " *
                                     "edges in the 'abs' column."))
    end
end

"""
    valid(constraint, graph, plan, flip)

Determine if a flip proposal is valid with respect to a cut edges constraint.
It is assumed that the `cut_delta` field of `flip` has been populated.
"""
function valid(constraint::CutEdgesConstraint, graph::IndexedGraph,
               plan::Plan, flip::Flip)::Bool
    return plan.n_cut_edges + flip.Δ > constraint.max_cut_edges
end

"""
    ContiguityConstraint

A contiguity constraint. Ensures that every district is connected.
"""
struct ContiguityConstraint <: AbstractConstraint
    # No metadata (for now); implements the `AbstractConstraint` interface.
end

"""
    valid(constraint, graph, plan, flip)

Determine if a flip proposal maintains district-level contiguity.
"""
function valid(constraint::ContiguityConstraint, graph::IndexedGraph,
               plan::Plan, flip::Flip)::Bool
    neighbors = flip.cut_delta.neighbors
    source_node = iterate(neighbors)[1]
    pop!(neighbors, source_node)

    @inbounds for target_node in neighbors
        visited = zeros(Bool, graph.n_nodes)
        queue = Queue{Int}(64)  # TODO: auto-tune?
        enqueue!(queue, target_node)
        visited[target_node] = true
        found = false
        while !isempty(queue)
            curr_node = dequeue!(queue)
            if curr_node == source_node
                found = true
                break
            end
            for index in 1:graph.neighbors_per_node[curr_node]
                neighbor = graph.node_neighbors[index, curr_node]
                if (!visited[neighbor] && 
                    plan.assignment[neighbor] == flip.old_assignment &&
                    neighbor != flip.node)
                    visited[neighbor] = true
                    enqueue!(queue, neighbor)
                end
            end
        end
        if (isempty(queue) && !found)
            return false
        end
    end
    return true
end


"""
    InvalidConstraintException

Thrown when the parameters of a constraint are invalid.
"""
struct InvalidConstraintError <: Exception
    msg::AbstractString
end
Base.showerror(io::IO,
               e::InvalidConstraintError) = print(io, "Invalid constraint: ", e.msg)

