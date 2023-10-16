#!/usr/bin/env python3
# importing the module
import ast
import tifffile as tiff
import os
import argparse
import matplotlib.pyplot as plt
import numpy as np


# Create a function to create crops from a tiff image and a dictionary of crop coordinates
def create_crops(tiff_image, crop_dict):
    for index, (crop_name, crop) in enumerate(crop_dict.items()):
        crop_image = tiff_image[:, crop[0][0] : crop[0][1], crop[1][0] : crop[1][1]]
        basename = os.path.basename(args.input)
        basename = os.path.splitext(basename)[0]
        tiff.imsave(f"./{basename}_crop{index}.tiff", crop_image)
        ## Create a plot with all crop regions highlighted on the full image for easier selection
        # Create a maximum projection of the channels in tiff_image
        tiff_image_max = np.max(tiff_image, axis=0)
        plt.imshow(tiff_image_max, cmap="gray")
        plt.plot(
            [crop[1][0], crop[1][1], crop[1][1], crop[1][0], crop[1][0]],
            [crop[0][0], crop[0][0], crop[0][1], crop[0][1], crop[0][0]],
            "red",
            linewidth=1,
        )
        plt.text(
            crop[1][0], crop[0][0], str(index), color="white"
        )  # make the text red and add a label to each box with index of the crop
    plt.savefig(f"{basename}.crop_overview.png", dpi=300)


## Run the script
if __name__ == "__main__":
    # Add argument parser with arguments for input tiffile, crop_summary input file and output tiffile
    parser = argparse.ArgumentParser()
    parser.add_argument("-i", "--input", help="Input tiffile.")
    parser.add_argument("-c", "--crop_summary", help="Crop summary file.")
    args = parser.parse_args()

    # reading the crop information from the file
    with open(args.crop_summary) as f:
        crops = f.read()
    # reconstructing the data as a dictionary
    crops = ast.literal_eval(crops)
    ## Read in tiff image
    tiff_image = tiff.imread(args.input)
    if len(tiff_image.shape) == 2:
        tiff_image = np.expand_dims(tiff_image, axis=0)

    create_crops(tiff_image, crops)
