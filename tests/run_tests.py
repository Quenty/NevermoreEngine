# Runs the tests

import os
import sys
import json
import subprocess
import pathlib
import random

if not os.path.isdir("tests/out"):
  os.mkdir("tests/out")

# https://stackoverflow.com/questions/22081209/find-the-root-of-the-git-repository-where-the-file-lives
def find_vcs_root(test, dirs=(".git",)):
  prev, test = None, os.path.abspath(test)
  while prev != test:
    if any(os.path.isdir(os.path.join(test, d)) for d in dirs):
      return test
    prev, test = test, os.path.abspath(os.path.join(test, os.pardir))

  sys.exit('File not in git repository')
  return

def build_test(package_path, package_name):
  build_file = f"tests/out/{package_name}.tests.project.json"

  rel_package_path = os.path.relpath(package_path, os.path.dirname(build_file))

  # Cosntruct the package here instead of hoping the package comes with all of the dependencies
  # since rojo doesn't have optional directories, so we break things all over the place if we don't
  # do this.
  project_json = {
    "name": f"{package_name}-tests",
    "tree": {
      "$className": "DataModel",
      "ReplicatedStorage": {
        "$className": "ReplicatedStorage",
        "Nevermore": {
          "$path": "../../src/loader"
        }
      },
      "ServerScriptService": {
        "$className": "ServerScriptService",
        "Nevermore": {
          "$className": "Folder",
          package_name: {
            "$path": rel_package_path.replace("\\", "/"),
          }
        }
      }
    }
  }

  if os.path.isdir(os.path.join(package_path, "node_modules", "@quenty")):
    project_json["tree"]["ServerScriptService"]["Nevermore"]["@quenty"] = {
      "$path": f"{rel_package_path}/node_modules/@quenty"
    }

  with open(build_file, "w") as file:
    file.write(json.dumps(project_json, indent=2))

  out_file = f"tests/out/{package_name}.tests.rbxlx"
  subprocess.check_call(f"rojo build {build_file} -o {out_file}")
  return out_file

root = find_vcs_root(__file__)
os.chdir(root)

to_scan = []
with os.scandir("src") as it:
  for entry in it:
    if entry.is_dir():
      to_scan.append(entry.name)

# random.shuffle(to_scan)
for item in to_scan:
  package_path = os.path.relpath(os.path.join("src", item))
  print(f"Building {package_path}")

  # NPM install the latest version
  os.chdir(package_path)

  if os.system("npm install") != 0:
    raise "Failed to run npm install"

  # if os.system("npx lerna bootstrap") != 0:
  #   raise "Failed to run lerna bootstrap"

  os.chdir(root)

  # Build tests
  out_file = build_test(package_path, item)

  # Run tests
  subprocess.check_call(f"run-in-roblox --place {out_file} --script tests/execute_tests.lua")