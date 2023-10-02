import json
import matplotlib.pyplot as plt
from datetime import datetime

# Load data from JSON file
with open('data.json', 'r') as file:
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
plt.title('Distribution of Versions')
plt.xlabel('Version Number')
plt.ylabel('Count (Log Scale)' if use_log_scale else 'Count')
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
plt.tight_layout()
plt.savefig('version_distribution.png', dpi=300)
