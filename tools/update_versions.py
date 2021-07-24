import glob
import os
import json
import semver

# https://stackoverflow.com/questions/22081209/find-the-root-of-the-git-repository-where-the-file-lives
def find_vcs_root(test, dirs=(".git",)):
  prev, test = None, os.path.abspath(test)
  while prev != test:
    if any(os.path.isdir(os.path.join(test, d)) for d in dirs):
      return test
    prev, test = test, os.path.abspath(os.path.join(test, os.pardir))

  sys.exit('File not in git repository')
  return

def update_version(parent, key):
  if key in parent:
    for name in parent[key]:
      parent[key][name] = "^1.0.0"

def ensure_snippet(content, find_index, snippet):
  if snippet in content:
    return content

  lines = content.split("\n")
  index = find_index(lines)
  if index == None:
    return content

  # Modify
  lines.insert(index, snippet)

  return "\n".join(lines)

def find_changelog(lines):
  index = lines.index("## Changelog")
  return index + 1

root = find_vcs_root(__file__)
for packagejson_path in glob.glob(os.path.join(root, "src") + "/*/package.json"):
  with open(packagejson_path, "r") as file:
    package_data = json.loads(file.read())

  package_data["version"] = "1.0.0"

  update_version(package_data, "dependencies")
  update_version(package_data, "peerDependencies")
  update_version(package_data, "devDependencies")

  with open(packagejson_path, "w") as file:
    file.write(json.dumps(package_data, indent=2))


for readme_path in glob.glob(os.path.join(root, "src") + "/*/README.md"):
  with open(readme_path, "r") as file:
    original = file.read()

  content = original
  content = ensure_snippet(content, find_changelog, """
### 1.0.0
Initial release""")

  if content != original:
    with open(readme_path, "w") as file:
      file.write(content)

