# Publication preparation audit

Prepared on 2026-10-15 for **Energy-Efficient and Risk-Aware Joint Optimization for UAV-Assisted Mobile Edge Computing in Urban Environments**.

## Retained experiment material

| Original experiment folder | Retained source files | Bytes |
| --- | ---: | ---: |
| `Ablation_Study/` | 822 | 202,706,775 |
| `Application_Experiment/` | 2,882 | 330,905,022 |
| `Benchmark_Experiments/` | 1,166 | 462,278,610 |

The copy retains all active source programs, CEC input data, completed native MAT/CSV results, statistical workbooks, source snapshots, and experiment figures. The largest retained file is `Application_Experiment/Results/risk_weights/plot_data.mat` (15,020,597 bytes). No retained file reaches GitHub's 100 MiB per-file threshold. The source experiment folders were read only and their retained-file hashes were rechecked after packaging.

The excluded application `archive/` is a duplicate previous study, not the active published result tree. Local process caches, logs, confidential revision audits, the original manuscript and reviewer text, and the large raw pNEUMA CSV are excluded. The three experiment folders themselves remain present. The processed ground-position CSV, transformation protocol, official raw-download instructions, original raw checksum, and CC-BY-4.0 attribution are included.

## Integrity and privacy scope

- All 163 original MATLAB/C++/MEX program files retain their exact source hashes.
- All 3604 retained MAT/CSV files retain their exact source hashes; no measurement, objective value, seed, curve, model parameter, or result table was recomputed or edited.
- 14 readable JSON sidecars replace historical absolute path strings with repository-relative descriptions. A recursive comparison confirmed that numeric, Boolean, and null leaves did not change. Original protocol tokens remain associated with the unchanged native MAT records, rather than being silently recomputed for redacted JSON.
- The application README replaces links to omitted confidential revision audits with public release documentation.
- Eight source-path fields in the ablation protocol TXT are repository-relative; all protocol statements and numbers remain unchanged.
- The scanner inspected text formats and XLSX XML, decompressed all 3063 MATLAB v5 MAT/FIG containers, and inspected raw byte views of MEX/PDF/PNG files. It found 0 hits for the tested GitHub-token, AWS-access-key, OpenAI-style-key, and private-key-block patterns. No matched credential values were printed or stored. No MAT/FIG container was unsupported.
- **Native MATLAB provenance is intentionally unchanged.** Many original MAT/FIG records contain historical directory strings, including the original user-folder name. These non-secret provenance fields are retained to preserve the native record bytes and their source locks. This release does not claim that every local path was erased from binary records. Pattern scanning is not a proof that every possible credential format or private value is absent.
- `.gitattributes` disables line-ending conversion because source locks use exact bytes.

## Third-party notices

Original code headers remain intact. The original BSD-style notices for mLSHADE-SPACMA and NRBO were downloaded from the authors' official MathWorks release license links and included under `licenses/`. The pNEUMA license was verified directly against the official Zenodo API as `cc-by-4.0`. Exact notice URLs and hashes are recorded in `licenses/SOURCE_NOTICES.json`.

No blanket license was invented for the authors' code or for the remaining supplied comparator/CEC files. Their missing local license records are documented in `THIRD_PARTY_NOTICES.md`; a missing notice is not reported as a newly discovered prohibition. The maintainers may supplement original provenance later without changing the scientific results.

## Repository naming and publication

The full paper title contains 111 characters. GitHub allows at most 100 characters in a repository name. The repository slug therefore removes the connecting words while retaining every technical phrase; the README keeps the complete paper title. [GitHub's naming rule](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-new-repository) was checked on 2026-10-15.

Target repository: [Energy-Efficient-Risk-Aware-Joint-Optimization-UAV-Assisted-Mobile-Edge-Computing-Urban-Environments](https://github.com/MetaHeurLab/Energy-Efficient-Risk-Aware-Joint-Optimization-UAV-Assisted-Mobile-Edge-Computing-Urban-Environments). This audit records the local prepared snapshot, not a claim that a later remote push, a publisher submission, or a publication acceptance has completed. No unrelated repository was changed by this preparation.

The manifest lists every public payload file except itself and Git's internal database, so it has no impossible self-hash dependency. No experiments were rerun during release packaging.
