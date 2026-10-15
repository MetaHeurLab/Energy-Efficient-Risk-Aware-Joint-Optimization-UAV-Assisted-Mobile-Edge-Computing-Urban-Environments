function record=application_job(method,run,c,model,out,token,sourceHash)
% Native returned policy is primary; the callback minimum is diagnostic only.
maxNumCompThreads(1);
assert(any(strcmp(method,c.methods))&&run>=1&&run<=c.runs&&run==fix(run));
algorithmFile=which(method);
assert(~isempty(algorithmFile)&&strcmp(sha256_file(algorithmFile),sourceHash), ...
    'Application:Source','The executed algorithm differs from the frozen source.');
assert(numel(model.training)==12&&numel(model.validation)==100&& ...
    numel(model.independentValidation)==100,'Application:ScenarioSets');
assert(isempty(intersect(model.training,model.validation))&& ...
    isempty(intersect(model.training,model.independentValidation))&& ...
    isempty(intersect(model.validation,model.independentValidation)), ...
    'Application:ScenarioOverlap');
file=fullfile(out,'jobs',sprintf('%s_run%02d.mat',method,run));
if isfile(file)
    previous=load(file,'record','token');
    assert(strcmp(previous.token,token)&&strcmp(previous.record.FreshStudyToken,token), ...
        'Application:ResumeToken','A record from another study cannot be imported.');
    assert(strcmp(previous.record.AlgorithmSHA256,sourceHash), ...
        'Application:ResumeSource');
    if previous.record.SearchCompleted&&previous.record.VerificationPassed
        record=previous.record;
        assert(strcmp(record.Method,method)&&record.Run==run&& ...
            record.Seed==c.runSeedBase+run&&record.Population==c.population&& ...
            record.RequestedIterations==c.iterations,'Application:ResumeSettings');
        record.LoadedFromThisStudyCache=true;
        return
    end
    failedFolder=fullfile(out,'failures');
    if ~isfolder(failedFolder),mkdir(failedFolder);end
    copyfile(file,fullfile(failedFolder,sprintf('%s_run%02d_%s.mat', ...
        method,run,char(datetime('now','Format','yyyyMMdd_HHmmss_SSS')))));
end

