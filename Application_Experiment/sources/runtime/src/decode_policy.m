function p=decode_policy(x,c)
% Equations (1)-(6),(10), Section 3.3. No flight safety repair is hidden here.
validateattributes(x,{'double'},{'real','finite','numel',c.dimension});
x=reshape(x,1,[]);
assert(all(x>=-1e-10 & x<=1+1e-10),'GPC130:Bounds','Candidate outside unit box.');
x=min(1,max(0,x));
coefficients=reshape(2*x(1:2*c.M)-1,c.M,2).*(340./(1:c.M)');
tau=linspace(0,1,c.T)';
reference=(1-tau).*c.start+tau.*c.finish;
path=reference+sin(pi*tau*(1:c.M))*coefficients;
path(:,1)=min(c.area(1,2),max(c.area(1,1),path(:,1)));
path(:,2)=min(c.area(2,2),max(c.area(2,1),path(:,2)));
path(1,:)=c.start; path(end,:)=c.finish;
contraction=1;
if any(vecnorm(diff(path),2,2)>c.vmax*c.dt)
    lo=0; hi=1; offset=path-reference;
    assert(all(vecnorm(diff(reference),2,2)<=c.vmax*c.dt), ...
        'GPC130:Endpoints','Endpoints cannot be reached within speed limit.');
    for iteration=1:52
        middle=(lo+hi)/2;
        if all(vecnorm(diff(reference+middle*offset),2,2)<=c.vmax*c.dt)
            lo=middle;
        else
            hi=middle;
        end
    end
    contraction=lo; path=reference+lo*offset;
end
blocks=reshape(x(2*c.M+1:end),c.K,c.T,4);
p.path=path; p.offload=blocks(:,:,1); p.power=c.pmax*blocks(:,:,2);
p.bandwidth=shares(blocks(:,:,3)); p.cpu=c.edgeCPU*shares(blocks(:,:,4));
p.coefficients=coefficients; p.contraction=contraction;
end
function normalized=shares(values)
total=sum(values,1); zero=total==0;
values(:,zero)=1; normalized=values./sum(values,1);
end
