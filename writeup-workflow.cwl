#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: Workflow
label: Validate and archive writeup submission

requirements:
  - class: StepInputExpressionRequirement

inputs:
  adminUploadSynId:
    label: Synapse Folder ID accessible by an admin
    type: string
  submissionId:
    label: Submission ID
    type: int
  submitterUploadSynId:
    label: Synapse Folder ID accessible by the submitter
    type: string
  synapseConfig:
    label: filepath to .synapseConfig file
    type: File
  workflowSynapseId:
    label: Synapse File ID that links to the workflow
    type: string
  organizers:
    label: User or team ID for challenge organizers
    type: string
    default: "123"

outputs: []

steps:
  01_validate:
    doc: Check that submission is a valid Synapse project
    run: writeup-workflow/steps/validate-writeup.cwl
    in:
      - id: synapse_config
        source: "#synapseConfig"
      - id: submissionid
        source: "#submissionId"
      - id: challengewiki
        valueFrom: "syn64743570"
      - id: public
        default: true
      - id: admin
        source: "#organizers"
    out:
      - id: results
      - id: status
      - id: invalid_reasons
  
  02_validation_email:
    doc: >
        Send notifcation email to the submitter whether writeup submission
        has been accepted
    run: |-
        https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v4.1/cwl/validate_email.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: status
        source: "#01_validate/status"
      - id: invalid_reasons
        source: "#01_validate/invalid_reasons"
      # - id: errors_only
      #   default: true
    out: [finished]

  03_annotate_validation_with_output:
    doc: >
      Add `submission_status` and `submission_errors` annotations to the
      submission
    run: |-
      https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v4.1/cwl/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#01_validate/results"
      - id: to_public
        default: true
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
    out: [finished]

  04_check_status:
    run: |-
      https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v4.1/cwl/check_status.cwl
    in:
      - id: status
        source: "#01_validate/status"
      - id: previous_annotation_finished
        source: "#03_annotate_validation_with_output/finished"
      - id: previous_email_finished
        source: "#02_validation_email/finished"
    out: [finished]
 
  05_archive:
    doc: Create a copy of the Synapse project for archival purposes
    run: writeup-workflow/steps/archive.cwl
    in:
      - id: synapse_config
        source: "#synapseConfig"
      - id: submissionid
        source: "#submissionId"
      - id: admin
        source: "#organizers"
      - id: check_validation_finished 
        source: "#04_check_status/finished"
    out:
      - id: results

  06_annotate_archive_with_output:
    doc: Add `writeup` annotation to the submission
    run: |-
      https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v4.1/cwl/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#05_archive/results"
      - id: to_public
        default: true
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
      - id: previous_annotation_finished
        source: "#03_annotate_validation_with_output/finished"
    out: [finished]
