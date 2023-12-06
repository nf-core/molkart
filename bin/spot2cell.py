#!/usr/bin/env python

## Import packages
import pandas as pd
import numpy as np
from skimage.measure import regionprops_table
import tifffile as tiff
import argparse
import os


def assign_spots2cell(spot_table, cell_mask):
    # Initialize a dictionary to hold the counts
    gene_counts = {}

    # Calculate cell properties for cell_mask using regionprops_table
    cell_props = regionprops_table(
        cell_mask,
        properties=[
            "label",
            "centroid",
            "area",
            "major_axis_length",
            "minor_axis_length",
            "eccentricity",
            "solidity",
            "extent",
            "orientation",
        ],
    )

    # Turn cell props into a pandas DataFrame and add a Cell_ID column
    name_map = {
        "CellID": "label",
        "X_centroid": "centroid-1",
        "Y_centroid": "centroid-0",
        "Area": "area",
        "MajorAxisLength": "major_axis_length",
        "MinorAxisLength": "minor_axis_length",
        "Eccentricity": "eccentricity",
        "Solidity": "solidity",
        "Extent": "extent",
        "Orientation": "orientation",
    }

    for new_name, old_name in name_map.items():
        cell_props[new_name] = cell_props[old_name]

    for old_name in set(name_map.values()):
        del cell_props[old_name]

    cell_props = pd.DataFrame(cell_props)

    # Exclude any rows that contain Duplicated in the gene column from spot_table
    spot_table = spot_table[~spot_table["gene"].str.contains("Duplicated")]

    # Iterate over each row in the grouped DataFrame
    for index, row in spot_table.iterrows():
        # Get the x and y positions and gene
        x = int(row["x"])
        y = int(row["y"])
        gene = row["gene"]

        # Get the cell ID from the labeled mask
        cell_id = cell_mask[y, x]

        # If the cell ID is not in the dictionary, add it
        if cell_id not in gene_counts:
            gene_counts[cell_id] = {}
            if gene not in gene_counts[cell_id]:
                gene_counts[cell_id][gene] = 1
            else:
                gene_counts[cell_id][gene] += 1
        else:
            if gene not in gene_counts[cell_id]:
                gene_counts[cell_id][gene] = 1
            else:
                # Add the count for this gene in this cell ID
                gene_counts[cell_id][gene] += 1

    # Convert the dictionary of counts into a DataFrame
    gene_counts_df = pd.DataFrame(gene_counts).T

    # Add a column to gene_counts_df for the Cell_ID, make it the first column of the table
    gene_counts_df["CellID"] = gene_counts_df.index

    # Add the regionprops data from cell_props for each cell ID to gene_counts_df add NA when cell_ID exists in cell_props but not in gene_counts_df
    gene_counts_df = gene_counts_df.merge(cell_props, on="CellID", how="outer")

    # Convert NaN values to 0
    gene_counts_df = gene_counts_df.fillna(0)

    # Sort by Cell_ID in ascending order
    gene_counts_df = gene_counts_df.sort_values(by=["CellID"])

    # Make Cell_ID the first column in gene_counts_df
    gene_counts_df = gene_counts_df.set_index("CellID").reset_index()

    gene_counts_df[spot_table.gene.unique()] = gene_counts_df[spot_table.gene.unique()].astype(int)

    # Filter out cell_ID = 0 into it's own dataframe called background
    background = gene_counts_df[gene_counts_df["CellID"] == 0]
    gene_counts_df = gene_counts_df[gene_counts_df["CellID"] != 0]

    # Return both gene_counts_df and background
    return gene_counts_df, background


if __name__ == "__main__":
    # Add a python argument parser with options for input, output and image size in x and y
    parser = argparse.ArgumentParser()
    parser.add_argument("-s", "--spot_table", help="Spot table to project.")
    parser.add_argument("-c", "--cell_mask", help="Sample ID.")
    parser.add_argument("--tag", type=str, help="Additional tag to append to filename")
    parser.add_argument("--output", type=str, help="Output path")
    parser.add_argument("--version", action="version", version="0.1.0")

    args = parser.parse_args()

    ## Read in spot table
    spot_data = pd.read_csv(
        args.spot_table, names=["x", "y", "z", "gene", "empty"], sep="\t", header=None, index_col=None
    )

    cell_mask = tiff.imread(args.cell_mask)

    gene_counts_df, background = assign_spots2cell(spot_data, cell_mask)

    if args.output:
        outpath = args.output

    else:
        basename = os.path.basename(args.spot_table)
        basename = os.path.splitext(basename)[0]
        outpath = f"{basename}.{args.tag}.cellxgene.csv"
    gene_counts_df.to_csv(outpath, sep=",", header=True, index=False)
