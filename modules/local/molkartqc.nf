process MOLKARTQC{
    tag "$meta.id"
    label 'process_single'

    container 'ghcr.io/schapirolabor/molkart-local:v0.0.4'

    input:
    tuple val(meta), path(spot_table), path(cellxgene_table), val(segmethod), path(filterqc)

    output:
    tuple val(meta), path("*.csv"), emit: qc
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args   ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    collect_QC.py \\
        --cellxgene $cellxgene_table \\
        --spots $spot_table \\
        --sample_id $prefix \\
        --segmentation_method $segmethod \\
        --filterqc $filterqc \\
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
    touch ${prefix}.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        molkartqc: \$(collect_QC.py --version)
    END_VERSIONS
    """
}
