function cases=build_application_cases(root)
% Freeze seven cases; preferences match the archived six-case reviewer plan.
if nargin<1,root=application_root();end
base=paper_settings(root);
ids={'baseline','equal_weights','energy_weights','risk_weights', ...
    'penalty_low','penalty_high','measured_mobility'};
dataRoot=fullfile(application_research_root(),'Application_Experiment','sources','datasets','pneuma');
traceFile=fullfile(dataRoot,'user_positions.csv');protocolFile=fullfile(dataRoot,'trace_protocol.json');
assert(isfile(traceFile)&&isfile(protocolFile),'Application:MeasuredInput','The copied ground-mobility inputs are required.');
trace=jsondecode(fileread(protocolFile));traceSHA=sha256_file(traceFile);
assert(strcmp(traceSHA,trace.processed_sha256),'Application:TraceSHA');
positions=readtable(traceFile,'TextType','string');
assert(base.K==8&&base.T==16&&height(positions)==base.K*base.T,'Application:TraceSize');
assert(all(positions.X_m>=base.area(1,1)&positions.X_m<=base.area(1,2))&& ...
    all(positions.Y_m>=base.area(2,1)&positions.Y_m<=base.area(2,2)),'Application:TraceArea');
digest=java.security.MessageDigest.getInstance('SHA-256');
cases=repmat(struct('Id','','Configuration',[],'Model',[], ...
    'ConfigurationSHA256','','ModelSHA256',''),1,numel(ids));
for j=1:numel(ids)
    c=base;c.CaseId=ids{j};
    switch c.CaseId
        case 'equal_weights',c.weights=ones(size(c.weights))/numel(c.weights);
        case 'energy_weights',c.weights=[.5 .1 .1 .1 .1 .1];
        case 'risk_weights',c.weights=[.1 .1 .1 .5 .1 .1];
        case 'penalty_low',c.penalty=100;
        case 'penalty_high',c.penalty=10000;
        case 'measured_mobility'
            c.mobilityConvention='pNEUMA measured ground-vehicle positions, resampled without distance/time scaling; other UAV-MEC inputs simulated';
    end
    c.independentSeedKey=[c.StudyId ':' c.CaseId ':independent_validation'];
    digest.reset();digest.update(unicode2native(c.independentSeedKey,'UTF-8'));
    hex=lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2)',1,[]));
    c.independentScenarioSeed=hex2dec(hex(1:8));
    model=make_instance(c);
    if strcmp(c.CaseId,'measured_mobility')
        for user=1:c.K
            userRows=positions.User==user;
            assert(nnz(userRows)==c.T&&all(positions.TrackID(userRows)==trace.track_ids(user)),'Application:TraceTrack');
            for slot=1:c.T
                row=positions.User==user&positions.Slot==slot;
                assert(nnz(row)==1&&positions.RelativeTime_s(row)==(slot-1)*c.dt,'Application:TraceGrid');
                model.users(user,slot,:)=reshape([positions.X_m(row),positions.Y_m(row)],1,1,2);
            end
            model.roadRoutes{user}=[reshape(model.users(user,:,1),[],1),reshape(model.users(user,:,2),[],1)];
        end
        model.mobilitySource=struct('CSVFile','sources/datasets/pneuma/user_positions.csv', ...
            'CSV_SHA256',traceSHA,'ProtocolFile','sources/datasets/pneuma/trace_protocol.json', ...
            'ProtocolSHA256',sha256_file(protocolFile),'Protocol',trace);
        model.sourceStatus='Measured ground-vehicle positions only; UAV, tasks, channel, energy and safety simulated; future mobility known offline';
    end
    cases(j).Id=c.CaseId;cases(j).Configuration=c;cases(j).Model=model;
    digest.reset();digest.update(unicode2native(jsonencode(c),'UTF-8'));
    cases(j).ConfigurationSHA256=lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2)',1,[]));
    digest.reset();digest.update(unicode2native(jsonencode(model),'UTF-8'));
    cases(j).ModelSHA256=lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2)',1,[]));
end
configurations=[cases.Configuration];
assert(numel(unique([configurations.independentScenarioSeed]))==numel(cases),'Application:IndependentSeeds');
end
