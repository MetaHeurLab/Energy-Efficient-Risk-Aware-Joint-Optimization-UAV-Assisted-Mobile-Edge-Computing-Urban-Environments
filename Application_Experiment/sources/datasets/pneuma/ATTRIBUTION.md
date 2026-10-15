# pNEUMA ground-position input

**Source:** Emmanouil Barmpounakis and Nikolas Geroliminis, *pNEUMA dataset*, version 1, published 11 January 2024, Zenodo. [Official record](https://zenodo.org/records/10491409); [DOI 10.5281/zenodo.10491409](https://doi.org/10.5281/zenodo.10491409).

**License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/). The official Zenodo API returned `metadata.license.id = cc-by-4.0` on 2026-10-15. The release records that check in `licenses/pNEUMA_license_metadata.json` at the repository root.

**Associated article:** Barmpounakis, E., Geroliminis, N. (2020). On the new era of urban traffic monitoring with massive drone data: The pNEUMA large-scale field experiment. *Transportation Research Part C*, 111, 50--71. [DOI](https://doi.org/10.1016/j.trc.2019.11.023).

## Included derived input and changes

`user_positions.csv` contains eight resampled ground-vehicle tracks, not aircraft telemetry. The selected original track IDs are 26, 27, 87, 88, 89, 93, 116, and 124. A 150-second interval is resampled every ten seconds by linear interpolation within observed intervals, without extrapolation. Latitude/longitude are converted to local planar coordinates using the documented spherical approximation and translated into the simulated service area; distance and time scales are unchanged. `trace_protocol.json` records the selection rule, coordinate anchor, transformation, scope, and checksums.

Processed CSV SHA-256:

```text
69e840fb7c506b11aab24106e970225ac2a71da01c72712c5218ce729fe25ba8
```

Vehicles are mobile-user proxies. Future positions are known to the offline planner. UAV trajectories, computation workloads, channels, safety disks, and energy are simulated. The data do not establish measured UAV/MEC performance or represent a random citywide vehicle sample.

## Optional raw download

The original raw CSV is omitted from Git. The official Zenodo record supplies `pNEUMA_dataset.zip` (15.8 GB) and `README.html`. Download from the official record if raw-input reconstruction is needed, extract `20181024_d6_0830_0900.csv`, and place it under this folder's `raw/` directory. The supplied processed input is sufficient to reproduce the application cases; the experiment runner does not require the raw archive.

Expected raw file size: **492,760,287 bytes**. Expected SHA-256:

```text
ed5c54c5791cc8f7796255a82c93dd886233e5745096ac4e3bb52f5c1fac5bd0
```

The extraction/selection and coordinate transformations are documented in `trace_protocol.json`. Historical local filesystem locations in its readable public copy have been replaced by repository-relative descriptions; the numerical protocol fields and processed CSV are unchanged.
