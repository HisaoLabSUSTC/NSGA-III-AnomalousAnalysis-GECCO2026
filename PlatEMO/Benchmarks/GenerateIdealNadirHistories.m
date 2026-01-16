% Algorithms = {@GtNSGAIIIwH};
Algorithms = {@NSGAIIIwH, @PyNSGAIIIwH};
% Problems = {@ZDT6};
% Problems = {@UF1, @UF2, @UF3, @UF4, @UF5, @UF6, @UF7, @UF8, @UF9, @UF10, ...
%     @MaF10, @MaF11, @MaF12, @MaF13,@MaF14, @MaF15};

GenerateIdealNadirHistoriesMethod(Algorithms);

function GenerateIdealNadirHistoriesMethod(Algorithms, Problems)
    
    targetDir = fullfile('./Info/IdealNadirHistory'); mkdir(targetDir);
    sourceDirData = fullfile('./Data');

    if nargin < 2 || isempty(Problems)
        Problems = preprocessProblemHandles(Algorithms, sourceDirData);
    end
    
    % --- Determine all required Algorithm-Problem pairs ---
    AllPairs = {};
    for ph = 1:numel(Problems)
        for ah = 1:numel(Algorithms)
            AllPairs{end+1} = struct('AlgHandle', Algorithms{ah}, ...
                                     'ProbHandle', Problems(ph));
        end
    end
    
    % if isempty(gcp('nocreate'))
    %     disp('Starting parallel pool...');
    %     parpool; 
    % end
    
    fprintf('Starting parallel processing of %d tasks...\n', numel(AllPairs));
    
    % Use parfor to distribute the work of processing each file pair
    parfor i = 1:numel(AllPairs)
        currentPair = AllPairs{i};
        algHandle = currentPair.AlgHandle;
        problemHandle = currentPair.ProbHandle;

        
        algName = func2str(algHandle);
        % problem = func2str(problemHandle);
        
        % 1. Find the specific data file for this Alg/Problem combination
        dataFilePath = fullfile(sourceDirData, algName, [algName, '_', problemHandle{1}, '_', '*.mat']);
        dataFiles = dir(dataFilePath);
        
        % Processing logic moved to a helper function
        processStabilityData(dataFiles, algName, problemHandle, targetDir);
    end
    
    disp('Parallel processing complete.');
end

function processStabilityData(dataFiles, algName, problemHandle, targetDir)
    ideal_history = cell(1,numel(dataFiles));
    nadir_history = cell(1,numel(dataFiles));

    ph = str2func(problemHandle{1});
    Problem = ph('M', str2num(problemHandle{2})); M = Problem.M; D = Problem.D; proName = class(Problem);
    PF = Problem.GetOptimum(1000); 
    true_ideal_point = min(PF, [], 1);
    true_nadir_point = max(PF, [], 1);

    for fi=1:numel(dataFiles)
        disp(fi);

        dataPath = fullfile(dataFiles(fi).folder, dataFiles(fi).name);
        % --- 1. Load Data ---
        data = load(dataPath);
        resultMatrix = data.result;
        n_gens = size(resultMatrix, 1);
        N = numel(resultMatrix{1, 2});

        if strcmp(algName, "NSGAIIIwH")
            NormStruct = PlNormalizationHistory(M,N);
        elseif strcmp(algName, "PyNSGAIIIwH")
            NormStruct = PyNormalizationHistory(M);
        elseif strcmp(algName, "GtNSGAIIIwH")
            NormStruct = PyNormalizationHistory(M);
        else
            warning('MATLAB:AlgorithmName', "Algorithm name %s not recognized.", algName);
            return;
        end

        SS = initializeStabilityStruct(M, n_gens);
        
        Population = resultMatrix{1, 2};
        nds = nds_preprocess(Population);
        norm_update(algName, Problem, NormStruct, Population, nds);
        SS.ideal_point_history(1, :) = NormStruct.ideal_point;
        SS.nadir_point_history(1, :) = NormStruct.nadir_point;
        SS.FE_history(1) = resultMatrix{1, 1};

        for g = 2:n_gens
            Population = resultMatrix{g-1, 2};
            Offspring = resultMatrix{g, 3};
            Mixture = [Population, Offspring];
            nds = nds_preprocess(Mixture);
            norm_update(algName, Problem, NormStruct, Mixture, nds);
            
            SS.ideal_point_history(g, :) = NormStruct.ideal_point;
            SS.nadir_point_history(g, :) = NormStruct.nadir_point;
            SS.FE_history(g) = resultMatrix{g, 1};
        end
        ideal_history{fi} = SS.ideal_point_history;
        nadir_history{fi} = SS.nadir_point_history;
    end
    
    % --- 5. Compute Stability Metrics ---
    % SS = computeStabilityMetrics(SS, true_ideal_point, true_nadir_point, resultMatrix);
    % % --- 6. Save the Result ---
    
    targetAlgDir = fullfile(targetDir, algName);
    mkdir(targetAlgDir); 

    % [~, rawName] = fileparts(dataPath);
    outputFileName = ['IN-', algName, '-',proName, '.mat'];
    outputFilePath = fullfile(targetAlgDir, outputFileName);

    % Save the final stability struct
    save(outputFilePath, 'ideal_history', 'nadir_history');
end

