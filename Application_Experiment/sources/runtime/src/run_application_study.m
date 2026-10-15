function study=run_application_study(mode)
% Fresh case runs, exact native-policy replay, statistics and reusable plot data.
if nargin<1,mode='full';end
assert(any(strcmp(mode,{'full','smoke'})),'Application:Mode');
root=application_root();
addpath(fullfile(root,'src'),fullfile(root,'config'),fullfile(root,'algorithms'));
dataRoot=fullfile(application_research_root(),'Application_Experiment');
state=jsondecode(fileread(fullfile(dataRoot,'REBUILD_STATE.json')));
assert(strcmp(root,state.CodeDirectory)&&strcmp(dataRoot,state.DataDirectory),'Application:Location');
assert(state.OldActiveDataRemoved,'Application:OldData');
protected=jsondecode(fileread(state.ProtectedManifest));
check_protected(protected.ProtectedDirectories);
assert(license('test','Distrib_Computing_Toolbox')&&license('test','Statistics_Toolbox'), ...
    'Application:Products','The declared parallel and statistical products must be available.');
cases=build_application_cases(root);
if strcmp(mode,'smoke')
    for j=1:numel(cases)
        cases(j).Configuration.runs=1;cases(j).Configuration.iterations=3;
        cases(j).Configuration.workers=12;
        cases(j).ConfigurationSHA256=text_hash(jsonencode(cases(j).Configuration));
    end
end
c=cases(1).Configuration;methods=c.methods;M=numel(methods);C=numel(cases);R=c.runs;
if strcmp(mode,'full'),resultRoot=fullfile(dataRoot,'Results');
else,resultRoot=fullfile(dataRoot,'Temp','Smoke');end
for folder={resultRoot,fullfile(dataRoot,'data'),fullfile(dataRoot,'logs'), ...
        fullfile(dataRoot,'audit'),fullfile(dataRoot,'Temp','ClusterJobs')}
    if ~isfolder(folder{1}),mkdir(folder{1});end
end
[sources,hashes,algorithmHashes,sourceNotes]=freeze_sources(root,dataRoot,methods,mode);
study=struct('Version','application_fixed_generations_v1','StudyId',c.StudyId, ...
    'Mode',mode,'Methods',{methods},'AlgorithmHashes',{algorithmHashes}, ...
    'TargetSourceSHA256',algorithmHashes{1},'Sources',{sources},'SourceHashes',{hashes}, ...
    'SourceAdaptations',{sourceNotes},'CaseIds',{{cases.Id}}, ...
    'CaseOutputs',{{}},'DataDirectory',dataRoot,'ResultsDirectory',resultRoot, ...
    'PopulationInput',c.population,'CompleteIterations',c.iterations, ...
    'RunsPerMethod',R,'ExpectedSearchRuns',C*M*R,'PrimaryPolicy','Native returned policy', ...
    'ValidationScenarios',100,'AdditionalIndependentValidationScenarios',100, ...
    'NoFEStoppingRule',true,'FiguresCreated',0,'Status','running','SerialTimingOutput','');
outputs=cell(1,C);protocols=cell(1,C);
for j=1:C
    outputs{j}=fullfile(resultRoot,cases(j).Id);
    cfg=cases(j).Configuration;model=cases(j).Model;
    protocol=struct('Version',study.Version,'StudyId',c.StudyId,'Mode',mode, ...
        'CaseId',cases(j).Id,'Configuration',cfg,'ModelSHA256',cases(j).ModelSHA256, ...
        'Methods',{methods},'AlgorithmHashes',{algorithmHashes}, ...
        'TargetSourceSHA256',study.TargetSourceSHA256, ...
        'Sources',{sources},'SourceHashes',{hashes},'SourceAdaptations',{sourceNotes}, ...
        'PopulationInput',cfg.population,'CompleteIterations',cfg.iterations,'RunsPerMethod',R, ...
        'Seeds',cfg.runSeedBase+(1:R),'TrainingIndices',model.training, ...
        'ValidationIndices',model.validation,'IndependentValidationIndices',model.independentValidation, ...
        'NoFEStoppingRule',true,'CandidateCountsAreDiagnosticOnly',true, ...
        'PrimaryPolicy','Native returned policy; observer minimum diagnostic only', ...
        'ValidationUsedDuringSearch',false,'IndependentValidationUsedDuringSearch',false, ...
        'Timing','Concurrent search timings are diagnostics; isolated serial timing is separate', ...
        'Scope',model.sourceStatus,'FiguresCreated',0);
    protocol.Token=text_hash(jsonencode(protocol));protocols{j}=protocol;
    guard_protocol(outputs{j},protocol);
    if ~isfolder(fullfile(outputs{j},'jobs')),mkdir(fullfile(outputs{j},'jobs'));end
    token=protocol.Token;
    save(fullfile(outputs{j},'protocol.mat'),'protocol','token','-v7');
    write_json(fullfile(outputs{j},'protocol.json'),protocol);
    cSave=cfg;save_instance(outputs{j},cSave,model);
