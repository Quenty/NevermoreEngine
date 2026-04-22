import json
import os
from pathlib import Path
import yaml

def find_pnpm_workspace_root():
    """Find the pnpm workspace root by looking for pnpm-workspace.yaml"""
    current = Path.cwd()
    while current != current.parent:
        if (current / "pnpm-workspace.yaml").exists():
            return current
        current = current.parent
    return None

def get_workspace_packages(root):
    """Parse pnpm-workspace.yaml to get package patterns"""
    workspace_file = root / "pnpm-workspace.yaml"
    with open(workspace_file, 'r') as f:
        config = yaml.safe_load(f)
    return config.get('packages', [])

def find_package_json_files(root, patterns):
    """Find all package.json files matching workspace patterns"""
    package_files = []
    for pattern in patterns:
        # Remove trailing /* or /**
        pattern = pattern.rstrip('/*')
        search_path = root / pattern
        if search_path.is_dir():
            for pkg in search_path.rglob('package.json'):
                # Skip node_modules
                if 'node_modules' not in pkg.parts:
                    package_files.append(pkg)
    return package_files

def add_preinstall_script(package_json_path):
    """Add preinstall script to package.json"""
    with open(package_json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    preinstall_cmd = "npx only-allow pnpm"

    if data.get('scripts', {}).get('preinstall') == preinstall_cmd:
        print(f"✓ Already configured: {package_json_path}")
        return False

    # If scripts doesn't exist, insert it after dependencies (or devDependencies)
    if 'scripts' not in data:
        # Create new ordered dict with scripts in the right place
        new_data = {}
        inserted = False
        for key, value in data.items():
            # Insert scripts after dependencies or devDependencies
            if not inserted and key in ('dependencies', 'devDependencies', 'peerDependencies', 'contributors'):
                new_data['scripts'] = {}
                inserted = True
            new_data[key] = value
        # If no dependencies found, scripts stays at the end (already added by dict update)
        if not inserted:
            new_data['scripts'] = {}
        data = new_data

    data['scripts']['preinstall'] = preinstall_cmd

    with open(package_json_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write('\n')

    print(f"✓ Updated: {package_json_path}")
    return True

def main():
    root = find_pnpm_workspace_root()
    # root = Path("C:/Users/James Onnen/Documents/Git/libraries/Raven")
    if not root:
        print("Error: Could not find pnpm-workspace.yaml")
        return

    print(f"Found workspace root: {root}")

    try:
        patterns = get_workspace_packages(root)
        package_files = find_package_json_files(root, patterns)
        print(package_files)
        # Also add to root package.json if it exists
        root_pkg = root / "package.json"
        if root_pkg.exists():
            package_files.insert(0, root_pkg)

        updated_count = 0
        for pkg_file in package_files:
            if add_preinstall_script(pkg_file):
                updated_count += 1

        print(f"\nDone! Updated {updated_count} package(s).")
    except ImportError:
        print("Error: PyYAML is required. Install with: pip install pyyaml")

if __name__ == "__main__":
    main()