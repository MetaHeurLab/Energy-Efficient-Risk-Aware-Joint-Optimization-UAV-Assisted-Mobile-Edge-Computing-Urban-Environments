# Reproducing and inspecting the experiments

## Environment

The recorded application timing environment was MATLAB R2026a Update 5, Windows 64-bit, on an Intel Core Ultra 9 285K workstation. Isolated timing used one computation thread and no parallel pool. The complete experiment harnesses require Parallel Computing Toolbox and Statistics and Machine Learning Toolbox. Their worker count is bounded by the available MATLAB process profile. The DFPQNO core itself uses base MATLAB operations.

`cec17_func.mexw64` and `cec22_func.mexw64` are the supplied Windows binaries. Their C++ sources and input data are included. For a different platform or MATLAB ABI, configure a supported C++ MEX compiler and compile the source in its own suite directory, for example `mex cec17_func.cpp -DWINDOWS` on Windows. CEC 2022's actual source filename here is `cec22_func.cpp`. Keep each `input_data17` or `input_data22` folder beside its suite's MEX file. Do not replace the supplied benchmark implementation with another wrapper and assume numerical identity.

## Inspect the completed results first

From the repository root in MATLAB, these operations read existing outputs:

```matlab
s = load(fullfile('Application_Experiment','Results','STUDY.mat'));
disp(s.study.Status)
t = readtable(fullfile('Application_Experiment','Results','ALL_INDEPENDENT_SUMMARIES.csv'));
disp(t)
whos('-file',fullfile('Benchmark_Experiments','CEC2017','Results','D10','F1_Raw.mat'))
whos('-file',fullfile('Ablation_Study','Results','D10','F1_Raw.mat'))
```

The MAT files are the authoritative native records. The manifest preserves their original hashes. Historical directory strings in saved MATLAB structs identify the original execution environment; they are metadata, not directions to use another machine's files. Readable JSON sidecars have repository-relative path descriptions, so original scientific protocol tokens refer to the unmodified native MAT records rather than to a redacted JSON serialization.

## Benchmark comparisons

Run one entry file at a time from MATLAB:

- `Benchmark_Experiments/CEC2017/run_cec2017.m`
- `Benchmark_Experiments/CEC2022/run_cec2022.m`

Both entry scripts derive paths from their own locations. CEC 2017 uses F1--F30 excluding F2, dimensions 10/30/50/100, twelve methods, and 30 runs. CEC 2022 uses all twelve functions at dimensions 10/20 with the same number of methods and runs. Together these are 50,400 optimizer runs.

The common inputs are population 30 and a second argument of 750. Their meanings differ: AROA applies a 750-evaluation ceiling; mLSHADE-SPACMA uses 22,500 evaluations; DFPQNO evaluates 22,560 candidates. The scripts preserve these supplied-interface conventions. Method seeds differ. Per-function comparisons use two-sided rank-sum tests, with Holm correction within each dimension; functions are Friedman blocks for mean-error ranks.

The `Results/` subfolders contain per-function native raw MAT files, dimension-level statistics, protocol notes, workbooks, and figures. Entry scripts write to their own `Results/` and can replace result workbooks. Use a fresh working copy for a rerun if the archived release results must be preserved.

## Original ablations and final version validation

Run `Ablation_Study/run_cec2017.m`. Its active panel is the final DFPQNO plus Original Full, UniformInit, NoCurvature, NoArchive, FixedMemory, NoSlope, and FixedScale, at four dimensions over 29 functions and 30 common seeds: 27,840 runs. `DFPQNO_WithMemory.m` is also retained as an available source file; it is not a ninth member of the active panel.

Original Full is the original success-memory implementation, and the six controls ablate that version. The final DFPQNO was developed after this study and then compared with the original seven-version panel under the shared-seed protocol. It has the best mean rank among all eight versions at each of the four dimensions, without winning every function. These contrasts evaluate algorithm versions; they are not all single removals from the final confidence-weighted algorithm. NoSlope also removes dependent curvature/guidance, and FixedScale removes both memory and stochastic scale variation. The source contains the exact shared-seed construction and full-precision paired signed-rank procedure, with 203 corrected target/control contrasts per dimension.

## UAV-MEC application

Open `Application_Experiment/RUN_APPLICATION.m` and run it. The full study uses twelve methods, seven configurations, population input 40, 750 complete generations, and 30 shared optimizer seeds per configuration: 2,520 searches. AROA and mLSHADE-SPACMA use the documented generation-interface adaptations; mLSHADE-SPACMA retains population reduction, and actual model evaluation counts remain unequal.

Search uses twelve scenarios. Native returned policies are evaluated on the original 100-scenario pool and an additional independently drawn 100-scenario pool. The original pool had been inspected during development. Both pools use the same generating workload/channel models; neither selects the returned policy. The additional pool uses frozen code and policies. Infeasible returns are retained in the reported unpenalized objective and identified separately.

The complete application runner archives a previously complete `Results/` before a new full study. Interrupted runs resume only when source/configuration tokens match. A relocated clone gets its own root-derived paths and a fresh protocol; do not mix its new run identifiers with the saved native study.

After completion, run `Application_Experiment/PLOT_APPLICATION.m` to draw the saved data without rerunning optimization. Its paths are relative to the application folder and it reads case files from the local `Results/` tree. Isolated timing uses five fresh shared seeds per method; short warmups are excluded. Concurrent search times remain diagnostic.

The original manuscript, confidential review text, old duplicate application archive, local logs/process caches, and raw pNEUMA CSV are not required by these entry points and are not included. The processed pNEUMA CSV and its protocol are sufficient to rebuild all seven application cases. Refer to the dataset attribution for the optional raw-data reconstruction source.

## Verification in this release

The release audit checks hashes against the source trees, all original program/MEX bytes, every retained MAT/CSV record, unchanged numeric JSON leaves, candidate credential patterns, and GitHub's 100 MiB per-file threshold. `repository_manifest.json` records the exact inventory. This packaging check did not rerun tens of thousands of searches or re-estimate the paper's results.

`.gitattributes` disables automatic line-ending conversion because experiment source locks hash exact file bytes. Changing a source file or its line endings legitimately creates a different source token; do not claim it is the frozen original.
