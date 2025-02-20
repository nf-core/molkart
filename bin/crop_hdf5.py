#!/usr/bin/env python3
## Written by Kresimir Bestak and Florian Wuennemann and released under the MIT license
import tifffile
import numpy as np
import h5py
import pathlib
import os
import random
from skimage import filters
import scipy.io
import math
import argparse
import time

# Most of the code by Joshua Hess from the labsyspharm/mcmicro-ilastik repo: https://github.com/labsyspharm/mcmicro-ilastik


def IlastikPrepOME(
    input, output, crop, crop_size, nonzero_fraction, nuclei_index, num_channels, channelIDs, ring_mask, crop_amount
):
    """Function for exporting a large ome.tiff image as an hdf5 image for
    training ilastik random forest pixel classifier for cell segmentation"""

    # Create a pathlib object for the image name
    im_name = pathlib.Path(input)
    # Get the input directory
    im_dir = im_name.parent
    # Get the image name (remove ".ome")
    im_stem = im_name.stem.replace(".ome", "")
    # Create hdf5 name
    h5_name = im_stem + ".hdf5"

    # Check to see if ring mask is being applied
    if ring_mask:
        # Read the matlab file
        mat = scipy.io.loadmat(os.path.join(str(im_dir), (str(im_stem) + "-ROI-nodes.mat")))
        # Get the width and height indices for cropping
        min_w, max_w = math.floor(abs(mat["nodes"][:, 0]).min()), math.ceil(abs(mat["nodes"][:, 0]).max())
        min_h, max_h = math.floor(abs(mat["nodes"][:, 1]).min()), math.ceil(abs(mat["nodes"][:, 1]).max())

    # Check to see if the num_channels exists
    if num_channels == None and channelIDs == None:
        # raise an error
        raise ValueError("--num_channels and --channelIDs are not specified")

    # Otherwise continue
    else:
        # Condition 1
        if num_channels == None and channelIDs != None:
            # Set number of channels to length of channel IDs
            num_channels = len(channelIDs)
        # Check if number of channels and channelIDs agree
        elif num_channels != None and channelIDs == None:
            # Set channelIDs to be first n channels for num_channels
            channelIDs = range(0, num_channels)
        # infer the number of channels give the channel IDs
        else:
            # Check that the two agree
            if num_channels != len(channelIDs):
                # raise error
                raise ValueError("--num_channels and length of --channelIDs do not agree")

    # Check if the number of channels is even or odd
    if (num_channels % 2) == 0:
        step = 2
    else:
        step = 1

    # Read the tif image - Reads the image as cyx
    print("Reading " + im_name.stem + "...")
    tif = tifffile.TiffFile(im_name)
    # Set the index for the loop
    idx = 0
    # Add counter for channel index
    chan_idx = 0
    for i in range(int(num_channels / step)):
        # Get the channel indices based on the step
        chan_idx = channelIDs[idx : idx + step]
        # Convert the tifffile object to array
        im = tif.asarray(series=0, key=chan_idx)
        # Check to see what step size is (if step is 1, tiffile will not read color channel, only width and height)
        if step != 1:
            # Swap the axes to be in the order zyxc for ilastik
            im = np.swapaxes(im, 0, 2)
            # Swap the axes to be in the order zyxc for ilastik
            im = np.swapaxes(im, 0, 1)
        # Check if step size is 1 or two (again, if 1, then no color channel)
        if step != 1:
            # Reshape the array
            im = im.reshape((1, im.shape[0], im.shape[1], im.shape[2]))
        else:
            # Add a color axis when reshaping instead
            im = im.reshape((1, im.shape[0], im.shape[1], 1))
        # Check to see if ring mask is being applied
        if ring_mask:
            # Crop the region
            im = im[:, min_h:max_h, min_w:max_w, :]
        # Create an hdf5 dataset if idx is 0 plane
        if idx == 0:
            # Create hdf5
            h5 = h5py.File(pathlib.Path(os.path.join(output, h5_name)), "w")
            h5.create_dataset(str(im_stem), data=im[:, :, :, :], chunks=True, maxshape=(1, None, None, None))
            h5.close()
        else:
            # Append hdf5 dataset
            h5 = h5py.File(pathlib.Path(os.path.join(output, h5_name)), "a")
            # Add step size to the z axis
            h5[str(im_stem)].resize((idx + step), axis=3)
            # Add the image to the new channels
            h5[str(im_stem)][:, :, :, idx : idx + step] = im[:, :, :, :]
            h5.close()
        # Update the index
        idx = idx + step
    # Finished exporting the image
    print("Finished exporting image")

    # Optional to crop out regions for ilastik training
    if crop:
        # Get the index of nuclei in channelIDs
        nuclei_index = channelIDs.index(nuclei_index)
        # Run through each cropping iteration
        full_h5 = h5py.File(pathlib.Path(os.path.join(output, h5_name)), "r")
        im_nuc = full_h5[str(im_stem)][:, :, :, nuclei_index]
        im = full_h5[str(im_stem)][:, :, :, :]
        indices = {}
        count = 0
        thresh = filters.threshold_otsu(im_nuc[:, :, :])
        while count < crop_amount:
            # Get random height value that falls within crop range of the edges
            extension_h = crop_size[0] // 2
            h = random.randint(extension_h, im_nuc.shape[1] - extension_h)
            h_up, h_down = h - extension_h, h + extension_h
            # Get random width value that falls within crop range of the edges
            extension_w = crop_size[1] // 2
            w = random.randint(extension_w, im_nuc.shape[2] - extension_w)
            w_lt, w_rt = w - extension_w, w + extension_w
            # Crop the image with these coordinates expanding from center
            crop = im_nuc[:, h_up:h_down, w_lt:w_rt]
            crop_name = pathlib.Path(os.path.join(output, (im_stem + "_crop" + str(count) + ".hdf5")))
            # Check to see if the crop passes the nonzero fraction test
            if ((crop[0, :, :] > thresh).sum() / (crop.shape[1] * crop.shape[2])) >= nonzero_fraction:
                # Export the image to hdf5
                print("Writing " + crop_name.stem + ".hdf5...")
                crop = im[:, h_up:h_down, w_lt:w_rt, :]
                h5_crop = h5py.File(crop_name, "w")
                h5_crop.create_dataset(str(im_stem) + "_" + str(count), data=crop, chunks=True)
                h5_crop.close()
                print("Finished exporting " + crop_name.stem + ".hdf5")
                # Add one to the counter
                count = count + 1
                # Add the indices to a table to store the cropped indices
                indices.update({crop_name.stem: [(h_up, h_down), (w_lt, w_rt)]})
        # Export the indices to a text file to track the cropped regions
        summary = open(pathlib.Path(os.path.join(output, im_stem) + "_CropSummary.txt"), "w")
        summary.write(str(indices))
        summary.close()


