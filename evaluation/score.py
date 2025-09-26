#!/usr/bin/env python
import argparse
import json

parser = argparse.ArgumentParser()
parser.add_argument("-p", "--prediction_file", required=True, help="Submission File")
parser.add_argument("-o", "--output_file", required=True, help="Scoring results")
parser.add_argument(
    "-g", "--groundtruth_file", required=True, help="Goldstandard for scoring"
)

args = parser.parse_args()
score = 1 + 1
prediction_file_status = "SCORED"

result = {"auc": score, "submission_status": prediction_file_status}
with open(args.output_file, "w") as o:
    o.write(json.dumps(result))
