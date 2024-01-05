process CROPTIFF {
    tag "$meta.id"
    label 'process_single'

    container 'ghcr.io/schapirolabor/molkart-local:v0.0.4'

    input:
    tuple val(meta), path(image_stack)
    tuple val(meta), path(crop_summary)

    output:
    tuple val(meta), path("*.tiff"), emit: crop_tiff
    tuple val(meta), path("*.png") , emit: overview
    path "versions.yml"            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args   ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    crop_tiff.py \\
        --input $image_stack \\
        --crop_summary $crop_summary \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        molkart_croptiff: \$(crop_tiff.py --version)
    END_VERSIONS
    """
}
