clc; clear; close all
% Keep warnings visible; do not hide numerical or programming problems.
scriptDir = fileparts(mfilename('fullpath'));
cd(scriptDir); % CEC MEX loads input_data22 relative to the current folder.

outputRoot = fullfile(scriptDir, 'Results');
if ~isfolder(outputRoot)
    mkdir(outputRoot);
end

%% ======================== 参数设置 ========================
SearchAgents   = 30;      % 种群规模
Max_iteration  = 750;     % 最大迭代次数
dimensions     = [10 20]; % CEC2022 全部函数适用的维度
run_times      = 30;      % 每个函数独立运行次数
baseSeed       = 127955229; % frozen from panel-manifest SHA-256
alpha          = 0.05;     % 每个维度内全部目标/对手比较统一 Holm 校正

% ---------------- 并行计算设置 ----------------
% 自动识别全部可用逻辑处理器；每个处理器一个单线程进程。
% 每个“算法 × 独立运行”单独调度，完成后立即接手下一项计算。

% ---------------- 算法列表 ----------------
% 注意：将你提出的/最好的算法放在第一个位置，作为Wilcoxon检验的基准(Target)
% 每个算法一个同名 .m 文件；替换时修改下面对应的函数句柄和显示名称即可。
% NRBO 是必须保留的对比算法，不随其他对比项一起替换。
algoFcns  = {@DFPQNO, @AROA, @BBO, @BKA, @GJA, @HBO, @IVYA, @mLSHADE_SPACMA, @NDO, @NRBO, @SSLO, @TOC};
algoNames = {'DFPQNO', 'AROA', 'BBO', 'BKA', 'GJA', 'HBO', 'IVYA', 'mLSHADE_SPACMA', 'NDO', 'NRBO', 'SSLO', 'TOC'};
assert(numel(algoFcns)==numel(algoNames),'算法接口和名称的数量必须一致。');
algorithmReferences = describeAlgorithms(algoFcns,algoNames);
validateExperimentEnvironment(algoFcns, scriptDir);
numAlgo   = numel(algoFcns);


% ---------------- 函数集合 ----------------
% CEC2022 全部十二个函数，包括 F2。
func_list = 1:12;
numFuncs  = numel(func_list);
% Official CEC2022 objective error; the optimizer still receives raw f(x).
errorTolerance = 1e-8;
metricName = 'Objective error f(x)-f*, values below 1e-8 recorded as zero';
experimentMetadata = struct('startedAt',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')), ...
    'matlabVersion',version,'platform',computer,'randomGenerator','twister', ...
    'baseSeed',baseSeed,'dimensions',dimensions,'functionIds',func_list, ...
    'populationSize',SearchAgents,'iterations',Max_iteration,'runs',run_times, ...
    'algorithmReferences',algorithmReferences, ...
    'sourceFiles',snapshotExperimentCode(scriptDir), ...
    'statisticalProtocol','Per-function two-sided rank-sum; Holm across all target/opponent tests within each dimension; Friedman with functions as blocks', ...
    'rankMetric','Across-run mean objective error', ...
    'implementationProtocol','Selected implementations and adaptations are documented in algorithmReferences', ...
    'alpha',alpha);
experimentMetadata.excelSheets = resultSheetMap();
writeProtocolNotes(outputRoot, algorithmReferences);

% Count optimizer runs and output steps across all selected dimensions.
totalWork = numel(dimensions) * (numFuncs*(run_times*numAlgo + 1) + 1) + 1;
updateExperimentProgress('init', totalWork);
[experimentPool, cpuInfo] = startExperimentPool();
parallelOptions = parforOptions(experimentPool, ...
    'RangePartitionMethod','fixed','SubrangeSize',1);
