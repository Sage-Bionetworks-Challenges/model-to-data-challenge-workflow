#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: Workflow
label: SEA-AD DREAM Challenge evaluation workflow

requirements:
  - class: StepInputExpressionRequirement

inputs:
  adminUploadSynId:
    label: Folder synID accessible by an admin
    type: string
  submissionId:
    label: Submission ID
    type: int
  submitterUploadSynId:
    label: Folder synID accessible by the submitter
    type: string
  synapseConfig:
    label: Filepath to the .synapseConfig file
    type: File
  workflowSynapseId:
    label: File synID that links to the workflow
    type: string
  organizers:
    label: User or team ID for challenge organizers
    type: string
    default: "123"
  groundtruthSynId:
    label: File synID for the groundtruth file
    type: string
    default: "syn123"
  inputDir:
    label: Absolute filepath to the input data directory
    type: string
    default: "/home/ec2-user/validation_data"
  errors_only:
    label: Send email notifications only for errors (no notification for valid submissions)
    type: boolean
    default: true
  private_annotations:
    label: Annotations to be withheld from participants
    type: string[]
    default: []

outputs: []

steps:
  01_set_submitter_folder_permissions:
    doc: >
      Give challenge organizers `download` permissions to the docker logs
    run: |-
      https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v4.1/cwl/set_permissions.cwl
    in:
      - id: entityid
        source: "#submitterUploadSynId"
      - id: principalid
        source: "#organizers"
      - id: permissions
        valueFrom: "download"
      - id: synapse_config
        source: "#synapseConfig"
    out: []

  01_set_admin_folder_permissions:
    doc: >
      Give challenge organizers `download` permissions to the private submission folder
    run: |-
      https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v4.1/cwl/set_permissions.cwl
    in:
      - id: entityid
        source: "#adminUploadSynId"
      - id: principalid
        source: "#organizers"
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

  01_create_docker_config:
    doc: Create a Docker client configuration file using Synapse credentials
    run: steps/create_docker_config.cwl
    in:
      - id: synapse_config
        source: "#synapseConfig"
    out: 
      - id: docker_registry
      - id: docker_authentication

  02_run_docker:
    doc: >
      Run the participant Docker container against the input data to generate predictions
    run: steps/run_docker.cwl
    in:
      - id: docker_repository
        source: "#01_download_submission/docker_repository"
      - id: docker_digest
        source: "#01_download_submission/docker_digest"
      - id: submissionid
        source: "#submissionId"
      - id: docker_registry
        source: "#01_create_docker_config/docker_registry"
      - id: docker_authentication
        source: "#01_create_docker_config/docker_authentication"
      - id: parentid
        source: "#adminUploadSynId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: store
        default: true
      - id: input_dir
        source: "#inputDir"
      - id: docker_script
        default:
          class: File
          location: "steps/run_docker.py"
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
      exception to stop the workflow
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
    run: steps/upload_predictions.cwl
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
    doc: Validate format of generated predictions, prior to scoring
    run: steps/validate.cwl
    in:
      - id: input_file
        source: "#02_run_docker/predictions"
      - id: groundtruth
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
      exception to stop the workflow - this will prevent the attempt of
      scoring invalid predictions file (which will then result in errors)
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
      - id: input_file
        source: "#02_run_docker/predictions"
      - id: groundtruth
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
