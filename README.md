# Combinato Output Comparison Suite

This suite contains MATLAB utilities to **validate and verify reproducibility**
between outputs of the **old** and **new** Combinato pipelines for a single
recording session.

It ensures that scientific and metadata outputs are **numerically equivalent**,  
**structurally identical**, or **deterministically consistent** — supporting
regression testing and version control for Combinato refactoring.

---

## Directory Layout / Files Overview

    test_codes/
    │
    ├── run_all_combinato_tests.m 		# **Main driver** — automatically detects NEW/OLD output folders and dispatches file comparisons
    ├── compare_elementwise_mat.m 		# Element-wise comparison for numeric `.mat` files (`times_CSC*.mat`, `CSC*_spikes.mat`)
    ├── compare_cellwise_mat.m 			# Cell-by-cell comparison for `.mat` files (`cluster_info.mat`)
    ├── compare_struct_metrics.m 		# Field-wise recursive comparison for struct-based `.mat` files (`qMetrics.mat`)
    ├── compare_text_exact.m 			# Line-by-line deterministic text comparison (`ChannelNames.txt`, `do_sort_pos.txt`)
    ├── compare_structured_csv.m 		# Structured numeric/text CSV comparison (`DAS_Log_Micromed_*.csv`)
    ├── compare_checksum.m 				# SHA-256 and file-size comparison for all other non-.mat deterministic files
    └── logs/ 							# Directory where `.csv` test reports with metadata are automatically saved

---

## How to Use

Prerequisites:

    - Activate conda environment (if any) and open MATLAB.
    - Navigate to the test suite directory.

GUI mode:

    - Launch run_all_combinato_tests
    - In the popup, navigate and choose the output folders (for both New and Old)

Scripted mode:

    - run_all_combinato_tests(...'/path/to/new/session', ...'/path/to/old/session');

---
---

# What is tested?

Each file type is automatically matched by filename pattern and extension, and
dispatched to the appropriate helper function.  
Non-deterministic or auxiliary files (e.g. logs, JSON, PDFs) are skipped but recorded
for completeness.

---
---

## Element-wise .mat checks

Handled by: compare_elementwise_mat.m

Files:

    - times_CSC*.mat
    - CSC*_ spike.mat

| Property              | Description                                                               | Tolerance  |
| --------------------- | ------------------------------------------------------------------------- | ---------- |
| **Variable presence** | Both files must have same variable names (e.g. `cluster_class`, `spikes`) | exact      |
| **Matrix shape**      | Same number of rows (spikes) and columns (samples)                        | exact      |
| **Numeric content**   | Element-wise equality (each sample value)                                 | ≤ 1 × 10⁻⁶ |
| **Summary**           | Reports max absolute difference per variable                              | —          |

Detects differences in:

    - Spike counts
    - Spike waveform samples
    - Cluster assignments
    - Timestamp precision

---

## Cell-wise .mat checks

Handled by: compare_cellwise_mat.m

Files:

    - cluster_info.mat

| Property             | Description                                    | Tolerance  |
| -------------------- | ---------------------------------------------- | ---------- |
| **Cell dimensions**  | Same number of rows/columns (e.g. 3×64 matrix) | exact      |
| **Numeric cells**    | Absolute difference ≤ 1 × 10⁻⁶                 | ≤ 1 × 10⁻⁶ |
| **Text cells**       | String equality (`strcmp`)                     | exact      |
| **Type consistency** | Same class for both entries                    | exact      |
| **Empty cells**      | Treated as equal                               | —          |

Detects differences in:

    - Number of clusters
    - Cluster ID ordering
    - Label text (e.g. MU1, SU1)
    - Numeric values like spike counts or amplitudes

---

## Struct-based metric checks

Handled by: compare_struct_metrics.m

Files:

    - qMetrics.mat (and similar struct-based metrics)

| Property            | Description                                  | Tolerance  |
| ------------------- | -------------------------------------------- | ---------- |
| **Field names**     | Must be identical (recursive into subfields) | exact      |
| **Field sizes**     | Must match                                   | exact      |
| **Numeric content** | Element-wise equality within tolerance       | ≤ 1 × 10⁻⁶ |
| **Nested structs**  | Compared recursively                         | —          |

Detects differences in:

    - Spike quality metrics (isolation distance, SNR, peak-to-valley ratio, etc.)
    - Cluster quality or auto-reject thresholds

---

## Deterministic Text Checks

Handled by: **compare_text_exact.m**

Files:

    - ChannelNames.txt
    - do_sort_pos.txt

| Property           | Description                                  |
| ------------------ | -------------------------------------------- |
| **Line-by-line**   | Compares trimmed text line-by-line           |
| **Count match**    | Reports differing line counts                |
| **Content match**  | Reports first differing line (if any)        |
| **Output tag**     | Labeled as `text-exact` in CSV logs          |

Detects differences in:
    
    - Channel naming inconsistencies  
    - Sort order configuration changes  

---

## Structured CSV Checks

Handled by: **compare_structured_csv.m**

Files:

    - DAS_Log_Micromed_*.csv
    - other CSVs

| Property              | Description                                    | Tolerance  |
| --------------------- | ---------------------------------------------- | ---------- |
| **Shape**             | Same number of rows and columns                | exact      |
| **Numeric content**   | Element-wise equality within tolerance         | ≤ 1 × 10⁻⁶ |
| **Text content**      | Exact string match per column                  | exact      |
| **Report**            | Displays table dimensions and first mismatch (if any) | —      |

Detects differences in:

    - Numeric deviations in deterministic tables 
    - Text or categorical mismatches
    - Row or column count differences
    - Type changes within columns

---

## Checksum / file-level checks

Handled by: compare_checksum.m

Files:

    - All non-.mat files (e.g. jobfile.txt, .json, .png, .pdf, .eps, .log, etc.)

| Property           | Description                                   |
| ------------------ | --------------------------------------------- |
| **File size**      | Byte count difference (always checked)        |
| **SHA-256 hash**   | Cryptographic hash equality (default)         |
| **Fallback**       | If hash fails, falls back to size-only check  |

Behavior:
    
    - `.h5`, `.png`, `.jpg`, `.tif`, `.eps`, `.fig` → **Size-only comparison**
    - `.log`, `.json`, `.yaml`, `.pdf` → **Skipped** (non-deterministic)
    - `.txt` → **Special-cased** (see text-exact above)

Detects differences in:

    - Generated figures or summary plots (via size changes)
    - Text configuration or job logs (Skipped)
    - Metadata or missing output files
    - Any unexpected new file types (via fallback checksum)

---

### Notes
- All results are written as `.csv` reports under `logs/`.
- Each log includes metadata: timestamp, MATLAB version, and hostname.
- Files inside any folder named `combinatostuff_*` are automatically ignored.
- Numerical comparisons use a tolerance of **1e−6** by default.
- SHA-256 for stronger and more reliable checksum validation.
- Skipped entries represent non-deterministic outputs that can vary across runs.

---