experimentMetadata.parallel = cpuInfo;
save(fullfile(outputRoot,'CEC2022_Experiment_Manifest.mat'),'experimentMetadata');
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
filename = fullfile(outputDir, sprintf('cec2022_Results_D%d.xlsx', dim));
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

    [lb, ub, dim_use, fobj, optimumValue] = Get_Functions_cec2022(Function_name, dim);

    runSeeds = baseSeed + reshape(1:run_times*numAlgo,run_times,numAlgo) ...
        + ((dimIndex-1)*numFuncs+idx-1)*run_times*numAlgo;
    [best_scores, best_positions, cg_curves, runSeconds] = ...
        runExperimentTasks(algoPool, quietRunner, progressQueue, parallelOptions, ...
        runSeeds, SearchAgents, Max_iteration, lb, ub, dim_use, fobj);

    drawnow; % Process queued progress updates after the parallel work.
    updateExperimentProgress('stage', sprintf('D=%d F=%d | Saving figures and statistics', dim, Function_name));
    scoreErrors = cec2022Errors(best_scores, optimumValue, errorTolerance);
    curveErrors = cec2022Errors(cg_curves, optimumValue, errorTolerance);
    % Keep raw values for audit, and record exactly which errors were analyzed.
    save(fullfile(outputDir, sprintf('F%d_Raw.mat', Function_name)), ...
        'best_scores', 'best_positions', 'cg_curves', 'scoreErrors', 'curveErrors', ...
        'optimumValue', 'errorTolerance', 'metricName', 'algoNames', ...
        'dim', 'Function_name', 'SearchAgents', 'Max_iteration', 'run_times', ...
        'runSeeds', 'runSeconds', 'experimentMetadata');
    writematrix(scoreErrors,fullfile(outputDir,sprintf('F%d_ScoreErrors.csv',Function_name)));
    writematrix(reshape(mean(curveErrors,1),Max_iteration,numAlgo), ...
        fullfile(outputDir,sprintf('F%d_MeanCurve.csv',Function_name)));

    %% ================= 绘图：三图合一 (SCI 布局) =================
    % 布局：1行3列 [3D函数 | 收敛曲线 | 箱线图]
    % 这种宽长图适合放在论文页面的顶部或底部跨栏显示
    
    combinedFig = figure('Color', 'w', 'Visible', 'off', ...
        'Position', [100 100 1280 430]);
    % All three panels share one width, height, baseline and horizontal gap.
    panelPositions = [0.065 0.30 0.255 0.57; ...
                      0.390 0.30 0.255 0.57; ...
                      0.715 0.30 0.255 0.57];
    
    % --- 子图 1: 3D 函数景观 ---
    % 13 pt ticks remain about 7.3 pt when the PDF is placed at 190 mm width.
    landscapeAxes = axes('Parent', combinedFig, ...
        'Position', panelPositions(1,:), 'FontSize', 13);
    plotObjectiveLandscape(gca, fobj, dim_use);
    title(['F' num2str(Function_name)], 'FontName', 'Times New Roman');
    
    % --- 子图 2: 收敛曲线 ---
    convergenceAxes = axes('Parent', combinedFig, ...
        'Position', panelPositions(2,:), 'FontSize', 13);
    plotErrorConvergence(gca, curveErrors, algoNames, errorTolerance);
    title('Convergence curve', 'FontName', 'Times New Roman');

    % --- 子图 3: 箱线图 ---
    boxAxes = axes('Parent', combinedFig, ...
        'Position', panelPositions(3,:), 'FontSize', 13);
    boxplot_mat = scoreErrors; % run_times x numAlgo
    boxplot(boxplot_mat, 'Labels', algoNames, 'Symbol', 'o'); 
    title('Box plot', 'FontName', 'Times New Roman');
    ylabel('{\it f}({\bf x}) - {\it f}^{*}', 'Interpreter', 'tex', ...
        'FontName', 'Times New Roman');
    xtickangle(45); % 算法名字斜着放防止重叠
    grid on; box on;

    % Apply after plotting: surfc/boxplot may reset axes properties.
    set(findall(combinedFig, 'Type', 'axes'), 'FontSize', 13);
    % A shared bottom legend keeps readable labels clear of the curves.
    curveLegend = findobj(combinedFig, 'Type', 'legend');
    set(curveLegend, 'Orientation', 'horizontal', 'NumColumns', numel(algoNames), ...
        'Units', 'normalized', 'Location', 'southoutside', 'Box', 'off');
    drawnow;
    legendPosition = curveLegend.Position;
    legendPosition(1) = (1-legendPosition(3))/2;
    legendPosition(2) = 0.025;
    curveLegend.Position = legendPosition;
    % Plotting commands and the outside legend can resize individual axes.
    panelAxes = [landscapeAxes convergenceAxes boxAxes];
    for panel = 1:numel(panelAxes)
        set(panelAxes(panel), 'PositionConstraint', 'innerposition', ...
            'Position', panelPositions(panel,:));
        set(panelAxes(panel).Title, 'Units', 'normalized', ...
            'Position', [0.5 1.065 0]);
    end

    % 导出图片 (矢量 PDF 格式，清晰度最高)
    exportCompactPdf(combinedFig, fullfile(outputDir, ['CEC2022-F' num2str(Function_name) '_Combined.pdf']));
    savefig(combinedFig, fullfile(outputDir, ['CEC2022-F' num2str(Function_name) '_Combined.fig'])); % 如果需要保留fig源文件
    close(combinedFig);

    %% ================= 统计 1: 基本指标 (Sheet 1) =================
    worstV = max(scoreErrors, [], 1);
    bestV  = min(scoreErrors, [], 1);
    stdV   = std(scoreErrors, 0, 1);
    meanV  = mean(scoreErrors, 1);
    medV   = median(scoreErrors, 1);
    
    fun_col   = {['F' num2str(Function_name)];'';'';'';''};
    ind_col   = {'Best';'Worst';'Mean';'Median';'Std'};
    data_blk  = [bestV; worstV; meanV; medV; stdV]; % 注意顺序
    
    writeCell = [fun_col, ind_col, num2cell(data_blk)];
    startRow  = (idx-1)*5 + 2; 
    writecell(writeCell, filename, 'Sheet', sheet1, 'Range', ['A' num2str(startRow)]);

    % Store one summary per function/algorithm for valid function blocks.
    meanErrorMatrix(idx,:) = meanV;
    legacyFriedmanRanks(idx,:) = legacyFriedmanMeanRanks(scoreErrors);
    meanEffects(idx,:) = meanV(2:end)-meanV(1);
    for k = 2:numAlgo
        [rawPValues(idx,k-1), rankEffects(idx,k-1)] = ...
            compareIndependentSamples(scoreErrors(:,1), scoreErrors(:,k));
    end
    updateExperimentProgress('advance', 1);

