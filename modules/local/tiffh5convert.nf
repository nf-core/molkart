process TIFFH5CONVERT {
    tag "$meta.id"
    label 'process_single'

    container "ghcr.io/schapirolabor/molkart-local:v0.0.4"

    input:
    tuple val(meta), path(image), val(num_channels)

    output:
    tuple val(meta), path("*.hdf5"), emit: hdf5
    path "versions.yml"            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args   ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    crop_hdf5.py \\
        --input $image \\
        --output . \\
        --num_channels $num_channels \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        molkart_crophdf5: \$(crop_hdf5.py --version)
    END_VERSIONS
    """
}
