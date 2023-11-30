#!/usr/bin/env python
from __future__ import print_function, division
from distutils.log import error
import time
import argparse
from argparse import ArgumentParser as AP
from os.path import abspath
import os
import numpy as np
import tifffile as tf
from skimage.exposure import equalize_adapthist
from multiprocessing.spawn import import_main_path
import sys
import copy
import argparse
import numpy as np
import tifffile
import zarr
import skimage.transform
from aicsimageio import aics_image as AI
from ome_types import from_tiff, to_xml
from os.path import abspath
from argparse import ArgumentParser as AP
import time

# from memory_profiler import profile
# This API is apparently changing in skimage 1.0 but it's not clear to
# me what the replacement will be, if any. We'll explicitly import
# this so it will break loudly if someone tries this with skimage 1.0.
try:
    from skimage.util.dtype import _convert as dtype_convert
except ImportError:
    from skimage.util.dtype import convert as dtype_convert


def get_args():
    # Script description
    description = """Easy-to-use, large scale CLAHE"""

    # Add parser
    parser = AP(description=description, formatter_class=argparse.RawDescriptionHelpFormatter)

    # Sections
    inputs = parser.add_argument_group(title="Required Input", description="Path to required input file")
    inputs.add_argument("-r", "--input", dest="input", action="store", required=True, help="File path to input image.")
    inputs.add_argument("-o", "--output", dest="output", action="store", required=True, help="Path to output image.")
    inputs.add_argument(
        "--cliplimit", dest="clip", action="store", required=True, type=float, default=0.01, help="Clip Limit for CLAHE"
    )
    inputs.add_argument(
        "--kernel", dest="kernel", action="store", required=False, type=int, default=25, help="Kernel size for CLAHE"
    )
    inputs.add_argument(
        "--nbins", dest="nbins", action="store", required=False, type=int, default=256, help="Number of bins for CLAHE"
    )
    inputs.add_argument(
        "-p", "--pixel-size", dest="pixel_size", action="store", type=float, required=False, help="Image pixel size"
    )
    inputs.add_argument(
        "--tile-size",
        dest="tile_size",
        action="store",
        type=int,
        default=1072,
        help="Tile size for pyramid generation (must be divisible by 16)",
    )
    inputs.add_argument("--version", action="version", version="0.1.0")
    arg = parser.parse_args()

    # Standardize paths
    arg.input = abspath(arg.input)
    arg.clip = float(arg.clip)
    arg.pixel_size = float(arg.pixel_size)
    arg.nbins = int(arg.nbins)
    arg.kernel = int(arg.kernel)

    return arg


def preduce(coords, img_in, img_out):
    print(img_in.dtype)
    (iy1, ix1), (iy2, ix2) = coords
    (oy1, ox1), (oy2, ox2) = np.array(coords) // 2
    tile = skimage.img_as_float32(img_in[iy1:iy2, ix1:ix2])
    tile = skimage.transform.downscale_local_mean(tile, (2, 2))
    tile = dtype_convert(tile, "uint16")
    # tile = dtype_convert(tile, img_in.dtype)
    img_out[oy1:oy2, ox1:ox2] = tile


def format_shape(shape):
    return "%dx%d" % (shape[1], shape[0])


def subres_tiles(level, level_full_shapes, tile_shapes, outpath, scale):
    print(f"\n processing level {level}")
    assert level >= 1
    num_channels, h, w = level_full_shapes[level]
    tshape = tile_shapes[level] or (h, w)
    tiff = tifffile.TiffFile(outpath)
    zimg = zarr.open(tiff.aszarr(series=0, level=level - 1, squeeze=False))
    for c in range(num_channels):
        sys.stdout.write(f"\r  processing channel {c + 1}/{num_channels}")
        sys.stdout.flush()
        th = tshape[0] * scale
        tw = tshape[1] * scale
        for y in range(0, zimg.shape[1], th):
            for x in range(0, zimg.shape[2], tw):
                a = zimg[c, y : y + th, x : x + tw, 0]
                a = skimage.transform.downscale_local_mean(a, (scale, scale))
                if np.issubdtype(zimg.dtype, np.integer):
                    a = np.around(a)
                a = a.astype("uint16")
                yield a


