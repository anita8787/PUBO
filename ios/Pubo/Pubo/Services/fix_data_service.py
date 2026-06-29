import re

file_path = "DataService.swift"
with open(file_path, "r") as f:
    content = f.read()

deprecated_tag = '@available(*, deprecated, message: "Trips are now fully migrated to Firebase. Do not use legacy Python REST APIs.")\n    '

# Functions to deprecate
funcs = [
    "func fetchTrips",
    "func createTrip",
    "func getTrip",
    "func deleteTrip",
    "func updateTrip",
    "func addSpot",
    "func updateSpot",
    "func deleteSpot",
    "func reorderSpots"
]

for func in funcs:
    pattern = r'( {4})(' + func + r')'
    replacement = r'\1' + deprecated_tag.strip() + r'\n\1\2'
    content = re.sub(pattern, replacement, content)

with open(file_path, "w") as f:
    f.write(content)

print("Patch applied to DataService.swift")
