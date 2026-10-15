function [bestfit,bestpos,cg]=NDO(N,T,lb,ub,dim,fobj)
    if max(size(lb))==1
        lb=lb*ones(1,dim);
        ub=ub*ones(1,dim);
    end
    po=initialization(N,dim,ub,lb); % Initialize the positions of crested porcupines
    for i=1:N
        fit(i)=fobj(po(i,:));
    end
    % Update the best-so-far solution
    [bestfit,index]=min(fit);
    bestpos=po(index,:);    
    X=po;
    
    
    for t = 1:T 
        disp(['NDO ',num2str(t),' iteration'])
        for i=1:N
    
            R2=rand(1,dim)>rand;
            po_mean = mean(po);
            A = power(bestpos,po(i,:),bestfit,fit(i));
            A1 = randi([1,N]);
            A2 = randi([1,N]);
            A3 = randi([1,N]);
            fa=fobj(po(A2,:));
            fb=fobj(po(A3,:));
            if rand < 0.5 %% Stochastic Scattering Operator (SSO)
                po(i,:)=(R2).*po(i,:)+(1-R2).*(bestpos + rand(1,dim).*(po(A2,:)-po(A3,:)))+A.*exp(-t).*norm((fa)/(fb + eps)) ;
            else % Hybrid-Guided Operator (HGO)
                if rand < 0.5 
                    po(i,:)=  A.*rand(1,dim)+(1-rand(1,dim)).*po(i,:)+R2.*(po(A1,:)); 
                else
                    po(i,:)= bestpos.*rand(1,dim)+rand(1,dim).*(bestpos.*A .*rand(1,dim)-po(i,:)); 
                end
            end

            %% Return the search agents that exceed the search space's bounds
            for j=1:size(po,2)
                if  po(i,j)>ub(j)
                    po(i,j)=lb(j)+rand*(ub(j)-lb(j));
                elseif  po(i,j)<lb(j)
                    po(i,j)=lb(j)+rand*(ub(j)-lb(j));
                end
            end  

            nfit=fobj(po(i,:));
            %% update Global & Personal best solution
            if  fit(i)<nfit
                po(i,:)=X(i,:);    % Update local best solution
            else
                X(i,:)=po(i,:);
                fit(i)=nfit;
                if  fit(i)<=bestfit
                    bestpos=po(i,:);    % Update global best solution
                    bestfit=fit(i);
                end
            end
    
        end
        cg(t)=bestfit;
     end
end


% This function initialize the first population of search agents
function Positions=initialization(SearchAgents_no,dim,ub,lb)

    Boundary_no= size(ub,2); % number of boundaries
    
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


function p = power(p1,X,f1,f2)
    C = 1 - rand; 
    K = f2/(f1-f2);
    nemeta = rand.*C;
    p = p1 - nemeta .*K.*(p1 - X + eps);  
end




