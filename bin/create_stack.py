#!/usr/bin/env python

### This script takes a list of images and stacks them into a single image stack using Dask

import numpy as np
import argparse
import tifffile
from aicsimageio.writers import OmeTiffWriter
from aicsimageio import aics_image as AI
import aicsimageio
import dask
import dask.array as da


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("-i", "--input", nargs="+", help="List of images to stack")
    parser.add_argument(
        "-o",
        "--output",
        dest="output",
        type=str,
    )
    parser.add_argument("--num-channels", dest="num_channels", type=int)

    args = parser.parse_args()

    channel_counter = 0

    img = AI.AICSImage(args.input[0]).get_image_dask_data("CYX")
    out = da.empty(shape=[args.num_channels, img[0].shape[0], img[0].shape[1]])
    print(out.shape)
    if img.shape[0] > 1:
        for channel in range(img.shape[0]):
            out[channel_counter] = img[channel]
            channel_counter += 1
    else:
        out[channel_counter] = img[0]
        channel_counter += 1

    if len(args.input) > 1:
        for i in range(len(args.input[1:])):
            img = AI.AICSImage(args.input[1 + i]).get_image_dask_data("CYX")
            if img.shape[0] > 1:
                for channel in range(img.shape[0]):
                    out[channel_counter] = img[channel]
                    channel_counter += 1
            else:
                out[channel_counter] = img[0]
                channel_counter += 1

    OmeTiffWriter.save(out, args.output, dim_order="CYX")


if __name__ == "__main__":
    main()
