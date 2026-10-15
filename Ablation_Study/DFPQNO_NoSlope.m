    function [Best_Score, Best_Pos, CG_curve] = DFPQNO_NoSlope(N, MaxIt, LB, UB, dim, fobj)
    % Batch objective: candidates in rows, one returned value per row.
    % Population slope and its dependent Newton direction are removed.
    one = numel(dim); zero = one - one; two = one + one;
    dim = max(one, round(dim)); N = max(two, round(N));
    MaxIt = max(zero, round(MaxIt));
    LB = reshape(LB, one, []) + zeros(one, dim);
    UB = reshape(UB, one, []) + zeros(one, dim);
    lo = min(LB, UB); UB = max(LB, UB); LB = lo; width = UB - LB;
    rootD = sqrt(dim); rootN = sqrt(N);
    phi = (sqrt(one + two * two) - one) / two;
    CG_curve = zeros(one, MaxIt);
    
    X = LB + mod(rand(one, dim) + (one:N)' * mod((one:dim) * phi, one), one) .* width;
    X = [X; LB + UB - X];
    F = fobj(X); F = F(:);
    F(~isfinite(F)) = inf;
    [F, idx] = sort(F); X = X(idx(one:N), :); F = F(one:N);
    Best_Score = F(one); Best_Pos = X(one, :);
    H = max(two, ceil(rootD));
    M = phi * ones(H, one); k = one;
    A = zeros(N, dim); nA = zero;
    rows = (one:N)';
    
    for it = one:MaxIt
        [F, idx] = sort(F); X = X(idx, :);
    
        cool = (MaxIt - it + one) / (MaxIt + one);
        elite = min(N, max(two, ceil(rootN * (one + cool))));
        p = randi(elite, N, one);
        Fi = M(randi(H, N, one));
        Fi = min(one, max(one / rootD, Fi + tan(pi * (rand(N, one) - one / two)) / rootD));
        a = mod(rows - one + randi(N - one, N, one), N) + one;
        pool = [X; A(one:nA, :)];
        b = randi(N + nA - one, N, one);
        b = b + (b >= a);
        % Ablation: remove population-derived slope guidance.
        U = X + Fi .* (X(p, :) - X) ...
        + Fi .* (X(a, :) - pool(b, :));
        mask = rand(N, dim) < Fi;
        j = randi(dim, N, one);
        mask(rows + (j - one) * N) = true;
        U(~mask) = X(~mask);
        outside = U < LB | U > UB;
        repair = LB + rand(N, dim) .* width;
        U(outside) = repair(outside);
    
        Ft = fobj(U); Ft = Ft(:);
        Ft(~isfinite(Ft)) = inf;
        win = Ft < F;
        if any(win)
            gain = F(win) - Ft(win);
            w = gain / sum(gain);
            if all(isfinite(w))
                Fs = Fi(win);
                M(k) = sum(w .* Fs .^ two) ...
                    / (sum(w .* Fs) + eps);
                k = mod(k, H) + one;
            end
            old = [A(one:nA, :); X(win, :)];
            nA = min(N, size(old, one));
            keep = randperm(size(old, one), nA);
            A(one:nA, :) = old(keep, :);
            X(win, :) = U(win, :); F(win) = Ft(win);
        end
        [value, row] = min(F);
        if value < Best_Score, Best_Score = value; Best_Pos = X(row, :); end
        CG_curve(it) = Best_Score;
    end
    end
