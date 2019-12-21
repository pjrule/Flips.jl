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
    Flip,
    DummyFlip,  # TODO: remove?
    AbstractFlip,
    update!,  # TODO: remove?
    Plan,
    IndexedGraph,
    recom,
    recom_until_step,
    reversible_recom,
    reversible_recom_until_step,
    random_mst,
    balanced_cuts,
    cut_assignment,
    traverse_mst,
    pychain


include("./indexed_graph.jl")
include("./plan.jl")
include("./flip.jl")
include("./constraints.jl")
include("./chain.jl")
include("./recom.jl")
include("./pychain.jl")
end # module
