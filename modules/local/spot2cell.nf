process SPOT2CELL{
    debug true
    tag "$meta.id"
    label 'process_single'

    container 'ghcr.io/schapirolabor/molkart-local:v0.0.4'

    input:
    tuple val(meta) , path(spot_table)
    tuple val(meta2), path(cell_mask)

    output:
    tuple val(meta), path("*.csv"), emit: cellxgene_table
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args   ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    spot2cell.py \\
        --spot_table ${spot_table} \\
        --cell_mask ${cell_mask} \\
        --output ${prefix}.csv \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        molkart_spot2cell: \$(spot2cell.py --version)
    END_VERSIONS
    """
}
