function norm_update(algName, Problem, NormStruct, Population, nds)
    try
        if strcmp(algName, "NSGAIIIwH")
            NormStruct.update(Population.objs);
        elseif strcmp(algName, "PyNSGAIIIwH")
            NormStruct.update(Population.objs, nds);
        elseif strcmp(algName, "GtNSGAIIIwH") || strcmp(algName, "Gt-NSGA-III")
            if any(isinf(NormStruct.ideal_point)) || isempty(NormStruct.nadir_point)
                PF = Problem.GetOptimum(1000);
                true_ideal_point = min(PF, [], 1);
                true_nadir_point = max(PF, [], 1);
                NormStruct.ideal_point = true_ideal_point;
                NormStruct.nadir_point = true_nadir_point;
            end
        else
            NormStruct.update(Population.objs);
        end
    catch
        warning('NormStruct.update failed both attempts. Something wrong.');
    end
end