process CREATE_STACK {
    tag "$meta.id"
    label 'process_low'

    container 'ghcr.io/schapirolabor/molkart-local:v0.0.4'

    input:
    tuple val(meta), path(image)

    output:
    tuple val(meta), path("*.ome.tif") , emit: stack
    path "versions.yml"                , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args   ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    stack.py \\
        --input ${image} \\
        --output ${prefix}.ome.tif \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        molkart_stack: \$(stack.py --version)
    END_VERSIONS
    """
}
