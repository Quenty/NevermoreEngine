import glob
import os
import json
import re

# https://stackoverflow.com/questions/22081209/find-the-root-of-the-git-repository-where-the-file-lives
def find_vcs_root(test, dirs=(".git",)):
  prev, test = None, os.path.abspath(test)
  while prev != test:
    if any(os.path.isdir(os.path.join(test, d)) for d in dirs):
      return test
    prev, test = test, os.path.abspath(os.path.join(test, os.pardir))

  sys.exit('File not in git repository')
  return

def get_format_string(column_sizes):
  format_string_list = []
  for i, column_size in enumerate(column_sizes):
    format_string_list.append(f"{{{i}:{column_size}s}}")

  format_string = "| " + " | ".join(format_string_list) + " |"
  return format_string

def get_docs_link(package_path):
  with open(os.path.join(package_path, "README.md"), "r") as file:
    readme_contents = file.read()
    result = re.findall("(https://quenty\\.github\\.io/NevermoreEngine/api/\\w+)", readme_contents)

    if not result:
      return None

    return result[0]

def get_package_name(package_path):
  with open(os.path.join(package_path, "README.md"), "r") as file:
    readme_contents = file.read()
    result = re.findall("^## (.+)", readme_contents)

    if not result:
      return None

    return result[0]

def get_column_sizes(headers, package_data_list):
  column_sizes = [len(header) for header in headers]
  for columns in package_data_list:
    for i, column in enumerate(columns):
      column_sizes[i] = max(len(column), column_sizes[i])
  return column_sizes

def get_package_data_list(root):
  package_data_list = []

  for packagejson_path in glob.glob(os.path.join(root, "src") + "/*/package.json"):
    with open(packagejson_path, "r") as file:
      package_path = packagejson_path[:-len("package.json")]
      package_data = json.loads(file.read())
      rel_package_path = os.path.relpath(package_path, root)

      install_command = f"`npm i {package_data['name']}`"
      docs_link = get_docs_link(package_path)
      package_name = get_package_name(package_path) or package_data['name']

      linked_name = None
      if docs_link:
        linked_name = f"[{package_name}]({docs_link})"
      else:
        linked_name = package_name

      replaced_src = rel_package_path.replace('\\', '/')
      npm_link = f"https://www.npmjs.com/package/{package_data['name']}"
      github_link = f"https://github.com/Quenty/NevermoreEngine/tree/main/{replaced_src}"
      changelog_link = f"https://github.com/Quenty/NevermoreEngine/tree/main/{replaced_src}/CHANGELOG.md"

      description = package_data['description']
      columns = [linked_name, description, install_command, f"[docs]({docs_link})", f"[source]({github_link})", f"[changelog]({changelog_link})", f"[npm]({npm_link})"]
      package_data_list.append(columns)

  def get_name(entry):
    return entry[0].lower()
  package_data_list.sort(key=get_name)

  return package_data_list

def update_readme(root, output):
  readme_contents = None
  with open(os.path.join(root, "readme.md"), "r") as file:
    readme_contents = file.read()

  with open(os.path.join(root, "readme.md"), "w") as file:
    replacement = f"<!--package-list-generated-start-->\n\n{output}\n\n<!--package-list-generated-end-->"
    readme_contents = re.sub("(<!--package-list-generated-start-->.*<!--package-list-generated-end-->)", replacement, readme_contents, count=1, flags=re.DOTALL)
    file.write(readme_contents)

def get_header_seperator(format_string, column_sizes):
  return format_string.format(*("-" * size for size in column_sizes))

root = find_vcs_root(__file__)

headers = ["Package", "Description", "Install", "docs", "source", "changelog", "npm"]

package_data_list = get_package_data_list(root)
column_sizes = get_column_sizes(headers, []) # don't expand columns beyond header size
format_string = get_format_string(column_sizes)

# Build output
output_list = []
output_list.append(format_string.format(*headers))
output_list.append(get_header_seperator(format_string, column_sizes))

for columns in package_data_list:
  output_list.append(format_string.format(*columns))

output = ""
output += f"There are {len(package_data_list)} packages in Nevermore.\n\n"
output += "\n".join(output_list)
update_readme(root, output)
