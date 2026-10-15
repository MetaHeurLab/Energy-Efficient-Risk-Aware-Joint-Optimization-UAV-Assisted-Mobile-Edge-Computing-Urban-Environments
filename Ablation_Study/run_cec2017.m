clc; clear; close all
% Keep warnings visible; do not hide numerical or programming problems.
scriptDir = fileparts(mfilename('fullpath'));
cd(scriptDir); % Native CEC inputs load relative to the current suite folder.
addpath(scriptDir);
clear DFPQNO DFPQNO_Full DFPQNO_UniformInit DFPQNO_NoCurvature DFPQNO_NoArchive DFPQNO_FixedMemory DFPQNO_NoSlope DFPQNO_FixedScale

outputRoot = fullfile(scriptDir,'Results');
% Results stay beside this entry; temporary process storage remains on D:.
if ~isfolder(outputRoot)
    mkdir(outputRoot);
end

%% ======================== 参数设置 ========================
SearchAgents   = 30;      % 种群规模
Max_iteration  = 750;     % 最大迭代次数
dimensions     = [10 30 50 100]; % CEC2017 的四个测试维度
run_times      = 30;      % 每个函数独立运行次数
baseSeed       = 127955229; % frozen from panel-manifest SHA-256
alpha          = 0.05;     % One Holm family per dimension: all functions x all DFPQNO-versus-control contrasts.
makeFigures    = false;    % Set true to export figures; optimization and statistics are unchanged.

% ---------------- 并行计算设置 ----------------
% 自动识别全部可用逻辑处理器；每个处理器一个单线程进程。
% 每个“算法 × 独立运行”单独调度，完成后立即接手下一项计算。

% ---------------- 算法列表 ----------------
% 注意：将你提出的/最好的算法放在第一个位置，作为Wilcoxon检验的基准(Target)
% 每个算法一个同名 .m 文件；替换时修改下面对应的函数句柄和显示名称即可。
% Keep the original seven ablation methods unchanged; add the fusion candidate.
algoFcns  = {@DFPQNO, @DFPQNO_Full, @DFPQNO_UniformInit, @DFPQNO_NoCurvature, @DFPQNO_NoArchive, @DFPQNO_FixedMemory, @DFPQNO_NoSlope, @DFPQNO_FixedScale};
algoNames = {'DFPQNO', 'DFPQNO_Full', 'DFPQNO_UniformInit', 'DFPQNO_NoCurvature', 'DFPQNO_NoArchive', 'DFPQNO_FixedMemory', 'DFPQNO_NoSlope', 'DFPQNO_FixedScale'};
plotNames = {'DFPQNO (final fusion)', 'Original Full', 'Uniform init', 'No curvature', 'No archive', 'Fixed memory (previous best)', 'No slope', 'Fixed scale'};
originalBenchmarkMethodCount = 12; % Retain original target-column seed offsets.
assert(numel(algoFcns)==numel(algoNames)&&numel(algoFcns)==numel(plotNames), ...
    '算法接口、名称和图例的数量必须一致。');
algorithmReferences = describeAlgorithms(algoFcns,algoNames);
validateExperimentEnvironment(algoFcns, scriptDir);
numAlgo   = numel(algoFcns);


% ---------------- 函数集合 ----------------
% CEC2017 保留 F1-F30 中除 F2 外的二十九个函数。
func_list = setdiff(1:30,2);
numFuncs  = numel(func_list);
% Official CEC2017 objective error; the optimizer still receives raw f(x).
errorTolerance = 1e-8;
metricName = 'Raw objective error for statistics; errors below1e-8 are zeroed only for display';
statisticalProtocol = sprintf(['Exact paired signed-rank on native objective differences; ' ...
    'Holm across all %d functions and %d DFPQNO-versus-control contrasts (%d tests per dimension)'], ...
    numFuncs,numAlgo-1,numFuncs*(numAlgo-1));
experimentMetadata = struct('startedAt',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')), ...
    'matlabVersion',version,'platform',computer,'randomGenerator','twister', ...
    'baseSeed',baseSeed,'dimensions',dimensions,'functionIds',func_list, ...
    'populationSize',SearchAgents,'iterations',Max_iteration,'runs',run_times, ...
    'algorithmReferences',algorithmReferences, ...
    'sourceFiles',snapshotExperimentCode(scriptDir), ...
    'statisticalProtocol',statisticalProtocol, ...
    'seedRule',sprintf(['All %d algorithms share the same seed for each function, dimension and run; ' ...
        'original %d-method target-column offsets are preserved'],numAlgo,originalBenchmarkMethodCount), ...
    'originalBenchmarkMethodCount',originalBenchmarkMethodCount, ...
    'outputRoot',outputRoot, ...
    'figuresEnabled',makeFigures, ...
    'noEvaluationStopping',true, ...
    'initialEvaluationPolicy','UniformInit: N; all other algorithms: 2N', ...
    'searchEvaluationPolicy','UniformInit: N*(MaxIt+1); other variants: N*(MaxIt+2)', ...
    'postSearchReplayCalls',1, ...
    'rankMetric','Across-run mean objective error', ...
    'implementationProtocol','Original seven-method ablation panel unchanged, plus one new fusion candidate; candidate-versus-control contrasts compare algorithm versions rather than isolated removals from the candidate', ...
    'finalMethod','Fusion: uniform/opposition initialization, inverse-square-root dimension guidance, no success-memory feedback', ...
    'alpha',alpha);
finalSource = experimentMetadata.sourceFiles(strcmp({experimentMetadata.sourceFiles.file},'DFPQNO.m'));
assert(isscalar(finalSource),'CEC2017:FinalSourceSnapshot','The final reference source must occur once.');
experimentMetadata.versionToken = ['FusionFinal:' finalSource.sha256];
experimentMetadata.resultVersionPolicy = 'Only current-run results with matching versionToken and active source hashes identify this final method; earlier results retain their original labels and must not be combined across versions.';
experimentMetadata.excelSheets = resultSheetMap();
writeProtocolNotes(outputRoot, experimentMetadata);

% Count optimizer runs and output steps across all selected dimensions.
totalWork = numel(dimensions) * (numFuncs*(run_times*numAlgo + 1) + 1) + 1;
updateExperimentProgress('init', totalWork);
[experimentPool, cpuInfo] = startExperimentPool(fullfile('CEC2017','ParallelJobs'));
parallelOptions = parforOptions(experimentPool, ...
    'RangePartitionMethod','fixed','SubrangeSize',1);
experimentMetadata.parallel = cpuInfo;
save(fullfile(outputRoot,'CEC2017_Experiment_Manifest.mat'),'experimentMetadata');
updateExperimentProgress('cpu', cpuInfo.workers);
% Each worker enters this benchmark directory, even when reusing an older pool.
workerFactory = @() initializeWorker(scriptDir, algoFcns);
algoPool = parallel.pool.Constant(workerFactory);
quietRunner = @runAlgorithmQuietly; % Serialize the script-local function for workers.
progressQueue = parallel.pool.DataQueue;
afterEach(progressQueue, @(count) updateExperimentProgress('advance', count));

% ---------------- Excel 文件设置 ----------------
allRadarRanks = nan(numFuncs, numAlgo, numel(dimensions));
allWinTieLoss = zeros(numel(dimensions), numAlgo-1, 3);
for dimIndex = 1:numel(dimensions)
dim = dimensions(dimIndex);
outputDir = fullfile(outputRoot, sprintf('D%d', dim));
if ~isfolder(outputDir)
    mkdir(outputDir);
