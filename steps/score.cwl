#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool
label: Score predictions

requirements:
- class: InlineJavascriptRequirement
- class: InitialWorkDirRequirement
  listing:
  - entryname: score.py
    entry:
      $include: ../evaluation/score.py

inputs:
- id: pred_file
  type: File
  inputBinding:
    prefix: -p
- id: groundtruth_file
  type: File
  inputBinding:
    prefix: -g
- id: task_number
  type: string?
  inputBinding:
    prefix: -t
- id: check_validation_finished
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

baseCommand:
- python3
- score.py
arguments:
- prefix: -o
  valueFrom: results.json

hints:
  DockerRequirement:
    dockerPull: sagebionetworks/synapsepythonclient:v3.1.1   # TODO: update image as needed; see evaluation/README.md for more details.
