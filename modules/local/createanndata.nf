process CREATE_ANNDATA {
    tag "$meta.id"
    label 'process_low'

    container 'ghcr.io/schapirolabor/molkart-local:v0.0.4'

    input:
    tuple val(meta), path(spot2cell)

    output:
    tuple val(meta), path("*.adata") , emit: stack
    path "versions.yml"              , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args   ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    create_anndata.py \\
        --input ${spot2cell} \\
        --spatial_cols X_centroid Y_centroid \\
        --output ${prefix}.adata \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        molkart_createanndata: \$(create_anndata.py --version)
    END_VERSIONS
    """
}