end
study.CaseOutputs=outputs;
save(fullfile(resultRoot,'STUDY.mat'),'study','-v7');
write_json(fullfile(resultRoot,'STUDY.json'),study);
if strcmp(mode,'full'),save(fullfile(dataRoot,'data','cases.mat'),'cases','study','-v7');end
write_json(fullfile(dataRoot,'audit',[mode '_protected_before.json']), ...
    struct('FilesChecked',numel(protected.ProtectedDirectories),'AllUnchanged',true));

pool=gcp('nocreate');
assert(isempty(pool),'Application:ExistingPool','Close an existing parallel pool before starting this study.');
cluster=parcluster('Processes');cluster.JobStorageLocation=fullfile(dataRoot,'Temp','ClusterJobs');
cluster.NumThreads=1;
pool=parpool(cluster,min(c.workers,cluster.NumWorkers));
poolCleanup=onCleanup(@()close_pool(pool));
absoluteSources=cellfun(@(f)fullfile(root,f),sources,'UniformOutput',false);
addAttachedFiles(pool,absoluteSources);
queue=parallel.pool.DataQueue;completed=0;total=C*M*R;timer=tic;
afterEach(queue,@progress);
recordCells=cell(total,1);
taskCases=repelem(1:C,M*R);taskMethods=repmat(repelem(1:M,R),1,C);
taskRuns=repmat(1:R,1,C*M);
context=parallel.pool.Constant(struct('Cases',cases,'Outputs',{outputs}, ...
    'Protocols',{protocols},'Methods',{methods},'AlgorithmHashes',{algorithmHashes}));
fprintf('APPLICATION_START cases=%d methods=%d runs=%d N=%d T=%d workers=%d total=%d\n', ...
    C,M,R,c.population,c.iterations,pool.NumWorkers,total);
parfor task=1:total
    ctx=context.Value;caseIndex=taskCases(task);methodIndex=taskMethods(task);run=taskRuns(task);
    cfg=ctx.Cases(caseIndex).Configuration;model=ctx.Cases(caseIndex).Model;
    record=application_job(ctx.Methods{methodIndex},run,cfg,model,ctx.Outputs{caseIndex}, ...
        ctx.Protocols{caseIndex}.Token,ctx.AlgorithmHashes{methodIndex});
    recordCells{task}=record;
    send(queue,struct('Case',caseIndex,'Method',methodIndex,'Run',run, ...
        'Passed',record.SearchCompleted&&record.VerificationPassed));
end
delete(context);close_pool(pool);clear poolCleanup
allPassed=cellfun(@(z)z.SearchCompleted&&z.VerificationPassed,recordCells);
if ~all(allPassed)
    bad=recordCells(~allPassed);messages=cellfun(@(z)sprintf('%s run%d: %s [%s]', ...
        z.Method,z.Run,z.ErrorMessage,z.ErrorStage),bad,'UniformOutput',false);
    study.Status='failed';write_json(fullfile(resultRoot,'STUDY.json'),study);
    write_json(fullfile(resultRoot,'FAILURES.json'),messages);
    error('Application:FailedRuns','%d failed runs; records preserved. First: %s',numel(bad),messages{1});
