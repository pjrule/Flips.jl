"""
    IndexedGraph

A representation of an adjaacency graph optimized for redistricting applications.
Node-level population is stored in a special array; node neighbors and mappings
between node pairs and edge indices are also broken out into special arrays for
ease of access. Auxiliary metadata is stored as a dictionary in the `attributes`
column.

Importantly, this structure does _not_ store plan-level information, such as
a mapping between nodes and districts. This higher-level information should be
stored in a separate `Plan` structure.
"""
struct IndexedGraph
    n_nodes::Int
    n_edges::Int
    neighbors_per_node::Array{Int}
    node_neighbors::Array{Int, 2}
    population::Array{Int}
    src_dst_to_edge::SparseMatrixCSC{Int, Int}
    edges::Array{Int, 2}
    attributes::Array{Dict{String, Any}}
end

"""
    IndexedGraph (raw, pop_col)

Generate an IndexedGraph from a NetworkX-format adjacency graph dictionary.
This is typically loaded from a JSON file.
"""
function IndexedGraph(raw::Dict, pop_col::AbstractString)::IndexedGraph
    # Generate the base SimpleGraph.
    n_nodes = length(raw["nodes"])
    population = zeros(Int, n_nodes)
    graph = SimpleGraph(n_nodes)
    for (index, node) in enumerate(raw["nodes"])
        population[index] = node[pop_col]
    end
    for (index, edges) in enumerate(raw["adjacency"])
        for edge in edges
            if edge["id"] + 1 > index
                add_edge!(graph, index, edge["id"] + 1)
            end
        end
    end

    # Build graph indices.
    n_edges = ne(graph)
    all_edges = zeros(Int, 2, n_edges)
    cut_edges = BitSet(Int[])

    src_dst_to_edge = spzeros(Int, n_nodes, n_nodes)
    for (index, edge) in enumerate(edges(graph))
        all_edges[1, index] = src(edge)
        all_edges[2, index] = dst(edge)
        src_dst_to_edge[src(edge), dst(edge)] = index
        src_dst_to_edge[dst(edge), src(edge)] = index
    end

    node_neighbors = zeros(Int, 20, n_nodes) # TODO: fix this constant
    neighbors_per_node = zeros(Int, n_nodes)
    for index in 1:n_nodes
        for (neighbor_idx, neighbor) in enumerate(neighbors(graph, index))
            node_neighbors[neighbor_idx, index] = neighbor
            neighbors_per_node[index] += 1
        end
    end

    # Attach node-level attribute data.
    attributes = Array{Dict{String, Any}}(undef, n_nodes)
    for (index, node) in enumerate(raw["nodes"])
        attributes[index] = node
    end

    return IndexedGraph(n_nodes, n_edges, neighbors_per_node, node_neighbors,
                        population, src_dst_to_edge, all_edges, attributes)
end

"""
    edge_index(graph, src, dst)

Return the index of the edge connecting node `src` to node `dst`.
"""
function edge_index(graph::IndexedGraph, src::Int, dst::Int)::Int
    return graph.src_dst_to_edge[src, dst]
end
