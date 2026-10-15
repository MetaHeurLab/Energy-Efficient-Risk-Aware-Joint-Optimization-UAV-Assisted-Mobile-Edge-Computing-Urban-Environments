function [bestScores,bestPosts,Cnvg]=SSLO(NP,MaxIter,lb,ub,D,fobj)
   
    lb = lb .* ones(1,D); % Lower bound
    ub = ub .* ones(1,D); % Upper bound
    Range=ub-lb;  

    % Initialize the population
    X = lb + (ub - lb).*rand(NP,D);

    % Initialize fitness values
    fitness = zeros(NP,1);
    for i = 1:NP
        fitness(i,1) = feval(fobj,X(i,:));
    end       

    [fmin,bestIdX]=min(fitness);
    bestX= X(bestIdX,:);    

    Cnvg = zeros(1, MaxIter);
    newX = zeros(NP,D);

    beta = exp(1);
    unsuccess = zeros(1,NP);
    CR   = 0.9 * ones(NP, 1);

    for iter=1:MaxIter
        CROld = CR;
        [~,xId] = sort(fitness);
        for i=1:NP
            if i == xId(end) && rand < 0.25 
               w = exp(-(beta*max(0,iter-unsuccess(i)+randn(1,D)*10)/MaxIter).^beta); 
                if iter < 0.3*MaxIter                    
                    newX(i,:) =  X(i,:)+w.*sign(rand(1,D)-0.5).*abs(X(i,:));
                else
                    if unsuccess(i) <= 5                         
                        newX(i,:) =  X(xId(1),:)+w.*rand.*sign(rand(1,D)-0.5).*Range;
                    else
                        unsuccess(i) = 0;                     
                        newX(i,:) =  X(xId(1),:)+sign(rand(1,D)-0.5).*rand(1,D).*Range;
                    end
                end                 
            else
                while true; jx = ceil(rand*NP); if jx ~= i; break; end; end
                Stp = X(i,:) - X(jx,:);
                if fitness(jx) < fitness(i)
                    Stp = -Stp;
                end

                newX(i,:) = X(i,:) + 1.4588*log(1./rand(1,D)).*Stp;  
            end

            %% the interpolation strategy
            vd = newX(i,:) < lb;
            newX(i,vd) = (X(i,vd) + lb(1,vd)) / 2;

            % check the upper bound
            vd = newX(i,:) > ub;
            newX(i,vd) = (X(i,vd) + ub(1,vd)) / 2;

            if rand < 0.3, CR(i) = 0.0 + 1.0 * rand(1, 1); end
            rndqCR = CR(i)-0.1*rand(1,D);
            XCr    = (rand(1,D)<=rndqCR);            
            XCr(round(rand*D+0.5)) = true;  %Make sure that there is at least one dimension that will be changed.
            
            %% Crossover operator operation
            newX(i,:) = XCr.*newX(i,:) + (~XCr).*X(i,:);
        end
        
        for i=1:size(X,1)
            newfitness(i,1) = feval(fobj,newX(i,:));
            if newfitness(i)<=fitness(i)
                fitness(i)=newfitness(i);
                X(i,:)=newX(i,:);
                unsuccess(i) = 0;
            else
                CR(i) = CROld(i);
                unsuccess(i) = 1 + unsuccess(i);
            end
        end

        % Find the current best
        [fmin,bestIdX]= min(fitness) ;
        bestX   = X(bestIdX,:);

        Cnvg(iter)=fmin;
    APP_ITERATION_PROOF('mark',iter,NP,fmin);
       
    end %% End of iterations

    bestScores = fmin;
    bestPosts = bestX;
    
end