end

%% ======================== 函数区组排名及校正后的 Wilcoxon ========================
[friedValsMat, friedmanP, friedmanTable] = rankAcrossFunctions(meanErrorMatrix);
% One predefined comparison family: all functions x opponents in this dimension.
adjustedPValues = holmAdjust(rawPValues);
[rawWilcoxonData, wilcoxonData] = writeComparisonSheets(filename, func_list, ...
    algoNames, legacyFriedmanRanks, rawPValues, meanEffects, adjustedPValues, ...
    rankEffects, friedValsMat, friedmanP, friedmanTable, alpha);

updateExperimentProgress('stage', sprintf('D=%d | Saving summary and radar', dim));

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
writematrix(friedValsMat,fullfile(outputDir,sprintf('CEC2022_D%d_RadarRanks.csv',dim)));
radarFig = plotCec2022Radar(friedValsMat, func_list, algoNames, dim);
exportgraphics(radarFig, fullfile(outputDir, sprintf('CEC2022_D%d_Radar.pdf', dim)), 'ContentType', 'vector', 'Padding', 6);
exportgraphics(radarFig, fullfile(outputDir, sprintf('CEC2022_D%d_Radar.png', dim)), 'Resolution', 300, 'Padding', 6);
savefig(radarFig, fullfile(outputDir, sprintf('CEC2022_D%d_Radar.fig', dim)));
close(radarFig);
save(fullfile(outputDir, 'Statistics.mat'), 'friedValsMat', 'wilcoxonData', ...
    'summary', 'algoNames', 'func_list', 'dim', 'metricName', 'errorTolerance', ...
    'meanErrorMatrix','rawPValues','adjustedPValues','rankEffects','friedmanP','friedmanTable','alpha', ...
    'legacyFriedmanRanks','rawWilcoxonData','meanEffects');
