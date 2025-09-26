"""Run participant Docker model and store logs."""
from __future__ import print_function

import argparse
import glob
import json
import os
import requests
import tempfile

import docker
import synapseclient


def create_log_file(log_filename, log_text=None):
    """Create log file"""
    with open(log_filename, "w") as log_file:
        if log_text is not None:
            if isinstance(log_text, bytes):
                log_text = log_text.decode("utf-8")
            log_file.write(log_text.encode("ascii", "ignore").decode("ascii"))
        else:
            log_file.write("Docker container did not produce any STDOUT or logs.")


def get_last_lines(log_filename, n=5):
    """Get last N lines of log file (default=5)."""
    lines = 0
    with open(log_filename, "rb") as f:
        try:
            f.seek(-2, os.SEEK_END)
            # Keep reading, starting at the end, until n lines is read.
            while lines < n:
                f.seek(-2, os.SEEK_CUR)
                if f.read(1) == b"\n":
                    lines += 1
        except OSError:
            # If file only contains one line, then only read that one
            # line.  This exception will probably never occur, but
            # adding it in, just in case.
            f.seek(0)
        last_lines = f.read().decode()
    return last_lines


def store_log_file(syn, log_filename, parentid, store=True):
    """Store log file"""
    statinfo = os.stat(log_filename)
    if statinfo.st_size > 0:
        # If log file is larger than 50Kb, only save last few lines.
        if statinfo.st_size / 1000.0 > 50:
            log_tail = get_last_lines(log_filename)
            create_log_file(log_filename, log_tail)
        ent = synapseclient.File(log_filename, parent=parentid)
        if store:
            try:
                syn.store(ent)
            except synapseclient.exceptions.SynapseHTTPError as err:
                print(err)


def remove_docker_container(client, container_name):
    """Remove docker container"""
    try:
        cont = client.containers.get(container_name)
        cont.stop()
        cont.remove()
    except Exception:
        print(f"Unable to remove container: {container_name}")


def remove_docker_image(client, image_name):
    """Remove docker image"""
    try:
        client.images.remove(image_name, force=True)
    except Exception:
        print(f"Unable to remove image: {image_name}")


def run_docker(syn, args, docker_client, output_dir_to_mount, timeout=10800):
    """Run Docker model.

    If model exceeds timeout (default 3 hours), stop the container.
    """
    docker_image = f"{args.docker_repository}@{args.docker_digest}"
    container_name = f"{args.submissionid}-docker_run"
    log_filename = f"{args.submissionid}-docker_logs.txt"
    input_dir = args.input_dir

    print("Mounting volumes...")
    volumes = {
        input_dir: {
            "bind": "/input",
            "mode": "ro",
        },
        output_dir_to_mount: {
            "bind": "/output",
            "mode": "rw",
        },
    }

    # Remove any pre-existing container with the same name
    remove_docker_container(docker_client, container_name)

    print("Pulling submitted Docker image...")
    try:
        docker_client.images.pull(docker_image)
    except docker.errors.APIError as err:
        errors = f"Unable to pull image: {err}"
        return False, errors

    print(f"Running container '{container_name}'...")
    try:
        container = docker_client.containers.run(
            docker_image,
            detach=True,
            volumes=volumes,
            name=container_name,
            network_disabled=True,
            mem_limit="60g",
            shm_size="1g",
            stderr=True,
        )

        # Wait for the container to finish
        container.wait(timeout=timeout)
        log_text = container.logs()
        create_log_file(log_filename, log_text=log_text)
        store_log_file(syn, log_filename, args.parentid, store=args.store)
        container.remove()
        return True, ""
    except requests.exceptions.ConnectionError:
        log_text = (
            f"Container exceeded execution time limit of {timeout / 60} "
            "minutes; stopping container."
        )
        remove_docker_container(docker_client, container_name)
        create_log_file(log_filename, log_text=log_text)
        store_log_file(syn, log_filename, args.parentid, store=args.store)
        container.remove()
        return False, log_text
    except Exception as err:
        log_text = f"Error running container: {err}"
        create_log_file(log_filename, log_text=log_text)
        store_log_file(syn, log_filename, args.parentid, store=args.store)
        container.remove()
        return False, log_text


def main(syn, args):
    """Main function."""

    status = "VALIDATED_DOCKER"
    invalid_reasons = ""
    if not args.docker_repository and not args.docker_digest:
        status = "INVALID"
        invalid_reasons = "Submission is not a Docker image, please try again."
    else:
        # The new toil version doesn't seem to pull the docker config file from
        # .docker/config.json.
        config = synapseclient.Synapse().getConfigFile(configPath=args.synapse_config)
        authen = dict(config.items("authentication"))
        client = docker.DockerClient(base_url="unix://var/run/docker.sock")
        client.login(
            username=authen["username"],
            password=authen["authtoken"],
            registry="https://docker.synapse.org",
        )

        with tempfile.TemporaryDirectory(dir=os.getcwd()) as output_dir:
            # Update permissions so that non-root container can write to it
            new_permissions = 0o777
            os.chmod(output_dir, new_permissions)

            success, run_error = run_docker(syn, args, client, output_dir)
            if not success:
                status = "INVALID"
                invalid_reasons = run_error
            else:
                output_file = glob.glob(os.path.join(output_dir, "predictions.csv"))
                if output_file:
                    os.rename(output_file[0], os.path.join(os.getcwd(), "predictions.csv"))
                else:
                    status = "INVALID"
                    invalid_reasons = (
                        "Container did not generate a file called predictions.csv"
                    )
        remove_docker_image(client, f"{args.docker_repository}@{args.docker_digest}")

    with open("results.json", "w") as out:
        out.write(
            json.dumps(
                {
                    "submission_status": status,
                    "submission_errors": invalid_reasons,
                    "admin_folder": args.parentid,
                }
            )
        )


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-s", "--submissionid", required=True, help="Submission Id")
    parser.add_argument(
        "-p", "--docker_repository", required=True, help="Docker Repository"
    )
    parser.add_argument("-d", "--docker_digest", required=True, help="Docker Digest")
    parser.add_argument("-i", "--input_dir", required=True, help="Input Directory")
    parser.add_argument(
        "-c", "--synapse_config", required=True, help="credentials file"
    )
    parser.add_argument("--store", action="store_true", help="to store logs")
    parser.add_argument(
        "--parentid", required=True, help="Parent Id of submitter directory"
    )
    args = parser.parse_args()

    syn = synapseclient.Synapse(configPath=args.synapse_config)
    syn.login(silent=True)
    main(syn, args)
