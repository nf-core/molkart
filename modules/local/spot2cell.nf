process SPOT2CELL{
    debug true
    tag "Assigning spots to cells for $meta.id"
    label 'process_single'

    container 'ghcr.io/schapirolabor/background_subtraction:v0.3.3'

    input:
    tuple val(meta) , path(spot_table)
    tuple val(meta2), path(cell_mask)
    val(tag)

    output:
    tuple val(meta), path("*.csv"), emit: cellxgene_table

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: tag ? "${meta.id}_${tag}" : "${meta.id}"

    """
    spot2cell.py \
        --spot_table ${spot_table} \
        --cell_mask ${cell_mask} \
        --tag ${tag} \
        --output ${prefix}.csv
    """
}