end
filename = fullfile(outputDir, sprintf('cec2017_Results_D%d.xlsx', dim));
sheet1 = 'Sheet1'; % 基本统计
% Sheet2: 原 Friedman 平均秩表；Sheet3: 原 Wilcoxon p 值和符号。
% Sheet4: Holm 校正；Sheet5: 秩效应；Sheet6: 函数区组总体 Friedman。
if exist(filename,'file'); delete(filename); end
initializeResultWorkbook(filename, algoNames); % 固定 Sheet1 至 Sheet6 的顺序

% 数据容器
meanErrorMatrix = nan(numFuncs, numAlgo);
legacyFriedmanRanks = nan(numFuncs, numAlgo);
meanEffects = nan(numFuncs, numAlgo-1);
rawPValues = nan(numFuncs, numAlgo-1);
rankEffects = nan(numFuncs, numAlgo-1);

%% ======================== 主循环：遍历函数 ========================
for idx = 1:numFuncs
    Function_name = func_list(idx);
    updateExperimentProgress('stage', sprintf('D=%d F=%d | Running', dim, Function_name));

    [lb, ub, dim_use, fobj] = Get_Functions_cec2017(Function_name, dim);
    optimumValue = 100*Function_name;

    configOffset = (dimIndex-1)*numFuncs+idx-1;
    pairedSeeds = baseSeed + configOffset*run_times*originalBenchmarkMethodCount + (1:run_times)';
    runSeeds = repmat(pairedSeeds,1,numAlgo);
    [best_scores, best_positions, cg_curves, runSeconds, runDiagnostics] = ...
        runExperimentTasks(algoPool, quietRunner, progressQueue, parallelOptions, ...
        runSeeds, SearchAgents, Max_iteration, lb, ub, dim_use, fobj);

    drawnow; % Process queued progress updates after the parallel work.
    updateExperimentProgress('stage', sprintf('D=%d F=%d | Saving results', dim, Function_name));
    scoreErrors = cec2017Errors(best_scores, optimumValue, errorTolerance);
    curveErrors = cec2017Errors(cg_curves, optimumValue, errorTolerance);
    rawScoreErrors = best_scores-optimumValue;
    rawCurveErrors = cg_curves-optimumValue;
    % Keep raw values for audit, and record exactly which errors were analyzed.
    save(fullfile(outputDir, sprintf('F%d_Raw.mat', Function_name)), ...
        'best_scores', 'best_positions', 'cg_curves', 'scoreErrors', 'curveErrors', ...
        'optimumValue', 'errorTolerance', 'metricName', 'algoNames', ...
        'dim', 'Function_name', 'SearchAgents', 'Max_iteration', 'run_times', ...
        'runSeeds', 'runSeconds', 'runDiagnostics', 'rawScoreErrors', 'rawCurveErrors', 'experimentMetadata');
    writematrix(scoreErrors,fullfile(outputDir,sprintf('F%d_ScoreErrors.csv',Function_name)));
    writematrix(rawScoreErrors,fullfile(outputDir,sprintf('F%d_RawScoreErrors.csv',Function_name)));
    writematrix(reshape(mean(curveErrors,1),Max_iteration,numAlgo), ...
        fullfile(outputDir,sprintf('F%d_MeanCurve.csv',Function_name)));

    exportFunctionFigures(makeFigures, outputDir, Function_name, fobj, dim_use, ...
        curveErrors, plotNames, errorTolerance, scoreErrors);

    %% ================= 统计 1: 基本指标 (Sheet 1) =================
    worstV = max(rawScoreErrors, [], 1);
    bestV  = min(rawScoreErrors, [], 1);
    stdV   = std(rawScoreErrors, 0, 1);
    meanV  = mean(rawScoreErrors, 1);
    medV   = median(rawScoreErrors, 1);
    
    fun_col   = {['F' num2str(Function_name)];'';'';'';''};
    ind_col   = {'Best';'Worst';'Mean';'Median';'Std'};
    data_blk  = [bestV; worstV; meanV; medV; stdV]; % 注意顺序
    
    writeCell = [fun_col, ind_col, num2cell(data_blk)];
    startRow  = (idx-1)*5 + 2; 
    writecell(writeCell, filename, 'Sheet', sheet1, 'Range', ['A' num2str(startRow)]);

    % Store one summary per function/algorithm for valid function blocks.
    meanErrorMatrix(idx,:) = mean(rawScoreErrors,1);
    legacyFriedmanRanks(idx,:) = legacyFriedmanMeanRanks(rawScoreErrors);
    meanEffects(idx,:) = mean(best_scores(:,2:end)-best_scores(:,1),1);
    for k = 2:numAlgo
        [rawPValues(idx,k-1), rankEffects(idx,k-1)] = ...
            comparePairedSamples(best_scores(:,1),best_scores(:,k));
    end
    updateExperimentProgress('advance', 1);

end

%% ======================== 函数区组排名及校正后的 Wilcoxon ========================
[friedValsMat, friedmanP, friedmanTable] = rankAcrossFunctions(meanErrorMatrix);
% One predeclared family contains all functions x all candidate-versus-control contrasts within this dimension.
adjustedPValues = holmAdjust(rawPValues);
[rawWilcoxonData, wilcoxonData] = writeComparisonSheets(filename, func_list, ...
    algoNames, legacyFriedmanRanks, rawPValues, meanEffects, adjustedPValues, ...
    rankEffects, friedValsMat, friedmanP, friedmanTable, alpha);

updateExperimentProgress('stage', sprintf('D=%d | Saving summary', dim));

% The corrected win/tie/loss counts continue to use Sheet4 (Holm).
summary = cell(numAlgo, 5);
summary(1,:) = {'Target', 'Opponent', 'Win (+)', 'Tie (=)', 'Loss (-)'};
for k = 2:numAlgo
    signs = wilcoxonData(:, 2*k-1);
    counts = [sum(strcmp(signs, '+')), sum(strcmp(signs, '=')), sum(strcmp(signs, '-'))];
    allWinTieLoss(dimIndex,k-1,:) = reshape(counts, 1, 1, 3);
    summary(k,:) = [algoNames(1), algoNames(k), num2cell(counts)];
end

% Preserve every dimension for the final horizontal radar strip.
allRadarRanks(:,:,dimIndex) = friedValsMat;
% Polygon radar keeps the same mean-error ranks, now reported in Sheet6.
writematrix(friedValsMat,fullfile(outputDir,sprintf('CEC2017_D%d_RadarRanks.csv',dim)));
exportRadarFigures(makeFigures, friedValsMat, func_list, plotNames, dim, ...
    fullfile(outputDir, sprintf('CEC2017_D%d_Radar', dim)));
save(fullfile(outputDir, 'Statistics.mat'), 'friedValsMat', 'wilcoxonData', ...
    'summary', 'algoNames', 'func_list', 'dim', 'metricName', 'errorTolerance', ...
    'meanErrorMatrix','rawPValues','adjustedPValues','rankEffects','friedmanP','friedmanTable','alpha', ...
    'legacyFriedmanRanks','rawWilcoxonData','meanEffects','experimentMetadata');
updateExperimentProgress('advance', 1);
end
updateExperimentProgress('stage', 'Saving combined ranks and win/tie/loss summary');
% Left to right: dimensions, in the same order as the experiment loop.
exportRadarFigures(makeFigures, allRadarRanks, func_list, plotNames, dimensions, ...
    fullfile(outputRoot, 'CEC2017_AllDimensions_Radar'));
save(fullfile(outputRoot, 'Radar_AllDimensions.mat'), ...
    'allRadarRanks', 'func_list', 'algoNames', 'dimensions', 'metricName', 'errorTolerance', 'experimentMetadata');
