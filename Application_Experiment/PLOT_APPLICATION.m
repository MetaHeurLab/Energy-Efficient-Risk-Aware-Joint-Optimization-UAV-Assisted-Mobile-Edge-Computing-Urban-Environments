% F5: draw saved data; edit STYLE below without rerunning RUN_APPLICATION.
style.Font='Arial';style.FontSize=8.5;style.TickFontSize=7.5;
style.PanelFontSize=10;style.Width=12.2;style.Visible='off';
style.LineWidth=.75;style.TargetLineWidth=1.5;style.AxisLineWidth=.5;
style.PointSize=2.5;style.PNGResolution=600;style.ExportFormats={'fig','pdf','png'};
style.Ink=[.18 .21 .25];style.Faint=[.80 .83 .85];
style.Colours=[.18 .39 .63;.80 .49 .27;.31 .60 .54;.69 .43 .49; ...
 .54 .50 .66;.66 .60 .35;.36 .62 .72;.38 .46 .54; ...
 .61 .43 .31;.46 .61 .40;.64 .53 .62;.48 .54 .58];
style.LineStyles={'-','--',':','-.','-','--',':','-.','-','--',':','-.'};
style.ZoneFill=[.96 .92 .88];style.ZoneEdge=[.77 .66 .56];
style.HeatAnchors=[.97 .98 .97;.77 .88 .87;.46 .70 .73;.18 .39 .63];
style.RankAnchors=flipud(style.HeatAnchors);

plotRoot=fileparts(mfilename('fullpath'));previousPath=path;
restorePath=onCleanup(@()path(previousPath));addpath(fullfile(plotRoot,'src'));
workspace=plotRoot;
resultsFolder=fullfile(workspace,'Results');
studyFile=fullfile(resultsFolder,'STUDY.mat');
assert(isfile(studyFile),'Application:PlotMissingStudy','Complete RUN_APPLICATION.m first.');
saved=load(studyFile,'study');study=saved.study;
assert(strcmp(study.Status,'complete'),'Application:PlotIncompleteStudy');
fprintf('PLOT_LOAD_STUDY %s\n',study.StudyId);
caseIds=cellstr(string(study.CaseIds));
data=cell(size(caseIds));sources=cell(size(caseIds));
usedFiles={studyFile};usedHashes={file_hash(studyFile)};
for j=1:numel(caseIds)
 folder=fullfile(resultsFolder,caseIds{j});sourceFile=fullfile(folder,'plot_data.mat');
 saved=load(sourceFile,'plotData');d=saved.plotData;
 assert(strcmp(d.Schema.Version,'native_policy_application_data_v2')&& ...
  strcmp(d.CaseId,caseIds{j})&&strcmp(d.StudyId,study.StudyId),'Application:PlotVersion');
 assert(size(d.Native.Curves,1)==numel(d.Seeds)&& ...
  size(d.Native.Curves,2)==numel(d.Iterations)&&size(d.Native.Curves,3)==numel(d.Methods),'Application:PlotDimensions');
 assert(all(isfinite(d.Native.Curves(:)))&& ...
  all(isfinite(metric_values(d.Native.ValidationMetrics,'Primary')),'all'),'Application:PlotFinite');
 files=cellfun(@(name)fullfile(folder,name),d.InputFiles,'UniformOutput',false);
 hashes=cellfun(@file_hash,files,'UniformOutput',false);
 assert(isequal(hashes,d.InputSHA256),'Application:PlotChangedData');data{j}=d;
 sources{j}=struct('CaseId',caseIds{j},'PlotDataFile',sourceFile,'PlotDataSHA256',file_hash(sourceFile), ...
  'InputFiles',{files},'InputSHA256',{hashes},'Token',d.StudyToken,'TargetSourceSHA256',d.TargetSourceSHA256);
 usedFiles=[usedFiles {sourceFile} files]; %#ok<AGROW>
 usedHashes=[usedHashes {sources{j}.PlotDataSHA256} hashes]; %#ok<AGROW>
 fprintf('PLOT_INPUT_VERIFIED %s\n',caseIds{j});
end
methods=data{1}.Methods;M=numel(methods);
assert(M==size(style.Colours,1)&&all(cellfun(@(d)isequal(d.Methods,methods)&& ...
 strcmp(d.TargetSourceSHA256,data{1}.TargetSourceSHA256),data)),'Application:PlotMethods');
target=find(strcmp(methods,'DFPQNO'));competitor=find(strcmp(methods,'AROA'));
baseline=find(strcmp(caseIds,'baseline'));mobility=find(strcmp(caseIds,'measured_mobility'));
assert(isscalar(target)&&isscalar(competitor)&&isscalar(baseline)&&isscalar(mobility),'Application:PlotCases');
% Pictures and Results are siblings beside this script.
pictureFolder=fullfile(plotRoot,'Pictures',study.StudyId);
mainFolder=fullfile(pictureFolder,'Main');suppFolder=fullfile(pictureFolder,'Supplementary');
if ~isfolder(mainFolder),mkdir(mainFolder);end
if ~isfolder(suppFolder),mkdir(suppFolder);end
rngBefore=rng;entries=cell(10,1);q=0;

