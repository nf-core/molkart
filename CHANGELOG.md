# nf-core/molkart: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v1.0dev - [2023.18.10]

Added barebones version of multiqc output.

### `Added`

- emit value for png overview for createtrainingtiff
- molcart-qc: added sampleid-segmentation tag as sample id, as multiqc was only showing the second row if sample id is same - can this be fixed to unique row?
-

### `Fixed`

### `Dependencies`

### `Deprecated`

## v1.0.1dev - [2023.12.10]

Molkart adapted to most nf-core standards with optional parameters, multiple segmentation options, as well as membrane channel handling. Started work on creating training subset functionality.

### `Added`

- parameters for pipeline execution
- ext.args logic for almost all modules with external parameters
- channel logic for membrane handling
- create stack process if membrane image present for Cellpose
- optional clahe
- started work on create subset functionality

### `Fixed`

### `Dependencies`

### `Deprecated`

## v1.0dev - [date]

Initial release of nf-core/molkart, created with the [nf-core](https://nf-co.re/) template.

### `Added`

### `Fixed`

### `Dependencies`

### `Deprecated`
