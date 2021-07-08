# Utility script to make creating npm packages easier
# Author: Quenty

import os
import sys
import json

def read_file_path():
  file_path = os.path.abspath(sys.argv[1]);
  if not os.path.isfile(file_path):
    sys.exit(f'Bad file: "{file_path}"')
    return

  return file_path

# https://stackoverflow.com/questions/22081209/find-the-root-of-the-git-repository-where-the-file-lives
def find_vcs_root(test, dirs=(".git",)):
  prev, test = None, os.path.abspath(test)
  while prev != test:
    if any(os.path.isdir(os.path.join(test, d)) for d in dirs):
      return test
    prev, test = test, os.path.abspath(os.path.join(test, os.pardir))

  sys.exit('File not in git repository')
  return

def get_src_folder_type(rel_file_path):
  if "Modules\\Client" in rel_file_path:
    return "Client"
  elif "Modules\\Server" in rel_file_path:
    return "Server"
  elif "Modules\\Shared" in rel_file_path:
    return "Shared"
  else:
    sys.exit(f'Could not identify folder type from {rel_file_path}')
    return

def get_package_name_from_file_path(file_path):
  base_name = os.path.basename(file_path)
  name = os.path.splitext(base_name)[0]
  return name

def get_readme(package_name, usage, description):
  return f"""## {package_name}
<div align="center">
  <a href="http://quenty.github.io/api/">
    <img src="https://img.shields.io/badge/docs-website-green.svg" alt="Documentation" />
  </a>
  <a href="https://discord.gg/mhtGUS8">
    <img src="https://img.shields.io/badge/discord-nevermore-blue.svg" alt="Discord" />
  </a>
  <a href="https://github.com/Quenty/NevermoreEngine/actions">
    <img src="https://github.com/Quenty/NevermoreEngine/workflows/luacheck/badge.svg" alt="Actions Status" />
  </a>
</div>

{description}

## Installation
```
npm install @quenty/{package_name.lower()} --save
```
{usage}

## Changelog

### 0.0.0
Initial commit
"""

def get_file_content(file_path):
  with open(file_path, "r", encoding='utf-8') as file:
    return file.read()

def detect_require(content):
  return "require = require" in content

def get_peer_dependencies(content):
  if detect_require(content):
    return { "@quenty/loader": "~0.0.2" }
  else:
    return {}

def generate_usage(content):
  # Hahah, what is perf
  lines = content.split("\n")

  functions = [] # (func_str, doc_str)
  last_docs = None
  for line in lines:
    if line.startswith("--- "):
      last_docs = line.removeprefix("--- ")
    elif line.startswith("-- "):
      continue # do not reset last_docs
    elif line.startswith("function "):
      # avoid private methods
      if ":_" not in line:
        functions.append(
          (line.removeprefix("function "), last_docs))
      last_docs = None
    else:
      last_docs = None

  if not functions:
    return ""

  usage = ["\n## Usage", "Usage is designed to be simple.", ""]
  for func_tuple in functions:
    (func_str, doc_str) = func_tuple
    usage.append(f"### `{func_str}`")
    if (doc_str):
      usage.append(doc_str)
    usage.append("")

  return "\n".join(usage)

def get_package_json(package_name, peer_dependencies, description, tags):
  return json.dumps({
    "name": f"@quenty/{package_name.lower()}",
    "version": "0.0.0",
    "description": description,
    "keywords": [
      "Roblox",
      "Nevermore",
      "Lua"
    ] + tags,
    "contributors": [
      "Quenty"
    ],
    "license": "MIT",
    "repository": {
      "type": "git",
      "url": "https://github.com/Quenty/NevermoreEngine.git",
      "directory": f"src/{package_name.lower()}/"
    },
    "dependencies": {},
    "peerDependencies": peer_dependencies,
    "bugs": {
      "url": "https://github.com/Quenty/NevermoreEngine/issues"
    },
    "publishConfig": {
      "access": "public"
    }
  }, indent=2)

def get_default_project_json(package_name):
  return f"""{{
  "name": "{package_name}",
  "tree": {{
    "$path": "src"
  }}
}}
"""

def get_tags(rel_file_path):
  head = os.path.dirname(rel_file_path)
  split = head.split("\\")

  def allowed(word):
    return word not in ["Modules", "Shared", "Server", "Client"]

  tags = list(filter(allowed, split))
  return tags

def extract_description(contents):
  if not contents.startswith("--- "):
    return None

  # Hahah, what is perf
  lines = contents.split("\n")

  header_comments = []
  for line in lines:
    if line.startswith("-- @"):
      break
    else:
      for option in ["--- ", "-- "]:
        if line.startswith(option):
          header_comments.append(line.removeprefix(option))
          break
      else:
        break

  header_comments = [line.strip() for line in header_comments]
  return " ".join(header_comments)


def get_description(contents):
  description = extract_description(contents)

  if description:
    return description
  else:
    return input("No description in comment. Please provide one:")

def write_file(root, file_name, content):
  file_path = os.path.join(root, file_name)
  with open(file_path, "w") as file:
    file.write(content)

### 1. Read in file and determine what type it is (shared/client) ###
file_path = read_file_path()
repo_path = find_vcs_root(file_path)
rel_file_path = os.path.relpath(file_path, repo_path)
src_folder_type = get_src_folder_type(rel_file_path)

### 2. Make package folder ###
package_name = get_package_name_from_file_path(file_path)
package_root_path = os.path.join(repo_path, "src", package_name.lower())

### Generate metadata ###
content = get_file_content(file_path)
peer_dependencies = get_peer_dependencies(content)
description = get_description(content)
tags = get_tags(rel_file_path)
usage = generate_usage(content)

if not os.path.exists(package_root_path):
  os.mkdir(package_root_path)

### 3. Generate README ###
write_file(package_root_path, "README.md", get_readme(package_name, usage, description))

### 4. Generate default.project.json ###
write_file(package_root_path, "default.project.json", get_default_project_json(package_name))

### 5. Generate package.json ###
write_file(package_root_path, "package.json", get_package_json(package_name, peer_dependencies, description, tags))

### 6. Move file ###
new_file_folder_path = os.path.join(package_root_path, "src", src_folder_type)
os.makedirs(new_file_folder_path, exist_ok=True)

new_file_path = os.path.join(new_file_folder_path, os.path.basename(file_path))
os.rename(file_path, new_file_path)

### 7. Run npm install to generate package.json ###
os.chdir(package_root_path)
os.system("npm install")