% Main 1: every method converges visibly; close comparison uses both pools.
d=data{baseline};fig=new_figure(6.6,style);tiles=tiledlayout(fig,1,2,'Padding','compact','TileSpacing','compact');
ax=nexttile(tiles);draw_convergence(ax,d,style,true);title(ax,'Training convergence');panel_letter(ax,'a',style);
ax=nexttile(tiles);draw_close_validation(ax,d,[target competitor],style);
title(ax,'Returned-policy validation');panel_letter(ax,'b',style);
caption=['Baseline, population input 40, 750 complete generations and 30 shared optimizer seeds. ' ...
 '(a) Across-seed median native penalized training objective on a log axis; the DFPQNO band is the ' ...
 'nearest-rank interquartile range. All twelve methods are drawn; ten secondary methods are grey. ' ...
 '(b) All 30 native DFPQNO and AROA policies on the original and additional independent 100-scenario pools ' ...
 '(circles and squares). Thin whiskers span min--max, thick segments span IQR and centre ticks mark medians. ' ...
 'Scenarios are not treated as independent optimizer replicates. Observer policies are never substituted.'];
q=q+1;entries{q}=export_figure(fig,mainFolder,'01_performance',caption, ...
 'Baseline convergence and two-pool native policy distributions; AROA is close to DFPQNO.',sources(baseline),style);

% Main 2: retain component tradeoffs instead of claiming universal dominance.
fig=new_figure(8.4,style);tiles=tiledlayout(fig,2,3,'Padding','compact','TileSpacing','compact');
fields={'Energy_kJ','MeanLatency_s','Latency95_s','Completion','Fairness','CVaR'};
names={'Energy (kJ)','Mean latency (s)','P95 latency (s)','Completion (%)','Jain fairness','CVaR overrun'};
for k=1:numel(fields)
 ax=nexttile(tiles);values=metric_values(d.Native.ValidationMetrics,fields{k});
 if strcmp(fields{k},'Completion'),values=100*values;end
 draw_paired_metrics(ax,values(:,[target competitor]),style);title(ax,names{k});panel_letter(ax,char('a'+k-1),style);
end
caption=['Baseline original-validation components for the same 30 shared-seed native DFPQNO and AROA ' ...
 'policies. Grey lines connect matched seeds; points include every run and black ticks show means. Energy, ' ...
 'mean/P95 latency and CVaR overrun are minimized; completion and fairness are maximized. Displayed vertical ' ...
 'ranges are not all zero-based. AROA has slightly better mean P95 latency, completion, fairness and CVaR, ' ...
 'while DFPQNO improves energy, mean latency and the composite objective. No component significance is asserted.'];
q=q+1;entries{q}=export_figure(fig,mainFolder,'02_metric_tradeoffs',caption, ...
 'Six paired distributions show energy and mean-latency gains with small tradeoffs in four other components.',sources(baseline),style);

% Main 3: actual lower-median validation runs, never independently selected.
fig=new_figure(6.8,style);tiles=tiledlayout(fig,1,2,'Padding','compact','TileSpacing','compact');
ax=nexttile(tiles);draw_trajectory(ax,data{baseline},[target competitor],style);
title(ax,'Synthetic user mobility');panel_letter(ax,'a',style);
ax=nexttile(tiles);draw_trajectory(ax,data{mobility},[target competitor],style);
title(ax,'Recorded ground mobility');panel_letter(ax,'b',style);
caption=['UAV polylines of the preselected lower-median original-native-validation run for each method: ' ...
 'DFPQNO blue solid, AROA orange dashed. Grey traces show eight users; shaded circles are model exclusion ' ...
 'zones, and an open circle/square marks prescribed start/finish. Coordinates are in kilometres with equal ' ...
 'axis scaling and identical 2 km square bounds. Left: synthetic user traces. Right: interpolated pNEUMA ' ...
 'ground-vehicle traces. Only ground mobility is measured; UAV flight, tasks, channels, energy and safety ' ...
 'are simulated. Representatives are not selected on the additional independent pool. Model paths do not ' ...
 'establish flight-test safety or robustness to navigation errors.'];
q=q+1;entries{q}=export_figure(fig,mainFolder,'03_trajectories',caption, ...
 'Two blue and dashed orange UAV path comparisons among grey user traces and three shaded model disks.',sources([baseline mobility]),style);

% Main 4: the same recorded-mobility DFPQNO representative as Main 3b.
d=data{mobility};r=d.Representatives{target};p=r.Policy;c=d.Configuration;
fig=new_figure(7.8,style);tiles=tiledlayout(fig,2,2,'Padding','compact','TileSpacing','compact');
arrays={p.offload,p.power,c.bandwidth*p.bandwidth/1e6,p.cpu/1e9};
resourceNames={'Offloaded fraction','Transmit power (W)','Bandwidth (MHz)','Edge CPU (GHz)'};
limits={[0 1],[0 c.pmax],[0 max(arrays{3}(:))],[0 max(arrays{4}(:))]};
for k=1:4
 ax=nexttile(tiles);imagesc(ax,(0:c.T-1)*c.dt,1:c.K,arrays{k},limits{k});
 set(ax,'YDir','normal','XTick',[0 50 100 150],'YTick',[1 4 8]);colormap(ax,colour_map(style.HeatAnchors));
 cb=colorbar(ax);cb.FontSize=style.TickFontSize;cb.FontName=style.Font;
 title(ax,resourceNames{k});xlabel(ax,'Service time (s)');ylabel(ax,'User');apply_axes(ax,style);panel_letter(ax,char('a'+k-1),style);
