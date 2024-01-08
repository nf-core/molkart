#!/usr/bin/env python
import time
import argparse
from argparse import ArgumentParser as AP
from os.path import abspath
import argparse
import numpy as np
from skimage.measure import label, regionprops
from skimage.io import imread, imsave
from os.path import abspath
from argparse import ArgumentParser as AP
import time
import pandas as pd


def get_args():
    # Script description
    description = """Segmentation mask filtering"""

    # Add parser
    parser = AP(description=description, formatter_class=argparse.RawDescriptionHelpFormatter)

    # Sections
    inputs = parser.add_argument_group(title="Required Input", description="Path to required input file")
    inputs.add_argument("-r", "--input", dest="input", action="store", required=True, help="File path to input image.")
    inputs.add_argument("-o", "--output", dest="output", action="store", required=True, help="Path to output image.")
    inputs.add_argument(
        "--output_qc", dest="output_qc", action="store", required=False, help="Path to output qc csv file."
    )
    inputs.add_argument(
        "--min_area",
        dest="min_area",
        action="store",
        type=int,
        default=None,
        help="Lower area (in px) threshold for cell removal",
    )
    inputs.add_argument(
        "--max_area",
        dest="max_area",
        action="store",
        type=int,
        default=None,
        help="Upper area (in px) threshold for cell removal",
    )
    inputs.add_argument("--version", action="version", version="0.1.0")
    arg = parser.parse_args()

    # Standardize paths
    arg.input = abspath(arg.input)
    arg.output = abspath(arg.output)
    if arg.output_qc is None:
        arg.output_qc = abspath(arg.output.replace(".tif", ".csv"))
    return arg


def filter_areas(mask, min_area=None, max_area=None):
    labeled_mask = label(mask, background=0)
    measure_tmp = regionprops(labeled_mask)
    num_cells = len(measure_tmp)
    # Create a mapping between label and area
    label_area_map = {prop.label: prop.area for prop in measure_tmp}

    if min_area and max_area:
        small_valid_labels = np.array([label for label, area in label_area_map.items() if area >= min_area])
        large_valid_labels = np.array([label for label, area in label_area_map.items() if area <= max_area])
        valid_labels = np.intersect1d(small_valid_labels, large_valid_labels)
        retained_masks = np.isin(labeled_mask, valid_labels) * labeled_mask
        small_labels = num_cells - len(small_valid_labels)
        large_labels = num_cells - len(large_valid_labels)
        relabeled_mask = label(retained_masks, background=0)
    elif min_area:
        valid_labels = np.array([label for label, area in label_area_map.items() if area >= min_area])
        retained_masks = np.isin(labeled_mask, valid_labels) * labeled_mask
        large_labels = 0
        small_labels = num_cells - len(valid_labels)
        relabeled_mask = label(retained_masks, background=0)
    elif max_area:
        valid_labels = np.array([label for label, area in label_area_map.items() if area <= max_area])
        retained_masks = np.isin(labeled_mask, valid_labels) * labeled_mask
        large_labels = num_cells - len(valid_labels)
        small_labels = 0
        relabeled_mask = label(retained_masks, background=0)
    else:
        small_labels = 0
        large_labels = 0
        relabeled_mask = labeled_mask

    return relabeled_mask, small_labels, large_labels, num_cells


def main(args):
    print(f"Head directory = {args.input}")

    # Example usage
    in_path = args.input
    output = args.output
    min_area = args.min_area
    max_area = args.max_area

    mask = imread(in_path)
    mask, small, big, total = filter_areas(mask, min_area=min_area, max_area=max_area)
    imsave(output, mask.astype("int32"), check_contrast=False)
    print(f"Filtered mask saved to {output}")

    qc_df = pd.DataFrame(
        {
            "below_min_area": [small],
            "below_percentage": [small / total],
            "above_max_area": [big],
            "above_percentage": [big / total],
            "total_labels": [total],
        },
        index=None,
    )
    qc_df.to_csv(output.replace(".tif", ".csv"), index=False)
    print()


if __name__ == "__main__":
    # Read in arguments
    args = get_args()

    # Run script
    st = time.time()
    main(args)
    rt = time.time() - st
    print(f"Script finished in {rt // 60:.0f}m {rt % 60:.0f}s")
