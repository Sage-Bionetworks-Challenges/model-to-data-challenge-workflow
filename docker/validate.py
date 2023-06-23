#!/usr/bin/env python3
"""Validate task <task_number> prediction file.

Prediction files require 2 columns:
    - Participant_ID
    - Disease_Name
"""
import argparse
import json
import pandas as pd
import numpy as np

INDEX_COL = "Participant_ID"
PRED_COL = "Disease_Name" #neccessary when validating a TSV

def determine_file_type(pred_file):
    file_metadata = "TSV" if pred_file.endswith('.tsv') else "CSV"
    return file_metadata
    
def get_args():
    """Set up command-line interface and get arguments."""
    parser = argparse.ArgumentParser()
    parser.add_argument("-p", "--predictions_file",
                        type=str, required=True)
    parser.add_argument("-g", "--goldstandard_file",
                        type=str, required=True)
    parser.add_argument("-o", "--output", type=str)
    parser.add_argument("-t", "--task", type=str, required=False)
    return parser.parse_args()


def check_dups(pred):
    """Check for duplicate participant IDs i.e. confirm all IDs are unique."""
    duplicates = pred.duplicated(subset=[INDEX_COL])
    if duplicates.any():
        return (
            f"Found {duplicates.sum()} duplicate participant ID(s): "
            f"{pred[duplicates].Participant_ID.to_list()}"
        )
    return ""


def check_missing_ids(gold, pred):
    """Check for missing participant IDs."""
    pred = pred.set_index(INDEX_COL)
    missing_ids = gold.index.difference(pred.index)
    if missing_ids.any():
        return (
            f"Found {missing_ids.shape[0]} missing participant ID(s): "
            f"{missing_ids.to_list()}"
        )
    return ""


def check_unknown_ids(gold, pred):
    """Check for unknown participant IDs."""
    pred = pred.set_index(INDEX_COL)
    unknown_ids = pred.index.difference(gold.index)
    if unknown_ids.any():
        return (
            f"Found {unknown_ids.shape[0]} unknown participant ID(s): "
            f"{unknown_ids.to_list()}"
        )
    return ""

def validate_mlti(gold_file, pred_file,task_number):
    """CSV prediction file use only!
    Used to validate a  predictions file where >1 task should be validated.
    Implement when >1 tasks in the challenge will accept a file as the data submission.
    Validate predictions file against goldstandard.
    """
    errors = []
    #Add additional columns below as needed
    # Lines 18-27 are utilized when a CSV is submitted by Participants
    COLS = {
        "1": {
            'Participant_ID': np.int64,
            'Disease_Name': str
        },
        "2": {
            'Participant_ID': np.int64,
            'Disease_Name': str
        }
    }
    if determine_file_type(pred_file) == "CSV":
        gold = pd.read_csv(gold_file,
                           index_col=INDEX_COL)
        try:
            pred = pd.read_csv(pred_file,
                               usecols=COLS[task_number],
                               dtype=COLS[task_number],
                               float_precision='round_trip')
        except ValueError as err:
            errors.append(
                f"Invalid column names and/or types: {str(err)}. "
                f"Expecting: {str(COLS[task_number])}."
            )
        else:
            errors.append(check_dups(pred))
            errors.append(check_missing_ids(gold, pred))
            errors.append(check_unknown_ids(gold, pred))
    else:
        gold = pd.read_csv(gold_file,
                           sep="\t",
                           index_col=INDEX_COL)
        try:
            pred = pd.read_csv(pred_file,
                               sep="\t",
                               usecols=COLS[task_number],
                               dtype=COLS[task_number])
        except ValueError as err:
            errors.append(
                f"Invalid column names and/or types: {str(err)}. "
                f"Expecting: {str(COLS[task_number])}."
            )
        else:
            errors.append(check_dups(pred))
            errors.append(check_missing_ids(gold, pred))
            errors.append(check_unknown_ids(gold, pred))
    
    return errors

def validate_sngl(gold_file, pred_file):
    """CSV prediction file use only!
    Used to validate a TSV predictions file where 1 task should be validated.
    Implement when only 1 task in the challenge will accept a file as the data submission.
    Validate predictions file against goldstandard.
    """
    errors = []
    cols = {INDEX_COL: np.int64, PRED_COL: str}

    if determine_file_type(pred_file) == "CSV":
        gold = pd.read_csv(gold_file,
                           index_col=INDEX_COL)
        try:
            pred = pd.read_csv(pred_file,
                               usecols=cols,
                               dtype=cols,
                               float_precision='round_trip'
            )
        except ValueError:
            errors.append(
                f"Invalid column names and/or types found. "
                f"Expecting: {str(cols)}."
                )
        else:
            errors.append(check_dups(pred))
            errors.append(check_missing_ids(gold, pred))
            errors.append(check_unknown_ids(gold, pred))
    else:
        gold = pd.read_csv(gold_file,
                           sep="\t",
                           index_col=INDEX_COL)
        try:
            pred = pd.read_csv(pred_file,
                               sep="\t",
                               usecols=cols,
                               dtype=cols)
        except ValueError:
            errors.append(
                f"Invalid column names and/or types found. "
                f"Expecting: {str(cols)}."
                )
        else:
            errors.append(check_dups(pred))
            errors.append(check_missing_ids(gold, pred))
            errors.append(check_unknown_ids(gold, pred))
    return errors


def main():
    """Main function."""
    args = get_args()

    if args.task:
        invalid_reasons = validate_mlti(
            gold_file=args.goldstandard_file,
            pred_file=args.predictions_file,
            task_number=args.task
        )
    else:
        invalid_reasons = validate_sngl(
            gold_file=args.goldstandard_file,
            pred_file=args.predictions_file,
        )

    invalid_reasons = "\n".join(filter(None, invalid_reasons))
    status = "INVALID" if invalid_reasons else "VALIDATED"

    # truncate validation errors if >500 (character limit for sending email)
    if len(invalid_reasons) > 500:
        invalid_reasons = invalid_reasons[:496] + "..."
    res = json.dumps({
        "submission_status": status,
        "submission_errors": invalid_reasons
    })

    if args.output:
        with open(args.output, "w") as out:
            out.write(res)
    else:
        print(res)


if __name__ == "__main__":
    main()
