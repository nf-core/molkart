process CREATE_STACK {
    tag "$meta.id"
    label 'process_low'

    container 'ghcr.io/schapirolabor/background_subtraction:v0.3.3'

    input:
    tuple val(meta), path(image)

    output:
    tuple val(meta), path("*.ome.tif"), emit: stack

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    create_stack.py \\
        --input ${image} \\
        --output ${prefix}.ome.tif \\
        --num-channels 2 \\
        $args
    """
}
