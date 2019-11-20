
    left_pop = plan.district_populations[flip.left_district]
    right_pop = plan.district_populations[flip.right_district]
    @inbounds for (index, node) in flip.nodes
        if flip.old_assignments[index] == flip.left_district
            left_pop -= flip.populations[index]
        else
            right_pop -= flip.populations[index]
        end
        if flip.new_assignments[index] == flip.left_district
            left_pop += flip.populations[index]
        else
            right_pop += flip.populations[index]
        end
    end
