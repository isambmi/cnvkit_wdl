Two options for running CNVKit:

1. **End-to-end** (`CnvKit.wdl`): A single WDL running the distinct CNVkit steps (non-`batch`) using scatter-gather parallelization, outputing an aggregated SEG file

Steps executed: Access, AutoBin, Coverage (tumor and normal), Fix, Segment, Reference, and Aggregation of segment files


2. **Modular** (Recommended for large cloud-based cohorts to workaround timeouts): Separate WDLs for each processing stage. 

Workflows: preprocess (Access and AutoBin) -> coverage (tumor and normal) -> reference (uses normal coverages) -> calling (Fix and Segment using tumor coverages and Reference)