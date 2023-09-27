#!/usr/bin/env python

#### This script takes regionprops_tabe output from mcquant and the raw spot tables from Resolve bioscience as input
#### and calculates some QC metrics for masks and spot assignments

import argparse
import pandas as pd

def summarize_spots(spot_table):
    ## Calculate number of spots per gene
    tx_per_gene = spot_table.groupby('gene').count().reset_index()

    ## Calculate the total number of spots in spot_table
    total_spots = spot_table.shape[0]

    return(tx_per_gene,total_spots)

def summarize_segmasks(mcquant,spots_summary):
    ## Calculate the total number of cells (rows) in mcquant
    total_cells = mcquant.shape[0]

    ## Calculate the average segmentation area from column Area in mcquant
    avg_area = mcquant['Area'].mean()

    ## Calculate the % of spots assigned
    ## Subset mcquant for all columns with _intensity_sum in the column name and sum the column values
    spot_assign = mcquant.filter(regex='_intensity_sum').sum(axis=1)
    spot_assign_total = int(sum(spot_assign))
    spot_assign_per_cell =  total_cells and spot_assign_total / total_cells or 0
    #spot_assign_per_cell = spot_assign_total / total_cells
    spot_assign_percent = spot_assign_total / spots_summary[1] * 100

    return(total_cells,avg_area,spot_assign_per_cell,spot_assign_total,spot_assign_percent)

if __name__ == "__main__":
    # Write an argparse with input options mcquant_in, spots and output options outdir, sample_id
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-i",
        "--mcquant",
        help="mcquant regionprops_table."
        )
    parser.add_argument(
        "-s",
        "--spots",
        help="Resolve biosciences spot table."
        )
    parser.add_argument(
        "-o",
        "--outdir",
        help="Output directory."
    )

    parser.add_argument(
        "-d",
        "--sample_id",
        help="Sample ID."
        )

    parser.add_argument(
        "-g",
        "--segmentation_method",
        help="Segmentation method used."
        )

    args = parser.parse_args()

    ## Read in mcquant table
    mcquant = pd.read_csv(args.mcquant)

    ## Read in spot table
    spots = pd.read_table(args.spots, sep='\t', names=['x', 'y', 'z', 'gene'])
    spots = spots[~spots.gene.str.contains("Duplicated")]

    ## Summarize spots table
    summary_spots = summarize_spots(spots)
    summary_segmentation = summarize_segmasks(mcquant,summary_spots)

    ## Create pandas data frame with one row per parameter and write each value in summary_segmentation to a new row in the data frame
    summary_df = pd.DataFrame(columns=['sample_id','segmentation_method','total_cells','avg_area','total_spots','spot_assign_per_cell','spot_assign_total','spot_assign_percent',])
    summary_df.loc[0] = [args.sample_id + "_" + args.segmentation_method,args.segmentation_method,summary_segmentation[0],summary_segmentation[1],summary_spots[1],summary_segmentation[2],summary_segmentation[3],summary_segmentation[4]]

    # Write summary_df to a csv file
    summary_df.to_csv(f"{args.outdir}/{args.sample_id}.{args.segmentation_method}.spot_QC.csv", header = True, index=False)
