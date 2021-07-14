from git import Repo
import os

repo = Repo("C:\\Users\\jonne\\Documents\\Git\\libraries\\Nevermore")
assert not repo.bare

for file_path in repo.untracked_files:
	if file_path.endswith("package-lock.json"):
		package_name = os.path.dirname(os.path.abspath(file_path)).split("\\")[-1]

		repo.index.add(file_path)
		repo.index.commit(f"Fixup {package_name}")
		print(f"Added commit for {package_name}")
