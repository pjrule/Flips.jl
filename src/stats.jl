struct VoteShareStat <: AbstractStat
    label::AbstractString
    column::AbstractString
end

function dump_stats(graph::IndexedGraph, initial_plan::Plan, config::ChainConfig,
                    flips_buffer::Array{Flip}, snapshot_dir::AbstractString,
                    snapshot_index::Int)
    generated_stats = Dict{AbstractString, Any}()
    for stat in config.stats
        generated_stats[stat.label] = generate(stat, graph, initial_plan, flips_buffer)
    end
    # TODO: render chain metadata as part of dump
    open(joinpath(snapshot_dir, "snapshot_$snapshot_index.json"), "w") do f
        JSON.print(f, Dict("assignment" => initial_plan.assignment,
                           "stats" => generated_stats))
    end
end

"""
    generate(stat, graph, plan, flips_buffer)

[
  {"share": [...], "freq": [...]},
  ...
]
"""
function generate(stat::VoteShareStat, graph::IndexedGraph, plan::Plan,
                  flips_buffer::Array{Flip})
    shares = zeros(Float64, plan.n_districts, length(flips_buffer))
    district_populations = plan.district_populations
    district_voter_counts = zeros(Int, plan.n_districts)
    for index in 1:graph.n_nodes
        district = plan.assignment[index]
        district_voter_counts[district] += graph.attributes[index][stat.column]
    end

    @inbounds for (index, flip) in enumerate(flips_buffer)
        district_populations[flip.left_district] = flip.left_pop
        district_populations[flip.left_district] = flip.right_pop
        for (node_index, node) in enumerate(flip.nodes)
            node_voters = graph.attributes[node][stat.column]
            district_voter_counts[flip.old_assignments[node_index]] -= node_voters
            district_voter_counts[flip.new_assignments[node_index]] += node_voters
        end
        shares[:, index] = (1.0 * district_voter_counts) ./ district_populations
    end

    sort!(shares, dims=1)
    district_bins = [DefaultDict{Float64, Int}(0) for _ in 1:plan.n_districts]
    @inbounds for flip_index in 1:length(flips_buffer)
        for district_index in 1:plan.n_districts
            district_share = shares[district_index, flip_index]
            district_bins[district_index][district_share] += 1
        end
    end

    rendered_bins = [Dict("share" => zeros(Float64, length(district_bins[index])),
                          "freq" => zeros(Int, length(district_bins[index])))
                     for index in 1:plan.n_districts]
    @inbounds for district_index in 1:plan.n_districts
        for (bin_index, (share, freq)) in enumerate(district_bins[district_index])
            rendered_bins[district_index]["share"][bin_index] = share
            rendered_bins[district_index]["freq"][bin_index] = freq
        end
    end
    return rendered_bins
end