end
caption=sprintf(['Recorded-mobility DFPQNO allocations for the representative in Fig. 03b (run %d, seed %d). ' ...
 'Each cell is one of eight users at one of sixteen original samples (0--150 s); no smoothing is applied. ' ...
 'Offload and power scales use model bounds. Bandwidth/CPU scales start at zero and end at the largest ' ...
 'displayed allocation, not total resource capacity. Values are decoded saved policies, not UAV measurements.'],r.Run,r.Seed);
q=q+1;entries{q}=export_figure(fig,mainFolder,'04_resource_allocation',caption, ...
 'Four user-by-time heatmaps of offloading, power, bandwidth and edge CPU.',sources(mobility),style);

% Main 5: saved bootstrap intervals and model margins; no new tests.
globalFile=fullfile(resultsFolder,'GLOBAL_WILCOXON_HOLM.csv');
if ~isfile(globalFile)
 globalFile=fullfile(plotRoot,'audit','GLOBAL_WILCOXON_HOLM.csv');
end
contrasts=readtable(globalFile,'TextType','string');usedFiles{end+1}=globalFile;usedHashes{end+1}=file_hash(globalFile);
fig=new_figure(7.0,style);tiles=tiledlayout(fig,1,2,'Padding','compact','TileSpacing','compact');
ax=nexttile(tiles);draw_gain(ax,contrasts,caseIds,style);title(ax,'Composite gain vs AROA');panel_letter(ax,'a',style);
ax=nexttile(tiles);draw_margins(ax,data,target,style);title(ax,'DFPQNO model clearance');panel_letter(ax,'b',style);
caption=['Seven completed configurations, 30 native policies per method and case. (a) Relative reduction ' ...
 'in mean primary J against AROA: 100(mean AROA minus mean DFPQNO)/mean AROA. Circles/squares identify ' ...
 'original/additional independent validation. Segments are saved paired bootstrap 95% intervals (5000 ' ...
 'resamples), not simultaneous intervals. Filled markers denote saved Holm-adjusted significance; open ' ...
 'markers denote nonsignificance. Risk weights is marked ns: its signed-rank contrast fails the ' ...
 'saved Holm correction over all 154 comparisons. Absolute objectives under different weights are not ' ...
 'pooled. (b) All DFPQNO native-policy minimum model exclusion-zone clearances, in centimetres on a log ' ...
 'axis. Thick segments are nearest-rank IQRs; black ticks are medians. Small positive model margins are ' ...
 'not allowances for GPS, wind or actuation errors.'];
q=q+1;entries{q}=export_figure(fig,mainFolder,'05_sensitivity',caption, ...
 'Most gain intervals are positive, risk-weighted intervals cross zero, and model clearance varies by case.',sources,style);

% Main 6: fresh isolated serial timing, excluding warmup and post-search checks.
[~,timingTag]=fileparts(char(study.SerialTimingOutput));
assert(~isempty(timingTag),'Application:PlotTimingFolder','Missing serial timing directory name.');
timingFile=fullfile(resultsFolder,'serial_timing',timingTag,'serial_timing.mat');
saved=load(timingFile,'timing');timing=saved.timing;
assert(timing.NoParallelWorkers&&timing.WarmupExcluded&&~timing.SearchRuntimeIncludesPostSearchChecks&& ...
 isequal(timing.Methods,methods)&&strcmp(timing.TargetSourceSHA256,data{1}.TargetSourceSHA256),'Application:PlotSerialVersion');
usedFiles{end+1}=timingFile;usedHashes{end+1}=file_hash(timingFile);
timingSource={struct('CaseId','serial_timing','PlotDataFile',timingFile,'PlotDataSHA256',usedHashes{end})};
fig=new_figure(7.4,style);tiles=tiledlayout(fig,1,1,'Padding','compact');ax=nexttile(tiles);
[~,order]=sort(median(timing.RuntimeMatrix,1));draw_horizontal_samples(ax,timing.RuntimeMatrix(:,order),methods(order),order,style);
xlabel(ax,'Serial search time (s)');title(ax,'Isolated workstation timing (n = 5 per method)');
caption=['Five fresh shared-seed serial search times per method, ordered by median. All points, min--max ' ...
 'whiskers, nearest-rank IQR segments and median ticks are shown. Population input 40 and 750 generations ' ...
 'use the saved single-thread workstation protocol; short warmups and post-search validation/saving are ' ...
 'excluded. Search times include algorithm/objective instrumentation. Concurrent timings are not used. ' ...
 'Local times exclude telemetry, mobility prediction, case construction, communication and actuation ' ...
 'and do not establish onboard real-time performance.'];
