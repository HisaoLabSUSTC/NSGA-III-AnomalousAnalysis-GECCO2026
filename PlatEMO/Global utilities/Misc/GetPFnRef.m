function [PF, ref] = GetPFnRef(Problem, N)
    if nargin < 2
        N = 1000;
    end
    PF = Problem.GetOptimum(N);
    ref = BetterRefGetter(PF, 1.2);
    % if isempty(PF)
    %     ref = ones(1, Problem.M);
    % elseif size(PF, 1) == 1
    %     ref = PF;
    % elseif isnumeric(PF) && ismatrix(PF)
    %     ref = RefGetter(PF, 1.2);
    % elseif iscell(PF)
    %     if Problem.M == numel(PF)
    %         PF = reshape(cat(3, PF{:}), [], numel(PF));
    %         ref = RefGetter(PF, 1.2);
    %     end
    % else
    %     ref = ones(1, Problem.M);
    %     warning("Format not supported.");
    % end
end