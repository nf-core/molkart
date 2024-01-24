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

ch_multiqc_config                     = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
ch_multiqc_custom_config              = params.multiqc_config ? Channel.fromPath( params.multiqc_config, checkIfExists: true ) : Channel.empty()
ch_multiqc_logo                       = params.multiqc_logo   ? Channel.fromPath( params.multiqc_logo, checkIfExists: true ) : Channel.empty()
ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { CROPTIFF       } from '../modules/local/croptiff'
include { CROPHDF5       } from '../modules/local/crophdf5'
include { CREATE_ANNDATA } from '../modules/local/createanndata'
include { CREATE_STACK   } from '../modules/local/createstack'
include { CLAHE          } from '../modules/local/clahe'
include { MASKFILTER     } from '../modules/local/maskfilter'
include { MOLKARTQC      } from '../modules/local/molkartqc'
include { MOLKARTQCPNG   } from '../modules/local/molkartqcpng'
include { SPOT2CELL      } from '../modules/local/spot2cell'
include { TIFFH5CONVERT  } from '../modules/local/tiffh5convert'

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
include { CELLPOSE                    } from '../modules/nf-core/cellpose/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/custom/dumpsoftwareversions/main'
include { DEEPCELL_MESMER             } from '../modules/nf-core/deepcell/mesmer/main'
include { ILASTIK_MULTICUT            } from '../modules/nf-core/ilastik/multicut/main'
include { ILASTIK_PIXELCLASSIFICATION } from '../modules/nf-core/ilastik/pixelclassification/main'
include { MINDAGAP_DUPLICATEFINDER    } from '../modules/nf-core/mindagap/duplicatefinder/main'
include { MINDAGAP_MINDAGAP           } from '../modules/nf-core/mindagap/mindagap/main'
include { MULTIQC                     } from '../modules/nf-core/multiqc/main'

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
    //ch_from_samplesheet = Channel.fromSamplesheet("input")

    ch_from_samplesheet = Channel.fromSamplesheet("input")

    // stain: "1" denotes membrane, stain: "0" denotes nuclear image
    // this is used to preserve the order later
    ch_from_samplesheet
        .map {
            it[3] != [] ? tuple([id:it[0],stain:"1"], it[3]) : null
        }.set { membrane_tuple } // if a membrane image is provided, return membrane image channel tuple (meta, path)

    ch_from_samplesheet
        .map { it -> tuple([id:it[0],stain:"0"], it[1]) }
        .set { image_tuple } // creates nuclear image channel tuple (meta, path)

    ch_from_samplesheet
        .map { it -> tuple([id:it[0]], it[2]) }
        .set { spot_tuple } // creates spot table channel tuple (meta, path)

    //
    // MODULE: Run Mindagap_mindagap
    //
    mindagap_in = membrane_tuple.mix(image_tuple) // mindagap input contains both membrane and nuclear images
    MINDAGAP_MINDAGAP(mindagap_in)
    ch_versions = ch_versions.mix(MINDAGAP_MINDAGAP.out.versions)

    //
    // MODULE: Apply Contrast-limited adaptive histogram equalization (CLAHE)
    // CLAHE is either applied to all images, or none.
    //
    CLAHE(MINDAGAP_MINDAGAP.out.tiff)
    ch_versions = ch_versions.mix(CLAHE.out.versions)

    map_for_stacks = !params.skip_clahe ? CLAHE.out.img_clahe : MINDAGAP_MINDAGAP.out.tiff

    map_for_stacks
        .map {
            meta, tiff -> [meta.subMap("id"), tiff, meta.stain] // creates a channel containing only the sample id in meta, path to preprocessed image and the stain value ("0" or "1")
        }.groupTuple() // combines based on meta
        .map{
            meta, paths, stains -> [meta, [paths[0], stains[0]], [paths[1], stains[1]]] // reorganizes to match path and stain
        }.map{
            meta, stain1, stain2 -> [meta, [stain1, stain2].sort{ it[1] }] // sort by stain index (0 for nuclear, 1 for other)
        }.map{
            meta, list -> [meta, list[0], list[1]] // sorted will have null as first list
        }.map{
            it[1][0] != null ? [it[0],it[1][0],it[2][0]] : [it[0],it[2][0]] // if null, only return the valid nuclear path value, otherwise return both nuclear and membrane paths
        }.set { grouped_map_stack }

    grouped_map_stack.filter{ // for rows without a present membrane image, set channel to no_stack
        it[2] == null
        }.set{ no_stack }

    grouped_map_stack.filter{ // for rows where the membrane image is present, make it compliant with STACK inputs
        it[2] != null
        }.map{
            [it[0],tuple(it[1],it[2])]
        }.set{ create_stack_in }

    //
    // MODULE: Stack channels if membrane image provided for segmentation
    //
    CREATE_STACK(create_stack_in)
    ch_versions = ch_versions.mix(CREATE_STACK.out.versions)
    stack_mix = no_stack.mix(CREATE_STACK.out.stack)

    if ( params.create_training_subset ) {
        // Create subsets of the image for training an ilastik model
        stack_mix.join(
            grouped_map_stack.map{
                it[2] == null ? tuple(it[0], 1) : tuple(it[0], 2)
            } // hardcodes that if membrane channel present, num_channels is 2, otherwise 1
        ).set{ training_in }

        CROPHDF5(training_in)
        ch_versions = ch_versions.mix(CROPHDF5.out.versions)
        // Combine images with crop_summary for making the same training tiff stacks as ilastik
        tiff_crop = stack_mix.join(CROPHDF5.out.crop_summary)
        CROPTIFF(
            tiff_crop.map(it -> tuple(it[0],it[1])),
            tiff_crop.map(it -> tuple(it[0],it[2])),
            )
        ch_versions = ch_versions.mix(CROPTIFF.out.versions)
        MOLKARTQCPNG(CROPTIFF.out.overview.map{
                    tuple('matchkey', it[1])
                    }.groupTuple().map{ it[1]} )
        ch_versions = ch_versions.mix(MOLKARTQCPNG.out.versions)
    } else {

    //
    // MODULE: MINDAGAP Duplicatefinder
    //
    // Filter out potential duplicate spots from the spots table
    MINDAGAP_DUPLICATEFINDER(spot_tuple)
    ch_versions = ch_versions.mix(MINDAGAP_DUPLICATEFINDER.out.versions)

    qc_spots = MINDAGAP_DUPLICATEFINDER.out.marked_dups_spots

    //
    // MODULE: DeepCell Mesmer segmentation
    //
    segmentation_masks = Channel.empty()
    if (params.segmentation_method.split(',').contains('mesmer')) {
        DEEPCELL_MESMER(
            grouped_map_stack.map{ tuple(it[0], it[1]) },
            grouped_map_stack.map{
                it[2] == null ? [[:],[]] : tuple(it[0], it[2]) // if no membrane channel specified, give empty membrane input; if membrane image exists, provide it to the process
            }
        )
        ch_versions = ch_versions.mix(DEEPCELL_MESMER.out.versions)
        segmentation_masks = segmentation_masks
            .mix(DEEPCELL_MESMER.out.mask
                .combine(Channel.of('mesmer')))
    }
    //
    // MODULE: Cellpose segmentation
    //
    cellpose_custom_model = params.cellpose_custom_model ? stack_mix.combine(Channel.fromPath(params.cellpose_custom_model)) : []
    if (params.segmentation_method.split(',').contains('cellpose')) {
        CELLPOSE(
            stack_mix,
            cellpose_custom_model ? cellpose_custom_model.map{it[2]} : []
            )
        ch_versions = ch_versions.mix(CELLPOSE.out.versions)
        segmentation_masks = segmentation_masks
            .mix(CELLPOSE.out.mask
                .combine(Channel.of('cellpose')))
    }
    //
    // MODULE: ilastik segmentation
    //
    if (params.segmentation_method.split(',').contains('ilastik')) {
        if (params.ilastik_pixel_project == null) {
            error "ILASTIK_PIXELCLASSIFICATION module was not provided with the project .ilp file."
        }
        stack_mix.join(
            grouped_map_stack.map{
                it[2] == null ? tuple(it[0], 1) : tuple(it[0], 2)
            }).set{ tiffin }

        TIFFH5CONVERT(tiffin)
        ch_versions = ch_versions.mix(TIFFH5CONVERT.out.versions)

        TIFFH5CONVERT.out.hdf5.combine(
            Channel.fromPath(params.ilastik_pixel_project)
            ).set{ ilastik_in }
        ILASTIK_PIXELCLASSIFICATION(
            ilastik_in.map{ [it[0], it[1]] },
            ilastik_in.map{ [it[0], it[2]] }
        )
        ch_versions = ch_versions.mix(ILASTIK_PIXELCLASSIFICATION.out.versions)

        if (params.ilastik_multicut_project == null) {
            error "ILASTIK_MULTICUT module was not provided with the project .ilp file."
        }
        ilastik_in.join(ILASTIK_PIXELCLASSIFICATION.out.output)
            .combine(Channel.fromPath(params.ilastik_multicut_project))
            .set{ multicut_in }

        ILASTIK_MULTICUT(
            multicut_in.map{ tuple(it[0], it[1]) },
            multicut_in.map{ tuple(it[0], it[4]) },
            multicut_in.map{ tuple(it[0], it[3]) }
        )
        ch_versions = ch_versions.mix(ILASTIK_MULTICUT.out.versions)
        segmentation_masks = segmentation_masks
            .mix(ILASTIK_MULTICUT.out.out_tiff
                .combine(Channel.of('ilastik')))
    }
    segmentation_masks.map{
        meta, mask, segmentation ->
        new_meta = meta.clone()
        new_meta.segmentation = segmentation
        [new_meta, mask]
    }.set { matched_segmasks }

    //
    // MODULE: filter segmentation masks
    //
    MASKFILTER(matched_segmasks)
    ch_versions = ch_versions.mix(MASKFILTER.out.versions)
    MASKFILTER.out.filtered_mask.map{
        meta, mask ->
        tuple(meta.subMap("id"), mask, meta.segmentation)
    }.set { filtered_masks }

    //
    // MODULE: assign spots to segmentation mask
    //
    qc_spots
        .combine(filtered_masks, by: 0)
        .map {
            meta, spots_table, mask, segmethod ->
            new_meta = meta.clone()
            new_meta.segmentation = segmethod
            [new_meta, spots_table, mask]
            }
        .set { dedup_spots }

    SPOT2CELL(
        dedup_spots.map(it -> tuple(it[0],it[1])),
        dedup_spots.map(it -> tuple(it[0],it[2]))
    )
    ch_versions = ch_versions.mix(SPOT2CELL.out.versions)

    //
    // MODULE: create anndata squidpy object from spot2cell table
    //
    CREATE_ANNDATA(
        SPOT2CELL.out.cellxgene_table
    )
    ch_versions = ch_versions.mix(CREATE_ANNDATA.out.versions)

    //
    // MODULE: MOLKARTQC
    //
    SPOT2CELL.out.cellxgene_table.combine(
            MASKFILTER.out.filtered_qc, by: 0
        ).map{
            meta, quant, filterqc ->
            [meta.subMap("id"), quant, meta.segmentation, filterqc]
        }.set { spot2cell_out }

    qc_spots
        .combine(spot2cell_out, by: 0)
        .set{ molkartqc }

    MOLKARTQC(molkartqc)
    ch_versions = ch_versions.mix(MOLKARTQC.out.versions)

    }
    //
    // MODULE: CUSTOM_DUMPSOFTWAREVERSIONS
    //

    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

    //
    // MODULE: MultiQC
    //
    workflow_summary       = WorkflowMolkart.paramsSummaryMultiqc(workflow, summary_params)
    ch_workflow_summary    = Channel.value(workflow_summary)
    methods_description    = WorkflowMolkart.methodsDescriptionText(workflow, ch_multiqc_custom_methods_description, params)
    ch_methods_description = Channel.value(methods_description)

    ch_multiqc_files = Channel.empty()

    if ( params.create_training_subset ){
        ch_multiqc_files = ch_multiqc_files.mix(
            MOLKARTQCPNG.out.png_overview
            .collectFile(name: "crop_overview.png", storeDir: "${params.outdir}/multiqc" ))
        ch_multiqc_files = ch_multiqc_files.mix(
            CROPHDF5.out.crop_summary.map{it[1]}
            .collectFile(name: 'crop_overview.txt', storeDir: "${params.outdir}/multiqc")
        )
    } else {
        ch_multiqc_files = ch_multiqc_files.mix(
            MOLKARTQC.out.qc.map{it[1]}
            .collectFile(name: 'final_QC.all_samples.csv', keepHeader: true, storeDir: "${params.outdir}/multiqc"))
    }
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
