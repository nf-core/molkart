# nf-core/molkart: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v1.0.1dev - [2023.23.10]

- Replace `PROJECT_SPOTS` and `MCQUANT` modules with spot2cells. This new (for now local) module reduces the RAM requirements drastically, because it doesn't create a multi-channel stack for the spots. Spots are assigned by looking up cell IDs at x,y, positions and iterating over the deduplicated spots table.
- Added process labels to many modules to fix linting warnings
- Added meta map to molcart_qc output to remove linting warning

## v1.0.1dev - [2023.22.10]

Replaced the `clahe` param with `skip_clahe` so that the default value for running CLAHE is `False`.

### `Added`

- skip_clahe param (default False)
- removed clahe param
- adjusted workflow to check the params.skip_clahe value instead of the params.clahe
- adjusted the ext.when in modules.config

### `Fixed`

### `Dependencies`

### `Deprecated`

## v1.0dev - [2023.18.10]

Added barebones version of multiqc output.

### `Added`

- emit value for png overview for createtrainingtiff
- molcart-qc: added sampleid-segmentation tag as sample id, as multiqc was only showing the second row if sample id is same - can this be fixed to unique row?
- input for multiqc are the csv files produced by molcart qc

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
