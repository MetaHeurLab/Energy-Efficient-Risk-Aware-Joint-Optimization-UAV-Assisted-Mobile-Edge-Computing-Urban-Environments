function c=paper_settings(root)
% Paper model values are preserved; experiment controls have one definition.
if nargin==0,root=fileparts(fileparts(mfilename('fullpath')));end
c.root=root;c.K=8;c.T=16;c.M=6;c.dimension=2*c.M+4*c.K*c.T;
c.dt=10;c.area=[0 2000;0 2000];c.altitude=100;
c.vmax=25;c.amax=5;c.bandwidth=10e6;c.pmax=.25;
c.localCPU=1.2e9;c.edgeCPU=15e9;c.deadline=.65;c.battery=45000;
c.alpha=.90;c.beta0=1e-3;c.nu=1.15;c.shadowDB=2;c.taskSigma=.18;
c.kappaLocal=1e-28;c.kappaEdge=.45e-28;
c.start=[260 300];c.finish=[1740 1700];
c.zoneCenters=[700 720;1090 1110;1450 1430];c.zoneRadii=[145;165;135];
c.weights=[.26 .22 .18 .18 .10 .06];c.eta=.58;
c.references=[60000 .65 1 .35 .20 .15];c.penalty=1000;
c.rateFloor=eps;c.cpuFloor=1;c.feasibilityTolerance=1e-9;
c.optimizationScenarios=12;c.validationScenarios=100;c.scenarioSeed=24062026;
c.independentValidationScenarios=100;
c.population=40;c.iterations=750;c.runs=30;c.runSeedBase=24063000;c.workers=24;
c.methods={'DFPQNO','AROA','BBO','BKA','GJA','HBO','IVYA', ...
    'mLSHADE_SPACMA','NDO','NRBO','SSLO','TOC'};
% Reconstruction assumptions remain explicit; no field measurements are implied.
c.noiseDensity=10^((-174-30)/10);
c.propulsion=struct('P0',79.86,'Pi',88.63,'Utip',120,'v0',4.03, ...
    'd0',.6,'rhoAir',1.225,'solidity',.05,'diskArea',.503);
c.mobilityConvention='deterministic synthetic piecewise road traces; see make_instance.m';
c.shadowConvention='zero-mean Gaussian shadowing in dB; task factor is unit-mean lognormal';
c.penaltyConvention='sum of squared normalized acceleration, segment-safety and worst-battery violations';
c.quantileConvention='MATLAB prctile default; pooled scenario-user-slot latencies';
c.StudyId='20261013_180558';c.CaseId='baseline';
c.independentSeedAlgorithm='SHA-256 of UTF-8 key; first 8 hex digits as big-endian unsigned 32-bit integer';
c.independentSeedKey=[c.StudyId ':' c.CaseId ':independent_validation'];
digest=java.security.MessageDigest.getInstance('SHA-256');
digest.update(unicode2native(c.independentSeedKey,'UTF-8'));
hex=lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2)',1,[]));
c.independentScenarioSeed=hex2dec(hex(1:8));
end