end
for j=1:C
    indices=(j-1)*M*R+(1:M*R);records=vertcat(recordCells{indices});
    c=cases(j).Configuration;model=cases(j).Model;protocol=protocols{j};token=protocol.Token;
    save(fullfile(outputs{j},'all_runs.mat'),'records','c','model','protocol','token','-v7');
    verify_records(records,c,model,protocol,outputs{j});
    if strcmp(mode,'full')
        analyze_application_data(outputs{j});export_application_data(outputs{j});
    end
    fprintf('APPLICATION_CASE_VERIFIED %s runs=%d\n',cases(j).Id,numel(records));
end
if strcmp(mode,'full')
    timingTag=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
    study.SerialTimingOutput=fullfile(resultRoot,'serial_timing',timingTag);
    save(fullfile(resultRoot,'STUDY.mat'),'study','-v7');
    write_json(fullfile(resultRoot,'STUDY.json'),study);
    measure_application_runtime(cases(1),study,study.SerialTimingOutput);
    study.IsolatedSerialSearchRuns=M*5;study.ExcludedWarmupRuns=M;
    consolidate_cases(outputs,resultRoot);
end
check_source_hashes(root,sources,hashes);check_protected(protected.ProtectedDirectories);
write_json(fullfile(dataRoot,'audit',[mode '_protected_after.json']), ...
    struct('FilesChecked',numel(protected.ProtectedDirectories),'AllUnchanged',true));
study.Status='complete';study.CompletedSearchRuns=total;study.ElapsedSeconds=toc(timer);
save(fullfile(resultRoot,'STUDY.mat'),'study','-v7');write_json(fullfile(resultRoot,'STUDY.json'),study);
write_result_manifest(resultRoot);
fprintf('APPLICATION_COMPLETE fresh_study_runs=%d figures=0 seconds=%.3f data=%s\n', ...
    total,study.ElapsedSeconds,resultRoot);

    function progress(message)
        completed=completed+1;
        if completed==1||mod(completed,24)==0||completed==total||~message.Passed
            fprintf('APPLICATION_PROGRESS %d/%d %.1f%% elapsed=%.1fmin case=%s last_passed=%d\n', ...
                completed,total,100*completed/total,toc(timer)/60,cases(message.Case).Id,message.Passed);
        end
    end
end

function [sources,hashes,algorithmHashes,notes]=freeze_sources(root,dataRoot,methods,mode)
files=[dir(fullfile(root,'src','*.m'));dir(fullfile(root,'config','*.m')); ...
    dir(fullfile(root,'algorithms','*.m'));dir(fullfile(root,'RUN_APPLICATION.m'))];
sources=cell(numel(files),1);hashes=sources;
for k=1:numel(files)
    path=fullfile(files(k).folder,files(k).name);
    sources{k}=path(numel(root)+2:end);hashes{k}=sha256_file(path);
end
[sources,order]=sort(sources);hashes=hashes(order);
if strcmp(mode,'full'),sourceRoot=fullfile(dataRoot,'sources');
else,sourceRoot=fullfile(dataRoot,'Temp','SmokeSources');end
original=fullfile(sourceRoot,'benchmark_algorithms');
snapshot=fullfile(sourceRoot,'runtime');
if ~isfolder(original),mkdir(original);end
algorithmHashes=cell(1,numel(methods));notes=cell(1,numel(methods));
entries=cell(1,numel(methods));benchmark=fileparts(root);
for m=1:numel(methods)
    name=[methods{m} '.m'];current=fullfile(root,'algorithms',name);
    source=fullfile(benchmark,'Benchmark_Experiments','CEC2022',name);
    other=fullfile(benchmark,'Benchmark_Experiments','CEC2017',name);
    originalSHA=sha256_file(source);assert(strcmp(originalSHA,sha256_file(other)),'Application:BenchmarkSource');
    algorithmHashes{m}=sha256_file(current);
    if strcmp(methods{m},'DFPQNO')
        assert(strcmp(originalSHA,algorithmHashes{m}),'Application:TargetUnchanged');
        notes{m}='Byte-identical benchmark core; generation witnesses obtained from objective batches';
    elseif strcmp(methods{m},'AROA')
        notes{m}='Second input adapted from FE ceiling to complete generations; no FE cap or history padding; generation witness added';
    elseif strcmp(methods{m},'mLSHADE_SPACMA')
        notes{m}='Second input adapted to complete generations; population/stage schedule uses generation progress; internal population reduction retained; generation witness added';
    else
        notes{m}='Native numerical code unchanged; one non-random generation witness added';
    end
    originalCopy=fullfile(original,name);guard_copy(source,originalCopy,originalSHA);
    entries{m}=struct('Method',methods{m},'BenchmarkSource',source,'BenchmarkSHA256',originalSHA, ...
        'ExecutedSource',current,'ExecutedSHA256',algorithmHashes{m},'Adaptation',notes{m});