summaryFile = fullfile(outputRoot, 'CEC2017_WinTieLoss_Summary.xlsx');
writeWinTieLossSummary(summaryFile, allWinTieLoss, dimensions, algoNames, func_list, errorTolerance);
updateExperimentProgress('advance', 1);
updateExperimentProgress('finish', []);
delete(algoPool);
meanRanks = reshape(mean(allRadarRanks,1),numAlgo,numel(dimensions));
fprintf('\n===== DFPQNO FUSION VERSION SUMMARY: CEC2017 =====\n');
fprintf('Protocol: %d functions, %d runs/function, N=%d, T=%d\n',numFuncs,run_times,SearchAgents,Max_iteration);
for dimIndex = 1:numel(dimensions)
    dimensionRanks=meanRanks(:,dimIndex);targetRank=dimensionRanks(1);
    targetPosition=1+sum(dimensionRanks<targetRank);
    fprintf('D=%3d | DFPQNO (final) average rank %.6f | position %d/%d\n', ...
        dimensions(dimIndex),targetRank,targetPosition,numAlgo);
end
fprintf('=========================================\n');
fprintf('Results: %s\n', outputRoot);

function exportFunctionFigures(enabled, outputDir, Function_name, fobj, dim_use, ...
    curveErrors, plotNames, errorTolerance, scoreErrors)
if ~enabled
    return
end
% Three panels: objective landscape, convergence and score distribution.
combinedFig = figure('Color', 'w', 'Visible', 'off', ...
    'Position', [100 100 1280 430]);
% All three panels share one width, height, baseline and horizontal gap.
panelPositions = [0.065 0.30 0.255 0.57; ...
                  0.390 0.30 0.255 0.57; ...
                  0.715 0.30 0.255 0.57];

% 13 pt ticks remain about 7.3 pt when the PDF is placed at 190 mm width.
landscapeAxes = axes('Parent', combinedFig, ...
    'Position', panelPositions(1,:), 'FontSize', 13);
plotObjectiveLandscape(gca, fobj, dim_use);
title(['F' num2str(Function_name)], 'FontName', 'Times New Roman');

convergenceAxes = axes('Parent', combinedFig, ...
    'Position', panelPositions(2,:), 'FontSize', 13);
plotErrorConvergence(gca, curveErrors, plotNames, errorTolerance);
title('Convergence curve', 'FontName', 'Times New Roman');

boxAxes = axes('Parent', combinedFig, ...
    'Position', panelPositions(3,:), 'FontSize', 13);
boxplot_mat = scoreErrors; % run_times x numAlgo
boxplot(boxplot_mat, 'Labels', plotNames, 'Symbol', 'o');
title('Box plot', 'FontName', 'Times New Roman');
ylabel('{\it f}({\bf x}) - {\it f}^{*}', 'Interpreter', 'tex', ...
    'FontName', 'Times New Roman');
xtickangle(45);
grid on; box on;

% Apply after plotting: surfc/boxplot may reset axes properties.
set(findall(combinedFig, 'Type', 'axes'), 'FontSize', 13);
curveLegend = findobj(combinedFig, 'Type', 'legend');
set(curveLegend, 'Orientation', 'horizontal', 'NumColumns', 3, ...
    'Units', 'normalized', 'Location', 'southoutside', 'Box', 'off');
drawnow;
legendPosition = curveLegend.Position;
legendPosition(1) = (1-legendPosition(3))/2;
legendPosition(2) = 0.025;
curveLegend.Position = legendPosition;
panelAxes = [landscapeAxes convergenceAxes boxAxes];
for panel = 1:numel(panelAxes)
    set(panelAxes(panel), 'PositionConstraint', 'innerposition', ...
        'Position', panelPositions(panel,:));
    set(panelAxes(panel).Title, 'Units', 'normalized', ...
        'Position', [0.5 1.065 0]);
end

exportCompactPdf(combinedFig, fullfile(outputDir, ['CEC2017-F' num2str(Function_name) '_Combined.pdf']));
savefig(combinedFig, fullfile(outputDir, ['CEC2017-F' num2str(Function_name) '_Combined.fig']));
close(combinedFig);
end

function exportRadarFigures(enabled, ranks, functionIds, names, dimensions, baseName)
if ~enabled
    return
end
radarFig = plotCec2017Radar(ranks, functionIds, names, dimensions);
exportgraphics(radarFig, [baseName '.pdf'], 'ContentType', 'vector', 'Padding', 6);
exportgraphics(radarFig, [baseName '.png'], 'Resolution', 300, 'Padding', 6);
savefig(radarFig, [baseName '.fig']);
close(radarFig);
end

function radarFig = plotCec2017Radar(meanRanks, functionIds, names, dimensions)
% One polygon radar per dimension, with one shared legend below all panels.
% No titles, subtitles, explanatory footers, or preview annotations are drawn.
numFunctions = numel(functionIds);
numAlgorithms = numel(names);
numPanels = numel(dimensions);
assert(numFunctions >= 3 && size(meanRanks, 1) == numFunctions && ...
    size(meanRanks, 2) == numAlgorithms && size(meanRanks, 3) == numPanels, ...
    'Radar data must contain functions x algorithms x dimensions.');
assert(all(isfinite(meanRanks), 'all') && all(meanRanks >= 1 & meanRanks <= numAlgorithms, 'all'), ...
    'Mean ranks must be finite and within the algorithm rank range.');

% Restrained colors, distinct markers, and a stronger first/target algorithm.
palette = [ ...
    0.10 0.18 0.30; ... % DFPQNO
    0.24 0.51 0.73; ... % Original Full
    0.22 0.61 0.53; ... % Uniform initialization
    0.82 0.60 0.22; ... % No curvature
    0.61 0.44 0.67; ... % No archive
    0.85 0.43 0.31; ... % Fixed memory (previous best)
    0.43 0.53 0.62; ... % No slope
    0.52 0.58 0.28];    % Fixed scale

markers = {'o', 's', 'd', '^', 'v', '>', '<', 'p'};
theta = pi/2 - (0:numFunctions-1) * 2*pi/numFunctions;
closedTheta = [theta theta(1)];
maxRank = numAlgorithms;

if numPanels == 1
    figureSize = [1480 1020];
    panelLeft = 0.15;
    panelWidth = 0.70;
    functionFontSize = 20;
    rankFontSize = 15;
    legendFontSize = 15;
    strokeScale = 1;
else
    figureSize = [680*numPanels 760];
    panelLeft = 0.012;
    panelWidth = 0.976/numPanels;
    % About 7 pt after placing the four-panel strip at 190 mm width.
    functionFontSize = 7*numPanels;
    rankFontSize = 6.75*numPanels;
    legendFontSize = 7*numPanels;
    strokeScale = 0.45*numPanels;
end
radarFig = figure('Color', 'w', 'Position', [50 80 figureSize], ...
    'Visible', 'off', 'Name', 'CEC2017 radar', 'NumberTitle', 'off');
legendAxes = gobjects(1);
legendHandles = gobjects(1, numAlgorithms);
for panel = 1:numPanels
    ax = axes('Parent', radarFig, 'Position', ...
        [panelLeft+(panel-1)*panelWidth 0.14 panelWidth 0.84]);
hold(ax, 'on');
axis(ax, 'equal');
axis(ax, 'off');
xlim(ax, [-1.19 1.19] * maxRank);
ylim(ax, [-1.19 1.19] * maxRank);

patch(ax, maxRank*cos(closedTheta), maxRank*sin(closedTheta), [0.975 0.981 0.990], ...
    'EdgeColor', 'none', 'HandleVisibility', 'off');