updateExperimentProgress('advance', 1);
end
updateExperimentProgress('stage', 'Saving combined radar and win/tie/loss summary');
% Left to right: dimensions, in the same order as the experiment loop.
radarStripFig = plotCec2022Radar(allRadarRanks, func_list, algoNames, dimensions);
stripBase = fullfile(outputRoot, 'CEC2022_AllDimensions_Radar');
exportgraphics(radarStripFig, [stripBase '.pdf'], 'ContentType', 'vector', 'Padding', 6);
exportgraphics(radarStripFig, [stripBase '.png'], 'Resolution', 300, 'Padding', 6);
savefig(radarStripFig, [stripBase '.fig']);
close(radarStripFig);
save(fullfile(outputRoot, 'Radar_AllDimensions.mat'), ...
    'allRadarRanks', 'func_list', 'algoNames', 'dimensions', 'metricName', 'errorTolerance');
summaryFile = fullfile(outputRoot, 'CEC2022_WinTieLoss_Summary.xlsx');
writeWinTieLossSummary(summaryFile, allWinTieLoss, dimensions, algoNames, func_list, errorTolerance);
updateExperimentProgress('advance', 1);
updateExperimentProgress('finish', []);
delete(algoPool);
meanRanks = reshape(mean(allRadarRanks,1),numAlgo,numel(dimensions));
fprintf('\n===== DFPQNO FINAL SUMMARY: CEC2022 =====\n');
fprintf('Protocol: %d functions, %d runs/function, N=%d, T=%d\n',numFuncs,run_times,SearchAgents,Max_iteration);
for dimIndex = 1:numel(dimensions)
    dimensionRanks=meanRanks(:,dimIndex);targetRank=dimensionRanks(1);
    targetPosition=1+sum(dimensionRanks<targetRank);
    fprintf('D=%3d | DFPQNO average rank %.6f | position %d/%d\n', ...
        dimensions(dimIndex),targetRank,targetPosition,numAlgo);
end
fprintf('=========================================\n');
fprintf('Results: %s\n', outputRoot);

function radarFig = plotCec2022Radar(meanRanks, functionIds, names, dimensions)
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
    0.10 0.18 0.30; ... % DFPQNO: ink navy
    0.24 0.51 0.73; ... % AROA: blue
    0.22 0.61 0.53; ... % BBO: teal
    0.82 0.60 0.22; ... % BKA: ochre
    0.61 0.44 0.67; ... % GJA: purple
    0.85 0.43 0.31; ... % HBO: terracotta
    0.43 0.53 0.62; ... % IVYA: slate
    0.34 0.68 0.73; ... % mLSHADE_SPACMA: aqua
    0.57 0.64 0.32; ... % NDO: olive
    0.44 0.43 0.70; ... % NRBO: indigo
    0.74 0.40 0.54; ... % SSLO: rose
    0.30 0.58 0.42];    % TOC: green

markers = {'o', 's', 'd', '^', 'v', '>', '<', 'p', 'h', 'x', '+', '*'};
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
    'Visible', 'off', 'Name', 'CEC2022 radar', 'NumberTitle', 'off');
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
    'NumColumns', numAlgorithms, 'AutoUpdate', 'off');
lgd.ItemTokenSize = [28 16];
lgd.TextColor = [0.17 0.21 0.27];
lgd.Units = 'normalized';
drawnow;
legendPosition = lgd.Position;
lgd.Position = [(1-legendPosition(3))/2 0.025 legendPosition(3) legendPosition(4)];
applyPublicationFonts(radarFig);
end
function [score, position, curve] = runAlgorithmQuietly(algorithm, varargin)
% Capture ordinary iteration messages without changing the optimizer itself.
% Actual warnings are printed, and exceptions still propagate to MATLAB.
lastwarn('');
quietCall = @() algorithm(varargin{:}); %#ok<NASGU> Invoked by evalc below.
[captured, score, position, curve] = evalc('quietCall()');
expectedIterations = varargin{2};
expectedDimension = varargin{5};
assert(isscalar(score) && isreal(score) && isfinite(score), ...
    'CEC2022:InvalidBest','%s returned an invalid best value.',func2str(algorithm));
