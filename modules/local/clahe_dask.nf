process CLAHE_DASK{
    debug false
    tag "Applying CLAHE to $meta.id"

    container 'ghcr.io/schapirolabor/background_subtraction:v0.3.3'

    input:
    tuple val(meta), path(image)

    output:
    tuple val(meta), path("*.clahe.tiff") , emit: img_clahe

    script:
    """
    apply_clahe.dask.py \
    --raw ${image} \
    --output ${image.baseName}.clahe.tiff \
    --cliplimit 0.01 \
    --kernel 25 \
    --nbins 256 \
    --channel 0 \
    --pixel-size 0.138
    """

}
