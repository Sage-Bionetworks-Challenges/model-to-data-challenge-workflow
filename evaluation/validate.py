#!/usr/bin/env python

"""Example validation script.

This is a minimal example of how a prediction file can be checked
for expected structure and format, prior to scoring.

In order to display the results on Synapse, the results must be
written to a JSON file. This JSON file will then be used to annotate
the submission (next step in the workflow CWL).
"""

import argparse
import csv
import json


def validate_csv(filepath, delim=",", expected_cols=["id"]):
    """
    Checks for expected colnames in the CSV file.
    """
    errors = []
    with open(filepath) as csvfile:
        reader = csv.DictReader(csvfile, delimiter=delim)
        for colname in expected_cols:
            if colname not in reader.fieldnames:
                errors.append(f"'{colname}' is missing from the prediction file")
    return "\n".join(errors)


def main():
    """Main function."""

    if args.entity_type != "FileEntity":
        errors = f"Submission should be a file, not {args.entity_type}"
    else:
        errors = validate_csv(
            args.prediction_file,
            expected_cols=[
                "PatientID",
                "probability",
            ],
        )

    result = {
        "submission_status": "INVALID" if errors else "VALIDATED",
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
        "-e",
        "--entity_type",
        default="FileEntity",
        help="Submission type, based on Synapse entities",
    )
    parser.add_argument(
        "-o",
        "--output_file",
        default="results.json",
        help="Output JSON file for scores and results",
    )
    args = parser.parse_args()
    main()
