function [objective,metric,detail]=evaluate_policy(x,c,model,indices)
% Equations (7)-(27), vectorized across K x T x S. Flight uses T-1 segments.
if nargin<4, indices=model.training; end
p=decode_policy(x,c); S=numel(indices);
assert(S>=1,'GPC130:Scenarios','At least one scenario is required.');
D=model.workload(:,:,indices); C=model.cycles;
d2=(p.path(:,1)'-model.users(:,:,1)).^2+ ...
    (p.path(:,2)'-model.users(:,:,2)).^2+c.altitude^2;
channel=c.beta0*model.shadow(:,:,indices)./(d2.^c.nu);
BW=c.bandwidth*p.bandwidth; noise=c.noiseDensity*BW;
rate=BW.*log1p(p.power.*channel./max(noise,realmin))/log(2);
rate(repmat(BW==0,1,1,S))=0;
localCycles=(1-p.offload).*D.*C; edgeCycles=p.offload.*D.*C;
localTime=localCycles/c.localCPU;
uploadTime=p.offload.*D./max(rate,c.rateFloor);
edgeTime=edgeCycles./max(p.cpu,c.cpuFloor);
latency=max(localTime,uploadTime+edgeTime);
speed=vecnorm(diff(p.path),2,2)/c.dt; f=c.propulsion;
% Stable form of sqrt(sqrt(1+a^2)-a), where a=v^2/(2v0^2).
a=speed.^2/(2*f.v0^2); induced=1./sqrt(sqrt(1+a.^2)+a);
powerFly=f.P0*(1+3*speed.^2/f.Utip^2)+f.Pi*induced+ ...
    .5*f.d0*f.rhoAir*f.solidity*f.diskArea*speed.^3;
flightEnergy=c.dt*sum(powerFly);
energyLocal=c.kappaLocal*localCycles*c.localCPU^2;
energyUpload=p.power.*uploadTime;
energyEdge=c.kappaEdge*edgeCycles.*p.cpu.^2;
uav=flightEnergy+reshape(sum(energyEdge,[1 2]),S,1);
energy=uav+reshape(sum(energyLocal+energyUpload,[1 2]),S,1);
complete=latency<=c.deadline;
bits=reshape(sum(D.*complete,2),c.K,S);
fair=sum(bits,1).^2./max(c.K*sum(bits.^2,1),realmin);
fair(sum(bits,1)==0)=0;
fraction=reshape(sum(D.*complete,[1 2])./max(sum(D,[1 2]),realmin),S,1);
weightedLatency=reshape(sum(D.*latency,[1 2])./max(sum(D,[1 2]),realmin),S,1);
meanLatency=mean(weightedLatency);
violation=max(latency(:)/c.deadline-1,0);
tailCount=max(1,ceil((1-c.alpha)*numel(violation)));
cvar=mean(maxk(violation,tailCount));
latency95=prctile(latency(:),95);
raw=[mean(energy),meanLatency,latency95,cvar,1-mean(fraction),1-mean(fair)];
z=raw./c.references; weighted=c.weights.*z;
primary=c.eta*max(weighted)+(1-c.eta)*sum(weighted);
acceleration=vecnorm(diff(p.path,2),2,2)/c.dt^2;
aViolation=max(acceleration/c.amax-1,0);
clearance=segment_clearance(p.path,c.zoneCenters);
sViolation=max(1-clearance./c.zoneRadii,0);
bViolation=max(max(uav)/c.battery-1,0);
penalty=c.penalty*(sum(aViolation.^2)+sum(sViolation.^2,'all')+bViolation^2);
objective=primary+penalty;
if nargout>1
    speedViolation=max(speed/c.vmax-1,0);
    areaViolation=max([c.area(1,1)-p.path(:,1);p.path(:,1)-c.area(1,2); ...
        c.area(2,1)-p.path(:,2);p.path(:,2)-c.area(2,2);0]);
    endpointError=max(abs([p.path(1,:)-c.start,p.path(end,:)-c.finish]));
    shareError=max(abs([sum(p.bandwidth,1)-1,sum(p.cpu,1)/c.edgeCPU-1]));
    maxViolation=max([aViolation(:);sViolation(:);bViolation;speedViolation; ...
        areaViolation;endpointError;shareError]);
    metric=struct('Primary',primary,'Penalized',objective,'Penalty',penalty, ...
        'Energy_kJ',mean(energy)/1000,'MeanLatency_s',meanLatency, ...
        'Latency95_s',latency95,'Completion',mean(fraction), ...
        'Fairness',mean(fair),'CVaR',cvar,'Feasible',maxViolation<=c.feasibilityTolerance, ...
        'MaxViolation',maxViolation,'FlightEnergy_J',flightEnergy, ...
        'WorstBattery_J',max(uav),'MaxSpeed_m_s',max(speed), ...
        'MaxAcceleration_m_s2',max(acceleration),'MinSafetyMargin_m', ...
        min(clearance-c.zoneRadii,[],'all'),'NormalizedCosts',z);
end
if nargout>2
    detail=struct('policy',p,'latency',latency,'completed',complete, ...
        'totalEnergy',energy,'uavEnergy',uav,'rate',rate,'localTime',localTime, ...
        'uploadTime',uploadTime,'edgeTime',edgeTime,'completionScenario',fraction, ...
        'fairnessScenario',fair,'weightedLatencyScenario',weightedLatency, ...
        'speed',speed,'acceleration',acceleration,'clearance',clearance, ...
        'energyLocal',energyLocal,'energyUpload',energyUpload,'energyEdge',energyEdge);
end
end
