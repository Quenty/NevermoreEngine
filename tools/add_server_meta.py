import os
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

contents = """{
  "className": "Camera"
}"""

root = find_vcs_root(__file__)
for server_folder in glob.glob(os.path.join(root, "src") + "/*/src/Server"):
  init_meta_json = os.path.join(server_folder, "init.meta.json")
  if os.path.exists(init_meta_json):
    print(init_meta_json)
  else:
    with open(init_meta_json, "w") as f:
      f.write(contents)

