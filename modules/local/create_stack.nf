process CREATE_STACK {
    tag "Stacking channels for $meta.id"

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
        --output ${meta.id}.stack.ome.tif \\
        --num-channels 2
    """
}
