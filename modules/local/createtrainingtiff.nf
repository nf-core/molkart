process CREATETRAININGTIFF {
    tag "$meta.id"
    label 'process_single'

    container 'docker.io/labsyspharm/mcmicro-ilastik:1.6.1'

    input:
    tuple val(meta), path(image_stack)
    tuple val(meta), path(crop_summary)

    output:
    tuple val(meta), path("*crop*.tiff"),        emit: crop_tiff
    tuple val(meta), path("*crop_overview.png"), emit: overview

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    crop_tiff.py --input $image_stack --crop_summary $crop_summary
    """
}
