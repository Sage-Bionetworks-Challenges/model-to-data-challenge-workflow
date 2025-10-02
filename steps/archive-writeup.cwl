#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool
doc: Archive a Project (writeup) submission

requirements:
- class: InlineJavascriptRequirement

inputs:
- id: submissionid
  type: int
- id: admin
  type: string
- id: synapse_config
  type: File
- id: check_validation_finished
  type: boolean?

outputs:
- id: results
  type: File
  outputBinding:
    glob: results.json

baseCommand: challengeutils
arguments:
- prefix: -c
  valueFrom: $(inputs.synapse_config.path)
- valueFrom: archive-project
- valueFrom: $(inputs.submissionid)
- valueFrom: $(inputs.admin)
- prefix: --output
  valueFrom: results.json

hints:
  DockerRequirement:
    dockerPull: sagebionetworks/challengeutils:v4.0.1
