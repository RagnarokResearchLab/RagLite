import json
import matplotlib.pyplot as plt
from datetime import datetime
import os

import sys

# Check if a filename is provided
if len(sys.argv) < 2:
    print("Please provide a JSON filename as an argument.")
    sys.exit(1)

filename = sys.argv[1]

# Construct the path to the JSON file
file_path = os.path.join("Exports", filename) + "-versions.json"

print("Loading data set from " + file_path)

# Load data from the JSON file
with open(file_path, 'r') as file:
    versions = json.load(file)

# Convert string keys to floats (JSON keys are always strings)
versions = {float(k): v for k, v in versions.items()}

# Extract version numbers and their counts
version_nums = list(versions.keys())
counts = list(versions.values())

# Flag to determine if the y-axis should be in logarithmic scale
use_log_scale = False
add_date_annotation = True

# Create a bar plot
plt.bar(version_nums, counts, color='blue')

# Title and labels
plot_title = 'Distribution of ' + filename.upper() + ' versions'
print("Generating plot: " + plot_title)
plt.title(plot_title)
plt.xlabel('Version Number')
plt.ylabel('Count (Log Scale)' if use_log_scale else 'Number of Files')
plt.xticks(version_nums)  # ensures that each version number is shown on the x-axis

# If the flag is set, change the y-axis to logarithmic scale
if use_log_scale:
    plt.yscale('log')

# Annotate with the current date
if add_date_annotation:
	current_date = datetime.now().strftime('%Y-%m-%d')
	plt.annotate(f"Snapshot: {current_date}",
             xy=(0.05, 0.95),
             xycoords='axes fraction',
             fontsize=10,
             fontweight='bold')

# Save the plot to a file
output_file_name = os.path.join("Exports", filename) + "-versions.png"
print("Saving plot as " + output_file_name)
plt.tight_layout()
plt.savefig(output_file_name, dpi=300)