end
for k=1:numel(sources)
    target=fullfile(snapshot,sources{k});folder=fileparts(target);
    if ~isfolder(folder),mkdir(folder);end
    guard_copy(fullfile(root,sources{k}),target,hashes{k});
end
write_json(fullfile(sourceRoot,'algorithm_sources.json'),vertcat(entries{:}));
write_json(fullfile(sourceRoot,'runtime_sources.json'), ...
    struct('Sources',{sources},'SourceHashes',{hashes},'PlotScriptExcludedFromSearchProtocol',true));
end

function guard_copy(source,target,expected)
if isfile(target)
    assert(strcmp(sha256_file(target),expected),'Application:FrozenCopy','A frozen source differs: %s',target);
else
    copyfile(source,target);assert(strcmp(sha256_file(target),expected),'Application:CopyHash');
end
end

function guard_protocol(out,protocol)
file=fullfile(out,'protocol.mat');
if isfile(file)
    old=load(file,'protocol');
    assert(strcmp(old.protocol.Token,protocol.Token),'Application:ExistingProtocol', ...
        'Existing data use another protocol; no file has been overwritten: %s',out);
elseif isfolder(out)
    items=dir(out);items=items(~ismember({items.name},{'.','..'}));
    assert(isempty(items),'Application:UnboundOutput','Refuse an existing output without a protocol: %s',out);
end
end

function save_instance(out,c,model)
save(fullfile(out,'fixed_instance.mat'),'c','model','-v7');
end

function close_pool(pool)
if ~isempty(pool)&&isvalid(pool),delete(pool);end
end

function check_source_hashes(root,sources,hashes)
for k=1:numel(sources)
    assert(strcmp(sha256_file(fullfile(root,sources{k})),hashes{k}),'Application:SourceChanged');
end
end

function check_protected(entries)
for k=1:numel(entries)
    path=fullfile(entries(k).Root,entries(k).RelativePath);
    assert(isfile(path)&&strcmpi(sha256_file(path),entries(k).SHA256), ...
        'Application:ProtectedChanged','Protected file changed externally: %s',path);
end
end

function consolidate_cases(outputs,resultRoot)
parts=cell(numel(outputs),1);independent=parts;
for k=1:numel(outputs)
    a=readtable(fullfile(outputs{k},'performance_summary.csv'),'TextType','string');
    b=readtable(fullfile(outputs{k},'independent_validation_summary.csv'),'TextType','string');
    [~,caseId]=fileparts(outputs{k});
    a=addvars(a,repmat(string(caseId),height(a),1),'Before',1,'NewVariableNames','Case');
    b=addvars(b,repmat(string(caseId),height(b),1),'Before',1,'NewVariableNames','Case');
    parts{k}=a;independent{k}=b;
end
writetable(vertcat(parts{:}),fullfile(resultRoot,'ALL_CASE_SUMMARIES.csv'));
writetable(vertcat(independent{:}),fullfile(resultRoot,'ALL_INDEPENDENT_SUMMARIES.csv'));
end

function write_result_manifest(root)
files=dir(fullfile(root,'**','*'));files=files(~[files.isdir]);entries=cell(numel(files),1);count=0;
for k=1:numel(files)
    if strcmp(files(k).name,'DATA_MANIFEST.json'),continue,end
    path=fullfile(files(k).folder,files(k).name);
    count=count+1;entries{count}=struct('File',path(numel(root)+2:end), ...
        'Bytes',files(k).bytes,'SHA256',sha256_file(path));
end
write_json(fullfile(root,'DATA_MANIFEST.json'),vertcat(entries{1:count}));
end

function digest=text_hash(value)
engine=java.security.MessageDigest.getInstance('SHA-256');engine.update(unicode2native(value,'UTF-8'));
digest=lower(reshape(dec2hex(typecast(engine.digest(),'uint8'),2)',1,[]));
end
