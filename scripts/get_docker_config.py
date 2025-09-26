#!/usr/bin/env python
import argparse
import base64
import json

import synapseclient

parser = argparse.ArgumentParser()
parser.add_argument("-r", "--results", required=True, help="validation results")
parser.add_argument("-c", "--synapse_config", required=True, help="credentials file")
args = parser.parse_args()

# Must read in credentials (username and password)
config = synapseclient.Synapse().getConfigFile(configPath=args.synapse_config)
authen = dict(config.items("authentication"))
if authen.get("username") is None and authen.get("authtoken") is None:
    raise Exception("Config file must have username and authtoken")
authen_string = "{}:{}".format(authen["username"], authen["authtoken"])
docker_auth = base64.encodebytes(authen_string.encode("utf-8"))

result = {
    "docker_auth": docker_auth.decode("utf-8"),
    "docker_registry": "https://docker.synapse.org",
}
with open(args.results, "w") as o:
    o.write(json.dumps(result))
