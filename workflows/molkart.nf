/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    PRINT PARAMS SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { paramsSummaryLog; paramsSummaryMap; fromSamplesheet } from 'plugin/nf-validation'

def logo = NfcoreTemplate.logo(workflow, params.monochrome_logs)
def citation = '\n' + WorkflowMain.citation(workflow) + '\n'
def summary_params = paramsSummaryMap(workflow)

// Print parameter summary log to screen
log.info logo + paramsSummaryLog(workflow) + citation

WorkflowMolkart.initialise(params, log)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

ch_multiqc_config          = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
ch_multiqc_custom_config   = params.multiqc_config ? Channel.fromPath( params.multiqc_config, checkIfExists: true ) : Channel.empty()
ch_multiqc_logo            = params.multiqc_logo   ? Channel.fromPath( params.multiqc_logo, checkIfExists: true ) : Channel.empty()
ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { CLAHE_DASK                 } from '../modules/local/clahe_dask'
include { MINDAGAP_DUPLICATEFINDER   } from '../modules/local/mindagap_duplicatefinder'
include { PROJECT_SPOTS              } from '../modules/local/project_spots'
include { MOLCART_QC                 } from '../modules/local/molcart_qc'

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { MULTIQC                     } from '../modules/nf-core/multiqc/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/custom/dumpsoftwareversions/main'
include { MINDAGAP_MINDAGAP           } from '../modules/nf-core/mindagap/mindagap/main'
include { CELLPOSE                    } from '../modules/nf-core/cellpose/main'
include { DEEPCELL_MESMER             } from '../modules/nf-core/deepcell/mesmer/main'
include { ILASTIK_PIXELCLASSIFICATION } from '../modules/nf-core/ilastik/pixelclassification/main'
include { MCQUANT                     } from '../modules/nf-core/mcquant/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary
def multiqc_report = []

workflow MOLKART {

    ch_versions = Channel.empty()

    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //
    ch_from_samplesheet = Channel.fromSamplesheet("input")
    ch_from_samplesheet
        .map { sample_id, nuclear_image, spot_table -> tuple([id: sample_id], nuclear_image) }
        .set { image_tuple }

    //
    // MODULE: Run Mindagap_mindagap
    //
    MINDAGAP_MINDAGAP(image_tuple, 7, 100)

    ch_versions = ch_versions.mix(MINDAGAP_MINDAGAP.out.versions)

    // Stack images

    //
    // MODULE: Apply Contrast-limited adaptive histogram equalization (CLAHE)
    //

    CLAHE_DASK(MINDAGAP_MINDAGAP.out.tiff) // TODO : Add local module for testing

    //
    // MODULE: MINDAGAP Duplicatefinder
    //
    // Filter out potential duplicate spots from the spots table
    ch_from_samplesheet
        .map { sample_id, nuclear_image, spot_table -> tuple([id: sample_id], spot_table) }
        .set { spot_tuple }

    MINDAGAP_DUPLICATEFINDER(spot_tuple)

    ch_versions = ch_versions.mix(MINDAGAP_DUPLICATEFINDER.out.versions)

    //
    // MODULE: PROJECT SPOTS
    //
    // Transform spot table to 2 dimensional numpy array to use with MCQUANT

    qc_spots = MINDAGAP_DUPLICATEFINDER.out.marked_dups_spots
    dedup_spots = qc_spots
        .join(image_tuple)

    PROJECT_SPOTS(
        dedup_spots.map(it -> tuple(it[0],it[1])),
        dedup_spots.map(it -> it[2])
    )

    //
    // MODULE: DeepCell Mesmer segmentation
    //
    segmentation_masks = Channel.empty()
    if (params.segmentation_method.split(',').contains('mesmer')) {
        DEEPCELL_MESMER(CLAHE_DASK.out.img_clahe, [[:], []])
        ch_versions = ch_versions.mix(DEEPCELL_MESMER.out.versions)
        segmentation_masks = segmentation_masks
            .mix(DEEPCELL_MESMER.out.mask
                .combine(Channel.of('mesmer')))
    }

    //
    // MODULE: Cellpose segmentation
    //
    if (params.segmentation_method.split(',').contains('cellpose')) {
        CELLPOSE(CLAHE_DASK.out.img_clahe, [])
        ch_versions = ch_versions.mix(CELLPOSE.out.versions)
        segmentation_masks = segmentation_masks
            .mix(CELLPOSE.out.mask
                .combine(Channel.of('cellpose')))
    }

    PROJECT_SPOTS.out.img_spots
        .join(PROJECT_SPOTS.out.channel_names)
        .map{
            meta,tiff,channels -> [meta,tiff,channels]
            }
        .combine(segmentation_masks, by: 0)
        .map {
            meta, tiff, channels, mask, seg ->
            new_meta = meta.clone()
            new_meta.segmentation = seg
            [new_meta, tiff, channels, mask]
        }.set{ mcquant_in }

    /// Prepare input for MCQuant using images and spots
    //mcquant_in = PROJECT_SPOTS.out.img_spots
    ///    .join(PROJECT_SPOTS.out.channel_names)
    //    .map{
    //        meta,tiff,channels -> [meta,tiff,channels]
    //        }
    //    .combine(segmentation_masks, by: 0)

    //
    // MODULE: MCQuant
    //
    MCQUANT(
        mcquant_in.map{it -> tuple(it[0],it[1])},
        mcquant_in.map{it -> tuple(it[0],it[3])},
        mcquant_in.map{it -> tuple(it[0],it[2])}
        )
    ch_versions = ch_versions.mix(MCQUANT.out.versions)

    //
    // MODULE: MOLCART_QC
    //
    MCQUANT.out.csv
        .map {
            meta, quant ->
            [meta.subMap("id"), quant, meta.segmentation]
        }.set { mcquant_out }

    qc_spots.combine(
        mcquant_out, by: 0)
        .set{ molcart_qc }

    molcart_qc.view()

    MOLCART_QC(
            molcart_qc.map{it -> tuple(it[0],it[2])},
            molcart_qc.map{it -> tuple(it[0],it[1])},
            molcart_qc.map{it -> it[3]}
        )

    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

    //
    // MODULE: MultiQC
    //
    workflow_summary    = WorkflowMolkart.paramsSummaryMultiqc(workflow, summary_params)
    ch_workflow_summary = Channel.value(workflow_summary)
    methods_description    = WorkflowMolkart.methodsDescriptionText(workflow, ch_multiqc_custom_methods_description, params)
    ch_methods_description = Channel.value(methods_description)

    ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect())

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList()
    )
    multiqc_report = MULTIQC.out.report.toList()
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.dump_parameters(workflow, params)
    NfcoreTemplate.summary(workflow, params, log)
    if (params.hook_url) {
        NfcoreTemplate.IM_notification(workflow, params, summary_params, projectDir, log)
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