q=q+1;entries{q}=export_figure(fig,mainFolder,'06_serial_runtime',caption, ...
 'Twelve isolated timing distributions, with DFPQNO having the lowest median.',timingSource,style);

% Supplement 1: all twelve methods; do not remove infeasible native returns.
d=data{baseline};[~,order]=sort(mean(metric_values(d.Native.ValidationMetrics,'Primary'),1));
fig=new_figure(8.5,style);tiles=tiledlayout(fig,1,2,'Padding','compact','TileSpacing','compact');
pools={d.Native.ValidationMetrics,d.Native.IndependentValidationMetrics};
for k=1:2
 ax=nexttile(tiles);values=metric_values(pools{k},'Primary');feasible=metric_values(pools{k},'Feasible');
 draw_horizontal_samples(ax,values(:,order),methods(order),order,style,feasible(:,order));
 if k==2,ax.YTickLabel={};end
 set(ax,'XScale','log');xlabel(ax,'Primary J (log scale)');
 if k==1,title(ax,'Original validation');else,title(ax,'Independent validation');end
 panel_letter(ax,char('a'+k-1),style);
end
caption=['All 30 native baseline policies for all twelve methods on original/additional independent ' ...
 '100-scenario pools. Row order follows original-validation mean J and is preserved on the right. Points, ' ...
 'min--max whiskers, nearest-rank IQR segments and medians are shown on log axes. Red crosses mark model ' ...
 'infeasibility; no run is removed or replaced by an observer return. Primary J excludes penalties, ' ...
 'so feasibility must be read alongside the objective.'];
q=q+1;entries{q}=export_figure(fig,suppFolder,'S01_all_method_validation',caption, ...
 'Two all-method validation distributions with infeasible native returns marked by red crosses.',sources(baseline),style);

% Supplement 2: descriptive rank of mean within each case, not across weights.
originalRanks=zeros(M,numel(data));independentRanks=originalRanks;
for j=1:numel(data)
 originalRanks(:,j)=mean_order_rank(mean(metric_values(data{j}.Native.ValidationMetrics,'Primary'),1));
 independentRanks(:,j)=mean_order_rank(mean(metric_values(data{j}.Native.IndependentValidationMetrics,'Primary'),1));
end
fig=new_figure(8.8,style);tiles=tiledlayout(fig,1,2,'Padding','compact','TileSpacing','compact');
ax=nexttile(tiles);draw_rank_map(ax,originalRanks,methods,style);title(ax,'Original validation');panel_letter(ax,'a',style);
ax=nexttile(tiles);draw_rank_map(ax,independentRanks,methods,style);ax.YTickLabel={};
title(ax,'Independent validation');panel_letter(ax,'b',style);
caption=['Ranks of across-seed mean native primary J within each configuration (1 is lowest, exact ties ' ...
 'share average rank). Columns 1--7: baseline, equal weights, energy weights, risk weights, penalty 100, ' ...
 'penalty 10000, recorded ground mobility. These are descriptive mean ranks, not Friedman ranks or a proof ' ...
 'of significant dominance; risk-weighted DFPQNO--AROA remains nonsignificant after correction.'];
q=q+1;entries{q}=export_figure(fig,suppFolder,'S02_within_case_ranks',caption, ...
 'Two twelve-method by seven-case mean-rank heatmaps, with DFPQNO at rank one throughout.',sources,style);

% Supplement 3: stable numerical method key across six full-component panels.
fig=new_figure(10.2,style);tiles=tiledlayout(fig,2,3,'Padding','compact','TileSpacing','compact');
for k=1:numel(fields)
 ax=nexttile(tiles);values=metric_values(d.Native.ValidationMetrics,fields{k});
 if strcmp(fields{k},'Completion'),values=100*values;end
 draw_horizontal_samples(ax,values,arrayfun(@num2str,1:M,'UniformOutput',false),1:M,style, ...
  metric_values(d.Native.ValidationMetrics,'Feasible'));
 title(ax,names{k});ylabel(ax,'Method number');panel_letter(ax,char('a'+k-1),style);
end
caption=['Baseline original-validation components for all 30 native policies from twelve methods. Key ' ...
 '(unchanged across panels): 1 DFPQNO, 2 AROA, 3 BBO, 4 BKA, 5 GJA, 6 HBO, 7 IVYA, 8 mLSHADE-SPACMA, ' ...
 '9 NDO, 10 NRBO, 11 SSLO, 12 TOC. Points include all runs; thin whiskers span min--max, thick lines span ' ...
 'nearest-rank IQR and black ticks mark medians. Red crosses flag model-infeasible returns. Completion ' ...
 'is a percentage; fairness/CVaR are dimensionless. Each panel uses its stated range.'];
q=q+1;entries{q}=export_figure(fig,suppFolder,'S03_all_method_components',caption, ...
 'Six distribution panels show the full twelve-method physical performance and model feasibility.',sources(baseline),style);

