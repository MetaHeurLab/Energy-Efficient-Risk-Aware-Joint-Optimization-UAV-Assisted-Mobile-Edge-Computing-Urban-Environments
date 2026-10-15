function [Best_score, Best_pos, curve] = GJA(nPop, Max_iter, lb, ub, dim, fobj)
% GJA  A population-based metaheuristic optimizer.
    % -------------------------
    % Initialization
    % -------------------------
    Positions = initialization(nPop, dim, ub, lb);
    fitness   = arrayfun(@(i) fobj(Positions(i, :)), 1:nPop);

    [Best_score, bestIdx] = min(fitness);
    Best_pos = Positions(bestIdx, :);

    curve  = zeros(Max_iter, 1);
    memory = [];

    range = ub - lb;   % Precompute boundary range

    % -------------------------
    % Main loop
    % -------------------------
    for iter = 1:Max_iter

        % Cosine-hyperbolic driven decay (beta decreases from 1.2 to 0.3)
        beta_start = 1.2;
        beta_end   = 0.3;
        beta = beta_start - (beta_start - beta_end) * ...
               ((cosh(iter / Max_iter * 5) - 1) / (cosh(5) - 1));

        alpha = beta * 0.6;

        % Squared decay curve used by multiple operators
        decay = linspace(1, 0, Max_iter) .^ 2;

        % Batch position update container
        newPositions = Positions;

        for i = 1:nPop

            % -------------------------
            % Stage 1: Hybrid movement
            % -------------------------
            if rand < 0.5
                step = levy_flight(dim, beta) .* alpha;
            else
                step = randn(1, dim) .* alpha .* range / sqrt(iter + 1);
            end

            newX = Positions(i, :) + step;

            % -------------------------
            % Stage 2: Efficient "smell" guidance (every 3 iterations)
            % -------------------------
            if mod(iter, 3) == 0
                dir_factor = sign(Best_pos - newX);
                newX = newX + 0.3 * rand(1, dim) .* dir_factor .* range;
            end

            % -------------------------
            % Implicit group greed (follow a "scent source")
            % -------------------------
            [~, sorted_idx] = sort(fitness);
            scent_source = sorted_idx(ceil(rand^2 * nPop));
            newX = newX + 0.5 * decay(iter) * (Positions(scent_source, :) - newX);

            % -------------------------
            % Truncation / tail-cutting mutation
            % -------------------------
            if norm(newX - Best_pos) > 0.1 * norm(range)
                mut_prob = (1 - decay(iter)) * ones(1, dim);
                mut_dims = find(rand(1, dim) < mut_prob);

                if ~isempty(mut_dims)
                    newX(mut_dims) = Best_pos(mut_dims) + ...
                        randn(size(mut_dims)) .* range(mut_dims) / (iter + 1);
                end
            end

            % -------------------------
            % Boundary handling
            % -------------------------
            newX = min(max(newX, lb), ub);

            newPositions(i, :) = newX;
        end

        % -------------------------
        % Evaluate and accept improvements
        % -------------------------
        newFitness = arrayfun(@(i) fobj(newPositions(i, :)), 1:nPop);

        improved = newFitness < fitness;
        Positions(improved, :) = newPositions(improved, :);
        fitness(improved) = newFitness(improved);

        % -------------------------
        % Update global best
        % -------------------------
        [current_best, bestIdx] = min(fitness);
        if current_best < Best_score
            Best_score = current_best;
            Best_pos   = Positions(bestIdx, :);
        end

        % -------------------------
        % Memory mechanism (every 5 iterations)
        % -------------------------
        if mod(iter, 5) == 0
            [~, top5] = mink(fitness, 5);

            memory = unique([memory; Positions(top5, :)], 'rows', 'stable');
            memory = memory(1:min(5, size(memory, 1)), :);

            % Memory injection: replace worst 10%
            [~, worst] = maxk(fitness, ceil(0.1 * nPop));
            Positions(worst, :) = memory(randi(size(memory, 1), 1, numel(worst)), :);

            % Recalculate fitness for replaced individuals
            fitness(worst) = arrayfun(@(k) fobj(Positions(k, :)), worst);
        end

        curve(iter) = Best_score;
    end
end

% ------------------------------------------------------------
% Levy flight operator
% ------------------------------------------------------------
function step = levy_flight(dim, beta)
    sigma = (gamma(1 + beta) * sin(pi * beta / 2) / ...
            (gamma((1 + beta) / 2) * beta * 2^((beta - 1) / 2)))^(1 / beta);

    u = randn(1, dim) * sigma;
    v = randn(1, dim);

    step = u ./ abs(v).^(1 / beta);
end

% This function initialize the first population of search agents
function Positions=initialization(nPop,dim,ub,lb)

Boundary_no= size(ub,2); % number of boundaries

% If the boundaries of all variables are equal and user enter a signle
% number for both ub and lb
if Boundary_no==1
    Positions=rand(nPop,dim).*(ub-lb)+lb;
end

% If each variable has a different lb and ub
if Boundary_no>1
    for i=1:dim
        ub_i=ub(i);
        lb_i=lb(i);
        Positions(:,i)=rand(nPop,1).*(ub_i-lb_i)+lb_i;
    end
end
end
