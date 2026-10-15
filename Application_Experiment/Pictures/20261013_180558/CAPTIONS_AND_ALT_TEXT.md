# Application figure captions

Study: 20261013_180558. Saved native policies only.

## 01_performance

Baseline, population input 40, 750 complete generations and 30 shared optimizer seeds. (a) Across-seed median native penalized training objective on a log axis; the DFPQNO band is the nearest-rank interquartile range. All twelve methods are drawn; ten secondary methods are grey. (b) All 30 native DFPQNO and AROA policies on the original and additional independent 100-scenario pools (circles and squares). Thin whiskers span min--max, thick segments span IQR and centre ticks mark medians. Scenarios are not treated as independent optimizer replicates. Observer policies are never substituted.

Alt text: Baseline convergence and two-pool native policy distributions; AROA is close to DFPQNO.

## 02_metric_tradeoffs

Baseline original-validation components for the same 30 shared-seed native DFPQNO and AROA policies. Grey lines connect matched seeds; points include every run and black ticks show means. Energy, mean/P95 latency and CVaR overrun are minimized; completion and fairness are maximized. Displayed vertical ranges are not all zero-based. AROA has slightly better mean P95 latency, completion, fairness and CVaR, while DFPQNO improves energy, mean latency and the composite objective. No component significance is asserted.

Alt text: Six paired distributions show energy and mean-latency gains with small tradeoffs in four other components.

## 03_trajectories

UAV polylines of the preselected lower-median original-native-validation run for each method: DFPQNO blue solid, AROA orange dashed. Grey traces show eight users; shaded circles are model exclusion zones, and an open circle/square marks prescribed start/finish. Coordinates are in kilometres with equal axis scaling and identical 2 km square bounds. Left: synthetic user traces. Right: interpolated pNEUMA ground-vehicle traces. Only ground mobility is measured; UAV flight, tasks, channels, energy and safety are simulated. Representatives are not selected on the additional independent pool. Model paths do not establish flight-test safety or robustness to navigation errors.

Alt text: Two blue and dashed orange UAV path comparisons among grey user traces and three shaded model disks.

## 04_resource_allocation

Recorded-mobility DFPQNO allocations for the representative in Fig. 03b (run 13, seed 24063013). Each cell is one of eight users at one of sixteen original samples (0--150 s); no smoothing is applied. Offload and power scales use model bounds. Bandwidth/CPU scales start at zero and end at the largest displayed allocation, not total resource capacity. Values are decoded saved policies, not UAV measurements.

Alt text: Four user-by-time heatmaps of offloading, power, bandwidth and edge CPU.

## 05_sensitivity

Seven completed configurations, 30 native policies per method and case. (a) Relative reduction in mean primary J against AROA: 100(mean AROA minus mean DFPQNO)/mean AROA. Circles/squares identify original/additional independent validation. Segments are saved paired bootstrap 95% intervals (5000 resamples), not simultaneous intervals. Filled markers denote saved Holm-adjusted significance; open markers denote nonsignificance. Risk weights is marked ns: its signed-rank contrast fails the saved Holm correction over all 154 comparisons. Absolute objectives under different weights are not pooled. (b) All DFPQNO native-policy minimum model exclusion-zone clearances, in centimetres on a log axis. Thick segments are nearest-rank IQRs; black ticks are medians. Small positive model margins are not allowances for GPS, wind or actuation errors.

Alt text: Most gain intervals are positive, risk-weighted intervals cross zero, and model clearance varies by case.

## 06_serial_runtime

Five fresh shared-seed serial search times per method, ordered by median. All points, min--max whiskers, nearest-rank IQR segments and median ticks are shown. Population input 40 and 750 generations use the saved single-thread workstation protocol; short warmups and post-search validation/saving are excluded. Search times include algorithm/objective instrumentation. Concurrent timings are not used. Local times exclude telemetry, mobility prediction, case construction, communication and actuation and do not establish onboard real-time performance.

Alt text: Twelve isolated timing distributions, with DFPQNO having the lowest median.

## S01_all_method_validation

All 30 native baseline policies for all twelve methods on original/additional independent 100-scenario pools. Row order follows original-validation mean J and is preserved on the right. Points, min--max whiskers, nearest-rank IQR segments and medians are shown on log axes. Red crosses mark model infeasibility; no run is removed or replaced by an observer return. Primary J excludes penalties, so feasibility must be read alongside the objective.

Alt text: Two all-method validation distributions with infeasible native returns marked by red crosses.

## S02_within_case_ranks

Ranks of across-seed mean native primary J within each configuration (1 is lowest, exact ties share average rank). Columns 1--7: baseline, equal weights, energy weights, risk weights, penalty 100, penalty 10000, recorded ground mobility. These are descriptive mean ranks, not Friedman ranks or a proof of significant dominance; risk-weighted DFPQNO--AROA remains nonsignificant after correction.

Alt text: Two twelve-method by seven-case mean-rank heatmaps, with DFPQNO at rank one throughout.

## S03_all_method_components

Baseline original-validation components for all 30 native policies from twelve methods. Key (unchanged across panels): 1 DFPQNO, 2 AROA, 3 BBO, 4 BKA, 5 GJA, 6 HBO, 7 IVYA, 8 mLSHADE-SPACMA, 9 NDO, 10 NRBO, 11 SSLO, 12 TOC. Points include all runs; thin whiskers span min--max, thick lines span nearest-rank IQR and black ticks mark medians. Red crosses flag model-infeasible returns. Completion is a percentage; fairness/CVaR are dimensionless. Each panel uses its stated range.

Alt text: Six distribution panels show the full twelve-method physical performance and model feasibility.

## S04_all_case_convergence

Across-seed median native penalized training objectives for twelve methods in all seven cases, 30 shared optimizer seeds and 750 complete generations. Blue shading is DFPQNO nearest-rank IQR. All vertical axes are log-scaled and independently chosen per case. Absolute objectives under different preference weights are not compared. Colors and line patterns are consistent across panels.

Alt text: Seven twelve-method convergence panels and a two-column method key.

