#!/bin/bash

# Script to setup and run VACASK processes
# Available processes are the Python modules in vacask package

# List of available processes (module names without .py extension)
PROCESSES=(
    "sg13g2tovc"
)

# Function to display the menu
show_menu() {
    echo "Available VACASK processes:"
    echo "--------------------------------"
    for i in "${!PROCESSES[@]}"; do
        echo "$((i + 1)). ${PROCESSES[i]}"
    done
    echo "--------------------------------"
}

# Function to validate the choice
validate_choice() {
    local choice=$1
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#PROCESSES[@]} ]; then
        echo "valid"
    else
        echo "invalid"
    fi
}

# Function to find vacask Python path
find_vacask_python_path() {
    # Try to find vacask python path in several locations
    
    # 1. Check if we're running from the vacask_installer directory
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local local_path="$script_dir/lib/vacask/python"
    if [ -d "$local_path" ]; then
        echo "$local_path"
        return 0
    fi
    
    # 2. Check parent directory (in case script is in a subdirectory)
    local parent_path="$(dirname "$script_dir")/lib/vacask/python"
    if [ -d "$parent_path" ]; then
        echo "$parent_path"
        return 0
    fi
    
    # 3. Check grandparent directory
    local grandparent_path="$(dirname "$(dirname "$script_dir")")/lib/vacask/python"
    if [ -d "$grandparent_path" ]; then
        echo "$grandparent_path"
        return 0
    fi
    
    # 4. Check common system paths
    local system_paths=(
        "/usr/local/lib/vacask/python"
        "/usr/lib/vacask/python"
        "/opt/vacask/lib/vacask/python"
    )
    
    for path in "${system_paths[@]}"; do
        if [ -d "$path" ]; then
            echo "$path"
            return 0
        fi
    done
    
    # 5. Try to find it using python3 itself
    if command -v python3 &> /dev/null; then
        local py_path=$(python3 -c "import sys; sys.path.insert(0, '/usr/local/lib/vacask/python'); import vacask; import os; print(os.path.dirname(vacask.__file__))" 2>/dev/null)
        if [ -n "$py_path" ] && [ -d "$py_path" ]; then
            # Get the parent directory (vacask/python)
            echo "$(dirname "$py_path")"
            return 0
        fi
    fi
    
    return 1
}

# Main script
echo "VACASK Process Setup Script"
echo "============================"
echo ""

# Show menu
show_menu

# Ask user to select a process
while true; do
    read -p "Select a process (1-${#PROCESSES[@]}): " choice
    if [ "$(validate_choice "$choice")" = "valid" ]; then
        break
    else
        echo "Invalid choice. Please enter a number between 1 and ${#PROCESSES[@]}."
    fi
done

# Get the selected process
selected_index=$((choice - 1))
selected_process="${PROCESSES[selected_index]}"

echo ""
echo "Selected process: $selected_process"
echo ""

# Find PYTHONPATH
PYTHONPATH=$(find_vacask_python_path)

if [ -z "$PYTHONPATH" ]; then
    echo "Error: Could not find vacask Python modules."
    echo ""
    echo "The vacask Python package should be in a directory like:"
    echo "  <install_dir>/lib/vacask/python"
    echo ""
    echo "Please ensure VACASK is installed and set PYTHONPATH manually:"
    echo "  export PYTHONPATH=<path_to_vacask_python>"
    echo "  ./setup-process.sh"
    exit 1
fi

echo "Using PYTHONPATH: $PYTHONPATH"

# Check if Python3 is available
if ! command -v python3 &> /dev/null; then
    echo "Error: python3 is not installed or not in PATH"
    exit 1
fi

# Run the selected process
echo "Running: PYTHONPATH=$PYTHONPATH python3 -m vacask.$selected_process --openvaf-options --target_cpu generic"
echo ""

PYTHONPATH="$PYTHONPATH" python3 -m vacask.$selected_process --openvaf-options --target_cpu generic

# Check the exit status
exit_status=$?
if [ $exit_status -ne 0 ]; then
    echo ""
    echo "Process exited with status: $exit_status"
fi

exit $exit_status
