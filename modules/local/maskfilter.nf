process MASKFILTER {
    tag "$meta.id"
    label 'process_single'

    container 'ghcr.io/schapirolabor/background_subtraction:v0.4.1'

    input:
    tuple val(meta), path(mask)

    output:
    tuple val(meta), path("*.tif"), emit: filtered_mask
    tuple val(meta), path("*.csv"), emit: filtered_qc
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    maskfilter.py \\
        --input ${mask} \\
        --output ${prefix}.tif \\
        --output_qc ${prefix}.csv \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        molkart_maskfilter: \$(maskfilter.py --version)
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    touch ${prefix}.tif

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        molkart_maskfilter: \$(maskfilter.py --version)
    END_VERSIONS
    """
}
