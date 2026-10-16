#!/usr/bin/env python
## Written by Kresimir Bestak and Florian Wuennemann and released under the MIT license.
import pandas as pd
import numpy as np
from anndata import AnnData
import argparse
from argparse import ArgumentParser as AP
from os.path import abspath
import time
from scipy.sparse import csr_matrix


def get_args():
    # Script description
    description = """Anndata object creation"""

    # Add parser
    parser = AP(description=description, formatter_class=argparse.RawDescriptionHelpFormatter)

    # Sections
    inputs = parser.add_argument_group(title="Required Input", description="Path to required input file")
    inputs.add_argument("-i", "--input", type=str, help="Path to the spot2cell csv file.")
    inputs.add_argument("-s", "--spatial_cols", nargs="+", help="Column names for location data.")
    inputs.add_argument(
        "-o", "--output", dest="output", action="store", required=True, help="Path to output anndata object."
    )
    inputs.add_argument("--version", action="version", version="0.1.0")
    arg = parser.parse_args()
    arg.input = abspath(arg.input)
    arg.output = abspath(arg.output)
    return arg


def create_spatial_anndata(input, spatial_cols):
    df = pd.read_csv(input)
    spatial_coords = np.array(df[args.spatial_cols].values.tolist())
    # Find the index of 'Y_centroid' column
    y_centroid_index = df.columns.get_loc("X_centroid")
    # Create a list of all columns from 'Y_centroid' to the end
    metadata_cols = df.columns[y_centroid_index:]
    # Extract the excluded columns as metadata
    metadata = df[metadata_cols]

    count_table = csr_matrix(df.drop(list(metadata_cols), axis=1).values.tolist())
    adata = AnnData(count_table, obsm={"spatial": spatial_coords})
    # Add the metadata to adata.obs
    for col in metadata.columns:
        adata.obs[col] = metadata[col].values
    adata.obs_names = [f"Cell_{i:d}" for i in range(adata.n_obs)]
    return adata


def main(args):
    adata = create_spatial_anndata(args.input, args.spatial_cols)
    adata.write(args.output)


if __name__ == "__main__":
    args = get_args()
    st = time.time()
    main(args)
    rt = time.time() - st
    print(f"Script finished in {rt // 60:.0f}m {rt % 60:.0f}s")