def detect_pixel_size(img_path, pixel_size=None):
    if pixel_size is None:
        print("Pixel size overwrite not specified")
        try:
            metadata = ome_types.from_tiff(img_path)
            pixel_size = metadata.images[0].pixels.physical_size_x
        except Exception as err:
            print(err)
            print("Pixel size detection using ome-types failed")
            pixel_size = None
    return pixel_size


def main(args):
    _version = "0.1.0"
    print(f"Head directory = {args.input}")
    print(f"ClipLimit = {args.clip}, nbins = {args.nbins}, kernel_size = {args.kernel}, pixel_size = {args.pixel_size}")

    # clahe = cv2.createCLAHE(clipLimit = int(args.clip), tileGridSize=tuple(map(int, args.grid)))

    img_in = AI.AICSImage(args.input)
    img_dask = img_in.get_image_dask_data("CYX").astype("uint16")
    adapted = img_dask[0].compute() / 65535
    adapted = (
        equalize_adapthist(adapted, kernel_size=args.kernel, clip_limit=args.clip, nbins=args.nbins) * 65535
    ).astype("uint16")
    img_dask[0] = adapted

    # construct levels
    tile_size = args.tile_size
    scale = 2
    pixel_size = detect_pixel_size(args.input, args.pixel_size)
    if pixel_size is None:
        pixel_size = 1

    dtype = img_dask.dtype
    base_shape = img_dask[0].shape
    num_channels = img_dask.shape[0]
    num_levels = (np.ceil(np.log2(max(1, max(base_shape) / tile_size))) + 1).astype(int)
    factors = 2 ** np.arange(num_levels)
    shapes = (np.ceil(np.array(base_shape) / factors[:, None])).astype(int)

    print("Pyramid level sizes: ")
    for i, shape in enumerate(shapes):
        print(f"   level {i+1}: {format_shape(shape)}", end="")
        if i == 0:
            print("(original size)", end="")
        print()
    print()
    print(shapes)

    level_full_shapes = []
    for shape in shapes:
        level_full_shapes.append((num_channels, shape[0], shape[1]))
    level_shapes = shapes
    tip_level = np.argmax(np.all(level_shapes < tile_size, axis=1))
    tile_shapes = [(tile_size, tile_size) if i <= tip_level else None for i in range(len(level_shapes))]

    software = f"molkart_clahe {_version}"
    pixel_size = pixel_size
    metadata = {
        "Creator": software,
        "Pixels": {
            "PhysicalSizeX": pixel_size,
            "PhysicalSizeXUnit": "\u00b5m",
            "PhysicalSizeY": pixel_size,
            "PhysicalSizeYUnit": "\u00b5m",
        },
    }

    # write pyramid
    with tifffile.TiffWriter(args.output, ome=True, bigtiff=True) as tiff:
        tiff.write(
            data=img_dask,
            metadata=metadata,
            shape=level_full_shapes[0],
            subifds=int(num_levels - 1),
            dtype=dtype,
            resolution=(10000 / pixel_size, 10000 / pixel_size, "centimeter"),
            tile=tile_shapes[0],
        )
        for level, (shape, tile_shape) in enumerate(zip(level_full_shapes[1:], tile_shapes[1:]), 1):
            tiff.write(
                data=subres_tiles(level, level_full_shapes, tile_shapes, args.output, scale),
                shape=shape,
                subfiletype=1,
                dtype=dtype,
                tile=tile_shape,
            )
    print()


if __name__ == "__main__":
    # Read in arguments
    args = get_args()

    # Run script
    st = time.time()
    main(args)
    rt = time.time() - st
    print(f"Script finished in {rt // 60:.0f}m {rt % 60:.0f}s")