% Supplement 4: all seven cases with unchanged method colors and patterns.
fig=new_figure(11.7,style);tiles=tiledlayout(fig,3,3,'Padding','compact','TileSpacing','compact');labels=case_labels(caseIds);
for j=1:numel(data)
 ax=nexttile(tiles);draw_convergence(ax,data{j},style,false);title(ax,labels{j});
 xlabel(ax,'Generation');ylabel(ax,'Training J');panel_letter(ax,char('a'+j-1),style);
end
for block=1:2
 ax=nexttile(tiles);axis(ax,'off');hold(ax,'on');
 for row=1:6
  m=(block-1)*6+row;y=1-(row-.5)/6;
  plot(ax,[0 .17],[y y],'Color',style.Colours(m,:),'LineStyle',style.LineStyles{m},'LineWidth',1);
  text(ax,.22,y,method_label(methods{m}),'FontName',style.Font,'FontSize',style.TickFontSize, ...
   'Color',style.Ink,'Interpreter','none','VerticalAlignment','middle');
 end
 xlim(ax,[0 1]);ylim(ax,[0 1]);
end
caption=['Across-seed median native penalized training objectives for twelve methods in all seven cases, ' ...
 '30 shared optimizer seeds and 750 complete generations. Blue shading is DFPQNO nearest-rank IQR. ' ...
 'All vertical axes are log-scaled and independently chosen per case. Absolute objectives under different ' ...
 'preference weights are not compared. Colors and line patterns are consistent across panels.'];
q=q+1;entries{q}=export_figure(fig,suppFolder,'S04_all_case_convergence',caption, ...
 'Seven twelve-method convergence panels and a two-column method key.',sources,style);

% Rendering must not change input bytes or random state.
for k=1:numel(usedFiles)
 assert(strcmp(file_hash(usedFiles{k}),usedHashes{k}),'Application:PlotMutatedInput','Changed input: %s',usedFiles{k});
end
assert(isequaln(rngBefore,rng),'Application:PlotRNG');entries=entries(1:q);
manifest=struct('StudyId',study.StudyId,'PlotScriptSHA256',file_hash([mfilename('fullpath') '.m']), ...
 'Style',style,'Sources',{sources},'ReadOnlyInputFiles',{usedFiles},'InputSHA256',{usedHashes}, ...
 'Figures',{entries},'OptimizationCalls',0,'ModelEvaluationCalls',0,'StatisticalTestsRerun',0, ...
 'RNGUnchanged',true,'DataFilesChanged',false,'NativeFIGReopened',true, ...
 'StyleReference','Nature/Science aesthetics adapted to compact 122 mm manuscript width','PublisherComplianceVerified',false);
fid=fopen(fullfile(pictureFolder,'FIGURE_MANIFEST.json'),'w','n','UTF-8');assert(fid>=0);
fprintf(fid,'%s\n',jsonencode(manifest,PrettyPrint=true));fclose(fid);
fid=fopen(fullfile(pictureFolder,'CAPTIONS_AND_ALT_TEXT.md'),'w','n','UTF-8');assert(fid>=0);
fprintf(fid,'# Application figure captions\n\nStudy: %s. Saved native policies only.\n\n',study.StudyId);
for k=1:q
 fprintf(fid,'## %s\n\n%s\n\nAlt text: %s\n\n',entries{k}.Name,entries{k}.Caption,entries{k}.AltText);
end
fclose(fid);
fprintf('PLOT_APPLICATION_COMPLETE main=6 supplementary=4 formats=FIG/PDF/PNG output=%s\n',pictureFolder);
clear restorePath

function fig=new_figure(height,style)
fprintf('PLOT_CREATE_FIGURE height=%.1fcm\n',height);
fig=figure('Visible',style.Visible,'Color','white','Units','centimeters', ...
 'WindowStyle','normal','Position',[2 2 style.Width height],'Name','Application study','NumberTitle','off');
fprintf('PLOT_FIGURE_READY\n');
end

function apply_axes(ax,style)
set(ax,'FontName',style.Font,'FontSize',style.TickFontSize,'LineWidth',style.AxisLineWidth, ...
 'TickDir','out','TickLength',[.012 .012],'Box','off','XColor',style.Ink,'YColor',style.Ink,'TickLabelInterpreter','none');
grid(ax,'off');ax.Title.FontSize=style.FontSize;ax.Title.FontWeight='normal';ax.Title.Color=style.Ink;
ax.XLabel.FontSize=style.FontSize;ax.YLabel.FontSize=style.FontSize;
end

function panel_letter(ax,letter,style)
text(ax,0,1.10,letter,'Units','normalized','FontName',style.Font,'FontSize',style.PanelFontSize, ...
 'FontWeight','bold','Color',style.Ink,'Clipping','off','VerticalAlignment','bottom');
end

