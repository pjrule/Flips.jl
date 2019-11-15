"""
    ChainConfig

Stores the configuration of a reproducible MCMC run. All chain runs have a random seed,
a number of steps, and a snapshot interval. (A step is an accepted plan, not a proposal.)
Chain run configurations are designed to be relatively independent of the graphs they are
applied to, allowing the use of a general chain configuration with a variety of graphs.
"""
struct ChainConfig
    seed::Int
    steps::Int
    snapshot_interval::Int
    constraints::Array{AbstractConstraint}
    stats::Array{AbstractStat}
    # TODO: proposal_type
end

"""
    ChainConfig(graph, initial_plan, raw)

Load a chain configuration from a raw configuration dictionary
(typically loaded from a JSON file).
"""
function ChainConfig(graph::IndexedGraph, initial_plan::Plan, raw::Dict)
    # Required parameters: seed, steps, interval
    if haskey(raw, "seed") && raw["seed"] isa Integer
        seed = raw["seed"]
    else
        throw(InvalidConfigError("Chain configuration must include an integer " *
                                 "random seed in the 'seed' field."))
    end
    if haskey(raw, "steps") && raw["steps"] isa Integer && raw["steps"] > 0
        steps = raw["steps"]
    else
        throw(InvalidConfigError("Chain configuration must include a positive " *
                                 "number of steps in the 'steps' field."))
    end
    if haskey(raw, "interval") && raw["interval"] isa Integer && raw["interval"] > 0
        interval = raw["interval"]
    else
        throw(InvalidConfigError("Chain configuration must include a positive " *
                                 "snapshot interval in the 'interval' field."))
    end

    # Constraints (optional)
    if haskey(raw, "proposal") && haskey(raw["proposal"], "constraints")
        n_constraints = length(raw["proposal"]["constraints"])
    else
        n_constraints = 0
    end
    constraints = Array{AbstractConstraint}(undef, n_constraints + 1)
    if n_constraints > 0
        for (index, (name, params)) in enumerate(raw["proposal"]["constraints"])
            if name == "population"
                constraints[index] = PopulationConstraint(graph, initial_plan, params)
            elseif name == "cut_edges"
                constraints[index] = CutEdgesConstraint(graph, initial_plan, params)
            else
                # TODO: more constraint types?
                throw(InvalidConfigError("Invalid constraint type '$name'."))
            end
        end
    end
    constraints[n_constraints + 1] = ContiguityConstraint()  # implicit!
    sort!(constraints, by=constraint_priority)
    
    # Stats (optional)
    if haskey(raw, "stats")
        n_stats = length(raw["stats"])
    else
        n_stats = 0
    end
    stats = Array{AbstractStat}(undef, n_stats)
    if n_stats > 0
        for (index, (name, params)) in enumerate(raw["stats"])
            if !haskey(params, "type")
                throw(InvalidConfigError("Must specify a 'type' field for statistic " *
                                         "'$name'."))
            # TODO: more sophisticated per-stat error checking?
            elseif params["type"] == "vote_share"
                stats[index] = VoteShareStat(name, params["column"])
            else
                throw(InvalidConfigError("Encountered an invalid statistic type."))
            end
        end
    end

    return ChainConfig(seed, steps, interval, constraints, stats)
end

"""
  constraint_priority(constraint)

Custom comparator for sorting constraints. For optimal performance, computationally
inexpensive constraints (e.g. PopulationConstraint) should be tested before
computationally expensive constraints.
"""
function constraint_priority(constraint::AbstractConstraint)::Int
    if constraint isa PopulationConstraint
        return 1  # cheapest
    elseif constraint isa CutEdgesConstraint
        return 2
    end
    return 3
end

"""
    InvalidConfigError

Thrown when a configuration is invalid.
"""
struct InvalidConfigError <: Exception
  msg::AbstractString
end

Base.showerror(io::IO,
               e::InvalidConfigError) = print(io, "Invalid chain configuration: ", e.msg)

