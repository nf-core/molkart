process MOLKARTQCPNG {
    label 'process_single'

    container 'ghcr.io/schapirolabor/molkart-local:v0.0.4'

    input:
    path(png)

    output:
    path("*.png")      , emit: png_overview
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    """
    collect_QC.py \\
        --png_overview $png \\
        --outdir . \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        molkartqc: \$(collect_QC.py --version)
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    touch ${prefix}.png

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        molkartqc: \$(collect_QC.py --version)
    END_VERSIONS
    """
}
