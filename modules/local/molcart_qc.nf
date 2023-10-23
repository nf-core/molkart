process MOLCART_QC{
    tag "${meta.id}"
    container 'docker.io/wuennemannflorian/project_spots:latest'
    label 'process_single'

    input:
    tuple val(meta), path(mcquant)
    tuple val(meta2), path(spot_table)
    val(segmethod)

    output:
    path("*.csv"), emit: qc

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def sample_id = "${meta.id}"
    """
    collect_QC.py \
        --mcquant $mcquant \
        --spots $spot_table \
        --sample_id $sample_id \
        --segmentation_method $segmethod \
        --outdir .
    """
}