function draw_convergence(ax,d,style,focus)
curves=d.Native.Curves;middle=reshape(median(curves,1),numel(d.Iterations),numel(d.Methods));
target=find(strcmp(d.Methods,'DFPQNO'));comparator=find(strcmp(d.Methods,'AROA'));
sorted=sort(curves(:,:,target),1);R=size(curves,1);lo=sorted(max(1,ceil(.25*R)),:);hi=sorted(max(1,ceil(.75*R)),:);
hold(ax,'on');fill(ax,[d.Iterations fliplr(d.Iterations)],[lo fliplr(hi)], ...
 .18*style.Colours(target,:)+.82,'EdgeColor','none','HandleVisibility','off');handles=gobjects(numel(d.Methods),1);
for m=[setdiff(1:numel(d.Methods),[comparator target],'stable') comparator target]
 colour=style.Colours(m,:);width=style.LineWidth;
 if focus&&m~=target&&m~=comparator,colour=style.Faint;width=.5;end
 if m==target,width=style.TargetLineWidth;end
 handles(m)=plot(ax,d.Iterations,middle(:,m),'Color',colour,'LineStyle',style.LineStyles{m},'LineWidth',width);
end
assert(all(middle(:)>0)&&all(lo>0),'Application:PlotLogValues');set(ax,'YScale','log');
xlim(ax,[1 max(d.Iterations)]);xticks(ax,[0 250 500 750]);xlabel(ax,'Generation');ylabel(ax,'Penalized training J');apply_axes(ax,style);
if focus
 other=find(~ismember(1:numel(d.Methods),[target comparator]),1);
 legend(ax,handles([target comparator other]),{'DFPQNO','AROA','Other 10 methods'}, ...
  'Location','northeast','FontSize',style.TickFontSize,'Box','off','Interpreter','none');
end
end

