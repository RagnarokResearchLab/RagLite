import matplotlib.pyplot as plt

# Data
versions = {
    2: 3,
    2.1: 242,
    2.3: 373,
    2.4: 2682,
    2.5: 49151
}

# Extract version numbers and their counts
version_nums = list(versions.keys())
counts = list(versions.values())

# Create a bar plot
plt.bar(version_nums, counts, color='blue')

# Title and labels
plt.title('Distribution of Versions')
plt.xlabel('Version Number')
plt.ylabel('Count')
plt.xticks(version_nums)  # ensures that each version number is shown on the x-axis

# Save the plot to a file before showing
plt.tight_layout()
plt.savefig('version_distribution.png', dpi=300)

# If you still want to display after saving, uncomment the line below
# plt.show()
