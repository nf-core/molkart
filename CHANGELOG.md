# nf-core/molkart: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v1.0.1dev - [2023.12.18]

### `Fixed`

- Changed file prefix used in CLAHE to prevent file naming collisions if user used dots in filenames

## v1.0.1dev - [2023.12.15]

### `Added`

- Added config file for full test dataset

## v1.0.1dev - [2023.12.11]

Crop overview is provided to Multiqc - now when create_training_subset is run, multiqc and customdumpsoftwareversions are also run.

### `Added`

- removed CropSummary.txt from published outputs - it gets collected at multiqc step and published there
- moved crop_overview.png to MultiQC folder
- gitpod container is nf-core/gitpod:dev instead of latest to include new versions of nf-tools and nf-test
- MOLKARTQCPNG process to add name to png for multiqc report, and combine if multiple samples are processed

## v1.0.1dev - [2023.12.07]

Local module revamp - all should use the same Docker image to save space.

### `Added`

- renamed CREATEILASTIKTRAININGSUBSET to CROPHDF5
- renamed TIFFTRAININGSUBSET to CROPTIFF
- local modules now use the ghcr.io/schapirolabor/molkart-local:v0.0.1 container
- CREATE_STACK when clause - also applied the size check logic in molkart.nf
- Added crop_hdf5.py script instead of using mcmicro-ilastik container
- pattern to only return cropped images and overview (not versions or full hdf5 image)
- clahe does not use aicsimageio anymore
- create stack outputs a pyramidal tif (Palom)
- updated mesmer module - accordingly added prefix logic (and for maskfilter)

## v1.0.1dev - [2023.12.05]

Added MASKFILTER module.

### `Added`

- MASKFILTER module with respective script, parameters, qc measures that are passed to MOLKARTQC and MULTIQC
- renamed molcart_qc to MOLKARTQC
- versions to main local modules (MOLKARTQC, SPOT2CELL)
- CREATE_STACK when clause (so that it does not show in the progress when it doesn't run)
- comments in molkart.nf for clarity

### `Fixed`

- collect_QC average area is now rounded
- prefix handling in some modules

### `Removed`

- SAMPLESHEETCHECK subworkflow and Python script

## v1.0.1dev - [2023.12.02]

Replaced local module for mindagap/duplicatefinder with nf-core module.

### `Added`

- installed mindagap/duplicatefinder via nf-core tools

### `Removed`

- removed local mindagap_duplicatefinder.nf in local modules

## v1.0.1dev - [2023.11.30.]

Changes to clahe - more nf-core compliant, script change, versions, updated tests.

### `Added`

- Clahe now outputs versions
- --clahe_pyramid_tile parameter (hidden)

### `Fixed`

- clahe local module now follows nf-core guidelines with output naming defined through ext.prefix
- In all cases, the same writer will be used for clahe now
- Fixed CLAHE metadata
- renamed process from CLAHE_DASK to CLAHE
- renamed tilesize parameter to mindagap_tilesize for clarity

### `Removed`

- clahe_skip_pyramid parameter

## v1.0.1dev - [2023.11.28.]

Fixed file naming schema for mindagap and spot2cell. If only mesmer is used for segmentation, create stack does not have to be run.

### `Fixed`

- Mindagap outputs, in case the filenames were the same, would overwrite each other.
- spot2cell outputs, in case the filenames and segmentation method were the same, would overwrite each other.
- removed hardcoded memory requirement for CREATEILASTIKTRAININGSUBSET
- if only mesmer is used for segmentation, create stack does not have to be run.

## v1.0.1dev - [2023.11.24.]

Added first nf-tests for the pipeline.

### `Added`

- nf-test for 3 runs
- main.nf where the input only has the nuclear channel (does not run clahe or ilastik)
- main.nf where the input has both nuclear and membrane image (runs clahe, does not run ilastik)
- main.nf where the input only has the nuclear channel (does not run clahe), creates training subset

## v1.0.1dev - [2023.11.15]

Upgraded workflow, fixed multisample cellpose segmentation with custom model. Added options necessary to make testing work on small images.

### `Added`

- white background in metromap
- clahe_skip_pyramid parameter to skip pyramid generation in the clahe step - necessary for smaller data

### `Fixed`

- Cellpose custom model functions with multiple samples now.

## v1.0.1dev - [2023.11.13]

Added documentation - usage.md and output.md

### `Added`

- usage.md documentation
- output.md documentation
- segmentation outputs are all moved to a segmentation folder.
- updated nf-core module versions
- CITATIONS.md updated
- README.md updated
- WorkflowMolkart.groovy updated to return citations if tools are used (added commas)

## v1.0.1dev - [2023.25.10]

Implemented the tilesize parameter for Mindagap_mindagap and mindagap_duplicatefinder so that smaller representative images can be used as test.

### `Added`

- tilesize param
- tilesize passing to mindagap and duplicatefinder in modules.config
-

### `Fixed`

### `Dependencies`

### `Deprecated`

## v1.0.1dev - [2023.23.10]

- Replace `PROJECT_SPOTS` and `MCQUANT` modules with spot2cells. This new (for now local) module reduces the RAM requirements drastically, because it doesn't create a multi-channel stack for the spots. Spots are assigned by looking up cell IDs at x,y, positions and iterating over the deduplicated spots table.
- Added process labels to many modules to fix linting warnings
- Added meta map to molcart_qc output to remove linting warning -- adjusted script for multiqc input accordingly
- Added duplicated spots counts to collect_qc.py and multiqc_config.yml so that they also get counted.
- Added tag option to spot2cell so that the output names with same sample id and different segmentation methods can be differentiated (they were overwriting each other previously)
- removed project spots and mcquant from modules.config
- changed pattern for molcart_qc as it was not matching the files (removed {})
- added meta value to segmethod input in molcart_qc
- spot counts are now int values
- QC metrics rounded to 2 decimals

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
