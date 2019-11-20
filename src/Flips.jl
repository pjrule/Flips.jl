module Flips

using Random
using LightGraphs
using MetaGraphs 
using SparseArrays
using DataStructures
using JSON
using Memoize

abstract type AbstractStat end

export
    Flips,
    DummyFlip,  # TODO: remove?
    update!,  # TODO: remove
    Flip,
    Plan,
    IndexedGraph,
    ChainConfig,
    run_chain!,
    reversible_recom,
    random_mst,
    balanced_cuts,
    cut_assignment,
    traverse_mst


include("./indexed_graph.jl")
include("./plan.jl")
include("./flip.jl")
include("./constraints.jl")
include("./chain_config.jl")
include("./chain.jl")
include("./stats.jl")
include("./recom.jl")
end # module
