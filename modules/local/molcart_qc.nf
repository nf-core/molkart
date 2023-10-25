process MOLCART_QC{
    tag "${meta.id}"
    container 'docker.io/wuennemannflorian/project_spots:latest'
    label 'process_single'

    input:
    tuple val(meta), path(cellxgene_table)
    tuple val(meta2), path(spot_table)
    tuple val(meta3), val(segmethod)

    output:
    tuple val(meta), path("*.csv"), emit: qc

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def sample_id = "${meta.id}"
    """
    collect_QC.py \
        --cellxgene $cellxgene_table \
        --spots $spot_table \
        --sample_id $sample_id \
        --segmentation_method $segmethod \
        --outdir .
    """
}
