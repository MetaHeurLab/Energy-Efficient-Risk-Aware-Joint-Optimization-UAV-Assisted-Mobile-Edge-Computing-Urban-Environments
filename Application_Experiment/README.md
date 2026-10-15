# Application experiment

Open `RUN_APPLICATION.m` in MATLAB and press Run/F5. It completes all experiments,
checks every returned policy, and saves MAT/CSV/JSON data. It does not draw figures.
After the study completes, run `PLOT_APPLICATION.m` to draw the saved data. Edit the
style block at the top of that file to change colours, fonts, panel sizes or exports.
The plot script is excluded from the experiment source lock, so these edits do not
require new optimization runs.

## Publication figures

The independent plot script creates six main figures and four supplementary
figures from the completed study, without calling an optimizer, reevaluating a
model or repeating a statistical test. Each figure is saved as editable MATLAB
FIG, vector PDF and a 600 dpi PNG in `Pictures/<StudyId>/Main/` or
`Pictures/<StudyId>/Supplementary/` beside the application scripts. Native FIG files are
reopened during export to verify their axes, line and image objects.

The output location is derived from the plot script as `Pictures/<StudyId>/`: `Results`
and `Pictures` are sibling folders. The script does not contain a fixed absolute
picture save address, and it does not change MATLAB's current working folder.
Case data and serial timing are located beneath the current `Results` folder;
historical absolute case-output addresses in the saved index are not used for
reading. Original index files remain unchanged as experiment records.

The style block defines the muted palette, Arial fonts and actual 122 mm width.
The main figures cover convergence/validation, six component tradeoffs, synthetic
and recorded-ground-mobility paths, recorded-mobility resource allocations,
weight/penalty sensitivity with saved confidence intervals, and isolated serial
runtime. Supplementary figures preserve all twelve methods, all seven cases and
model-infeasible outcomes. `CAPTIONS_AND_ALT_TEXT.md` records units, uncertainty,
representative-selection rules and limits; `FIGURE_MANIFEST.json` records source
and export hashes. Change the plot script and press F5 to regenerate the figures
without modifying the saved experiment data.

All runtime paths are derived from this application's directory. `Results`,
`Pictures` and `algorithms` are siblings; inputs, logs, temporary files and source
snapshots also use local subfolders. No drive or user directory is hardcoded.
Input data must already be present in the indicated local folders; the entry
scripts do not fetch historical data from another drive.

## Experimental protocol

- The same 12 methods as the protected CEC comparison: DFPQNO, AROA, BBO, BKA,
  GJA, HBO, IVYA, mLSHADE_SPACMA, NDO, NRBO, SSLO and TOC.
- Common population input 40, 750 complete generations and 30 runs per case.
  Function-evaluation counts are diagnostics and never stop the search.
- Seven conditions: baseline; equal, energy and risk weights; penalty 100 and
  10000; measured ground mobility. Each condition has 360 full searches.
- Search uses 12 scenarios. The original 100 validation scenarios and 100 newly
  generated independent scenarios evaluate the native returned policy after search.
  Neither validation pool selects the policy. Observer minima remain diagnostics.
  The original validation pool was previously used during development; the new
  independent pool strengthens scenario validation but is still simulated.
- DFPQNO is byte-identical to the latest benchmark core. Nine comparators have
  only non-random generation witnesses. AROA and mLSHADE_SPACMA have documented
  adaptations from evaluation clocks to complete generation clocks.
  mLSHADE_SPACMA retains its internal population reduction; a common population
  input does not imply constant active population for this method.
- Isolated serial timing uses five additional common seeds per method, one
  computation thread and no parallel pool. Its 12 short warmups are excluded.
- Friedman, paired Wilcoxon, within-case Holm correction and paired bootstrap
  intervals are saved with the unfiltered individual results. An average winner
  does not automatically win every physical metric or every individual run.
  Every method uses the same trajectory decoder and resource normalization.
  `Feasible` checks the specified flight, safety, battery and allocation
  constraints; the task deadline is evaluated through completion and CVaR and
  is not a guarantee that every task finishes on time.

MATLAB R2026a, Parallel Computing Toolbox and Statistics and Machine Learning
Toolbox are required by this experimental harness and the supplied comparators.
The standalone DFPQNO core has not gained these dependencies.

## Data locations

`Results/STUDY.mat` is the index for the seven conditions and the current serial
timing folder. Each `Results/<condition>/` contains the frozen configuration/model,
360 individual job files, `all_runs.mat`, `VERIFY.json`, statistics, individual
curves and `plot_data.mat`. Complete native and observer histories are separate.
`sources/` contains copied benchmark originals, runtime snapshots and dataset
provenance. `audit/` contains integrity and reviewer-coverage checks. Previous
application files were removed from the active study and retained separately under
`archive/`; they are never used as results for this study.

Successful interrupted searches resume only when all source hashes, parameters
and study tokens match. A mismatch stops the run without importing old data.
Serial timing always uses a new folder and fresh searches. Plot output is written
only by `PLOT_APPLICATION.m` to `Pictures/<StudyId>/`.

The public release integrity checks, source hashes, and reconstruction limits are
documented in the repository-root `PUBLICATION_AUDIT.md`, `repository_manifest.json`,
and `REPRODUCIBILITY.md`. Confidential revision audits are not included.

## Scope of the evidence

The measured-mobility condition uses pNEUMA ground-vehicle trajectories, which
the dataset authors collected from aerial traffic recordings in Athens:
[official dataset](https://zenodo.org/records/10491409) and
[official data notes](https://zenodo.org/records/10491409/files/README.html).
Vehicles serve as mobile-user proxies. UAV motion, workloads, channels, energy
models and safety disks remain simulated. Future user positions are known to this
offline optimizer. This study does not establish real UAV/MEC deployment,
multi-UAV contention or onboard real-time performance. Serial times measure
workstation planning cost; communication, prediction and execution costs remain
outside that measurement.

The sibling `Benchmark_Experiments` and `Ablation_Study` folders are read-only
throughout application execution.
