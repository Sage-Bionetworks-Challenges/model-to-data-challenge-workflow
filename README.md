<div align="center">
  <h1>
    Model-to-Data Challenge Infrastructure Template
  </h1>

  <h3>
    Ready-to-use workflow template for evaluating Docker images submitted on
    <a href="https://www.synapse.org" title="Synapse.org">Synapse.org</a>
  </h3>

  <br/>

  <img 
    alt="GitHub release (latest by date)" 
    src="https://img.shields.io/github/release/sage-bionetworks-challenges/model-to-data-challenge-workflow?label=latest%20release&display_name=release&style=flat-square">
  <img 
    alt="GitHub Release Date" 
    src="https://img.shields.io/github/release-date/sage-bionetworks-challenges/model-to-data-challenge-workflow?style=flat-square&color=green">
  <img 
    alt="GitHub" 
    src="https://img.shields.io/github/license/sage-bionetworks-challenges/model-to-data-challenge-workflow?style=flat-square&color=orange">
</div>


### 💡 Should You Use This Template?

The model-to-data (m2d) workflow is ideal for scenarios where participants
train their algorithm locally using provided training data. Participants will
then submit their algorithm as a containerized Docker image to be run against
the hold-out validation/test data (which they will have no access to) in
order to generate a predictions file, which is then evaluated against the
hidden groundtruth data.

### 🚀 Quick Start

* **Customize evaluation logic:** modify the scoring and validation scripts
  within the `evaluation` folder
* **Configure workflow:** adapt `workflow.cwl` (and `writeup-workflow.cwl`,
  if applicable) to define the inputs and steps specific to your challenge
* **Test your changes:** use [`cwltool`](https://github.com/common-workflow-language/cwltool)
  to test your CWL scripts within the `steps`  folder

---

### Technical Details & Resources

#### Repository structure

This template provides all necessary components for a full challenge pipeline:

```
.
├── evaluation      // core scoring and validation scripts
├── README.md
├── scripts         // scripts called by the individual CWL scripts in `steps`
├── steps           // individual CWL scripts (called by the main workflow CWLs)
├── workflow.cwl          // CWL workflow for evaluating submissions
└── writeup-workflow.cwl  // CWL workflow to validate and archive writeup submissions
```

#### Resource docs 

This workflow uses CWL, Docker, and the SynapseWorkflowOrchestrator to run
the challenge pipeline. For more information on how to utilize these tools,
see their docs below:

* CWL: https://www.commonwl.org/user_guide/
* Docker: https://docs.docker.com/get-started/
* SynapseWorkflowOrchestrator: https://github.com/Sage-Bionetworks/SynapseWorkflowOrchestrator