for rankValue = 1:maxRank
    if rankValue == maxRank
        gridColor = [0.66 0.71 0.77];
        gridWidth = 1.0*strokeScale;
    else
        gridColor = [0.85 0.88 0.91];
        gridWidth = 0.65*strokeScale;
    end
    plot(ax, rankValue*cos(closedTheta), rankValue*sin(closedTheta), ...
        'Color', gridColor, 'LineWidth', gridWidth, 'HandleVisibility', 'off');
end
for j = 1:numFunctions
    plot(ax, [0 maxRank*cos(theta(j))], [0 maxRank*sin(theta(j))], ...
        'Color', [0.84 0.87 0.90], 'LineWidth', 0.65*strokeScale, 'HandleVisibility', 'off');
    text(ax, 1.09*maxRank*cos(theta(j)), 1.09*maxRank*sin(theta(j)), ...
        sprintf('F%d', functionIds(j)), 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', 'FontName', 'Times New Roman', ...
        'FontSize', functionFontSize, 'Color', [0.17 0.21 0.27]);
end

lineHandles = gobjects(1, numAlgorithms);
for a = [2:numAlgorithms 1] % Draw the target last so it remains visible.
    color = palette(mod(a-1, size(palette, 1)) + 1, :);
    marker = markers{mod(a-1, numel(markers)) + 1};
    ranks = meanRanks(:, a, panel).';
    closedRanks = [ranks ranks(1)];
    if a == 1
        lineWidth = 2.7*strokeScale;
        markerSize = 6.2*sqrt(strokeScale);
        markerFace = color;
    else
        lineWidth = 1.25*strokeScale;
        markerSize = 5.0*sqrt(strokeScale);
        markerFace = 'none';
    end
    lineHandles(a) = plot(ax, closedRanks.*cos(closedTheta), closedRanks.*sin(closedTheta), ...
        'Color', color, 'LineWidth', lineWidth, 'Marker', marker, ...
        'MarkerSize', markerSize, 'MarkerIndices', 1:numFunctions, ...
        'MarkerFaceColor', markerFace, 'DisplayName', names{a});
end

% Rank labels sit between spokes, with a white backing for readability.
labelAngle = pi/2 + pi/numFunctions;
for rankValue = unique([1:2:maxRank maxRank])
    text(ax, rankValue*cos(labelAngle), rankValue*sin(labelAngle), num2str(rankValue), ...
        'FontName', 'Times New Roman', 'FontSize', rankFontSize, 'Color', [0.40 0.45 0.51], ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
        'BackgroundColor', 'w', 'Margin', 0.5);
end

    if panel == 1
        legendAxes = ax;
        legendHandles = lineHandles;
    end
end
lgd = legend(legendAxes, legendHandles, names, 'Interpreter', 'none', 'Box', 'off', ...
    'FontName', 'Times New Roman', 'FontSize', legendFontSize, 'Orientation', 'horizontal', ...
    'NumColumns', 3, 'AutoUpdate', 'off');
lgd.ItemTokenSize = [28 16];
lgd.TextColor = [0.17 0.21 0.27];
lgd.Units = 'normalized';
drawnow;
legendPosition = lgd.Position;
lgd.Position = [(1-legendPosition(3))/2 0.025 legendPosition(3) legendPosition(4)];
applyPublicationFonts(radarFig);
end
function [score,position,curve,diagnostic] = runAlgorithmQuietly(algorithm,varargin)
% Passive callback witness, outside the unchanged single-function optimizers.
expectedPopulation=varargin{1};expectedIterations=varargin{2};expectedDimension=varargin{5};
originalObjective=varargin{6};calls=0;evaluations=0;batchRows=[];invalid=0;observedBest=Inf;
lowerBound=reshape(varargin{3},1,[])+zeros(1,expectedDimension);
upperBound=reshape(varargin{4},1,[])+zeros(1,expectedDimension);
varargin{6}=@observedObjective;lastwarn('');
quietCall=@()algorithm(varargin{:}); %#ok<NASGU>
[captured,score,position,curve]=evalc('quietCall()');
assert(isscalar(score)&&isreal(score)&&isfinite(score),'CEC2017:InvalidBest','Invalid returned best.');
assert(isreal(position)&&numel(position)==expectedDimension&&all(isfinite(position(:))),'CEC2017:InvalidPosition');
positionRow=reshape(position,1,[]);
assert(all(positionRow>=lowerBound&positionRow<=upperBound),'CEC2017:OutOfBounds');
assert(isreal(curve)&&numel(curve)==expectedIterations&&all(isfinite(curve(:)))&&all(diff(curve(:))<=0)&&curve(end)==score,'CEC2017:InvalidCurve');
if strcmp(func2str(algorithm),'DFPQNO_UniformInit')
    expectedInitialRows=expectedPopulation;
else
    expectedInitialRows=2*expectedPopulation;
end
assert(calls==expectedIterations+1&&evaluations==expectedInitialRows+expectedPopulation*expectedIterations&&...
 isequal(batchRows,[expectedInitialRows,repmat(expectedPopulation,1,expectedIterations)]),'CEC2017:IncompleteNativeGenerations');
assert(isequal(score,observedBest),'CEC2017:CallbackBest');
replayed=originalObjective(positionRow);assert(isequal(score,replayed),'CEC2017:ReturnedPolicyReplay');
diagnostic=struct('ActualObjectiveCalls',calls,'ActualCandidateRows',evaluations,'BatchRows',batchRows,...
 'ActualFullOffspringGenerations',numel(batchRows)-1,'InvalidCandidateRows',invalid,...
 'ReturnedScoreEqualsCallbackBest',true,'ReturnedPolicyExactlyReplayed',true,'PostSearchReplayCalls',1,...
 'NoFEStoppingRule',true,'NoRNGOrAddedSearchObjectiveCallsFromObserver',true);
if ~isempty(lastwarn),fprintf(2,'\n%s',captured);end
 function values=observedObjective(X)
  assert(isnumeric(X)&&isreal(X)&&size(X,2)==expectedDimension,'CEC2017:CandidateShape');
  n=size(X,1);calls=calls+1;evaluations=evaluations+n;batchRows(end+1)=n;
  invalid=invalid+sum(~all(isfinite(X),2)|~all(X>=lowerBound&X<=upperBound,2));
  values=originalObjective(X);assert(isnumeric(values)&&numel(values)==n,'CEC2017:FitnessShape');
  usable=values(isfinite(values));if ~isempty(usable),observedBest=min(observedBest,min(usable));end
 end
end

function records = snapshotExperimentCode(scriptDir)
% Store exact code hashes with every new experiment's raw results.
files = [dir(fullfile(scriptDir,'*.m')); dir(fullfile(scriptDir,'*.cpp')); ...
    dir(fullfile(scriptDir,'cec17_func.mexw64')); dir(fullfile(scriptDir,'input_data17','*.txt'))];