assert(isreal(position) && numel(position)==expectedDimension && all(isfinite(position(:))), ...
    'CEC2022:InvalidPosition','%s returned an invalid position.',func2str(algorithm));
lowerBound = reshape(varargin{3},1,[])+zeros(1,expectedDimension);
upperBound = reshape(varargin{4},1,[])+zeros(1,expectedDimension);
positionRow = reshape(position,1,[]);
assert(all(positionRow>=lowerBound & positionRow<=upperBound), ...
    'CEC2022:OutOfBounds','%s returned a position outside the bounds.',func2str(algorithm));
assert(isreal(curve) && numel(curve)==expectedIterations && all(isfinite(curve(:))) ...
    && all(diff(curve(:))<=0) && curve(end)==score, ...
    'CEC2022:InvalidCurve','%s returned an incomplete or inconsistent curve.',func2str(algorithm));
if ~isempty(lastwarn)
    fprintf(2, '\n%s', captured);
end
end

function records = snapshotExperimentCode(scriptDir)
% Store exact code hashes with every new experiment's raw results.
files = [dir(fullfile(scriptDir,'*.m')); dir(fullfile(scriptDir,'*.cpp')); ...
    dir(fullfile(scriptDir,'cec22_func.mexw64')); dir(fullfile(scriptDir,'input_data22','*.txt'))];
records = repmat(struct('file','','sha256','','sourceBytes',uint8([])),numel(files),1);
for i = 1:numel(files)
    sourcePath = fullfile(files(i).folder,files(i).name);
    fid = fopen(sourcePath,'rb');
    assert(fid>=0,'CEC2022:CodeSnapshot','Cannot read %s.',sourcePath);
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

function [pool, cpuInfo] = startExperimentPool()
% One single-threaded process per available logical CPU. CEC MEX uses global
% state, so separate processes are required even on machines with many cores.
runtime = java.lang.Runtime.getRuntime();
count = double(runtime.availableProcessors());
assert(isfinite(count) && count >= 1 && count == fix(count), ...
    'CEC2022:CpuDetection', 'Cannot determine the available logical CPU count.');
pool = gcp('nocreate');
if ~isempty(pool)
    matches = ~isa(pool,'parallel.ThreadPool') && ...
        isa(pool.Cluster,'parallel.cluster.Local') && ...
        pool.NumWorkers == count && pool.Cluster.NumThreads == 1;
    if ~matches
        % Do not cancel unrelated work when replacing an existing small pool.
        queue = pool.FevalQueue;
        assert(isempty(queue.RunningFutures) && isempty(queue.QueuedFutures), ...
            'CEC2022:PoolBusy', 'The existing pool has active tasks. Let them finish before running this experiment.');
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
    jobFolder = fullfile(tempdir,'ParallelJobs');
    if ~isfolder(jobFolder)
        mkdir(jobFolder);
    end
    cluster.JobStorageLocation = jobFolder;
    poolFactory = @() parpool(cluster,count,'IdleTimeout',120); %#ok<NASGU> Called by evalc below.
    lastwarn('');
    [captured,pool] = evalc('poolFactory()');
    if ~isempty(lastwarn)
        fprintf(2,'\n%s',captured);
    end
end
pool.IdleTimeout = 120;
assert(pool.NumWorkers == count,'CEC2022:PoolSize', ...
    'Expected %d workers but started %d.',count,pool.NumWorkers);
cpuInfo = struct('availableLogicalProcessors',count,'workers',pool.NumWorkers, ...
    'threadsPerWorker',pool.Cluster.NumThreads,'poolType',class(pool), ...
    'detectionMethod','java.lang.Runtime.availableProcessors', ...
    'taskScheduling','One algorithm and independent run per task; fixed subrange size 1');
end

