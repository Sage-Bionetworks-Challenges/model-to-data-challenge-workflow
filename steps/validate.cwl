#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool
doc: Validate predictions prior to scoring

requirements:
- class: InlineJavascriptRequirement
- class: InitialWorkDirRequirement
  listing:
  - entryname: validate.py
    entry:
      $include: ../evaluation/validate.py

inputs:
- id: pred_file
  type: File
- id: groundtruth_file
  type: File?
  inputBinding:
    prefix: -g
- id: entity_type
  type: string?
  inputBinding:
    prefix: -e
- id: previous_annotation_finished
  type: boolean?

outputs:
- id: results
  type: File
  outputBinding:
    glob: results.json
- id: status
  type: string
  outputBinding:
    glob: results.json
    outputEval: $(JSON.parse(self[0].contents)['submission_status'])
    loadContents: true
- id: invalid_reasons
  type: string
  outputBinding:
    glob: results.json
    outputEval: $(JSON.parse(self[0].contents)['submission_errors'])
    loadContents: true

baseCommand:
- python3
- validate.py
arguments:
- prefix: -p
  valueFrom: $(inputs.pred_file.path)
- prefix: -o
  valueFrom: results.json

hints:
  DockerRequirement:
    dockerPull: sagebionetworks/synapsepythonclient:v3.1.1  # TODO: update image as needed; see evaluation/README.md for more details
