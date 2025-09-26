#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool
label: Score predictions

requirements:
- class: InlineJavascriptRequirement

inputs:
- id: input_file
  type: File
- id: groundtruth
  type: File
- id: task_number
  type: string
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

baseCommand: score.py
arguments:
- prefix: -p
  valueFrom: $(inputs.input_file.path)
- prefix: -g
  valueFrom: $(inputs.groundtruth.path)
- prefix: -t
  valueFrom: $(inputs.task_number)
- prefix: -o
  valueFrom: results.json

hints:
  DockerRequirement:
    dockerPull: ghcr.io/sage-bionetworks-challenges/sea-ad-dream:latest
