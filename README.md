# Energy-Efficient and Risk-Aware Joint Optimization for UAV-Assisted Mobile Edge Computing in Urban Environments

MATLAB programs, configurations, and completed experimental results for the paper's DFPQNO optimizer and UAV-assisted mobile edge computing study.

The repository contains the three experiment folders:

| Folder | Contents | Entry point |
| --- | --- | --- |
| `Ablation_Study/` | Original Full and its ablation controls, followed by validation of the final DFPQNO across eight versions and four dimensions | `run_cec2017.m` |
| `Application_Experiment/` | Single-UAV planning model, twelve optimizers, seven configurations, saved native policies, two evaluation pools, serial timing, and figures | `RUN_APPLICATION.m`; plotting: `PLOT_APPLICATION.m` |
| `Benchmark_Experiments/` | CEC 2017 and CEC 2022 supplied-interface comparisons, input data, optimizer implementations, run-level MAT files, CSV/XLSX summaries, and figures | `CEC2017/run_cec2017.m`, `CEC2022/run_cec2022.m` |

The saved results can be inspected without running an optimizer. See [REPRODUCIBILITY.md](REPRODUCIBILITY.md) for paths, dependencies, run instructions, and protocol limits. [repository_manifest.json](repository_manifest.json) records file hashes and the public-copy transformations. [PUBLICATION_AUDIT.md](PUBLICATION_AUDIT.md) describes the release inventory and checks.

## Requirements and data

The experiment harnesses use MATLAB R2026a, Parallel Computing Toolbox, and Statistics and Machine Learning Toolbox. The saved study used R2026a Update 5. Included native MEX binaries target Windows 64-bit; source files are provided for rebuilding. Standalone `DFPQNO.m` uses base MATLAB operations.

The processed pNEUMA position input and its transformation protocol are included under `Application_Experiment/sources/datasets/pneuma/`. These are derived ground-vehicle tracks used as mobile-user proxies, not UAV flight measurements. The large upstream archive and the raw 492,760,287-byte CSV are omitted; attribution, official download links, and the raw checksum are in that folder's [ATTRIBUTION.md](Application_Experiment/sources/datasets/pneuma/ATTRIBUTION.md).

## Interpretation

CEC comparisons use the supplied implementations and their argument conventions. Actual evaluation counts differ; these results are not an official-budget or equal-evaluation competition result. The ablation controls are defined relative to Original Full. The final algorithm was developed after that study and has the best mean rank among the eight tested versions at all four dimensions; this does not imply a win on every function or isolate every component of the final algorithm.

Application runs compute offline plans for one UAV. Only the recorded ground positions come from measurements; UAV motion, task workloads, channels, energy, and exclusion zones are simulated. Model feasibility does not guarantee that every task meets its deadline. Workstation search time does not establish onboard execution or online replanning.

## Source integrity and licensing

Program files, native MAT/CSV experiment records, and existing source notices are preserved byte for byte. Readable JSON sidecars and the ablation protocol source-path fields replace historical absolute local-path strings with repository-relative descriptions; their numeric values are unchanged. Native MATLAB records retain their original provenance fields and checksums.

[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) identifies third-party components and the licenses verified for supplied mLSHADE-SPACMA, NRBO, and pNEUMA material. No blanket replacement license has been selected for the authors' own code or for components whose original license was not identified. Public availability is not a claim that every component has the same license.
