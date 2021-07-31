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

def get_packagejson_path_for_readme(readme):
  return os.path.join(os.path.dirname(os.path.realpath(readme)), "package.json")

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

def after_header(lines):
  return 1

def at_end(lines):
  return len(lines)

def with_no_changelog(lines):
  if "## Changelog" in lines:
    return None

  return at_end(lines)

def skip_whitespace(lines, index):
  while index < len(lines) and lines[index].strip() == "":
    index = index + 1
  return index

def skip_text_except_headers(lines, index):
  while index < len(lines) and lines[index].strip() != "" and not lines[index].strip().startswith("#"):

    index = index + 1
  return index

def at_installation(lines):
  if "## Installation" in lines:
    return None

  # end of header
  index = lines.index("</div>")

  # skip all whitespace
  index = skip_whitespace(lines, index + 1)

  # skip description (if we have it)
  index = skip_text_except_headers(lines, index)

  # skip
  index = min(index + 1, skip_whitespace(lines, index + 1))

  return index

badges = """<div align="center">
  <a href="http://quenty.github.io/api/">
    <img src="https://img.shields.io/badge/docs-website-green.svg" alt="Documentation" />
  </a>
  <a href="https://discord.gg/mhtGUS8">
    <img src="https://img.shields.io/badge/discord-nevermore-blue.svg" alt="Discord" />
  </a>
  <a href="https://github.com/Quenty/NevermoreEngine/actions">
    <img src="https://github.com/Quenty/NevermoreEngine/actions/workflows/build.yml/badge.svg" alt="Build and release status" />
  </a>
</div>"""

changelog = """## Changelog

### 0.0.1
Added documentation

### 0.0.0
Initial commit"""

def get_installation_text(package_data):
  return f"""## Installation
```
npm install {package_data["name"]} --save
```
"""

def remove_change_log(content):
  if "## Changelog" not in content:
    return content

  lines = content.split("\n")
  index = lines.index("## Changelog")

  lines = lines[:index]

  return "\n".join(lines)

root = find_vcs_root(__file__)
for readme_path in glob.glob(os.path.join(root, "src") + "/*/README.md"):
  packagejson_path = get_packagejson_path_for_readme(readme_path)

  with open(readme_path, "r") as file:
    original = file.read()

  with open(packagejson_path, "r") as file:
    package_data = json.loads(file.read())
    package_version = semver.VersionInfo.parse(package_data["version"])

  content = original
  content = ensure_snippet(content, after_header, badges)
  content = ensure_snippet(content, at_installation, get_installation_text(package_data))
  content = remove_change_log(content)

  if content != original:
    package_version = package_version.bump_patch()
    print(f"Updated {readme_path} to {package_version}")

    with open(readme_path, "w") as file:
      file.write(content)

    #with open(packagejson_path, "w") as file:
    #  package_data["version"] = str(package_version)
    # file.write(json.dumps(package_data, indent=2))
