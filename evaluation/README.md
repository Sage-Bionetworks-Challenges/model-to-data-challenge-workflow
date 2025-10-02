If your validation and scoring scripts require libraries beyond the built-in
Python ones, it is recommended to containerize your execution environment. You
may use the provided files in this folder to help with this purpose.

Once your changes are ready, create a new release in your repo. This will trigger
the action to build and deploy this Docker image into your repo as a package.

Final steps would be to copy the image name into your "validate.cwl" and "score.cwl"
under hints.DockerRequirement.dockerPull.
