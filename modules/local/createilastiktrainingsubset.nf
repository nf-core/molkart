process CREATEILASTIKTRAININGSUBSET {
    tag "$meta.id"
    label 'process_single'

    container 'docker.io/labsyspharm/mcmicro-ilastik:1.6.1'

    input:
    tuple val(meta), path(image_stack)

    output:
    tuple val(meta), path("*crop*.hdf5")        , emit: ilastik_training
    tuple val(meta), path("*_CropSummary.txt")  , emit: crop_summary

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args   ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    python /app/CommandIlastikPrepOME.py \
        --input $image_stack \
        --output . \
        --num_channels 2 \
        $args
    """
}
