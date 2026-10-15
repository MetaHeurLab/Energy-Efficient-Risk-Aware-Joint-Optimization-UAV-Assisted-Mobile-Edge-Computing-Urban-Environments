function [HA_score, HA_pos, Convergence_curve] = HBO(warriors_no, Max_iter, lb, ub, dim, fobj)
    %% HBO - Hannibal's Battle Optimization Algorithm
    % Optimized version with improved structure and reduced code duplication
    
    %% Initialize global variables
    HA_pos = zeros(1, dim);
    HA_score = inf;
    Rom_Gen = zeros(1, dim);
    Rom_score = inf;
    Convergence_curve = zeros(1, Max_iter);
    
    %% Initialize populations
    roman_rate = 0.63;
    romans_no = round(warriors_no * roman_rate);
    cartagos_no = warriors_no - romans_no;
    
    [romans, cartagos, romans_fitness, cartagos_fitness] = initializePopulations(...
        romans_no, cartagos_no, dim, lb, ub, fobj);
    
    %% Sort and divide populations into strategic groups
    [left_romans, right_romans, center_romans] = divideRomans(romans, romans_fitness);
    [left_cartagos, right_cartagos, center_cartagos] = divideCartagos(cartagos, cartagos_fitness);
    
    %% Main optimization loop
    for it = 1:Max_iter
        % Determine battle phase based on iteration
        phase = getBattlePhase(it, Max_iter);
        
        % Execute battle strategies based on phase
        [left_romans, right_romans, center_romans, left_cartagos, right_cartagos, center_cartagos, ...
         HA_score, HA_pos, Rom_score, Rom_Gen] = executeBattlePhase(phase, ...
            left_romans, right_romans, center_romans, left_cartagos, right_cartagos, center_cartagos, ...
            Rom_Gen, HA_pos, HA_score, Rom_score, lb, ub, fobj);
        
        % Display progress and store convergence
        fprintf('Iteration #%d, Best objective = %.6e\n', it, HA_score);
        Convergence_curve(it) = HA_score;
    end
    
   
end

function [romans, cartagos, romans_fitness, cartagos_fitness] = initializePopulations(romans_no, cartagos_no, dim, lb, ub, fobj)
    %% Initialize and evaluate both populations
    romans = initialization(romans_no, dim, ub, lb);
    cartagos = initialization(cartagos_no, dim, ub, lb);
    
    romans_fitness = evaluatePopulation(romans, fobj);
    cartagos_fitness = evaluatePopulation(cartagos, fobj);
end

function fitness = evaluatePopulation(population, fobj)
    %% Evaluate fitness for entire population
    fitness = zeros(1, size(population, 1));
    for i = 1:size(population, 1)
        fitness(i) = fobj(population(i, :));
    end
end

function [left_group, right_group, center_group] = divideRomans(romans, romans_fitness)
    %% Divide Romans into strategic groups (best 3% each for left/right)
    [~, sorted_indices] = sort(romans_fitness);
    sorted_romans = romans(sorted_indices, :);
    
    percent_3 = max(1, round(0.03 * size(romans, 1)));
    left_group = sorted_romans(1:percent_3, :);
    right_group = sorted_romans(percent_3+1:min(2*percent_3, size(romans,1)), :);
    center_group = sorted_romans(2*percent_3+1:end, :);
end

function [left_group, right_group, center_group] = divideCartagos(cartagos, cartagos_fitness)
    %% Divide Carthaginians into strategic groups (worst 12% each for left/right) 
    [~, sorted_indices] = sort(cartagos_fitness, 'descend');
    sorted_cartagos = cartagos(sorted_indices, :);
    
    percent_12 = max(1, round(0.12 * size(cartagos, 1)));
    left_group = sorted_cartagos(1:percent_12, :);
    right_group = sorted_cartagos(percent_12+1:min(2*percent_12, size(cartagos,1)), :);
    center_group = sorted_cartagos(2*percent_12+1:end, :);
end

function phase = getBattlePhase(iteration, max_iter)
    %% Determine current battle phase
    if iteration <= 0.33 * max_iter
        phase = 1; % Early phase - all attacks
    elseif iteration <= 0.66 * max_iter
        phase = 2; % Middle phase - strategic retreats
    else
        phase = 3; % Final phase - encirclement
    end
end

