#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: Workflow
label: Evaluation workflow for project submissions
doc: > 
  This workflow validates and archives a writeup submission for a
  challenge. The writeup is expected to be a Synapse project and
  should be accessible to at least the Challenge onrganizers team.

requirements:
  - class: StepInputExpressionRequirement

inputs:
  # ------------------------------------------------------------------------------
  # SynapseWorkflowOrchestrator inputs - do not remove or modify.
  # ------------------------------------------------------------------------------
  adminUploadSynId:
    label: synID to folder that is downloadable by admin only
    type: string
  submissionId:
    label: Submission ID
    type: int
  submitterUploadSynId:
    label: synID to folder that is downloadable by submitter and admin
    type: string
  synapseConfig:
    label: Filepath to the .synapseConfig file
    type: File
  workflowSynapseId:
    label: File synID that links to the workflow
    type: string

  # ------------------------------------------------------------------------------
  # Core challenge configuration - MUST be updated and specific to your challenge.
  # ------------------------------------------------------------------------------
  challengeProjectId:
    label: synID for the challenge project
    type: string
    default: "syn123"  # Placeholder - MUST be updated
  organizersId:
    label: User or Team ID on Synapse for challenge organizers
    type: string
    default: "3379097" # Placeholder - MUST be updated

  # ------------------------------------------------------------------------------
  # Optional challenge configuration.
  # ------------------------------------------------------------------------------
  errors_only:
    label: Send email notifications only for errors (no notification for valid submissions)
    type: boolean
    default: false

outputs: []

steps:
  01_validate:
    doc: Check that submission is a valid Synapse project
    run: steps/validate-writeup.cwl
    in:
      - id: synapse_config
        source: "#synapseConfig"
      - id: submissionid
        source: "#submissionId"
      - id: challengewiki
        source: "#challengeProjectId"
      - id: public
        default: true
      - id: admin
        source: "#organizersId"
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
      - id: errors_only
        source: "#errors_only"
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
    doc: >
      Check the status of the submission validation; if 'INVALID', throw an
      exception to stop the workflow at this step
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
    run: steps/archive-writeup.cwl
    in:
      - id: synapse_config
        source: "#synapseConfig"
      - id: submissionid
        source: "#submissionId"
      - id: admin
        source: "#organizersId"
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
