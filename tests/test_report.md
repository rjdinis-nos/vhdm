# WSL VHD Disk Management - Test Report

Last Updated: 2025-11-22 23:06:24

<a id="test-suite-summary"></a>
## Test Suite Summary

| Test Suite | Last Run | Status | Tests Run | Passed | Failed | Duration |
|------------|----------|--------|-----------|--------|--------|----------|
| [test_attach.sh](#test-attach) | 2025-11-22 | <span style="color: green; font-weight: bold;">✓ PASSED</span> | 15 | 15 | 0 | 23s |
| [test_create.sh](#test-create) | 2025-11-22 | <span style="color: green; font-weight: bold;">✓ PASSED</span> | 10 | 10 | 0 | 14s |
| [test_delete.sh](#test-delete) | 2025-11-22 | <span style="color: red; font-weight: bold;">✗ FAILED</span> | 10 | 3 | 7 | 24s |
| [test_detach.sh](#test-detach) | 2025-11-22 | <span style="color: green; font-weight: bold;">✓ PASSED</span> | 10 | 10 | 0 | 33s |
| [test_mount.sh](#test-mount) | 2025-11-22 | <span style="color: green; font-weight: bold;">✓ PASSED</span> | 10 | 10 | 0 | 25s |
| [test_resize.sh](#test-resize) | 2025-11-22 | <span style="color: green; font-weight: bold;">✓ PASSED</span> | 21 | 21 | 0 | 23s |
| [test_status.sh](#test-status) | 2025-11-22 | <span style="color: green; font-weight: bold;">✓ PASSED</span> | 10 | 10 | 0 | 14s |
| [test_umount.sh](#test-umount) | 2025-11-22 | <span style="color: green; font-weight: bold;">✓ PASSED</span> | 10 | 10 | 0 | 48s |

<a id="test-attach"></a>
### test_attach.sh ![PASSED](https://img.shields.io/badge/status-PASSED-brightgreen)

[↑ Back to Summary](#test-suite-summary)

| Metric | Value |
|--------|-------|
| **Last Run** | 2025-11-22 |
| **Status** | ✓ PASSED |
| **Tests Run** | 15 |
| **Passed** | <span style="color: green;">15</span> |
| **Failed** | <span style="color: red;">0</span> |
| **Duration** | 23s |

#### Test Results

| # | Test Name | Status |
|---|-----------|--------|
| **1** | Test 1 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **2** | Test 2 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **3** | Test 3 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **4** | Test 4 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **5** | Test 5 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **6** | Test 6 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **7** | Test 7 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **8** | Test 8 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **9** | Test 9 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **10** | Test 10 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **11** | Test 11 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **12** | Test 12 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **13** | Test 13 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **14** | Test 14 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **15** | Test 15 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |

<a id="test-create"></a>
### test_create.sh ![PASSED](https://img.shields.io/badge/status-PASSED-brightgreen)

[↑ Back to Summary](#test-suite-summary)

| Metric | Value |
|--------|-------|
| **Last Run** | 2025-11-22 |
| **Status** | ✓ PASSED |
| **Tests Run** | 10 |
| **Passed** | <span style="color: green;">10</span> |
| **Failed** | <span style="color: red;">0</span> |
| **Duration** | 14s |

#### Test Results

| # | Test Name | Status |
|---|-----------|--------|
| **1** | Test 1 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **2** | Test 2 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **3** | Test 3 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **4** | Test 4 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **5** | Test 5 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **6** | Test 6 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **7** | Test 7 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **8** | Test 8 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **9** | Test 9 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **10** | Test 10 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |

<a id="test-delete"></a>
### test_delete.sh ![FAILED](https://img.shields.io/badge/status-FAILED-red)

[↑ Back to Summary](#test-suite-summary)

| Metric | Value |
|--------|-------|
| **Last Run** | 2025-11-22 |
| **Status** | ✗ FAILED |
| **Tests Run** | 10 |
| **Passed** | <span style="color: green;">3</span> |
| **Failed** | <span style="color: red;">7</span> |
| **Duration** | 24s |

#### Test Results

| # | Test Name | Status |
|---|-----------|--------|
| **1** | Attempt to delete attached VHD (should fail) | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **2** | Delete detached VHD by path | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **3** | Verify VHD file is removed after delete | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **4** | Delete detached VHD with --force flag | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **5** | Delete in quiet mode | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **6** | Test 6 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **7** | Test 7 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **8** | Create, detach, and delete a VHD | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **9** | Verify temp VHD is removed | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **10** | Test 10 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |

<a id="test-detach"></a>
### test_detach.sh ![PASSED](https://img.shields.io/badge/status-PASSED-brightgreen)

[↑ Back to Summary](#test-suite-summary)

| Metric | Value |
|--------|-------|
| **Last Run** | 2025-11-22 |
| **Status** | ✓ PASSED |
| **Tests Run** | 10 |
| **Passed** | <span style="color: green;">10</span> |
| **Failed** | <span style="color: red;">0</span> |
| **Duration** | 33s |

#### Test Results

| # | Test Name | Status |
|---|-----------|--------|
| **1** | Test 1 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **2** | Test 2 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **3** | Test 3 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **4** | Test 4 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **5** | Test 5 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **6** | Test 6 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **7** | Test 7 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **8** | Test 8 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **9** | Test 9 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **10** | Test 10 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |

<a id="test-mount"></a>
### test_mount.sh ![PASSED](https://img.shields.io/badge/status-PASSED-brightgreen)

[↑ Back to Summary](#test-suite-summary)

| Metric | Value |
|--------|-------|
| **Last Run** | 2025-11-22 |
| **Status** | ✓ PASSED |
| **Tests Run** | 10 |
| **Passed** | <span style="color: green;">10</span> |
| **Failed** | <span style="color: red;">0</span> |
| **Duration** | 25s |

#### Test Results

| # | Test Name | Status |
|---|-----------|--------|
| **1** | Test 1 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **2** | Test 2 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **3** | Test 3 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **4** | Test 4 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **5** | Test 5 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **6** | Test 6 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **7** | Test 7 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **8** | Test 8 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **9** | Test 9 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **10** | Test 10 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |

<a id="test-resize"></a>
### test_resize.sh ![PASSED](https://img.shields.io/badge/status-PASSED-brightgreen)

[↑ Back to Summary](#test-suite-summary)

| Metric | Value |
|--------|-------|
| **Last Run** | 2025-11-22 |
| **Status** | ✓ PASSED |
| **Tests Run** | 21 |
| **Passed** | <span style="color: green;">21</span> |
| **Failed** | <span style="color: red;">0</span> |
| **Duration** | 23s |

#### Test Results

| # | Test Name | Status |
|---|-----------|--------|
| **1** | Test 1 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **2** | Test 2 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **3** | Test 3 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **4** | Test 4 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **5** | Test 5 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **6** | Test 6 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **7** | Test 7 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **8** | Test 8 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **9** | Test 9 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **10** | Test 10 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **11** | Test 11 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **12** | Test 12 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **13** | Test 13 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **14** | Test 14 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **15** | Test 15 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **16** | Test 16 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **17** | Test 17 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **18** | Test 18 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **19** | Test 19 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **20** | Test 20 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **21** | Test 21 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |

<a id="test-status"></a>
### test_status.sh ![PASSED](https://img.shields.io/badge/status-PASSED-brightgreen)

[↑ Back to Summary](#test-suite-summary)

| Metric | Value |
|--------|-------|
| **Last Run** | 2025-11-22 |
| **Status** | ✓ PASSED |
| **Tests Run** | 10 |
| **Passed** | <span style="color: green;">10</span> |
| **Failed** | <span style="color: red;">0</span> |
| **Duration** | 14s |

#### Test Results

| # | Test Name | Status |
|---|-----------|--------|
| **1** | Test 1 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **2** | Test 2 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **3** | Test 3 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **4** | Test 4 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **5** | Test 5 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **6** | Test 6 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **7** | Test 7 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **8** | Test 8 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **9** | Test 9 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **10** | Test 10 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |

<a id="test-umount"></a>
### test_umount.sh ![PASSED](https://img.shields.io/badge/status-PASSED-brightgreen)

[↑ Back to Summary](#test-suite-summary)

| Metric | Value |
|--------|-------|
| **Last Run** | 2025-11-22 |
| **Status** | ✓ PASSED |
| **Tests Run** | 10 |
| **Passed** | <span style="color: green;">10</span> |
| **Failed** | <span style="color: red;">0</span> |
| **Duration** | 48s |

#### Test Results

| # | Test Name | Status |
|---|-----------|--------|
| **1** | Test 1 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **2** | Test 2 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **3** | Test 3 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **4** | Test 4 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **5** | Test 5 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **6** | Test 6 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **7** | Test 7 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **8** | Test 8 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **9** | Test 9 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **10** | Test 10 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |

---
*This report is automatically generated and updated when test suites are executed.*
