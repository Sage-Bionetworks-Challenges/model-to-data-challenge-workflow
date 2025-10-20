#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow
label: Evaluation workflow for Docker submissions
doc: >
  This workflow runs a Docker submission against an input dataset,
  validates the generated predictions file, and scores the predictions.

requirements:
  - class: StepInputExpressionRequirement

inputs:
  # ------------------------------------------------------------------------------
  # SynapseWorkflowOrchestrator inputs - do not remove or modify.
  # ------------------------------------------------------------------------------
  adminUploadSynId:
    label: synID to folder on Synapse that is downloadable by admin only
    type: string
  submissionId:
    label: Submission ID
    type: int
  submitterUploadSynId:
    label: synID to folder on Synapse that is downloadable by submitter and admin
    type: string
  synapseConfig:
    label: Abstolute filepath to .synapseConfig file
    type: File
  workflowSynapseId:
    label: synID to workflow file
    type: string

  # ------------------------------------------------------------------------------
  # Core challenge configuration - MUST be updated and specific to your challenge.
  # ------------------------------------------------------------------------------
  organizersId:
    label: userID or teamID for the organizers team on Synapse
    type: string
    default: "3379097" # Placeholder - MUST be updated
  groundtruthSynId:
    label: synID for the groundtruth file on Synapse
    type: string
    default: "syn123"  # Placeholder - MUST be updated
  inputDir:
    label: Absolute filepath to the input data directory on the host machine
    type: string
    default: "/home/user/input_data"  # Placeholder - MUST be updated

  # ------------------------------------------------------------------------------
  # Optional challenge configuration - update as needed.
  # ------------------------------------------------------------------------------
  container_memory_limit:
    label: Memory limit for running the container (e.g. '4g' or '200m')
    type: string
    default: "6g"
  container_swap_limit:
    label: Swap limit for running the container (e.g. '4g' or '200m'). See https://docs.docker.com/engine/containers/resource_constraints/ for more details.
    type: string
    default: "6g"
  container_time_limit:
    label: Time limit (in seconds) for running the container
    type: int
    default: 10800  # 3 hours
  errors_only:
    label: Send email notifications only for errors (no notification for valid submissions)
    type: boolean
    default: true
  private_annotations:
    label: Annotations to be withheld from participants
    type: string[]
    default: ["submission_errors"]

outputs: []