def MultiIlastikOMEPrep(
    input, output, crop, crop_size, nonzero_fraction, nuclei_index, num_channels, channelIDs, ring_mask, crop_amount
):
    """Function for iterating over a list of files and output locations to
    export large ome.tiff images in the correct hdf5 image format for ilastik
    random forest pixel classification and batch processing"""

    # Iterate over each image in the list if only a single output
    if len(output) < 2:
        # Iterate through the images and export to the same location
        for im_name in input:
            # Run the IlastikPrepOME function for this image
            IlastikPrepOME(
                im_name,
                output[0],
                crop,
                crop_size,
                nonzero_fraction,
                nuclei_index,
                num_channels,
                channelIDs,
                ring_mask,
                crop_amount,
            )
    # Alternatively, iterate over output directories
    else:
        # Check to make sure the output directories and image paths are equal in length
        if len(output) != len(input):
            raise (ValueError("Detected more than one output but not as many directories as images"))
        else:
            # Iterate through images and output directories
            for i in range(len(input)):
                # Run the IlastikPrepOME function for this image and output directory
                IlastikPrepOME(
                    input[i],
                    output[i],
                    crop,
                    crop_size,
                    nonzero_fraction,
                    nuclei_index,
                    num_channels,
                    channelIDs,
                    ring_mask,
                    crop_amount,
                )


def ParseInputOME():
    """Function for parsing command line arguments for input to ilastik prep functions"""
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--input",
        nargs="*",
        help="enter path to images with spaces between each image (Ex: /path1/image1.ome.tiff /path2/image2.ome.tiff)",
    )
    parser.add_argument("--output", nargs="*")
    parser.add_argument("--crop", action="store_true", default=False)
    parser.add_argument("--no-crop", dest="crop", action="store_false")
    parser.add_argument("--crop_size", type=int, nargs="*")
    parser.add_argument("--nonzero_fraction", type=float)
    parser.add_argument("--nuclei_index", type=int)
    parser.add_argument("--num_channels", type=int)
    parser.add_argument("--channelIDs", type=int, nargs="*")
    parser.add_argument("--ring_mask", action="store_true", default=False)
    parser.add_argument("--no-ring_mask", dest="ring_mask", action="store_false")
    parser.add_argument("--crop_amount", type=int)
    parser.add_argument("--version", action="version", version="0.1.0")

    args = parser.parse_args()

    # Adjustment to account for user-facing 1-based indexing and the 0-based Python implementation
    if args.nuclei_index != None:
        nuc_idx = args.nuclei_index - 1
    else:
        nuc_idx = None
    if args.channelIDs != None:
        chIDs = [x - 1 for x in args.channelIDs]
    else:
        chIDs = None

    # Create a dictionary object to pass to the next function
    dict = {
        "input": args.input,
        "output": args.output,
        "crop": args.crop,
        "crop_size": args.crop_size,
        "nonzero_fraction": args.nonzero_fraction,
        "nuclei_index": nuc_idx,
        "num_channels": args.num_channels,
        "channelIDs": chIDs,
        "ring_mask": args.ring_mask,
        "crop_amount": args.crop_amount,
    }
    # Print the dictionary object
    print(dict)
    # Return the dictionary
    return dict


if __name__ == "__main__":
    # Parse the command line arguments
    args = ParseInputOME()

    # Run script
    st = time.time()
    # Run the MultiIlastikOMEPrep function
    MultiIlastikOMEPrep(**args)
    rt = time.time() - st
    print(f"Script finished in {rt // 60:.0f}m {rt % 60:.0f}s")
