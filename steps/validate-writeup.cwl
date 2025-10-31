#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool
doc: Validate a Project (writeup) submission

requirements:
- class: InlineJavascriptRequirement

inputs:
- id: submissionid
  type: int
- id: challengewiki
  type: string
- id: public
  type: boolean?
  inputBinding:
    prefix: --public
- id: admin
  type: string?
  inputBinding:
    prefix: --admin
- id: synapse_config
  type: File

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

baseCommand: challengeutils
arguments:
- prefix: -c
  valueFrom: $(inputs.synapse_config.path)
- valueFrom: validate-project
- valueFrom: $(inputs.submissionid)
- valueFrom: $(inputs.challengewiki)
- prefix: --output
  valueFrom: results.json

hints:
  DockerRequirement:
    dockerPull: sagebionetworks/challengeutils:v4.0.1
