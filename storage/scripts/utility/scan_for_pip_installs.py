import os
import re
from collections import defaultdict

def search_pip_installs(base_dir, exclude_dirs, exclude_substrings=None):
    """
    Search .sh files for pip install commands, excluding specific directories and substrings.

    Args:
        base_dir (str): The directory to search within.
        exclude_dirs (list): List of directories to exclude from search.
        exclude_substrings (list): List of substrings to exclude from file or folder names.

    Returns:
        list: A list of pip packages found.
    """
    pip_packages = set()
    exclude_dirs = set(os.path.abspath(exclude) for exclude in exclude_dirs)
    exclude_substrings = exclude_substrings or []

    for root, dirs, files in os.walk(base_dir):
        # Exclude specified directories and those with excluded substrings
        dirs[:] = [
            d for d in dirs
            if os.path.abspath(os.path.join(root, d)) not in exclude_dirs and
               not any(substring in d for substring in exclude_substrings)
        ]

        for file in files:
            if not file.endswith(".sh"):  # Only scan .sh files
                continue

            # Exclude files with excluded substrings
            if any(substring in file for substring in exclude_substrings):
                continue

            file_path = os.path.join(root, file)
            try:
                with open(file_path, "r", encoding="utf-8") as f:
                    lines = f.readlines()
                    for line in lines:
                        if "pip install" in line:
                            packages = extract_pip_packages(line)
                            pip_packages.update(packages)
            except Exception as e:
                print(f"Error reading {file_path}: {e}")

    return list(pip_packages)


def extract_pip_packages(line):
    """
    Extract pip packages from a pip install command.
    """
    pip_match = re.search(r"pip\s+install\s+(.+)", line)
    if pip_match:
        return pip_match.group(1).strip().split()
    return []


def search_python_imports(base_dir, exclude_dirs, exclude_substrings=None):
    """
    Search .py files for import statements, excluding specific directories and substrings.

    Args:
        base_dir (str): The directory to search within.
        exclude_dirs (list): List of directories to exclude from search.
        exclude_substrings (list): List of substrings to exclude from file or folder names.

    Returns:
        list: A list of imported modules found.
    """
    imports = set()
    exclude_dirs = set(os.path.abspath(exclude) for exclude in exclude_dirs)
    exclude_substrings = exclude_substrings or []

    for root, dirs, files in os.walk(base_dir):
        # Exclude specified directories and those with excluded substrings
        dirs[:] = [
            d for d in dirs
            if os.path.abspath(os.path.join(root, d)) not in exclude_dirs and
               not any(substring in d for substring in exclude_substrings)
        ]

        for file in files:
            if not file.endswith(".py"):  # Only scan .py files
                continue

            # Exclude files with excluded substrings
            if any(substring in file for substring in exclude_substrings):
                continue

            file_path = os.path.join(root, file)
            try:
                with open(file_path, "r", encoding="utf-8") as f:
                    lines = f.readlines()
                    for line in lines:
                        if line.startswith("import ") or line.startswith("from "):
                            imports.update(extract_imports(line))
            except Exception as e:
                print(f"Error reading {file_path}: {e}")

    return list(imports)


def extract_imports(line):
    """
    Extract modules from an import statement.
    """
    imports = []
    import_match = re.match(r"(?:from|import)\s+([\w\.]+)", line)
    if import_match:
        imports.append(import_match.group(1))
    return imports


if __name__ == "__main__":
    base_directory = "/nsatt/storage/scripts"
    excluded_directories = [
        "/nsatt/storage/scripts/nsatt_web/venv"
    ]  # Specific excluded directories
    excluded_substrings = ["__pycache__", "sqlite-autoconf-3410200"]  # Substrings to exclude globally

    # Find pip installs
    print("Searching for pip install commands...")
    pip_installs = search_pip_installs(base_directory, excluded_directories, excluded_substrings)
    print(f"\nPip Packages Found:\n{'-'*40}")
    print("\n".join(pip_installs))

    # Find Python imports
    print("\nSearching for Python imports...")
    python_imports = search_python_imports(base_directory, excluded_directories, excluded_substrings)
    print(f"\nPython Imports Found:\n{'-'*40}")
    print("\n".join(python_imports))
