#!/usr/bin/env python

"""Example scoring script.

This is a minimal example of how a prediction file can be evaluated
using built-in Python functions. In this example, "accuracy" is
computed.

In order to display the scores (and other results) on Synapse, they
must be written to a JSON file. This JSON file will then be used to
annotate the submission (next step in the workflow CWL).
"""

import argparse
import csv
import json


def read_csv(filepath, delim=",", id_col="id"):
    """
    Parses a file and returns a dictionary, where id_col
    is will be used as the key.
    """
    data = {}
    with open(filepath) as csvfile:
        reader = csv.DictReader(csvfile, delimiter=delim)
        try:
            for row in reader:
                data[row[id_col]] = row
        except KeyError:
            return {}
    return data


def score_accuracy(gt, truth_label, pred, pred_label):
    """
    Compute scores of the predictions against the groundtruth/
    goldstandard.
    """
    correct_count = 0
    total_count = 0
    for patient_id, predictions in pred.items():
        if predictions.get(pred_label) == gt.get(patient_id).get(truth_label):
            correct_count += 1
        total_count += 1
    if total_count == 0:
        return 0
    return correct_count / total_count


def main():
    """Main function."""

    id_col = "PatientID"
    pred = read_csv(args.prediction_file, id_col=id_col)
    if not pred:
        scores = 0
        status = "INVALID"
        errors = f"Cannot be evaluated; {id_col} not found in the prediction file"
    else:
        truth = read_csv(args.groundtruth_file, id_col=id_col)
        status = "SCORED"
        errors = ""

        try:
            scores = score_accuracy(truth, "has_cancer", pred, "probability")
        except ValueError:
            scores = 0
            status = "INVALID"
            errors = "Cannot be evaluated; error encountered during scoring"

    result = {
        "accuracy": scores,
        "submission_status": status,
        "submission_errors": errors,
    }
    with open(args.output_file, "w") as o:
        o.write(json.dumps(result))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-p",
        "--prediction_file",
        required=True,
        help="Filepath to prediction CSV",
    )
    parser.add_argument(
        "-g",
        "--groundtruth_file",
        required=True,
        help="Filepath to groundtruth/goldstandard CSV",
    )
    parser.add_argument(
        "-o",
        "--output_file",
        default="results.json",
        help="Output JSON file for scores and results",
    )
    args = parser.parse_args()
    main()
