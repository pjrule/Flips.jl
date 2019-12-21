using ArgParse

function parse()
    s = ArgParseSettings()

    @add_arg_table s begin
        "graph"
            help = "A NetworkX-format adjacency graph with population and district metadata."
            required = true
        "outfile"
            help = "The name of the JSONL-format log "
        "--pop-col"
            default = "population"
            help = "The population column in the graph metadata."
        "--n-plans"
            default = 1000
            help = "The number of plans to generate."
        "--init-plan-col"
            default = "district"
            help = "The column specifying the initial district assignment in the graph metadata."
    end
end
