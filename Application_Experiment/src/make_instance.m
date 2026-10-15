function model=make_instance(c)
% Original 112 tensors are generated first, with the original draw order.
previous=rng;restore=onCleanup(@()rng(previous));
rng(c.scenarioSeed,'twister');
[k,t]=ndgrid(1:c.K,1:c.T);
model.nominalBits=1e6*(.55+.42*exp(-.5*((t-5)/2).^2)+ ...
    .58*exp(-.5*((t-12)/2.4).^2)+.16*(1+sin(.73*k+.51*t)));
model.cycles=760+210*(1+sin(.47*k-.35*t));
routes={ [220 300;780 300;780 630], [310 550;930 550;930 1040], ...
    [500 920;1150 920;1150 1260], [880 1220;1580 1220;1580 1550], ...
    [1270 1660;1780 1660;1780 1300], [1760 1490;1280 1490;1280 1050], ...
    [1580 890;1030 890;1030 450], [760 1460;760 1010;370 1010] };
model.users=zeros(c.K,c.T,2);model.roadRoutes=routes;
for user=1:c.K
    route=routes{user};lengths=vecnorm(diff(route),2,2);total=sum(lengths);
    traveled=linspace(0,.72*total,c.T);
    for slot=1:c.T
        distance=traveled(slot);
        segment=find(cumsum(lengths)>=distance,1);
        if isempty(segment),segment=numel(lengths);end
        prior=sum(lengths(1:segment-1));
        point=route(segment,:)+(distance-prior)/lengths(segment)*diff(route(segment:segment+1,:),1,1);
        model.users(user,slot,:)=reshape(point,1,1,2);
    end
end
S=c.optimizationScenarios+c.validationScenarios;
model.taskFactor=exp(c.taskSigma*randn(c.K,c.T,S)-.5*c.taskSigma^2);
model.workload=model.nominalBits.*model.taskFactor;
model.shadowDB=c.shadowDB*randn(c.K,c.T,S);
model.shadow=10.^(model.shadowDB/10);
model.training=1:c.optimizationScenarios;
model.validation=c.optimizationScenarios+(1:c.validationScenarios);
model.seed=c.scenarioSeed;model.generator='twister';
model.sourceStatus='Single-UAV simulated MEC inputs; synthetic ground routes, tasks and channels; reconstruction assumptions documented';
% A separate stream appends evaluation-only scenarios without altering old draws.
validateattributes(c.independentScenarioSeed,{'double'},{'scalar','integer','>=',0,'<=',2^32-1});
independent=RandStream('mt19937ar','Seed',c.independentScenarioSeed,'NormalTransform','Ziggurat');
extraTaskFactor=exp(c.taskSigma*randn(independent,c.K,c.T,c.independentValidationScenarios)-.5*c.taskSigma^2);
extraShadowDB=c.shadowDB*randn(independent,c.K,c.T,c.independentValidationScenarios);
model.taskFactor=cat(3,model.taskFactor,extraTaskFactor);
model.workload=cat(3,model.workload,model.nominalBits.*extraTaskFactor);
model.shadowDB=cat(3,model.shadowDB,extraShadowDB);
model.shadow=cat(3,model.shadow,10.^(extraShadowDB/10));
model.independentValidation=S+(1:c.independentValidationScenarios);
model.independentSeed=c.independentScenarioSeed;
model.independentGenerator='mt19937ar with Ziggurat normal transform';
model.independentSeedKey=c.independentSeedKey;
model.independentSeedAlgorithm=c.independentSeedAlgorithm;
model.independentValidationUse='Post-search evaluation only; excluded from search and policy selection';
model.originalValidationPoolPreviouslyUsedInDevelopment=true;
model.StudyId=c.StudyId;model.CaseId=c.CaseId;
clear restore
end
