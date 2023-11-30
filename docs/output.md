# nf-core/molkart: Output

## Introduction

This document describes the output produced by the pipeline. Most of the plots are taken from the MultiQC report, which summarises results at the end of the pipeline.

The directories listed below will be created in the results directory after the pipeline has finished. All paths are relative to the top-level results directory.

## Pipeline overview

The pipeline is built using [Nextflow](https://www.nextflow.io/) and processes data using the following steps:

- [Mindagap](#Mindagap) - Fill empty grid lines in a panorama image with neighbor-weighted values.
- [CLAHE](#CLAHE) - perform contrast-limited adaptive histogram equalization.
- [Create stacks](#create_stacks) - If a second image is provided, combine both into one stack as input for segmentation modules.
- [segmentation](#segmentation) - Segment single cells from provided image using segmentation method of choice (Cellpose, Mesmer, ilastik).
- [Mindagap_duplicatefinder](#Mindagap) - Take a spot table and search for duplicates along grid lines.
- [Spot2cell](#spot2cell) - Assign non-duplicated spots to segmented cells based on segmentation mask and extract cell shape information.
- [molkartqc](#molkartqc) - Produce QC metrics specific to this pipeline.
- [MultiQC](#multiqc) - Aggregate report describing results and QC from the whole pipeline.
- [Pipeline information](#pipeline-information) - Report metrics generated during the workflow execution.

- [Create training subset](#create-training-subset) - creates crops for segmentation training (Cellpose, ilastik).

### Mindagap

<details markdown="1">
<summary>Output files</summary>

- `mindagap/`
  - `*_gridfilled.tiff`: Gridfilled panorama file(s).
  - `*_markedDups.txt`: Spot table with duplicated spots marked as 'Duplicated'.

</details>

[Mindagap](https://github.com/ViriatoII/MindaGap) fills empty grids of a panorama made from several tiles using the mean of the immediate neighborhood, as well as marking duplicated spots near the grid from the spot table.

### CLAHE

<details markdown="1">
<summary>Output files</summary>

- `clahe/`
  - `*_clahe.tiff`: Image with contrast-limited adaptive histogram equalization applied.

</details>

[CLAHE](https://scikit-image.org/docs/stable/api/skimage.exposure.html#skimage.exposure.equalize_adapthist) is a algorithm from [scikit-image](https://scikit-image.org) for local contrast enhancement, that uses histograms computed over different tile regions of the image. Local details can therefore be enhanced even in regions that are darker or lighter than most of the image.

### Create_stacks

<details markdown="1">
<summary>Output files</summary>

- `stack/`
  - `*.ome.tif`: Image containing provided input images as channels.

</details>

Create stack is a local module used to merge images into a stack as preparation for segmentation processes.

### Segmentation

<details markdown="1">
<summary>Output files</summary>

- `segmentation/`
  - `cellpose/`
    - `*_cellpose_mask.tif`: Segmentation masks created by Cellpose.
  - `ilastik/`
    - `*_probability_maps.hdf5`: Probability maps created by ilastik's Pixel Classifier workflow.
    - `*_ilastik_mask.tif`: Segmentation masks created by ilastik's Boundary prediction with Multicut workflow.
  - `mesmer/`:
    - `*_mesmer_mask.tif`: Segmentation masks created by Mesmer.

</details>

[Cellpose](https://www.cellpose.org) is a segmentation tool that provides pretrained models as well as additional human-in-the loop training. If additional training is performed, the envisioned way of doing it is creating the training subset (`tiff`), and training the model in the [Cellpose GUI](https://cellpose.readthedocs.io/en/latest/gui.html) on the subset, then giving the trained model as an argument within the pipeline to complete the pipeline run.

[ilastik](https://www.ilastik.org) is an interactive learning and segmentation toolkit, with its application here envisioned as - create training subset (`hdf5`), create Pixel Classifier and Boundary prediction with Multicut projects with specified parameters. Within Molkart, the project files can be given and batch processing would be applied on the full images.

[Mesmer](https://deepcell.readthedocs.io/en/master/API/deepcell.applications.html#mesmer) is a segmentation tool that provides pretrained models for whole-cell and nuclear segmentation.

### Spot2cell

<details markdown="1">
<summary>Output files</summary>

- `spot2cell/`
  - `*.cellxgene.csv`: Cell-by-transcript `csv` file containing transcript counts per cell, as well as cell shape properties.

</details>

Spot2cell is a local module that assigns spots (without Duplicates) to cells via a spot table and segmentation mask.

### MolkartQC

<details markdown="1">
<summary>Output files</summary>

- `molkartqc/`
  - `*.spot_QC.csv`: ### Spot2cell

<details markdown="1">
<summary>Output files</summary>

- `molkartqc/`
  - `*.cellxgene.csv`: Sheet containing useful quality-control metrics specific to spot-based image processing methods.

</details>

MolkartQC is a local module used for gathering useful quality-control metrics for spot-based image processing methods, including: sample ID, used segmentation method, total number of cells, average cell area, total number of spots, average spot assignment per cell, total number of assigned spots, percentage of assigned spots, number of duplicated spots.

### MultiQC

<details markdown="1">
<summary>Output files</summary>

- `multiqc/`
  - `multiqc_report.html`: a standalone HTML file that can be viewed in your web browser.
  - `multiqc_data/`: directory containing parsed statistics from the different tools used in the pipeline.
  - `multiqc_plots/`: directory containing static images from the report in various formats.

</details>

[MultiQC](http://multiqc.info) is a visualization tool that generates a single HTML report summarising all samples in your project. Most of the pipeline QC results are visualised in the report and further statistics are available in the report data directory.

Results generated by MultiQC collate pipeline QC from supported tools e.g. FastQC. The pipeline has special steps which also allow the software versions to be reported in the MultiQC output for future traceability. For more information about how to use MultiQC reports, see <http://multiqc.info>.

### Pipeline information

<details markdown="1">
<summary>Output files</summary>

- `pipeline_info/`
  - Reports generated by Nextflow: `execution_report.html`, `execution_timeline.html`, `execution_trace.txt` and `pipeline_dag.dot`/`pipeline_dag.svg`.
  - Reports generated by the pipeline: `pipeline_report.html`, `pipeline_report.txt` and `software_versions.yml`. The `pipeline_report*` files will only be present if the `--email` / `--email_on_fail` parameters are used when running the pipeline.
  - Reformatted samplesheet files used as input to the pipeline: `samplesheet.valid.csv`.
  - Parameters used by the pipeline run: `params.json`.

### create-training-subset

<details markdown="1">
<summary>Output files</summary>

- `training_subset/`
  - `hdf5/`
    - `*_crop[0-9]+.hdf5`: `hdf5` crops for training Pixel classification and Multicut models with ilastik for segmentation.
    - `*CropSummary.txt`: Summary of the created crops - used by tiff crops and for overview creation.
  - `tiff/`
    - `*_crop[0-9]+.tiff`: `tiff` crops for training Cellpose to create a custom segmentation model.
    - `*.crop_overview.png`: Crop overview for visual assessment of crop placement on the whole sample.

</details>

Spot2cell is a local module that assigns spots (without Duplicates) to cells via a spot table and segmentation mask.

</details>

[Nextflow](https://www.nextflow.io/docs/latest/tracing.html) provides excellent functionality for generating various reports relevant to the running and execution of the pipeline. This will allow you to troubleshoot errors with the running of the pipeline, and also provide you with other information such as launch commands, run times and resource usage.