isTarget=strcmp(method,'DFPQNO');
seed=c.runSeedBase+run;rng(seed,'twister');initialRNG=rng;
candidateRows=0;modelCalls=0;calls=0;batchRows=[];
invalid=0;nonfinite=0;nonfiniteObjective=0;
observerBest=Inf;observerPosition=[];observerMetric=[];
bestFeasible=Inf;feasiblePosition=[];
APP_ITERATION_PROOF('reset',@observer_best);
rawScore=NaN;rawPosition=[];rawCurve=[];
trainingScore=NaN;training=[];validation=[];independentValidation=[];
observerTrainingMetric=[];observerValidation=[];
rawShapeValid=false;rawInBounds=false;rawExactBounds=false;
rawScoreMatches=false;rawScoreDifference=NaN;rawWasObservedBest=false;
postCalls=0;rawChecks=0;nativeReplayCalls=0;observerReplayCalls=0;
searchCompleted=false;verificationPassed=false;algorithmException=[];
errorStage='';errorID='';errorMessage='';
transcript='';
searchRNG=[];postRNG=[];searchElapsed=NaN;
jobTimer=tic;
try
    errorStage='algorithm';lastwarn('');searchTimer=tic;
    % Catch inside the captured call so output before an exception is retained.
    transcript=evalc('invoke_algorithm');
    searchElapsed=toc(searchTimer);
    [warningMessage,warningIdentifier]=lastwarn;
    searchRNG=rng;
    proof=APP_ITERATION_PROOF('get');
    if ~isempty(algorithmException),rethrow(algorithmException);end
    searchCompleted=proof.Count==c.iterations;
    errorStage='native_iteration_contract';
    assert(searchCompleted&&isequal(proof.Indices,1:c.iterations), ...
        'Application:IncompleteIterations','Every requested native generation must finish.');
    if isTarget
        assert(calls==c.iterations+1&&candidateRows==c.population*(c.iterations+2)&& ...
            isequal(batchRows,[2*c.population,repmat(c.population,1,c.iterations)]), ...
            'Application:TargetGenerations','Expected 2N initialization and N rows per generation.');
    end
    assert(isnumeric(rawCurve)&&isreal(rawCurve)&&isvector(rawCurve)&& ...
        numel(rawCurve)==c.iterations&&all(isfinite(rawCurve(:))), ...
        'Application:NativeCurve','Keep actual native history; do not truncate or pad it.');
    rawCurve=reshape(rawCurve,1,[]);
    assert(all(diff(rawCurve)<=0)&&isequaln(rawCurve,proof.NativeBest), ...
        'Application:NativeHistory','Native history must match the generation witnesses.');
    assert(numel(proof.ObserverBest)==c.iterations&& ...
        all(isfinite(proof.ObserverBest))&&all(diff(proof.ObserverBest)<=0), ...
        'Application:ObserverHistory');
    assert(isequal(size(proof.Population),[1,c.iterations]));
    if strcmp(method,'mLSHADE_SPACMA')
        assert(proof.Population(1)==c.population&& ...
            all(proof.Population>=4&proof.Population<=c.population)&& ...
            all(diff(proof.Population)<=0),'Application:NativePopulation');
        assert(candidateRows==c.population+sum(proof.Population), ...
            'Application:NativeCandidateCount');
    else
        assert(all(proof.Population==c.population),'Application:NativePopulation');
    end
    errorStage='native_return_contract';
    assert(isnumeric(rawScore)&&isscalar(rawScore)&&isreal(rawScore)&&isfinite(rawScore), ...
        'Application:ReturnedScore');
    assert(isequaln(rawCurve(end),rawScore),'Application:ReturnedHistory');
    rawShapeValid=isnumeric(rawPosition)&&isvector(rawPosition)&&numel(rawPosition)==c.dimension;
    assert(rawShapeValid,'Application:ReturnedShape');
    rawPosition=reshape(rawPosition,1,[]);
    rawInBounds=isreal(rawPosition)&&all(isfinite(rawPosition))&& ...
        all(rawPosition>=-1e-10&rawPosition<=1+1e-10);
    rawExactBounds=rawInBounds&&all(rawPosition>=0&rawPosition<=1);
    assert(rawInBounds,'Application:ReturnedBounds');
    assert(~isempty(observerPosition)&&isfinite(observerBest),'Application:NoObservedPolicy');

    errorStage='native_policy_replay';
    postCalls=postCalls+1;nativeReplayCalls=nativeReplayCalls+1;rawChecks=1;
    [trainingScore,training]=evaluate_policy(rawPosition,c,model,model.training);
    rawScoreMatches=isequaln(rawScore,trainingScore);
    rawScoreDifference=rawScore-trainingScore;
    assert(rawScoreMatches,'Application:ReturnedScoreReplay', ...
        'The native returned score does not replay at its native returned policy.');
    postCalls=postCalls+1;nativeReplayCalls=nativeReplayCalls+1;
    [~,validation]=evaluate_policy(rawPosition,c,model,model.validation);
    postCalls=postCalls+1;nativeReplayCalls=nativeReplayCalls+1;
    [~,independentValidation]=evaluate_policy(rawPosition,c,model,model.independentValidation);

    errorStage='observer_policy_replay';
    rawWasObservedBest=isequaln(rawPosition,observerPosition);
    if rawWasObservedBest
        observerTraining=trainingScore;observerTrainingMetric=training;
        observerValidation=validation;
    else
        postCalls=postCalls+1;observerReplayCalls=observerReplayCalls+1;
        [observerTraining,observerTrainingMetric]= ...
            evaluate_policy(observerPosition,c,model,model.training);
        postCalls=postCalls+1;observerReplayCalls=observerReplayCalls+1;
        [~,observerValidation]=evaluate_policy(observerPosition,c,model,model.validation);
    end
    assert(isequaln(observerTraining,observerBest)&& ...
        isequaln(observerTrainingMetric,observerMetric),'Application:ObserverReplay');
    assert(isequaln(proof.ObserverBest(end),observerBest),'Application:ObserverEnd');
    errorStage='post_search_rng';postRNG=rng;
    assert(isequaln(searchRNG,postRNG),'Application:PostSearchRNG', ...
        'Policy replay must not consume the search random stream.');
    verificationPassed=true;errorStage='';
catch failure
    [warningMessage,warningIdentifier]=lastwarn;
    errorID=failure.identifier;errorMessage=failure.message;
    if isempty(searchRNG),searchRNG=rng;end
    if isempty(postRNG),postRNG=rng;end
end
proof=APP_ITERATION_PROOF('get');
if verificationPassed
    termination='complete_iterations';
elseif searchCompleted
    termination='verification_error';
else
    termination='algorithm_error';
