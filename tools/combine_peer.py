import json
import os
import glob
from functools import lru_cache

# https://stackoverflow.com/questions/22081209/find-the-root-of-the-git-repository-where-the-file-lives
def find_vcs_root(test, dirs=(".git",)):
  prev, test = None, os.path.abspath(test)
  while prev != test:
    if any(os.path.isdir(os.path.join(test, d)) for d in dirs):
      return test
    prev, test = test, os.path.abspath(os.path.join(test, os.pardir))

  sys.exit('File not in git repository')
  return



def combine(dir_path, fromKey, toKey):
  if fromKey not in package_json:
    return

  source = package_json[fromKey]
  target = None
  if toKey in package_json:
  	target = package_json[toKey]
  else:
  	target = {}
  	package_json[toKey] = target

  for name in source:
    target[name] = source[name]

  package_json[fromKey] = {}

root = find_vcs_root(__file__)
for packagejson_path in glob.glob(os.path.join(root, "src") + "/*/package.json"):
  print(packagejson_path)
  package_json = None

  with open(packagejson_path, "r") as file:
    package_json = json.loads(file.read())

  dir_path = os.path.dirname(os.path.realpath(packagejson_path))

  combine(dir_path, "peerDependencies", "dependencies")

  print(package_json)
  with open(packagejson_path, "w") as file:
    file.write(json.dumps(package_json, indent=2).replace("\r\n", "\n"))