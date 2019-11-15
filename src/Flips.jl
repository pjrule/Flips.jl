module Flips

using Random
using LightGraphs
using MetaGraphs 
using SparseArrays
using DataStructures
using JSON

abstract type AbstractStat end

export
    Flips,
    Flip,
    Plan,
    IndexedGraph,
    ChainConfig,
    run_chain!

include("./indexed_graph.jl")
include("./plan.jl")
include("./flip.jl")
include("./constraints.jl")
include("./chain_config.jl")
include("./chain.jl")
include("./stats.jl")
end # module
