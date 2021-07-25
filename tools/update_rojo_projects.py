import os
import json
import glob

# https://stackoverflow.com/questions/22081209/find-the-root-of-the-git-repository-where-the-file-lives
def find_vcs_root(test, dirs=(".git",)):
  prev, test = None, os.path.abspath(test)
  while prev != test:
    if any(os.path.isdir(os.path.join(test, d)) for d in dirs):
      return test
    prev, test = test, os.path.abspath(os.path.join(test, os.pardir))

  sys.exit('File not in git repository')
  return

def get_packagejson_path_for_rojo(rojo_project):
  return os.path.join(os.path.dirname(os.path.realpath(rojo_project)), "package.json")

root = find_vcs_root(__file__)
for rojo_project in glob.glob(os.path.join(root, "src") + "/*/default.project.json"):
  packagejson_path = get_packagejson_path_for_rojo(rojo_project)

  with open(rojo_project, "r") as file:
    data = json.loads(file.read())

  if os.path.isdir(os.path.join(os.path.dirname(os.path.realpath(rojo_project)), "node_modules")):
    with open(rojo_project, "w") as file:
      data["tree"] = {
        "$className": "Folder",
        "src": {
          "$path": "src"
        },
        "node_modules": {
          "$path": "node_modules"
        }
      }

      file.write(json.dumps(data, indent=2))