function [left_romans, right_romans, center_romans, left_cartagos, right_cartagos, center_cartagos, ...
          HA_score, HA_pos, Rom_score, Rom_Gen] = executeBattlePhase(phase, ...
    left_romans, right_romans, center_romans, left_cartagos, right_cartagos, center_cartagos, ...
    Rom_Gen, HA_pos, HA_score, Rom_score, lb, ub, fobj)
    
    switch phase
        case 1 % Early phase: All attacks
            [right_cartagos, left_romans, HA_score, HA_pos, Rom_score, Rom_Gen] = ...
                executeAttack(@right_attack, right_cartagos, left_romans, Rom_Gen, HA_pos, HA_score, Rom_score, lb, ub, fobj);
            
            [left_cartagos, right_romans, HA_score, HA_pos, Rom_score, Rom_Gen] = ...
                executeAttack(@left_attack, left_cartagos, right_romans, Rom_Gen, HA_pos, HA_score, Rom_score, lb, ub, fobj);
            
            [center_cartagos, center_romans, HA_score, HA_pos, Rom_score, Rom_Gen] = ...
                executeAttack(@center_attack, center_cartagos, center_romans, Rom_Gen, HA_pos, HA_score, Rom_score, lb, ub, fobj);
            
        case 2 % Middle phase: Strategic retreats
            [right_cartagos, left_romans, HA_score, HA_pos, Rom_score, Rom_Gen] = ...
                executeAttack(@right_attack, right_cartagos, left_romans, Rom_Gen, HA_pos, HA_score, Rom_score, lb, ub, fobj);
            
            [left_cartagos, left_romans, HA_score, HA_pos, Rom_score, Rom_Gen] = ...
                executeAttack(@left_attack, left_cartagos, left_romans, Rom_Gen, HA_pos, HA_score, Rom_score, lb, ub, fobj);
            
            % Right Romans retreat
            [right_romans, HA_score, HA_pos, Rom_score, Rom_Gen] = ...
                executeRetreat(right_romans, HA_score, HA_pos, Rom_score, Rom_Gen, lb, ub, fobj);
            
            [center_cartagos, center_romans, HA_score, HA_pos, Rom_score, Rom_Gen] = ...
                executeAttack(@center_attack, center_cartagos, center_romans, Rom_Gen, HA_pos, HA_score, Rom_score, lb, ub, fobj);
            
        case 3 % Final phase: Encirclement
            [right_cartagos, center_romans, HA_score, HA_pos, Rom_score, Rom_Gen] = ...
                executeAttack(@right_attack, right_cartagos, center_romans, Rom_Gen, HA_pos, HA_score, Rom_score, lb, ub, fobj);
            
            % Left Romans retreat
            [left_romans, HA_score, HA_pos, Rom_score, Rom_Gen] = ...
                executeRetreat(left_romans, HA_score, HA_pos, Rom_score, Rom_Gen, lb, ub, fobj);
            
            [left_cartagos, center_romans, HA_score, HA_pos, Rom_score, Rom_Gen] = ...
                executeAttack(@left_attack, left_cartagos, center_romans, Rom_Gen, HA_pos, HA_score, Rom_score, lb, ub, fobj);
            
            % Right Romans retreat  
            [right_romans, HA_score, HA_pos, Rom_score, Rom_Gen] = ...
                executeRetreat(right_romans, HA_score, HA_pos, Rom_score, Rom_Gen, lb, ub, fobj);
            
            [center_cartagos, center_romans, HA_score, HA_pos, Rom_score, Rom_Gen] = ...
                executeAttack(@center_attack, center_cartagos, center_romans, Rom_Gen, HA_pos, HA_score, Rom_score, lb, ub, fobj);
    end
end

function [attackers, defenders, HA_score, HA_pos, Rom_score, Rom_Gen] = executeAttack(...
    attack_func, attackers, defenders, Rom_Gen, HA_pos, HA_score, Rom_score, lb, ub, fobj)
    %% Execute attack and update positions for both groups
    
    % Perform attack
    [attackers, defenders] = attack_func(attackers, defenders, Rom_Gen, HA_pos);
    
    % Evaluate and update attackers
    [attackers, HA_score, HA_pos, Rom_score, Rom_Gen] = ...
        evaluateAndUpdate(attackers, HA_score, HA_pos, Rom_score, Rom_Gen, lb, ub, fobj);
    
    % Evaluate and update defenders  
    [defenders, HA_score, HA_pos, Rom_score, Rom_Gen] = ...
        evaluateAndUpdate(defenders, HA_score, HA_pos, Rom_score, Rom_Gen, lb, ub, fobj);
end

function [retreaters, HA_score, HA_pos, Rom_score, Rom_Gen] = executeRetreat(...
    retreaters, HA_score, HA_pos, Rom_score, Rom_Gen, lb, ub, fobj)
    %% Execute retreat maneuver (random movement)
    
    for i = 1:size(retreaters, 1)
        retreaters(i, :) = retreaters(i, :) + randn(1, size(retreaters, 2)) .* (ub - lb);
    end
    
    [retreaters, HA_score, HA_pos, Rom_score, Rom_Gen] = ...
        evaluateAndUpdate(retreaters, HA_score, HA_pos, Rom_score, Rom_Gen, lb, ub, fobj);
end