end
record=struct('Method',method,'Run',run,'Seed',seed, ...
    'Evaluations',candidateRows,'CandidateRows',candidateRows,'ModelEvaluationCalls',modelCalls, ...
    'ObjectiveCalls',calls,'ObjectiveBatchRows',batchRows, ...
    'InvalidCandidates',invalid,'NonFiniteCandidates',nonfinite, ...
    'NonFiniteObjectiveValues',nonfiniteObjective, ...
    'TrainingObjective',trainingScore,'BestPosition',rawPosition, ...
    'TrainingMetrics',training,'Validation',validation,'IndependentValidation',independentValidation, ...
    'ObserverBestPosition',observerPosition,'ObserverTrainingObjective',observerBest, ...
    'ObserverTrainingMetrics',observerTrainingMetric,'ObserverValidation',observerValidation, ...
    'BestFeasibleTrainingObjective',bestFeasible,'BestFeasiblePosition',feasiblePosition, ...
    'Runtime_s',searchElapsed,'SearchRuntime_s',searchElapsed,'TotalTaskRuntime_s',toc(jobTimer), ...
    'RuntimeIncludesPostSearchChecks',false,'Termination',termination, ...
    'SearchCompleted',searchCompleted,'VerificationPassed',verificationPassed, ...
    'ErrorStage',errorStage,'ErrorIdentifier',errorID,'ErrorMessage',errorMessage, ...
    'RawReturnedScore',rawScore,'RawReturnedPosition',rawPosition,'RawReturnedCurve',rawCurve, ...
    'ObservedCurve',proof.ObserverBest,'Population',c.population,'RequestedIterations',c.iterations, ...
    'NativeCurveLength',numel(rawCurve),'ActualIterations',proof.Count,'IterationProof',proof, ...
    'AlgorithmSHA256',sourceHash,'AlgorithmFile',algorithmFile, ...
    'TargetStandaloneCore',isTarget,'TargetIterationsWitnessedByObjectiveBatches',isTarget, ...
    'PostSearchEvaluationCalls',postCalls,'NativePolicyReplayCalls',nativeReplayCalls, ...
    'ObserverPolicyReplayCalls',observerReplayCalls,'RawPositionVerificationCalls',rawChecks, ...
    'RawPositionShapeValid',rawShapeValid,'RawPositionInBounds',rawInBounds, ...
    'RawPositionWithinExactBounds',rawExactBounds,'BoundsTolerance',1e-10, ...
    'RawPositionTrainingObjective',trainingScore,'RawPositionTrainingMetrics',training, ...
    'RawScoreExactlyReplays',rawScoreMatches,'RawScoreMinusRecomputed',rawScoreDifference, ...
    'RawPositionEqualsObserverBest',rawWasObservedBest, ...
    'TrainingScenarioIndices',model.training,'ValidationScenarioIndices',model.validation, ...
    'IndependentValidationScenarioIndices',model.independentValidation, ...
    'ValidationDuringSearch',false,'IndependentValidationDuringSearch',false, ...
    'InitialRNGState',initialRNG,'FinalSearchRNGState',searchRNG,'PostSearchRNGState',postRNG, ...
    'NoEvaluationCap',true,'ObserverConsumesRandomNumbers',false, ...
    'FinalPolicyRule','Native returned policy; observer minimum is diagnostic only', ...
    'FreshStudyToken',token,'LoadedFromThisStudyCache',false, ...
    'AlgorithmTranscript',transcript,'LastWarningMessage',warningMessage, ...
    'LastWarningIdentifier',warningIdentifier);
save(file,'record','token','-v7');

    function invoke_algorithm
        try
            [rawScore,rawPosition,rawCurve]=feval(method,c.population,c.iterations, ...
                zeros(1,c.dimension),ones(1,c.dimension),c.dimension,@objective);
        catch failure
            algorithmException=failure;
        end
    end
    function value=observer_best
        value=observerBest;
    end
    function values=objective(X)
        if isvector(X)&&numel(X)==c.dimension,X=reshape(X,1,[]);end
        assert(isnumeric(X)&&ismatrix(X)&&size(X,2)==c.dimension, ...
            'Application:CandidateShape','The callback expects candidate rows.');
        count=size(X,1);values=Inf(count,1);
        calls=calls+1;batchRows(end+1)=count;
        if isTarget
            if calls==1,assert(count==2*c.population,'Application:TargetInitialization');
            else,assert(count==c.population,'Application:TargetOffspringBatch');end
        end
        for row=1:count
            candidateRows=candidateRows+1;candidate=X(row,:);
            numericValid=isreal(candidate)&&all(isfinite(candidate));
            if numericValid&&all(candidate>=-1e-10&candidate<=1+1e-10)
                modelCalls=modelCalls+1;
                [value,metric]=evaluate_policy(candidate,c,model,model.training);
                if isreal(value)&&isfinite(value)
                    values(row)=value;
                    if value<observerBest
                        observerBest=value;observerPosition=candidate;observerMetric=metric;
                    end
                    if metric.Feasible&&value<bestFeasible
                        bestFeasible=value;feasiblePosition=candidate;
                    end
                else
                    nonfiniteObjective=nonfiniteObjective+1;
                end
            else
                invalid=invalid+1;nonfinite=nonfinite+double(~numericValid);
            end
        end
        if isTarget&&calls>1
            APP_ITERATION_PROOF('mark',calls-1,c.population,observerBest);
        end
    end
end
