# Third-party material and notices

Original author/contact/citation headers in supplied source files have been retained. The following records describe identified components; they do not apply a new common license to the whole repository.

## mLSHADE-SPACMA

The supplied `mLSHADE_SPACMA.m` implementations derive from Shengwei Fu's author implementation accompanying:

Fu, S., Ma, C., Li, K., et al. (2025). Modified LSHADE-SPACMA with new mutation strategy and external archive mechanism for numerical optimization and point cloud registration. *Artificial Intelligence Review* 58, 72. [DOI](https://doi.org/10.1007/s10462-024-11053-1).

The author's [File Exchange release](https://www.mathworks.com/matlabcentral/fileexchange/177619-mlshade-spacma-final-code) provides a BSD-style three-clause notice, copyright 2024 Shengwei Fu. Its original complete text is preserved in [licenses/mLSHADE_SPACMA-BSD-3-Clause.txt](licenses/mLSHADE_SPACMA-BSD-3-Clause.txt), downloaded from that release's license URL. The local supplied benchmark interface and application generation adaptations are documented in the experiment code and `Application_Experiment/sources/algorithm_sources.json`. Numerical equivalence to every original release has not been established.

## Newton-Raphson-based optimizer (NRBO)

The source header credits R. Sowmya, M. Premkumar, and P. Jangir and their 2024 article in *Engineering Applications of Artificial Intelligence*, 128, 107532, [DOI](https://doi.org/10.1016/j.engappai.2023.107532). The [author's File Exchange release](https://www.mathworks.com/matlabcentral/fileexchange/158066-newton-raphson-based-optimizer-nrbo) provides a BSD-style three-clause notice, copyright 2024 Premkumar Manoharan. Its complete original text is in [licenses/NRBO-BSD-3-Clause.txt](licenses/NRBO-BSD-3-Clause.txt).

## CEC test suites

CEC 2017's supplied `cec17_func.cpp` header credits Noor Awad and records its 2016 origin and 2017 update. CEC 2022's native implementation and its transformation data are also retained with their existing headers. Official distribution locations are:

- [P-N-Suganthan/CEC2017-BoundContrained](https://github.com/P-N-Suganthan/CEC2017-BoundContrained)
- [P-N-Suganthan/2022-SO-BO](https://github.com/P-N-Suganthan/2022-SO-BO)

No separate redistribution-license file was present in the supplied local CEC trees, and none was identified on the opened official repository landing pages. This is an unresolved license-provenance record, not a claim that the material is MIT/BSD or that the original authors imposed an additional restriction. Existing sources, input files, and MEX binaries are kept unchanged.

## Other supplied comparators

The local supplied implementations `AROA.m`, `BBO.m`, `BKA.m`, `GJA.m`, `HBO.m`, `IVYA.m`, `NDO.m`, `SSLO.m`, and `TOC.m` do not contain a clear license grant in their supplied headers, and no LICENSE/COPYING/NOTICE file accompanied the local experiment folders. Their existing headers and the experiment's adaptation records are retained. This release does not guess full names, original authorship, or a redistribution license from an acronym alone, and does not claim that a missing header establishes a prohibition. Component-specific provenance can be supplemented by the maintainers without changing saved experiment measurements.

## pNEUMA

The included processed ground-position data derive from Emmanouil Barmpounakis and Nikolas Geroliminis's [pNEUMA dataset](https://zenodo.org/records/10491409), DOI [10.5281/zenodo.10491409](https://doi.org/10.5281/zenodo.10491409). The official record's API identified `cc-by-4.0` on 2026-10-15. [licenses/pNEUMA_license_metadata.json](licenses/pNEUMA_license_metadata.json) records that verification. Attribution, modifications, download links, and the excluded raw file's checksum are in [the dataset attribution](Application_Experiment/sources/datasets/pneuma/ATTRIBUTION.md).
