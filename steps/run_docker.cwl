#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool
label: Score Segmentations Lesion-wise

requirements:
  - class: InitialWorkDirRequirement
    listing:
      - $(inputs.docker_script)
      - entryname: .docker/config.json
        entry: |
          {"auths": {"$(inputs.docker_registry)": {"auth": "$(inputs.docker_authentication)"}}}
  - class: InlineJavascriptRequirement

inputs:
- id: submissionid
  type: int
- id: docker_repository
  type: string
  default: ""
- id: docker_digest
  type: string
  default: ""
- id: docker_registry
  type: string
- id: docker_authentication
  type: string
- id: parentid
  type: string
- id: synapse_config
  type: File
- id: input_dir
  type: string
- id: docker_script
  type: File
- id: store
  type: boolean?

outputs:
- id: predictions
  type: File?
  outputBinding:
    glob: predictions.csv
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

baseCommand: python3
arguments:
- valueFrom: $(inputs.docker_script.path)
- valueFrom: $(inputs.submissionid)
  prefix: -s
- valueFrom: $(inputs.docker_repository)
  prefix: -p
- valueFrom: $(inputs.docker_digest)
  prefix: -d
- valueFrom: $(inputs.store)
  prefix: --store
- valueFrom: $(inputs.parentid)
  prefix: --parentid
- valueFrom: $(inputs.synapse_config.path)
  prefix: -c
- valueFrom: $(inputs.input_dir)
  prefix: -i