steps:
  01_set_submitter_folder_permissions:
    doc: >
      Give challenge organizers `download` access to the docker logs
    run: |-
      https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v4.1/cwl/set_permissions.cwl
    in:
      - id: entityid
        source: "#submitterUploadSynId"
      - id: principalid
        source: "#organizersId"
      - id: permissions
        valueFrom: "download"
      - id: synapse_config
        source: "#synapseConfig"
    out: []

  01_set_admin_folder_permissions:
    doc: >
      Give challenge organizers `download` access to the private submission folder
    run: |-
      https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v4.1/cwl/set_permissions.cwl
    in:
      - id: entityid
        source: "#adminUploadSynId"
      - id: principalid
        source: "#organizersId"
      - id: permissions
        valueFrom: "download"
      - id: synapse_config
        source: "#synapseConfig"
    out: []

  01_download_submission:
    doc: Get information about Docker submission, e.g. image name and digest
    run: |-
      https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v4.1/cwl/get_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
    out:
      - id: filepath
      - id: docker_repository
      - id: docker_digest
      - id: entity_id
      - id: entity_type
      - id: evaluation_id
      - id: results

  01_download_groundtruth:
    doc: Download groundtruth file
    run: |-
      https://raw.githubusercontent.com/Sage-Bionetworks-Workflows/cwl-tool-synapseclient/v1.4/cwl/synapse-get-tool.cwl
    in:
      - id: synapseid
        source: "#groundtruthSynId"
      - id: synapse_config
        source: "#synapseConfig"
    out:
      - id: filepath

  02_run_docker:
    doc: >
      Run the participant Docker container against the input data to generate predictions
    run: steps/run-docker.cwl
    in:
      - id: docker_repository
        source: "#01_download_submission/docker_repository"
      - id: docker_digest
        source: "#01_download_submission/docker_digest"
      - id: submissionid
        source: "#submissionId"
      - id: parentid
        source: "#adminUploadSynId"  # Can be updated to: 'submitterUploadSynId' if participants can have access to logs
      - id: synapse_config
        source: "#synapseConfig"
      - id: store
        default: true
      - id: input_dir
        source: "#inputDir"
      - id: memory_limit
        source: "#container_memory_limit"
      - id: swap_limit
        source: "#container_swap_limit"
      - id: time_limit
        source: "#container_time_limit"
      - id: docker_script
        default:
          class: File
          location: "scripts/run_docker_model.py"
    out:
      - id: predictions
      - id: results
      - id: status
      - id: invalid_reasons

  03_send_docker_run_status:
    doc: Send email notification about container run results
    run: |-
      https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v4.1/cwl/validate_email.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: status
        source: "#02_run_docker/status"
      - id: invalid_reasons
        source: "#02_run_docker/invalid_reasons"
      - id: errors_only
        source: "#errors_only"
    out: [finished]

  03_annotate_docker_run_results:
    doc: >
      Add `submission_status` and `submission_errors` annotations to the
      submission based on the container run results
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v4.1/cwl/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#02_run_docker/results"
      - id: to_public
        default: true
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
    out: [finished]

  04_check_docker_run_status:
    doc: >
      Check the status of the container run; if 'INVALID', throw an
      exception to stop the workflow at this step. That way, the
      workflow will not attempt to evaluate a non-existent predictions
      file.
    run: |-
      https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v4.1/cwl/check_status.cwl
    in:
      - id: status
        source: "#02_run_docker/status"
      - id: previous_annotation_finished
        source: "#03_annotate_docker_run_results/finished"
      - id: previous_email_finished
        source: "#03_send_docker_run_status/finished"
    out: [finished]

  05_upload_generated_predictions:
    doc: Upload the generated predictions file to the private folder
    run: steps/upload-predictions.cwl
    in:
      - id: infile
        source: "#02_run_docker/predictions"
      - id: parentid
        source: "#adminUploadSynId"
      - id: used_entity
        source: "#01_download_submission/entity_id"
      - id: executed_entity
        source: "#workflowSynapseId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: check_docker_run_finished
        source: "#04_check_docker_run_status/finished"
    out:
      - id: uploaded_fileid
      - id: uploaded_file_version
      - id: results

  06_annotate_docker_upload_results:
    doc: >
      Add annotations about the uploaded predictions file to the submission
    run: |-
      https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v4.1/cwl/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#05_upload_generated_predictions/results"
      - id: to_public
        default: true
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
      - id: previous_annotation_finished
        source: "#03_annotate_docker_run_results/finished"
    out: [finished]

  07_validate:
    doc: Validate format of generated predictions file, prior to scoring
    run: steps/validate.cwl
    in:
      - id: pred_file
        source: "#02_run_docker/predictions"
      - id: groundtruth_file
        source: "#01_download_groundtruth/filepath"
      - id: previous_annotation_finished
        source: "#06_annotate_docker_upload_results/finished"
    out:
      - id: results
      - id: status
      - id: invalid_reasons
  
  08_send_validation_results:
    doc: Send email of the validation results to the submitter
    run: |-
      https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v4.1/cwl/validate_email.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: status
        source: "#07_validate/status"
      - id: invalid_reasons
        source: "#07_validate/invalid_reasons"
      - id: errors_only
        source: "#errors_only"
    out: [finished]

  08_add_validation_annots:
    doc: Update the submission annotations with validation results
    run: |-
      https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v4.1/cwl/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#07_validate/results"
      - id: to_public
        default: true
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
      - id: previous_annotation_finished
        source: "#06_annotate_docker_upload_results/finished"
    out: [finished]

  09_check_validation_status:
    doc: >
      Check the validation status of the submission; if 'INVALID', throw an
      exception to stop the workflow at this step. That way, the workflow
      will not attempt scoring invalid predictions file.
    run: |-
      https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v4.1/cwl/check_status.cwl
    in:
      - id: status
        source: "#07_validate/status"
      - id: previous_annotation_finished
        source: "#08_add_validation_annots/finished"
      - id: previous_email_finished
        source: "#08_send_validation_results/finished"
    out: [finished]

  10_score:
    run: steps/score.cwl
    in:
      - id: pred_file
        source: "#02_run_docker/predictions"
      - id: groundtruth_file
        source: "#01_download_groundtruth/filepath"
      - id: task_number
        source: "#01_download_submission/evaluation_id"
      - id: check_validation_finished
        source: "#09_check_validation_status/finished"
    out:
      - id: results
      - id: status
      
  11_send_score_results:
    doc: >
      Send email of the evaluation status (optionally with scores) to the submitter
    run: |-
      https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v4.1/cwl/score_email.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: results
        source: "#10_score/results"
      - id: private_annotations
        source: "#private_annotations"
    out: []

  11_add_score_annots:
    doc: >
      Update `submission_status` and add the scoring metric annotations
    run: |-
      https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v4.1/cwl/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#10_score/results"
      - id: to_public
        default: true
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
      - id: previous_annotation_finished
        source: "#08_add_validation_annots/finished"
    out: [finished]

  12_check_score_status:
    doc: >
      Check the scoring status of the submission; if 'INVALID', throw an
      exception so that final status is 'INVALID' instead of 'ACCEPTED'
    run: |-
      https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v4.1/cwl/check_status.cwl
    in:
      - id: status
        source: "#10_score/status"
      - id: previous_annotation_finished
        source: "#11_add_score_annots/finished"
    out: [finished]