function [best_scores, best_positions, cg_curves, runSeconds] = ...
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
% seed still belongs to exactly the same (run, algorithm) pair as before.
[runTimes,numAlgorithms] = size(runSeeds);
numTasks = runTimes*numAlgorithms;
taskSeeds = reshape(runSeeds.',[],1);
taskScores = nan(numTasks,1);
taskPositions = nan(numTasks,dimension);
taskCurves = nan(numTasks,iterations);
taskSeconds = nan(numTasks,1);
% Dereference the worker-local constant, never its contents on the client.
workerValue = @(constant) constant.Value;
workerRunner = @(varargin) quietRunner(varargin{:});
parfor (task = 1:numTasks, parallelOptions)
    algorithmIndex = mod(task-1,numAlgorithms)+1;
    workerFcns = workerValue(algoPool);
    rng(taskSeeds(task),'twister');
    algorithmTimer = tic;
    [score,position,curve] = workerRunner(workerFcns{algorithmIndex}, ...
        populationSize,iterations,lb,ub,dimension,fobj);
    taskSeconds(task) = toc(algorithmTimer);
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
        error('CEC2022:ProgressAction', 'Unknown progress action: %s', action);
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

function errors = cec2022Errors(values, optimumValue, tolerance)
% CEC2022 reporting metric: Fi(x)-Fi(x*), with errors below 1e-8 recorded as zero.
errors = values - optimumValue;
if any(~isfinite(errors), 'all')
    error('CEC2022:NonfiniteFitness', 'The optimizer returned a nonfinite fitness value.');
end
if any(errors < -tolerance, 'all')
    error('CEC2022:BelowOptimum', ...
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
notes = {'Metric', 'f(x)-f*, f*=[300 400 600 800 900 1800 2000 2200 2300 2400 2600 2700]'; ...
    'Zero tolerance', tolerance; ...
    'Test', 'Two-sided rank-sum; Holm adjusted p < 0.05, all functions x opponents within each dimension'; ...
    'Win (+)', 'Adjusted p < 0.05 and P(target<opponent) > P(target>opponent)'; ...
    'Tie (=)', 'No detected significant difference; not proof of equivalence'; ...
    'Loss (-)', 'Adjusted p < 0.05 and P(target>opponent) > P(target<opponent)'; ...
    'Overall counts', 'Sum over the tested function/dimension pairs; not independent runs'; ...
    'Convergence plot', 'X: iteration; Y: mean error, log scale; values <=1e-8 shown at the labeled floor'; ...
    'Radar plot', 'Per-function ranks of across-run mean errors; tied values share a rank; lower is better'};
writecell(notes, filename, 'Sheet', 'Notes', 'Range', 'A1');
end

function references = describeAlgorithms(handles,names)
% Read optional citation comments from the selected files, with no registry.
references = repmat(struct('name','','journal','','doi','', ...
    'publicationYear',NaN,'authorCode','','implementationNotes',''),1,numel(handles));
keys = {'Journal','DOI','PublicationYear','AuthorCode'};
fields = {'journal','doi','publicationYear','authorCode'};
for i=1:numel(handles)
    references(i).name = names{i};
    references(i).implementationNotes = implementationNotes(func2str(handles{i}));
    filename = which(func2str(handles{i}));
    if isempty(filename) || ~isfile(filename)
        continue
    end
    source = fileread(filename);
    if strcmp(func2str(handles{i}),'NRBO')
        references(i).journal = 'Engineering Applications of Artificial Intelligence';
        references(i).doi = '10.1016/j.engappai.2023.107532';
        references(i).publicationYear = 2024;
        references(i).authorCode = 'Existing NRBO.m, byte-for-byte preserved';
    end
    for k=1:numel(keys)
        token = regexp(source,['(?m)^% ' keys{k} ': ([^\r\n]+)'],'tokens','once');
        if isempty(token)
            continue
        end
        if strcmp(fields{k},'publicationYear')
            references(i).publicationYear = str2double(token{1});
        else
            references(i).(fields{k}) = token{1};
        end
    end
end
end

function handles = initializeWorker(folder, handles)
% CEC MEX loads data relative to the process working directory.
cd(folder);
for i = 1:numel(handles)
    name = func2str(handles{i});
    assert(strcmpi(fileparts(which(name)),folder), ...
        'CEC2022:WorkerPath','Worker resolved %s outside this experiment.',name);
end
end

function validateExperimentEnvironment(handles, folder)
required = {'ranksum','friedman','tiedrank','fmincon','normrnd','mvnrnd','createns','knnsearch','parpool'};
for i = 1:numel(required)
    assert(~isempty(which(required{i})), 'CEC2022:MissingDependency', ...
        'Required MATLAB function is unavailable: %s',required{i});
end
assert(exist('cec22_func','file')==3,'CEC2022:MissingMEX','cec22_func MEX is required.');
for i = 1:numel(handles)
    name = func2str(handles{i});
    assert(strcmpi(fileparts(which(name)),folder), ...
        'CEC2022:AlgorithmPath','%s must resolve inside the CEC2022 directory.',name);
end
end

function map = resultSheetMap()
map = {'Sheet1','Basic error statistics'; ...
       'Sheet2','Per-function Friedman mean ranks'; ...
       'Sheet3','Unadjusted Wilcoxon p-values and signs'; ...
       'Sheet4','Holm-adjusted Wilcoxon p-values and signs'; ...
       'Sheet5','Rank effects'; ...
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
% Preserve the original per-function table. Rows here are independent run
% indices; use the separate function-block test for overall inference.
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

function notes = sheetNotes()
notes = [{'Worksheet','Contents'}; resultSheetMap(); ...
    {'Sheet3 signs','Direction follows mean error, as in the original table.'}; ...
    {'Sheet4 / win-tie-loss','Direction follows rank effect after Holm adjustment.'}; ...
    {'Radar','Uses the function-block ranks in Sheet6.'}; ...
    {'Sheet2 interpretation','Run-row mean ranks; overall inference is in Sheet6.'}];
end

function [rawWilcoxonData, wilcoxonData] = writeComparisonSheets(filename, ...
    functionIds, names, legacyRanks, rawPValues, meanEffects, adjustedPValues, ...
    rankEffects, functionRanks, friedmanP, friedmanTable, alpha)
labels = cellstr(compose('F%d',functionIds(:)));
numFunctions = numel(functionIds);
writecell(rankingTable(labels,names,legacyRanks),filename,'Sheet','Sheet2','Range','A1');
% Sheet3 restores the original unadjusted test and mean-based sign direction.
rawWilcoxonData = comparisonRows(labels,rawPValues,meanEffects,alpha);
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

function [pValue,effect] = compareIndependentSamples(target,opponent)
% Rank effect: positive means target tends to have smaller objective errors.
if all(target==target(1)) && all(opponent==target(1))
    pValue = 1;
else
    pValue = ranksum(target,opponent);
end
effect = (sum(target(:)<opponent(:).','all') - ...
    sum(target(:)>opponent(:).','all')) / (numel(target)*numel(opponent));
end

function adjusted = holmAdjust(pValues)
assert(all(isfinite(pValues) & pValues>=0 & pValues<=1,'all'), ...
    'CEC2022:InvalidPValue','P-values must be finite and between zero and one.');
[ordered,indices] = sort(pValues(:));
count = numel(ordered);
orderedAdjusted = min(1,cummax(ordered.*(count:-1:1).'));
adjusted = zeros(size(pValues));
adjusted(indices) = orderedAdjusted;
end

function [ranks,pValue,testTable] = rankAcrossFunctions(meanErrors)
% Each function is one shared block; independent run indices are not blocks.
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
    0.82 0.60 0.22; 0.61 0.44 0.67; 0.85 0.43 0.31; ...
    0.43 0.53 0.62; 0.34 0.68 0.73; 0.57 0.64 0.32; ...
    0.44 0.43 0.70; 0.74 0.40 0.54];
if count>size(colors,1)
    colors = [colors; lines(count-size(colors,1))];
end
colors = colors(1:count,:);
end

function note = implementationNotes(name)
% Implementation provenance for the current CEC2022 experiment.
% Record algorithm sources and modifications to the original code.

switch name
    case 'DFPQNO'
        note = 'Target algorithm copied byte-for-byte from the current CEC2017 experiment.';

    case 'AROA'
        note = 'User-selected implementation; original source and modifications recorded in the experiment snapshot.';

    case 'BBO'
        note = 'User-selected implementation; original source and modifications recorded in the experiment snapshot.';

    case 'BKA'
        note = 'User-selected implementation; original source and modifications recorded in the experiment snapshot.';

    case 'GJA'
        note = 'User-selected implementation; original source and modifications recorded in the experiment snapshot.';

    case 'HBO'
        note = 'User-selected implementation; original source and modifications recorded in the experiment snapshot.';

    case 'IVYA'
        note = 'User-selected implementation; original source and modifications recorded in the experiment snapshot.';

    case 'mLSHADE_SPACMA'
        note = ['Modified LSHADE-SPACMA; ' ...
            'author MATLAB implementation adapted to the ' ...
            'common six-input interface; ' ...
            'function evaluation budget and bounds adapted; ' ...
            'numerical equivalence not yet verified.'];

    case 'NDO'
        note = 'User-selected implementation; original source and modifications recorded in the experiment snapshot.';

    case 'NRBO'
        note = 'Original user NRBO.m preserved byte-for-byte; 2024 journal paper, explicitly retained.';

    case 'SSLO'
        note = 'User-selected implementation; original source and modifications recorded in the experiment snapshot.';

    case 'TOC'
        note = 'User-selected implementation; original source and modifications recorded in the experiment snapshot.';

    otherwise
        note = 'User-selected implementation; record source snapshot and disclose any modifications.';
end
end

function writeProtocolNotes(folder,references)
fid = fopen(fullfile(folder,'CEC2022_Protocol.txt'),'w','n','UTF-8');
assert(fid>=0,'CEC2022:ProtocolFile','Cannot write the experiment protocol.');
closer = onCleanup(@() fclose(fid));
fprintf(fid,'CEC2022: F1-F12, dimensions 10 and 20; all bounds [-100,100].\n');
fprintf(fid,'Raw objectives drive optimization. Statistics use f(x)-f*. Errors below 1e-8 are recorded as zero.\n');
fprintf(fid,'Convergence: across-run arithmetic mean error on a logarithmic axis; zero is displayed at the labeled floor.\n');
fprintf(fid,'Left surface: raw objective slice with all coordinates after x2 fixed to zero. Box plots: final-run errors.\n');
fprintf(fid,'Sheet1: basic error statistics. Sheet2: original per-function Friedman mean ranks across run rows, Average and Rank.\n');
fprintf(fid,'Sheet3: original unadjusted two-sided rank-sum p-values and signs using mean-error direction.\n');
fprintf(fid,'Sheet4: two-sided rank-sum p-values corrected by Holm over all functions/opponents WITHIN EACH dimension.\n');
fprintf(fid,'Sheet5: rank effects P(target<opponent)-P(target>opponent).\n');
fprintf(fid,'Sheet6: across-run mean-error ranks and overall Friedman test with functions as blocks. Radar uses these same ranks.\n');
fprintf(fid,'Sheet2 retains the original descriptive run-row ranks; use the function-block test in Sheet6 for overall inference.\n');
fprintf(fid,'Win/loss require adjusted p<0.05 and a positive/negative rank effect. Tie means no detected significant difference, not equivalence.\n');
fprintf(fid,'Overall win/tie/loss counts describe the sum across dimensions; they are not an additional global significance test.\n');
fprintf(fid,'The horizontal radar panels follow the dimension order in the experiment manifest.\n');
fprintf(fid, ['Comparator implementations use the ' ...
    'common six-input interface; original algorithm ' ...
    'mechanisms and any adaptations are documented ' ...
    'in the experiment manifest.\n']);
for i = 1:numel(references)
    fprintf(fid,'\n%s | %s | DOI: %s | %g\n%s\n',references(i).name, ...
        references(i).journal,references(i).doi,references(i).publicationYear,references(i).implementationNotes);
end
end



