#!/usr/bin/env python
import argparse
import json

parser = argparse.ArgumentParser()
parser.add_argument("-o", "--output_file", required=True, help="validation results")
parser.add_argument(
    "-e", "--entity_type", required=True, help="synapse entity type downloaded"
)
parser.add_argument("-p", "--pred_file", help="Prediction File")

args = parser.parse_args()

if args.pred_file is None:
    prediction_file_status = "INVALID"
    invalid_reasons = ["Expected FileEntity type but found " + args.entity_type]
else:
    with open(args.pred_file, "r") as sub_file:
        message = sub_file.read()
    invalid_reasons = []
    prediction_file_status = "VALIDATED"
    if not message.startswith("test"):
        invalid_reasons.append("Submission must have test column")
        prediction_file_status = "INVALID"
result = {
    "submission_errors": "\n".join(invalid_reasons),
    "submission_status": prediction_file_status,
}

with open(args.output_file, "w") as o:
    o.write(json.dumps(result))
