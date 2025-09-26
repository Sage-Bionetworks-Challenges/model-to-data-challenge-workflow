#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool
doc: |
  Extract the Synapse credentials and formats it into a Docker config, in order to enable pulling from the Synapse Docker registry.

requirements:
- class: InlineJavascriptRequirement
- class: InitialWorkDirRequirement
  listing:
  - entryname: get_docker_config.py
    entry:
      $include: ../scripts/get_docker_config.py

inputs:
- id: synapse_config
  type: File

outputs:
- id: results
  type: File
  outputBinding:
    glob: results.json
- id: docker_registry
  type: string
  outputBinding:
    glob: results.json
    outputEval: $(JSON.parse(self[0].contents)['docker_registry'])
    loadContents: true
- id: docker_authentication
  type: string
  outputBinding:
    glob: results.json
    outputEval: $(JSON.parse(self[0].contents)['docker_auth'])
    loadContents: true

baseCommand: python3
arguments:
- valueFrom: get_docker_config.py
- prefix: -c
  valueFrom: $(inputs.synapse_config.path)
- prefix: -r
  valueFrom: results.json

hints:
  DockerRequirement:
    dockerPull: sagebionetworks/synapsepythonclient:v3.1.1
