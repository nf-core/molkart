process TIFFH5CONVERT {
    tag 'Converting tiff to h5'
    label 'process_single'

    container "docker.io/labsyspharm/mcmicro-ilastik:1.6.1"

    input:
    tuple val(meta), path(image)
    val(channel_ids)

    output:
    tuple val(meta), path("${meta.id}.stack.*.hdf5"), emit: hdf5
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    python /app/CommandIlastikPrepOME.py \
        --input $image \
        --output . \
        --channelIDs $channel_ids
    """
}