function draw_close_validation(ax,d,selected,style)
pools={d.Native.ValidationMetrics,d.Native.IndependentValidationMetrics};markers={'o','s'};
hold(ax,'on');R=numel(d.Seeds);jitter=.09*sin((1:R)'*pi*(sqrt(5)-1)/2);
for m=1:2
 for k=1:2
  values=metric_values(pools{k},'Primary');values=values(:,selected(m));x=m+(k-1.5)*.32;colour=style.Colours(selected(m),:);
  sorted=sort(values);iqrValues=sorted(ceil([.25 .75]*R));
  line(ax,[x x],[min(values) max(values)],'Color',.5*colour+.5,'LineWidth',.65);
  line(ax,[x x],iqrValues,'Color',colour,'LineWidth',3);
  plot(ax,x+jitter,values,markers{k},'MarkerSize',style.PointSize,'LineStyle','none','MarkerFaceColor','white','MarkerEdgeColor',colour);
  line(ax,x+[-.10 .10],repmat(median(values),1,2),'Color',style.Ink,'LineWidth',1);
 end
end
h1=plot(ax,NaN,NaN,'o','Color',style.Ink,'MarkerSize',3,'MarkerFaceColor','white');
h2=plot(ax,NaN,NaN,'s','Color',style.Ink,'MarkerSize',3,'MarkerFaceColor','white');
legend(ax,[h1 h2],{'Original','Independent'},'Location','northwest','FontSize',style.TickFontSize,'Box','off');
xlim(ax,[.55 2.45]);set(ax,'XTick',[1 2],'XTickLabel',{'DFPQNO','AROA'});ylabel(ax,'Primary objective J');apply_axes(ax,style);ax.YAxis.Exponent=0;
end

function draw_paired_metrics(ax,values,style)
hold(ax,'on');R=size(values,1);jitter=.07*sin((1:R)'*pi*(sqrt(5)-1)/2);
for r=1:R,plot(ax,[1 2]+jitter(r),values(r,:),'-','Color',[.86 .88 .90],'LineWidth',.4);end
for m=1:2
 plot(ax,m+jitter,values(:,m),'o','MarkerSize',style.PointSize,'LineStyle','none','MarkerFaceColor','white','MarkerEdgeColor',style.Colours(m,:));
 line(ax,m+[-.15 .15],repmat(mean(values(:,m)),1,2),'Color',style.Ink,'LineWidth',1.1);
end
xlim(ax,[.65 2.35]);set(ax,'XTick',[1 2],'XTickLabel',{'DFPQNO','AROA'});apply_axes(ax,style);ax.YAxis.Exponent=0;
end

function draw_trajectory(ax,d,selected,style)
c=d.Configuration;hold(ax,'on');theta=linspace(0,2*pi,100);
for k=1:numel(c.zoneRadii)
 patch(ax,(c.zoneCenters(k,1)+c.zoneRadii(k)*cos(theta))/1000, ...
  (c.zoneCenters(k,2)+c.zoneRadii(k)*sin(theta))/1000,style.ZoneFill, ...
  'EdgeColor',style.ZoneEdge,'LineWidth',style.AxisLineWidth,'HandleVisibility','off');
end
for user=1:c.K
 points=reshape(d.Model.users(user,:,:),c.T,2)/1000;
 plot(ax,points(:,1),points(:,2),'-','Color',[.73 .78 .80],'LineWidth',.6,'HandleVisibility','off');
 plot(ax,points(1,1),points(1,2),'.','Color',[.60 .66 .69],'MarkerSize',5,'HandleVisibility','off');
end
handles=gobjects(2,1);
for k=2:-1:1
 m=selected(k);points=d.Representatives{m}.Policy.path/1000;
 handles(k)=plot(ax,points(:,1),points(:,2),'Color',style.Colours(m,:),'LineStyle',style.LineStyles{m},'LineWidth',style.TargetLineWidth);
end
plot(ax,c.start(1)/1000,c.start(2)/1000,'o','MarkerEdgeColor',style.Ink,'MarkerFaceColor','white','MarkerSize',4,'HandleVisibility','off');
plot(ax,c.finish(1)/1000,c.finish(2)/1000,'s','MarkerEdgeColor',style.Ink,'MarkerFaceColor','white','MarkerSize',4,'HandleVisibility','off');
axis(ax,'equal');xlim(ax,c.area(1,:)/1000);ylim(ax,c.area(2,:)/1000);
set(ax,'XTick',0:1:2,'YTick',0:1:2);xlabel(ax,'x (km)');ylabel(ax,'y (km)');apply_axes(ax,style);
legend(ax,handles,{'DFPQNO','AROA'},'Location','northwest','FontSize',style.TickFontSize,'Box','off');
end

function draw_gain(ax,contrasts,ids,style)
hold(ax,'on');xline(ax,0,':','Color',style.Faint,'LineWidth',.8,'HandleVisibility','off');
poolIds={'original_validation','independent_validation'};markers={'o','s'};colours=style.Colours([1 3],:);
for j=1:numel(ids)
 for k=1:2
  match=contrasts.Case==string(ids{j})&contrasts.Pool==poolIds{k}&contrasts.Comparator=="AROA";
  row=contrasts(match,:);assert(height(row)==1,'Application:PlotContrast');y=j+(k-1.5)*.24;
  plot(ax,[row.PercentCI95Low row.PercentCI95High],[y y],'-','Color',colours(k,:),'LineWidth',.9);
  face='white';if row.GlobalHolm154<.05,face=colours(k,:);end
  plot(ax,row.MeanPercentReduction,y,markers{k},'Color',colours(k,:),'MarkerFaceColor',face,'MarkerSize',4);
 end
end
labels=case_labels(ids);
for j=1:numel(ids)
 rows=contrasts(contrasts.Case==string(ids{j})&contrasts.Comparator=="AROA",:);
 if all(rows.GlobalHolm154>=.05),labels{j}=[labels{j} ' (ns)'];end
end
set(ax,'YTick',1:numel(ids),'YTickLabel',labels,'YDir','reverse');ylim(ax,[.4 numel(ids)+.6]);xlabel(ax,'Relative reduction in J (%)');apply_axes(ax,style);
h1=plot(ax,NaN,NaN,'o','Color',colours(1,:));h2=plot(ax,NaN,NaN,'s','Color',colours(2,:));
legend(ax,[h1 h2],{'Original','Independent'},'Location','southoutside','Orientation','horizontal','FontSize',style.TickFontSize,'Box','off');
end

function draw_margins(ax,data,target,style)
hold(ax,'on');R=numel(data{1}.Seeds);jitter=.13*sin((1:R)'*pi*(sqrt(5)-1)/2);
for j=1:numel(data)
 values=metric_values(data{j}.Native.ValidationMetrics,'MinSafetyMargin_m');values=100*values(:,target);
 assert(all(values>0),'Application:PlotMargin');sorted=sort(values);iqrValues=sorted(ceil([.25 .75]*R));
 plot(ax,values,j+jitter,'o','MarkerSize',style.PointSize,'LineStyle','none','MarkerFaceColor','white','MarkerEdgeColor',style.Colours(target,:));
 plot(ax,iqrValues,[j j],'-','Color',style.Colours(target,:),'LineWidth',2.5);
 line(ax,repmat(median(values),1,2),j+[-.16 .16],'Color',style.Ink,'LineWidth',1);
end
set(ax,'XScale','log','YTick',1:numel(data),'YTickLabel',{},'YDir','reverse');
ylim(ax,[.4 numel(data)+.6]);xlabel(ax,'Minimum clearance (cm, log)');apply_axes(ax,style);
end

function draw_horizontal_samples(ax,values,labels,methodIndices,style,feasible)
if nargin<6,feasible=true(size(values));end
assert(all(isfinite(values(:)))&&isequal(size(feasible),size(values)),'Application:PlotSamples');
hold(ax,'on');R=size(values,1);jitter=.16*sin((1:R)'*pi*(sqrt(5)-1)/2);
for row=1:size(values,2)
 v=values(:,row);sorted=sort(v);iqrValues=sorted(max(1,ceil([.25 .75]*R)));colour=style.Colours(methodIndices(row),:);
 line(ax,[min(v) max(v)],[row row],'Color',.5*colour+.5,'LineWidth',.6);
 line(ax,iqrValues,[row row],'Color',colour,'LineWidth',2.5);good=logical(feasible(:,row));
 plot(ax,v(good),row+jitter(good),'o','MarkerSize',style.PointSize,'LineStyle','none','MarkerFaceColor','white','MarkerEdgeColor',colour);
 if any(~good),plot(ax,v(~good),row+jitter(~good),'x','MarkerSize',3.5,'LineStyle','none','Color',[.70 .28 .29]);end
 line(ax,repmat(median(v),1,2),row+[-.19 .19],'Color',style.Ink,'LineWidth',1);
end
set(ax,'YDir','reverse','YTick',1:numel(labels),'YTickLabel',cellfun(@method_label,labels,'UniformOutput',false));
ylim(ax,[.45 numel(labels)+.55]);apply_axes(ax,style);
end

function draw_rank_map(ax,values,methods,style)
imagesc(ax,values,[1 numel(methods)]);map=colour_map(style.RankAnchors);colormap(ax,map);
set(ax,'XTick',1:size(values,2),'YTick',1:numel(methods),'YTickLabel',cellfun(@method_label,methods,'UniformOutput',false));
xlabel(ax,'Configuration number');apply_axes(ax,style);
for row=1:size(values,1)
 for col=1:size(values,2)
  index=1+round((values(row,col)-1)/(numel(methods)-1)*(size(map,1)-1));colour=style.Ink;
  if dot(map(index,:),[.2126 .7152 .0722])<.55,colour=[1 1 1];end
  text(ax,col,row,sprintf('%g',values(row,col)),'HorizontalAlignment','center','FontName',style.Font,'FontSize',style.TickFontSize,'Color',colour);
 end
end
cb=colorbar(ax);cb.Ticks=[1 4 8 12];cb.FontSize=style.TickFontSize;cb.FontName=style.Font;
end

function values=metric_values(metrics,name)
values=reshape([metrics.(name)],size(metrics));
end

function ranks=mean_order_rank(values)
[ordered,order]=sort(values);ranks=zeros(numel(values),1);first=1;
while first<=numel(values)
 last=first;while last<numel(values)&&ordered(last+1)==ordered(first),last=last+1;end
 ranks(order(first:last))=(first+last)/2;first=last+1;
end
end

function label=method_label(method)
label=strrep(method,'_','-');
end

function labels=case_labels(ids)
labels=ids;
for j=1:numel(ids)
 switch ids{j}
  case 'baseline',labels{j}='Baseline';
  case 'equal_weights',labels{j}='Equal weights';
  case 'energy_weights',labels{j}='Energy weights';
  case 'risk_weights',labels{j}='Risk weights';
  case 'penalty_low',labels{j}='Penalty 100';
  case 'penalty_high',labels{j}='Penalty 10000';
  case 'measured_mobility',labels{j}='Recorded mobility';
 end
end
end

function map=colour_map(anchors)
map=interp1(linspace(0,1,size(anchors,1)),anchors,linspace(0,1,128));
end

function entry=export_figure(fig,folder,name,caption,altText,sources,style)
cleanup=onCleanup(@()close(fig));drawnow;position=fig.Position;
fig.UserData=struct('FigureId',name,'Caption',caption,'AltText',altText,'Sources',{sources}, ...
 'DataPolicy','Native returned policies only','FinalSize_cm',position(3:4));files=cell(size(style.ExportFormats));hashes=files;
for k=1:numel(style.ExportFormats)
 extension=style.ExportFormats{k};files{k}=fullfile(folder,[name '.' extension]);
 if strcmp(extension,'fig')
  savefig(fig,files{k});reopened=openfig(files{k},'new','invisible');
  assert(~isempty(findall(reopened,'Type','axes'))&&numel(findall(reopened,'Type','line'))==numel(findall(fig,'Type','line'))&& ...
   numel(findall(reopened,'Type','image'))==numel(findall(fig,'Type','image')),'Application:PlotNativeFIG');close(reopened);
 elseif strcmp(extension,'png')
  exportgraphics(fig,files{k},'Resolution',style.PNGResolution,'BackgroundColor','white', ...
   'Units','centimeters','Width',position(3),'Height',position(4),'Padding',.05);
 elseif strcmp(extension,'pdf')
  exportgraphics(fig,files{k},'ContentType','vector','BackgroundColor','white', ...
   'Units','centimeters','Width',position(3),'Height',position(4),'Padding',.05);
 else,error('Application:PlotFormat','Unsupported figure format: %s',extension);
 end
 hashes{k}=file_hash(files{k});
end
entry=struct('Name',name,'Caption',caption,'AltText',altText,'Sources',{sources},'FinalSize_cm',position(3:4), ...
 'Files',{files},'FileSHA256',{hashes},'EditableAxes',numel(findall(fig,'Type','axes')), ...
 'EditableLines',numel(findall(fig,'Type','line')),'EditableImages',numel(findall(fig,'Type','image')));
fprintf('EXPORTED %s size=%.1fx%.1fcm\n',name,position(3),position(4));clear cleanup
end

function hash=file_hash(file)
fid=fopen(file,'rb');assert(fid>=0,'Application:PlotHash','Cannot read %s.',file);
cleanup=onCleanup(@()fclose(fid));digest=java.security.MessageDigest.getInstance('SHA-256');
while ~feof(fid),digest.update(fread(fid,1024*1024,'*uint8'));end
hash=lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2)',1,[]));clear cleanup
end