records = repmat(struct('file','','sha256','','sourceBytes',uint8([])),numel(files),1);
for i = 1:numel(files)
    sourcePath = fullfile(files(i).folder,files(i).name);
    fid = fopen(sourcePath,'rb');
    assert(fid>=0,'CEC2017:CodeSnapshot','Cannot read %s.',sourcePath);
    closer = onCleanup(@() fclose(fid));
    bytes = fread(fid,Inf,'*uint8');
    clear closer
    digest = java.security.MessageDigest.getInstance('SHA-256');
    digest.update(typecast(bytes,'int8'));
    hashBytes = typecast(digest.digest(),'uint8');
    records(i).file = erase(sourcePath,[scriptDir filesep]);
    records(i).sha256 = lower(reshape(dec2hex(hashBytes,2).',1,[]));
    [~,~,extension] = fileparts(sourcePath);
    if any(strcmp(extension,{'.m','.cpp'}))
        records(i).sourceBytes = bytes;
    end
end
end

function [pool, cpuInfo] = startExperimentPool(jobFolder)
% One single-threaded process per available logical CPU. CEC MEX uses global
% state, so separate processes are required even on machines with many cores.
% Resolve this relative job folder under the D drive root reported by the system.
relativeFile=java.io.File(jobFolder);
assert(~relativeFile.isAbsolute()&&~contains(jobFolder,':'),'CEC2017:RelativeJobStorage', ...
    'Pass a relative process-storage folder.');
driveRoots=java.io.File.listRoots();researchBase='';
for driveIndex=1:numel(driveRoots)
    driveRoot=char(driveRoots(driveIndex).getCanonicalPath());
    if numel(driveRoot)>=2&&strcmpi(driveRoot(1),'D')&&driveRoot(2)==':'
        researchBase=fullfile(driveRoot,'Codex','Temp','DFPQNO_Final_Integration');
        break
    end
end
assert(~isempty(researchBase),'CEC2017:ResearchDrive','The D drive is required for temporary process storage.');
baseFile=java.io.File(researchBase);canonicalBase=char(baseFile.getCanonicalPath());
jobFile=java.io.File(fullfile(researchBase,jobFolder));jobFolder=char(jobFile.getCanonicalPath());
assert(strcmpi(canonicalBase,researchBase)&&startsWith(lower(jobFolder),lower([canonicalBase filesep])), ...
    'CEC2017:JobStorage','The canonical process-storage target must remain inside the research temporary directory.');
if ~isfolder(jobFolder),mkdir(jobFolder);end
runtime = java.lang.Runtime.getRuntime();
count = double(runtime.availableProcessors());
assert(isfinite(count) && count >= 1 && count == fix(count), ...
    'CEC2017:CpuDetection', 'Cannot determine the available logical CPU count.');
pool = gcp('nocreate');
if ~isempty(pool)
    matches = ~isa(pool,'parallel.ThreadPool') && ...
        isa(pool.Cluster,'parallel.cluster.Local') && ...
        pool.NumWorkers == count && pool.Cluster.NumThreads == 1 && ...
        strcmpi(pool.Cluster.JobStorageLocation,jobFolder);
    if ~matches
        % Do not cancel unrelated work when replacing an existing small pool.
        queue = pool.FevalQueue;
        assert(isempty(queue.RunningFutures) && isempty(queue.QueuedFutures), ...
            'CEC2017:PoolBusy', 'The existing pool has active tasks. Let them finish before running this experiment.');
        lastwarn('');
        captured = evalc('delete(pool)');
        if ~isempty(lastwarn)
            fprintf(2,'\n%s',captured);
        end
        pool = [];
    end
end
if isempty(pool)
    cluster = parcluster('Processes');
    % Change this object only; do not overwrite the user's saved profile.
    cluster.NumWorkers = count;
    cluster.NumThreads = 1;
    cluster.JobStorageLocation = jobFolder;
    poolFactory = @() parpool(cluster,count,'IdleTimeout',120); %#ok<NASGU> Called by evalc below.
    lastwarn('');
    [captured,pool] = evalc('poolFactory()');
    if ~isempty(lastwarn)
        fprintf(2,'\n%s',captured);
    end
end
pool.IdleTimeout = 120;
assert(pool.NumWorkers == count,'CEC2017:PoolSize', ...
    'Expected %d workers but started %d.',count,pool.NumWorkers);
cpuInfo = struct('availableLogicalProcessors',count,'workers',pool.NumWorkers, ...
    'threadsPerWorker',pool.Cluster.NumThreads,'poolType',class(pool), ...
    'detectionMethod','java.lang.Runtime.availableProcessors', ...
    'taskScheduling','One algorithm and independent run per task; fixed subrange size 1', ...
    'jobStorageLocation',jobFolder);
end

function [best_scores, best_positions, cg_curves, runSeconds, runDiagnostics] = ...
    runExperimentTasks(algoPool, quietRunner, progressQueue, parallelOptions, ...
    runSeeds, populationSize, iterations, lb, ub, dimension, fobj)
arguments
    algoPool (1,1) parallel.pool.Constant
    quietRunner (1,1) function_handle
    progressQueue (1,1) parallel.pool.DataQueue
    parallelOptions
    runSeeds
    populationSize
    iterations
    lb
    ub
    dimension
    fobj (1,1) function_handle
end
% Interleave algorithms and schedule each independent run separately. The
% every variant shares the frozen original target-column seed for this run.
[runTimes,numAlgorithms] = size(runSeeds);
numTasks = runTimes*numAlgorithms;
taskSeeds = reshape(runSeeds.',[],1);
taskScores = nan(numTasks,1);
taskPositions = nan(numTasks,dimension);
taskCurves = nan(numTasks,iterations);
taskSeconds = nan(numTasks,1);
taskDiagnostics = cell(numTasks,1);
% Dereference the worker-local constant, never its contents on the client.
workerValue = @(constant) constant.Value;
workerRunner = @(varargin) quietRunner(varargin{:});
parfor (task = 1:numTasks, parallelOptions)
    algorithmIndex = mod(task-1,numAlgorithms)+1;
    workerFcns = workerValue(algoPool);
    rng(taskSeeds(task),'twister');
    algorithmTimer = tic;
    [score,position,curve,diagnostic] = workerRunner(workerFcns{algorithmIndex}, ...
        populationSize,iterations,lb,ub,dimension,fobj);
    taskSeconds(task) = toc(algorithmTimer);
    taskDiagnostics{task} = diagnostic;
    taskScores(task) = score;
    taskPositions(task,:) = position(:).';
    taskCurves(task,:) = curve(:).';
    send(progressQueue,1);
end
% Restore the original MAT/statistics array layout: run x value x algorithm.
best_scores = reshape(taskScores,numAlgorithms,runTimes).';
best_positions = permute(reshape(taskPositions,numAlgorithms,runTimes,dimension),[2 3 1]);
cg_curves = permute(reshape(taskCurves,numAlgorithms,runTimes,iterations),[2 3 1]);
runSeconds = reshape(taskSeconds,numAlgorithms,runTimes).';
runDiagnostics = reshape(taskDiagnostics,numAlgorithms,runTimes).';
end

function updateExperimentProgress(action, value)
% A single client-side line; parallel workers only send completed-work counts.
persistent total completed stage timer lastUpdate lineLength workerCount
switch action
    case 'init'
        total = value;
        completed = 0;
        stage = 'Starting parallel pool';
        timer = tic;
        lastUpdate = -inf;
        lineLength = 0;
        workerCount = 0;
    case 'cpu'
        workerCount = value;
    case 'advance'
        completed = completed + value;
        if toc(timer) - lastUpdate < 0.25
            return;
        end
    case 'stage'
        stage = value;
    case 'finish'
        completed = total;
        stage = 'Complete';
    otherwise
        error('CEC2017:ProgressAction', 'Unknown progress action: %s', action);
end
elapsed = toc(timer);
elapsedText = sprintf('%02d:%02d:%02d', floor(elapsed/3600), ...
    mod(floor(elapsed/60), 60), mod(floor(elapsed), 60));
lineText = sprintf('Progress %6.2f%% | %d/%d | %s | Elapsed %s', ...
    100*min(completed/total, 1), completed, total, stage, elapsedText);
if workerCount > 0
    lineText = sprintf('%s | Workers %d',lineText,workerCount);
end
lineText = [lineText repmat(' ', 1, max(0, lineLength-numel(lineText)))];
fprintf('%s%s', repmat(char(8), 1, lineLength), lineText);
lineLength = numel(lineText);
lastUpdate = elapsed;
if strcmp(action, 'finish')
    fprintf('\n');
end
end

function applyPublicationFonts(fig)
% Apply the publication typeface to axes, tick labels, legends and all text.
set(findall(fig, '-property', 'FontName'), 'FontName', 'Times New Roman');
set(findall(fig, '-property', 'FontUnits'), 'FontUnits', 'points');
end

function exportCompactPdf(fig, filename)
% Match the PDF page to the figure canvas instead of a fixed paper sheet.
% Rasterize the dense 3D surface to prevent unbounded vector-renderer memory use.
% The canvas, fonts, panels and numerical content remain unchanged.
applyPublicationFonts(fig);
drawnow;
exportgraphics(fig, filename, 'ContentType', 'image', 'Resolution', 300, 'Padding', 6);
end

function errors = cec2017Errors(values, optimumValue, tolerance)
% CEC2017 reporting metric: Fi(x)-Fi(x*), with errors below 1e-8 recorded as zero.
errors = values - optimumValue;
if any(~isfinite(errors), 'all')
    error('CEC2017:NonfiniteFitness', 'The optimizer returned a nonfinite fitness value.');
end
if any(errors < -tolerance, 'all')
    error('CEC2017:BelowOptimum', ...
        'A fitness value is below the known optimum by more than the numerical tolerance.');
end
errors(errors < tolerance) = 0;
end

function plotObjectiveLandscape(ax, objective, dimension)
% Show the raw objective slice; only performance plots/statistics use errors.
% meshgrid columns are x1 and rows are x2, matching the actual axis labels.
coordinates = -100:2:100;
[x1, x2] = meshgrid(coordinates, coordinates);
rawValues = zeros(size(x1));
remainingCoordinates = zeros(1, dimension-2);
for point = 1:numel(x1)
    rawValues(point) = objective([x1(point) x2(point) remainingCoordinates]);
end
surfc(ax, x1, x2, rawValues, 'LineStyle', 'none');
xlabel(ax, '{\it x}_1', 'Interpreter', 'tex');
ylabel(ax, '{\it x}_2', 'Interpreter', 'tex');
zlabel(ax, 'F( x_1 , x_2 )', 'Interpreter', 'tex');
grid(ax, 'on');
box(ax, 'on');
end

function plotErrorConvergence(ax, curveErrors, names, tolerance)
% Average objective error across independent runs at each iteration.
numIterations = size(curveErrors, 2);
numAlgorithms = numel(names);
meanErrors = reshape(mean(curveErrors, 1), numIterations, numAlgorithms);
colors = publicationPalette(numAlgorithms);
hold(ax, 'on');
for algorithm = 1:numAlgorithms
    % Display-only floor: the statistical data keep their exact zeros.
    semilogy(ax, 1:numIterations, max(meanErrors(:, algorithm), tolerance), ...
        'LineWidth', 1.5, 'Color', colors(algorithm,:));
end
set(ax, 'YScale', 'log');
axis(ax, 'tight');
if any(meanErrors <= tolerance, 'all')
    ylim(ax, [tolerance max(10*tolerance, 1.1*max(meanErrors, [], 'all'))]);
    ticks = unique([tolerance ax.YTick]);
    ticks = ticks(ticks >= ax.YLim(1) & ticks <= ax.YLim(2));
    labels = compose("10^{%g}", log10(ticks));
    labels(ticks == tolerance) = "\leq10^{-8}";
    set(ax, 'YTick', ticks, 'YTickLabel', labels, 'TickLabelInterpreter', 'tex');
end
xlabel(ax, 'Iteration');
% The caption specifies the across-run mean; both error axes name the metric.
ylabel(ax, '{\it f}({\bf x}) - {\it f}^{*}', 'Interpreter', 'tex');
grid(ax, 'on');
box(ax, 'on');
legend(ax, names, 'Interpreter', 'none', 'FontSize', 12.5, 'Location', 'northeast');
end

function writeWinTieLossSummary(filename, counts, dimensions, names, functionIds, tolerance)
% Each function/dimension pair contributes one win, tie or loss per opponent.
numOpponents = numel(names)-1;
numDimensions = numel(dimensions);
numFunctions = numel(functionIds);
assert(isequal(sum(counts, 3), numFunctions*ones(numDimensions, numOpponents)), ...
    'Every opponent must have one outcome for each tested function and dimension.');
if isfile(filename)
    delete(filename);
end
overall = cell(numOpponents+1, 6);
overall(1,:) = {'Target', 'Opponent', 'Win (+)', 'Tie (=)', 'Loss (-)', 'Comparisons'};
totalCounts = reshape(sum(counts, 1), numOpponents, 3);
for opponent = 1:numOpponents
    overall(opponent+1,:) = [names(1), names(opponent+1), ...
        num2cell(totalCounts(opponent,:)), {numDimensions*numFunctions}];
end
writecell(overall, filename, 'Sheet', 'Overall', 'Range', 'A1');

byDimension = cell(numDimensions*numOpponents+1, 7);
byDimension(1,:) = {'Dimension', 'Target', 'Opponent', 'Win (+)', 'Tie (=)', 'Loss (-)', 'Comparisons'};
for dimensionIndex = 1:numDimensions
    for opponent = 1:numOpponents
        row = 1+(dimensionIndex-1)*numOpponents+opponent;
        byDimension(row,:) = [{dimensions(dimensionIndex)}, names(1), names(opponent+1), ...
            num2cell(reshape(counts(dimensionIndex,opponent,:), 1, 3)), {numFunctions}];
    end
end
writecell(byDimension, filename, 'Sheet', 'ByDimension', 'Range', 'A1');
notes = {'Metric', 'Full-precision f(x)-f*; correct suite optima are saved per function'; ...
    'Display zero floor only', tolerance; ...
    'Test', sprintf(['Exact paired signed-rank; Holm across all %d functions and %d ' ...
        'DFPQNO-versus-control contrasts (%d tests per dimension)'],numFunctions,numOpponents,numFunctions*numOpponents); ...
    'Win (+)', 'Adjusted p <0.05 and positive paired signed-rank effect favoring DFPQNO'; ...
    'Tie (=)', 'No detected significant difference; not proof of equivalence'; ...
    'Loss (-)', 'Adjusted p <0.05 and negative paired signed-rank effect favoring the variant'; ...
    'Overall counts', 'Sum over the tested function/dimension pairs; not independent runs'; ...
    'Convergence plot', 'X: iteration; Y: mean error, log scale; values <=1e-8 shown at the labeled floor'; ...
    'Radar plot', 'Per-function ranks of across-run mean errors; tied values share a rank; lower is better'};
writecell(notes, filename, 'Sheet', 'Notes', 'Range', 'A1');
end

function references = describeAlgorithms(handles,names)
% Original Full-based ablations remain unchanged; DFPQNO is an added version.
references=repmat(struct('name','','journal','','doi','','publicationYear',NaN,...
 'authorCode','','implementationNotes',''),1,numel(handles));
for i=1:numel(handles)
 references(i).name=names{i};references(i).authorCode=which(func2str(handles{i}));
 references(i).implementationNotes=implementationNotes(func2str(handles{i}));
end
end

function handles=initializeWorker(folder,handles)
% Every process resolves the user-provided local native binary and input folder.
cd(folder);addpath(folder);
clear cec17_func Get_Functions_cec2017
assert(strcmpi(which('cec17_func'),fullfile(folder,['cec17_func.' mexext])),'CEC2017:WorkerMEXPath');
assert(strcmpi(which('Get_Functions_cec2017'),fullfile(folder,'Get_Functions_cec2017.m')),'CEC2017:WorkerObjectivePath');
names=cellfun(@func2str,handles,'UniformOutput',false);
 handles=cell(size(handles));
 clear(names{:}); % Clear only these optimizer names in this worker.
 for i=1:numel(names)
  name=names{i};
  assert(strcmpi(which(name),fullfile(folder,[name '.m'])),'CEC2017:WorkerPath');
  handles{i}=str2func(name);
 end
end

function validateExperimentEnvironment(handles,folder)
% Statistics/plotting and process scheduling only; no unrelated solver toolbox.
required={'friedman','tiedrank','boxplot','parpool'};
for i=1:numel(required),assert(~isempty(which(required{i})),'CEC2017:MissingDependency','Required: %s',required{i});end
clear cec17_func Get_Functions_cec2017
assert(exist('cec17_func','file')==3&&strcmpi(which('cec17_func'),fullfile(folder,['cec17_func.' mexext])),'CEC2017:MissingMEX');
assert(strcmpi(which('Get_Functions_cec2017'),fullfile(folder,'Get_Functions_cec2017.m')),'CEC2017:ObjectivePath');
assert(isfolder(fullfile(folder,'input_data17')),'CEC2017:MissingInputs');
for i=1:numel(handles)
 name=func2str(handles{i});assert(strcmpi(which(name),fullfile(folder,[name '.m'])),'CEC2017:AlgorithmPath');
end
end

function map = resultSheetMap()
map = {'Sheet1','Full-precision error statistics'; ...
       'Sheet2','Per-function Friedman mean ranks'; ...
       'Sheet3','Exact paired signed-rank p-values and signs'; ...
       'Sheet4','Holm-adjusted exact paired p-values and signs'; ...
       'Sheet5','Paired rank-biserial effects'; ...
       'Sheet6','Function-block ranks and overall Friedman test'};
end

function header = comparisonHeader(names, prefix)
header = cell(1,1+2*(numel(names)-1));
header{1} = 'Function';
for k = 2:numel(names)
    header{2*k-2} = [prefix ' (' names{1} ' vs ' names{k} ')'];
    header{2*k-1} = 'Sig';
end
end

function initializeResultWorkbook(filename, names)
% Create every worksheet in its final order before writing any results.
headers = {[{'Function','Error indicator'},names], ...
    [{'Function'},names], comparisonHeader(names,'p-val'), ...
    comparisonHeader(names,'Holm p'), [{'Function'},names(2:end)], ...
    [{'Function'},names]};
for k = 1:numel(headers)
    writecell(headers{k},filename,'Sheet',sprintf('Sheet%d',k),'Range','A1');
end
end

function ranks = legacyFriedmanMeanRanks(errors)
% Preserve the per-function table. Rows here are common-seed paired run
% blocks shared by all component versions; overall inference is in Sheet6.
if all(errors==errors(:,1),'all')
    ranks = repmat((size(errors,2)+1)/2,1,size(errors,2));
else
    [~,~,statistics] = friedman(errors,1,'off');
    ranks = statistics.meanranks(:).';
end
end

function cells = rankingTable(labels, names, ranks)
averages = mean(ranks,1);
cells = [[{'Function'},names]; [labels,num2cell(ranks)]; ...
    [{'Average'},num2cell(averages)]; [{'Rank'},num2cell(tiedrank(averages))]];
end

function rows = comparisonRows(labels, pValues, direction, alpha)
rows = cell(size(pValues,1),1+2*size(pValues,2));
rows(:,1) = labels;
for k = 1:size(pValues,2)
    for i = 1:size(pValues,1)
        sig = '=';
        if pValues(i,k) < alpha
            if direction(i,k) > 0
                sig = '+';
            elseif direction(i,k) < 0
                sig = '-';
            end
        end
        rows{i,2*k} = pValues(i,k);
        rows{i,2*k+1} = sig;
    end
end
end

function notes=sheetNotes()
notes=[{'Worksheet','Contents'};resultSheetMap();...
 {'Paired seeds','Every component uses the same original target-column seed in each run.'};...
 {'Sheet3/4 signs','Direction follows matching signed ranks; positive favors DFPQNO.'};...
 {'Holm family','All selected functions x all DFPQNO-versus-control contrasts within each dimension.'};...
 {'Display floor','Only plotted/display errors are zeroed at1e-8; every statistical ranking/test uses full precision.'};...
 {'Sheet2','Common-seed descriptive ranks within each function; overall function-block inference inSheet6.'}];
end

function [rawWilcoxonData, wilcoxonData] = writeComparisonSheets(filename, ...
    functionIds, names, legacyRanks, rawPValues, ~, adjustedPValues, ...
    rankEffects, functionRanks, friedmanP, friedmanTable, alpha)
labels = cellstr(compose('F%d',functionIds(:)));
numFunctions = numel(functionIds);
writecell(rankingTable(labels,names,legacyRanks),filename,'Sheet','Sheet2','Range','A1');
% Raw exact paired test and signed-rank effect direction.
rawWilcoxonData = comparisonRows(labels,rawPValues,rankEffects,alpha);
writecell(rawWilcoxonData,filename,'Sheet','Sheet3','Range','A2');
% The added corrected test still drives the existing win/tie/loss summary.
wilcoxonData = comparisonRows(labels,adjustedPValues,rankEffects,alpha);
writecell(wilcoxonData,filename,'Sheet','Sheet4','Range','A2');
writecell([labels,num2cell(rankEffects)],filename,'Sheet','Sheet5','Range','A2');
writecell(rankingTable(labels,names,functionRanks),filename,'Sheet','Sheet6','Range','A1');
writecell({'Friedman p (functions as blocks)',friedmanP},filename, ...
    'Sheet','Sheet6','Range',sprintf('A%d',numFunctions+6));
if ~isempty(friedmanTable)
    writecell(friedmanTable,filename,'Sheet','Sheet6', ...
        'Range',sprintf('A%d',numFunctions+9));
else
    writecell({'Friedman test','All algorithms tied within every function; p = 1.'}, ...
        filename,'Sheet','Sheet6','Range',sprintf('A%d',numFunctions+9));
end
writecell(sheetNotes(),filename,'Sheet','Sheet6', ...
    'Range',sprintf('A%d',numFunctions+max(1,size(friedmanTable,1))+12));
end

function [pValue,effect,s]=comparePairedSamples(reference,variant)
% Positive effect favors the reference; native objective eps defines zeros.
assert(isvector(reference)&&isvector(variant)&&numel(reference)==numel(variant));
assert(all(isfinite(reference(:)))&&all(isfinite(variant(:))));
s=exactPairedSignedRank(variant(:)-reference(:),eps(reference(:))+eps(variant(:)));
pValue=s.P;effect=s.RankBiserial;
end
function s=exactPairedSignedRank(delta,zeroTolerance)
% Exact conditional sign-flip test, average ranks for exactly tied magnitudes.
delta=delta(:);zeroTolerance=zeroTolerance(:);keep=abs(delta)>zeroTolerance;d=delta(keep);n=numel(d);
s=struct('NNonzero',n,'Zeros',numel(delta)-n,'WPositive',0,'RankBiserial',0,'P',1);
if n==0,return,end
[v,order]=sort(abs(d));ranks=zeros(n,1);first=1;
while first<=n
 last=first;while last<n&&v(last+1)==v(first),last=last+1;end
 ranks(order(first:last))=(first+last)/2;first=last+1;
end
s.WPositive=sum(ranks(d>0));s.RankBiserial=2*s.WPositive/sum(ranks)-1;
weights=round(2*ranks);counts=1;
for k=1:n
 next=zeros(1,numel(counts)+weights(k));next(1:numel(counts))=counts;
 ix=weights(k)+(1:numel(counts));next(ix)=next(ix)+counts;counts=next;
end
observed=round(2*s.WPositive);
s.P=min(1,2*min(sum(counts(1:observed+1)),sum(counts(observed+1:end)))/2^n);
end

function adjusted = holmAdjust(pValues)
assert(all(isfinite(pValues) & pValues>=0 & pValues<=1,'all'), ...
    'CEC2017:InvalidPValue','P-values must be finite and between zero and one.');
[ordered,indices] = sort(pValues(:));
count = numel(ordered);
orderedAdjusted = min(1,cummax(ordered.*(count:-1:1).'));
adjusted = zeros(size(pValues));
adjusted(indices) = orderedAdjusted;
end

function [ranks,pValue,testTable] = rankAcrossFunctions(meanErrors)
% Each function is one shared block for across-function inference.
ranks = zeros(size(meanErrors));
for i = 1:size(meanErrors,1)
    ranks(i,:) = tiedrank(meanErrors(i,:));
end
if all(meanErrors==meanErrors(:,1),'all')
    pValue = 1;
    testTable = {};
else
    [pValue,testTable] = friedman(meanErrors,1,'off');
end
end

function colors = publicationPalette(count)
colors = [0.10 0.18 0.30; 0.24 0.51 0.73; 0.22 0.61 0.53; ...
    0.82 0.60 0.22; 0.61 0.44 0.67; 0.85 0.43 0.31; 0.43 0.53 0.62; 0.52 0.58 0.28];
if count>size(colors,1)
    colors = [colors; lines(count-size(colors,1))];
end
colors = colors(1:count,:);
end

function note=implementationNotes(name)
switch name
 case 'DFPQNO',note='New fusion candidate added to the unchanged original panel. Relative to previous-best FixedMemory, replace lattice initialization by N uniform candidates plus opposition screening, and change directional weight from 1/dim to 1/sqrt(dim). Retain slope, diagonal DFP, archive and phi-centered Cauchy scales; success memory remains absent. Complete performance is to be measured.';
 case 'DFPQNO_Full',note='Original complete algorithm, preserved byte-for-byte from the previous seven-method experiment: lattice/opposition initialization, population slope, diagonal DFP, archive, success-history scale memory, Cauchy perturbation and 1/dim directional weight. This is the original ablation reference, not an alias of the fusion.';
 case 'DFPQNO_UniformInit',note='Original Full-based control: replace lattice/opposition initialization and 2N screening by N independent uniform candidates. Retain original success memory, Cauchy perturbation, slope, DFP, archive and 1/dim directional weight.';
 case 'DFPQNO_NoCurvature',note='Original Full-based control: delete diagonal curvature and DFP updates; use the population slope directly through clip(-g). Retain original success memory and other original mechanisms. This is not a single deletion from the new fusion.';
 case 'DFPQNO_NoArchive',note='Original Full-based control: delete the displaced-parent archive and use current population donors. Retain original success memory and other original mechanisms. This is not a single deletion from the new fusion.';
 case 'DFPQNO_FixedMemory',note='Previous measured-best original ablation version: delete success-history feedback while retaining lattice/opposition initialization, phi-centered Cauchy perturbation, slope, DFP, archive and 1/dim guidance. Retained unchanged to measure whether the new fusion improves on it.';
 case 'DFPQNO_NoSlope',note='Original Full-based grouped control: delete population-slope estimation and its dependent diagonal DFP state and directional-guidance branch. Retain original success memory, Cauchy perturbation, archive and differential search; this does not isolate slope independently of DFP.';
 case 'DFPQNO_FixedScale',note='Original Full-based joint control: replace adaptive Cauchy scales by constant phi; delete both success-history memory and Cauchy perturbation. Retain original slope, DFP, archive, lattice/opposition initialization and 1/dim guidance. The historical source is unchanged; this does not isolate Cauchy perturbation alone.';
 otherwise,error('CEC2017:UnknownComponent','Unregistered component file: %s',name);
end
end

function writeProtocolNotes(folder,metadata)
references=metadata.algorithmReferences;
fid=fopen(fullfile(folder,'CEC2017_Protocol.txt'),'w','n','UTF-8');assert(fid>=0);closer=onCleanup(@()fclose(fid));
fprintf(fid,['CEC2017 final integration: one new fusion candidate plus the unchanged original ' ...
    'seven-method ablation panel (%d original methods); N=%d, MaxIt=%d, and %d paired independent runs.\n'], ...
    numel(references)-1,metadata.populationSize,metadata.iterations,metadata.runs);
fprintf(fid,'Final method: %s\nVersion token: %s\n',metadata.finalMethod,metadata.versionToken);
fprintf(fid,'Result version policy: %s\n',metadata.resultVersionPolicy);
fprintf(fid,'Study interpretation: %s. The original removals are defined relative to Original Full. Candidate-versus-control p-values compare versions; they cannot identify an isolated contribution to the fusion.\n',metadata.implementationProtocol);
fprintf(fid,'CEC2017 functions %s; dimensions %s; bounds[-100,100]; optimum100*F.\n', ...
    mat2str(metadata.functionIds),mat2str(metadata.dimensions));
fprintf(fid,'Shared seeds: %d+configOffset*%d*%d+run. %s.\n', ...
    metadata.baseSeed,metadata.runs,metadata.originalBenchmarkMethodCount,metadata.seedRule);
fprintf(fid,'Native raw objective values drive optimization and exact paired differences. Full-precision f(x)-f* drives all statistical ranks and Sheet1. Display error below1e-8 is zeroed only for figures/display exports.\n');
fprintf(fid,'Sheet2: common-seed per-function ranks. Sheet3: raw paired signed-rank p and rank direction. Sheet4: Holm-corrected paired tests. Sheet5: matched rank-biserial effects. Sheet6: function-block ranks and Friedman.\n');
fprintf(fid,'%s. One predefined Holm family per dimension.\n',metadata.statisticalProtocol);
fprintf(fid,'Figure export enabled: %d. Optimization and numerical statistics are independent of this setting.\n',metadata.figuresEnabled);
fprintf(fid,'Paired signed-rank uses eps(native reference)+eps(native variant), exactly tied nonzero absolute differences share ranks, exact conditional sign-flip distribution, two-sided inclusive tails. Nonsignificance is not equivalence.\n');
fprintf(fid,['No FE stopping or evaluation-budget comparison. UniformInit evaluates N initial candidates; ' ...
    'all other algorithms evaluate2N. Every iteration evaluatesN offspring forT iterations; batch callsT+1. ' ...
    'One returned-policy replay is post-search and excluded from search counts. ' ...
    'Observers add no random draw or search objective call.\n']);
fprintf(fid,'Raw MAT includes source hashes, actual per-run callback diagnostics and every seed. Results use the Results folder beside this entry; temporary cluster process storage uses D:. Native MEX and its input_data folder remain in this user suite folder.\n');
fprintf(fid,'Timings include concurrent scheduling and passive witness overhead; no claim of isolated fastest runtime. The paired signed-rank test assumes independent run seeds and a symmetric paired-difference null.\n');
for i=1:numel(references),fprintf(fid,'\n%s\n%s\nSource:%s\n',references(i).name,references(i).implementationNotes,references(i).authorCode);end
end


