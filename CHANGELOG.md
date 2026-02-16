# nf-core/molkart: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v1.3.0dev - [date]

### Added

### Changed

### Fixed

- [PR #130](https://github.com/nf-core/molkart/pull/130) - support for new Molecular Cartography spot table format (keep first 4 columns only)

## v1.2.0 - [date]

### Added

- [PR #109](https://github.com/nf-core/molkart/pull/109) - Added cellpose_cellprob_threshold parameter (@felixS27)

### Changed

- [PR #111](https://github.com/nf-core/molkart/pull/111) - Updated json schemas (@kbestak)
- [PR #116](https://github.com/nf-core/molkart/pull/116) - Update CI to use nf-test on changed files (@kbestak)
- [PR #118](https://github.com/nf-core/molkart/pull/118) - Template update (@kbestak)
- [PR #124](https://github.com/nf-core/molkart/pull/124) - Template update (@kbestak)

### Fixed

- [PR #115](https://github.com/nf-core/molkart/pull/115) - Added stub section for local modules (@kbestak)
- [PR #110](https://github.com/nf-core/molkart/pull/110) - Fixed starting index of created crops (0->1) (@miri-2000)

### Dependencies

## 1.1.0 - Resolution Road

### Added

- [PR #78](https://github.com/nf-core/molkart/pull/78) - Allow for Mindagap to be skipped using `skip_mindagap` parameter (@kbestak)
- [PR #81](https://github.com/nf-core/molkart/pull/81) - Add Stardist as a segmentation method (@kbestak)

### Changed

- [PR #71](https://github.com/nf-core/molkart/pull/71), [PR #88](https://github.com/nf-core/molkart/pull/88), [PR #94](https://github.com/nf-core/molkart/pull/94) - template updates from 2.11.1 to 3.2.0 (@kbestak)
- [PR #98](https://github.com/nf-core/molkart/pull/98) - Update all nf-core modules (@FloWuenne)
- [PR #99](https://github.com/nf-core/molkart/pull/99) - Clean up code to adhere to language server standards (@kbestak)
- [PR #100](https://github.com/nf-core/molkart/pull/100) - Added author and license information to all bin scripts (@FloWuenne)
- [PR #101](https://github.com/nf-core/molkart/pull/101) - Updated manifest and author information (@FloWuenne)
- [PR #102](https://github.com/nf-core/molkart/pull/102) - Updated documentation (@kbestak)
- [PR #107](https://github.com/nf-core/molkart/pull/107) - Updated nf-tests to use nft-utils (@FloWuenne)

### Fixed

- [PR #76](https://github.com/nf-core/molkart/pull/76) - Fix issue with custom content in MultiQC output (@kbestak)

### Dependencies

| Tool     | Previous version | New version |
| -------- | ---------------- | ----------- |
| Cellpose | 2.2.2            | 3.0.1       |
| Stardist |                  | 0.9.1       |
| MultiQC  | 1.19             | 1.27        |

## 1.0.0 - Spatial Circuit

First release of nf-core/molkart.
