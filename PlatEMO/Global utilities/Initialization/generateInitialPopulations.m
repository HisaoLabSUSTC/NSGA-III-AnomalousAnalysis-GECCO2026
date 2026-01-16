function generateInitialPopulations(problems, N, M, runs, sourceDir)
    if nargin<5
        sourceDir = './Info/InitialPopulation'; 
    end

    sourceDirData = sourceDir; 
    if ~exist(sourceDirData, 'dir')
        mkdir(sourceDirData);
    end
    
    % --- 1. Determine all required tasks (Problem-Run pairs) ---
    [P_indices, R_indices] = ndgrid(1:length(problems), 1:runs);
    all_tasks = [P_indices(:), R_indices(:)];
    total_pop_tasks = size(all_tasks, 1);

    fprintf('Task 1: Determining %d initial population tasks...\n', total_pop_tasks);

    % --- Initialize output collection array ---
    % This will hold the data and metadata generated in parallel.
    saved_data = cell(total_pop_tasks, 1); 

    % Start parallel pool if not already started
    % if isempty(gcp('nocreate'))
    %     parpool;
    % end
    
    % --- 2. Generate populations in PARALLEL (Computation) ---
    fprintf('Task 1: Generating populations in parallel...\n');
    
    for idx = 1:total_pop_tasks
        prob_idx = all_tasks(idx, 1);
        run_num = all_tasks(idx, 2);
        
        prob_handle = problems{prob_idx};
        prob_name = func2str(prob_handle);

        % Create problem instance to get M and D
        pro_inst = prob_handle('M', M);
        D = pro_inst.D;
        
        % Define target file name (used for final saving)
        fileName = sprintf('HS-%s_M%d_D%d_%d.mat', prob_name, M, D, run_num);
        filePath = fullfile(sourceDirData, fileName);
        
        % Check if file already exists before doing heavy computation
        if isfile(filePath)
            saved_data{idx} = []; % Store placeholder to indicate skipped task
            continue 
        end

        % Set a deterministic seed based on run_num and problem name
        seed_string = sprintf('%s_%d', prob_name, run_num);
        seed_value = sum(double(seed_string)); 
        
        % Reset the seed for the current worker's stream
        rng(seed_value, 'twister'); 
        
        % Generate the initial population (decision vectors)
        temp_pro_inst = prob_handle('M', M); 
        Population = temp_pro_inst.Initialization(N);
        
        heuristic_solutions = Population.decs; 
        
        % Store results in the temporary cell array (NO DISK I/O HERE)
        saved_data{idx} = struct(...
            'FileName', fileName, ...
            'FilePath', filePath, ...
            'Data', heuristic_solutions);
            
        fprintf('PARALLEL: Generated %s (Run %d)\n', prob_name, run_num);
    end
    
    % --- 3. Save populations SEQUENTIALLY (I/O) ---
    fprintf('Task 1: Saving populations sequentially...\n');

    saved_count = 0;
    for idx = 1:total_pop_tasks
        current_data = saved_data{idx};
        
        if isempty(current_data)
            continue; % Skipped in parfor (already existed)
        end
        
        % Extract data from the struct
        heuristic_solutions = current_data.Data;
        filePath = current_data.FilePath;
        
        % Perform the save operation outside of the parfor loop
        save(filePath, 'heuristic_solutions'); 
        saved_count = saved_count + 1;
        
        fprintf('SAVED: %s\n', current_data.FileName);
    end
    
    fprintf('Task 1: Initial population generation complete. Saved %d new files.\n', saved_count);
end