function [population, HA_score, HA_pos, Rom_score, Rom_Gen] = evaluateAndUpdate(...
    population, HA_score, HA_pos, Rom_score, Rom_Gen, lb, ub, fobj)
    %% Evaluate population and update best solutions
    
    for i = 1:size(population, 1)
        % Enforce bounds
        population(i, :) = enforceBounds(population(i, :), ub, lb);
        
        % Evaluate fitness
        fitness = fobj(population(i, :));
        
        % Update best solutions
        if fitness < HA_score
            HA_score = fitness;
            HA_pos = population(i, :);
        elseif fitness < Rom_score
            Rom_score = fitness;
            Rom_Gen = population(i, :);
        end
    end
end

function [new_pos_right, new_pos_left] = center_attack(pos_right, pos_left,General,Hannibal)
   
    
    c=0.94;
    random_vector_right = randn(size(pos_right)) * c*rand;
    random_vector_left = randn(size(pos_left)) * c*rand;
    new_pos_right = pos_right + random_vector_right.*(General - pos_right) ;
    new_pos_left = pos_left + random_vector_left.*(Hannibal - pos_left) ;
    
    
    
%     new_pos_right = parallaxe(new_pos_right,Hannibal) ; 
%     new_pos_left = parallaxe(new_pos_left,General) ;



end

function position = enforceBounds(position, ub, lb)
    flagUb = position > ub;
    flagLb = position < lb;
    position = position .* ~(flagUb + flagLb) + ub .* flagUb + lb .* flagLb;
end

% This function initialize the first population of search agents
function Positions=initialization(SearchAgents_no,dim,ub,lb)

Boundary_no= size(ub,2); % numnber of boundaries

% If the boundaries of all variables are equal and user enter a signle
% number for both ub and lb
if Boundary_no==1
    Positions=rand(SearchAgents_no,dim).*(ub-lb)+lb;
end

% If each variable has a different lb and ub
if Boundary_no>1
    for i=1:dim
        ub_i=ub(i);
        lb_i=lb(i);
        Positions(:,i)=rand(SearchAgents_no,1).*(ub_i-lb_i)+lb_i;
    end
end
end

function [new_pos_right, new_pos_left] = left_attack(pos_right, pos_left, General, Hannibal)
 random_vector_right = randn(size(pos_right)) * 0.5;
    random_vector_left = randn(size(pos_left)) * 0.5;
    % Mirror positions
    new_pos_right = 2*mean(pos_left) - random_vector_right.*pos_right;
    new_pos_left = 2*mean(pos_right) - random_vector_left.*pos_left;

  new_pos_right =  0.94*parallaxe(new_pos_right,Hannibal) ; 
  new_pos_left =  0.94*parallaxe(new_pos_left,General) ;
end

function [modified_pos_right] = parallaxe(pos_right,Rom_Gen)

N = size(pos_right,1);
if mod(N,2) ~= 0
 % Ensure that the number of elements in X matches the reshaping dimensions
%    assert(size(X,1) * size(X,2) == N*2, 'Number of elements in X does not match reshaping dimensions');
    couples = reshape(randperm(N-1), [], 2); % Use [] to automatically calculate size
else
    couples = reshape(randperm(N), [], 2); % Use [] to automatically calculate size
end

%couples = couples (1:floor(N/2), : ) ; 

modified_pos_right=pos_right;

modified_indices = [];

for idx = 1:size(couples, 1)
    couple_center = (pos_right(couples(idx, 1), :) + pos_right(couples(idx, 2), :)) / 2;
    center_to_gen_dist = norm(couple_center - Rom_Gen(1, :));
    
    for j = 1:2
        warrior_index = couples(idx, j);
        warrior = pos_right(couples(idx, j), :);
        influence_direction = (Rom_Gen(1, :) - warrior) / norm(Rom_Gen(1, :) - warrior);
        adjusted_step_size = center_to_gen_dist * (0.5+rand()*2);
        modified_pos_right(couples(idx, j), :) = warrior + adjusted_step_size * influence_direction;
        modified_indices = [modified_indices, warrior_index];
    end
end


% for j = 1:length(modified_indices)
%     i= modified_indices(j);
%     old_fitness = fobj(pos_right(i,:));
%     new_fitness = fobj(modified_pos_right(i,:));
%     
%     
%     if (new_fitness < old_fitness)
%         pos_right(i,:) =modified_pos_right(i,:)   ;
%         
%     end
%     
%     
%     
% end

end 

function [new_pos_right, new_pos_left] = right_attack(pos_right, pos_left,General,Hannibal)
    reflection_plane = (mean(pos_right) + mean(pos_left)) / 2;
    random_vector_right = randn(size(pos_right)) * 0.5;
    random_vector_left = randn(size(pos_left)) * 0.5;
    new_pos_right = reflection_plane + random_vector_right.*(reflection_plane - pos_right); 
    new_pos_left = reflection_plane + random_vector_left.*(reflection_plane - pos_left) ;
    
     new_pos_right = 0.94*parallaxe(new_pos_right,Hannibal) ; 
  new_pos_left = 0.94* parallaxe(new_pos_left,General) ;
end