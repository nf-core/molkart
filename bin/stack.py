#!/usr/bin/env python
import numpy as np
import argparse
import tifffile
import dask.array as da
from argparse import ArgumentParser as AP
import palom.pyramid
import palom.reader
import copy
import math
import time


def get_args():
    parser = AP(description="Stack a list of images into a single image stack using Dask")
    parser.add_argument("-i", "--input", nargs="+", help="List of images to stack")
    parser.add_argument("-o", "--output", dest="output", type=str)
    parser.add_argument("--pixel_size", dest="pixel_size", type=float, default=0.138)
    parser.add_argument("--tile_size", dest="tilesize", type=int, default=1072)
    parser.add_argument("--version", action="version", version="0.1.0")
    return parser.parse_args()


def num_levels_patch(self, base_shape):
    factor = max(base_shape) / self.max_pyramid_img_size
    return math.ceil(math.log(max(1, factor), self.downscale_factor)) + 1


def main(args):
    img = palom.reader.OmePyramidReader(args.input[0])
    mosaic = img.pyramid[0]
    mosaic_out = copy.copy(mosaic)

    for i in range(1, len(args.input)):
        img = palom.reader.OmePyramidReader(args.input[i])
        mosaic = img.pyramid[0]
        mosaic_out = da.concatenate([mosaic_out, copy.copy(mosaic)], axis=0)

    palom.pyramid.PyramidSetting.num_levels = num_levels_patch
    palom.pyramid.write_pyramid(
        [mosaic_out], args.output, channel_names=["stack"], downscale_factor=2, pixel_size=0.138, tile_size=368
    )


if __name__ == "__main__":
    # Read in arguments
    args = get_args()

    # Run script
    st = time.time()
    main(args)
    rt = time.time() - st
    print(f"Script finished in {rt // 60:.0f}m {rt % 60:.0f}s")
