process SPOT2CELL{
    debug true
    tag "Assigning spots to cells for $meta.id"
    label 'process_single'

    container 'ghcr.io/schapirolabor/background_subtraction:v0.3.3'

    input:
    tuple val(meta) , path(spot_table)
    tuple val(meta2), path(cell_mask)

    output:
    tuple val(meta), path("*cellxgene.tsv"), emit: cellxgene_table

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    spot2cell.py \
    --spot_table ${spot_table} \
    --cell_mask ${cell_mask}
    """
}
