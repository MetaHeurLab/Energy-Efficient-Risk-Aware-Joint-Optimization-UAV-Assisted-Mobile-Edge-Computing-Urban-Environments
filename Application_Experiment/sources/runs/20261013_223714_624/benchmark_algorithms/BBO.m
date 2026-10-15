function [best_fitness, best_solution, Convergence_curve] = BBO(N, Max_iteration, lb, ub, dim, fobj)
    % Check and expand boundaries if they are scalars
    if max(size(lb)==1)
        lb = lb.*ones(1,dim);
        ub = ub.*ones(1,dim);
    end 
    
    % Initialize population
    population = lb + (ub - lb) .* rand(N, dim);
    fitness = zeros(N, 1);
    for i = 1:N
        fitness(i) = fobj(population(i, :));
    end
    
    % Initialize best solution
    [best_fitness, idx] = min(fitness);
    best_solution = population(idx, :);
  
    % Convergence curve
    Convergence_curve = zeros(1, Max_iteration);
    
    % Main loop
    for t = 1:Max_iteration
        % Exploration-exploitation factor
        E = sin(pi/2*t / Max_iteration);
        
        for i = 1:N
            if rand < E % Exploitation phase
                % Information exchange between individuals
                for j = 1:dim
                    k = randi([1, N]);
                    while k == i % Ensure not selecting itself
                         k = randi([1, N]);
                    end
                     % Learn from randomly selected individual and best experience
                     population(i, j) = population(i, j) + rand * (population(k, j) - population(i, j)) + rand * (best_solution(j) - population(i, j)); 
                end
            else % Exploration phase  
                % Dynamic role division
                [~, sorted_idx] = sort(fitness);
                architects_idx = sorted_idx(1:round(N * 0.25));
                
                if ismember(i, architects_idx) % If architect
                    % Learn from other architects
                    for j = 1:dim
                        if rand < 0.5
                            k = architects_idx(randi(length(architects_idx)));
                            population(i, j) = population(i, j) + rand * (population(k, j) - population(i, j));
                        end
                    end
                else % If explorer
                    % Learn from architects and explore
                    for j = 1:dim
                        if rand < 0.5
                           k = architects_idx(randi(length(architects_idx)));
                           population(i, j) = population(i, j) + rand * (population(k, j) - population(i, j));
                        else
                           % Define a disturbance factor that decreases with iterations
                           disturbance = cos(pi/2*t / Max_iteration) * (ub(j) - lb(j)) * randn / 10;
                           % Perform small perturbation around current position
                           population(i, j) = population(i, j) + disturbance;
                        end
                    end
                end
            end
            
            % Boundary check
            population(i, :) = max(population(i, :), lb);
            population(i, :) = min(population(i, :), ub);
            
            % Update fitness
            new_fitness = fobj(population(i, :));
            if new_fitness < fitness(i)
                fitness(i) = new_fitness;
                if new_fitness < best_fitness
                    best_fitness = new_fitness;
                    best_solution = population(i, :);
                end
            end
        end
        
        % Update convergence curve
        Convergence_curve(t) = best_fitness;
    end
end