function SS = computeStabilityMetrics(SS, true_ideal_point, true_nadir_point, resultMatrix)
    
    delta = 10;
    tolerance = (true_nadir_point-true_ideal_point).*1e-4;
    n_gens = size(SS.ideal_point_history, 1);
    
    % Ensure there are enough generations to check the window
    if n_gens < delta
        warning('MATLAB:StabilityWindow', 'Not enough generations (%d) to check stability window of delta=%d.', n_gens, delta);
        return;
    end

    disp(SS.ideal_point_history')
    disp(SS.nadir_point_history')
    disp(SS)


    % --- 1. Absolute Stability: Check convergence to True PF Bounds ---
    
    % Ideal Point Absolute Stability: Absolute convergence to true_ideal_point
    is_abs_converged_ideal = all(abs(SS.ideal_point_history - true_ideal_point) < tolerance, 2);
    
    % Search backwards: Find the LAST generation (g) that starts a delta-stable window
    for g = n_gens - delta + 1 : -1 : 1
        % Check if the converged state holds for the entire window [g, g + delta - 1]
        if all(is_abs_converged_ideal(g : g + delta - 1))
            % Store the FE value of the first generation of this LAST stable window
            SS.abs_stability_ideal_gen = resultMatrix{g, 1}; 
            break; 
        end
    end
    
    % Nadir Point Absolute Stability: Absolute convergence to true_nadir_point
    is_abs_converged_nadir = all(abs(SS.nadir_point_history - true_nadir_point) < tolerance, 2);
    size(SS.nadir_point_history)
    size(true_nadir_point)
    size(vecnorm(SS.nadir_point_history - true_nadir_point, 2, 2))
    size(SS.nadir_point_history - true_nadir_point)
    disp([vecnorm(SS.nadir_point_history - true_nadir_point, 2, 2)'; (SS.nadir_point_history - true_nadir_point)']);

    
    for g = n_gens - delta + 1 : -1 : 1
        if all(is_abs_converged_nadir(g : g + delta - 1))
            SS.abs_stability_nadir_gen = resultMatrix{g, 1}; 
            break; 
        end
    end

    % --- 2. Relative Stability: Check if the estimated point stops moving ---
    
    % Ideal Point Relative Stability: Point must not move over the window [g, g + delta - 1]
    
    last_stable_ideal_gen = 0; % Initialized to track the generation index
    
    for g = n_gens - delta + 1 : -1 : 1
        
        % Check if ideal_point_history(g, :) is approximately equal to 
        % all points in the window [g+1, ..., g+delta-1]
        
        % Extract the window from g+1 to g+delta-1
        history_window = SS.ideal_point_history(g + 1 : g + delta - 1, :);
        current_point = SS.ideal_point_history(g, :);
        
        % Calculate difference matrix: (delta-1) rows by M columns
        diff_matrix = abs(history_window - current_point); 
        
        % Check if ALL differences in the matrix are within tolerance
        if all(diff_matrix(:) < tolerance)
            % Since we are searching backwards, the first match is the last instance
            last_stable_ideal_gen = g; 
            break; 
        end
    end
    
    % Store the FE value of the LAST generation that started a stable window
    if last_stable_ideal_gen > 0
        SS.rel_stability_ideal_gen = resultMatrix{last_stable_ideal_gen, 1};
    end
    
    % Nadir Point Relative Stability
    last_stable_nadir_gen = 0;
    
    for g = n_gens - delta + 1 : -1 : 1
        history_window = SS.nadir_point_history(g + 1 : g + delta - 1, :);
        current_point = SS.nadir_point_history(g, :);
        
        diff_matrix = abs(history_window - current_point);
        
        if all(diff_matrix(:) < tolerance)
            last_stable_nadir_gen = g;
            break;
        end
    end
    
    if last_stable_nadir_gen > 0
        SS.rel_stability_nadir_gen = resultMatrix{last_stable_nadir_gen, 1};
    end
end

function SS = initializeStabilityStruct(M, n_gens)
    SS = struct();
    
    % History tracking (for computing relative stability)
    SS.ideal_point_history = nan(n_gens, M);
    SS.nadir_point_history = nan(n_gens, M);
    SS.FE_history = nan(n_gens,1);
    
    % Final metrics (will store the FE value)
    SS.abs_stability_ideal_gen = NaN; % FE of first gen that stabilized, or NaN
    SS.abs_stability_nadir_gen = NaN;
    SS.rel_stability_ideal_gen = NaN; % FE of last gen that began a stable window, or NaN
    SS.rel_stability_nadir_gen = NaN;
end


function problemHandles = preprocessProblemHandles(algorithmHandles, sourceDirData)
    problemHandles = {};
    for ah = 1:numel(algorithmHandles)
        algName = func2str(algorithmHandles{ah});
        dataFile = dir(fullfile(sourceDirData, algName, '*.mat'));
        FileNames = {dataFile.name};
        
        for fi = 1:numel(FileNames)
            FileName = FileNames{fi};
            [~,rawName,~] = fileparts(FileName);
            tokens = strsplit(rawName,'_');
            
            % Ensure there's a token at index 2
            if length(tokens) >= 2
                problemHandles{end+1} = [tokens{2}, '-', tokens{3}(2:end)];
            end
        end
    end
    % Apply str2func to unique names to get a cell array of function handles

    uniqueProblemNames = unique(problemHandles);

    problemHandles = cellfun(@(f) split(f, '-'), uniqueProblemNames, 'UniformOutput', false);
end
