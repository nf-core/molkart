process CLAHE{
    debug false
    tag "$meta.id"
    label 'process_low'

    container 'ghcr.io/schapirolabor/background_subtraction:v0.3.3'

    input:
    tuple val(meta), path(image)

    output:
    tuple val(meta), path("*.tiff") , emit: img_clahe
    path "versions.yml"             , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    apply_clahe.dask.py \\
        --input ${image} \\
        --output ${prefix}.tiff \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        molkart_clahe: \$(apply_clahe.dask.py --version)
    END_VERSIONS
    """

}
