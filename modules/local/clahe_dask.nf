process CLAHE_DASK{
    debug false
    tag "Applying CLAHE to $meta.id"

    container 'ghcr.io/schapirolabor/background_subtraction:v0.3.3'

    input:
    tuple val(meta), path(image)

    output:
    tuple val(meta), path("*.clahe.tiff") , emit: img_clahe

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}_${meta.stain}"
    """
    apply_clahe.dask.py \\
        --raw ${image} \\
        --output ${prefix}.clahe.tiff \\
        $args
    """

}
