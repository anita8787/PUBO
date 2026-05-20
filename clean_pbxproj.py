"""
Remove manually-added duplicate entries from pbxproj.
The project uses PBXFileSystemSynchronizedRootGroup, which auto-includes
all files in the Pubo/ folder. The xcodeproj gem added redundant entries.
"""

pbx_path = '/Users/anita/Cursor/PUBO/ios/Pubo/Pubo.xcodeproj/project.pbxproj'

# UUIDs added by the xcodeproj ruby script that we need to REMOVE
build_file_uuids = {
    '0DF12C827D7280BF5612A61C',  # FeedbackView.swift in Sources
    '68D7E8517C31C5617ABED08F',  # GeneralSettingsView.swift in Sources
    '696D9935D751FE929F0794D0',  # TripTrashManager.swift in Sources
    'AB6F513775A77A3D0ABC823B',  # SpinnerWheelView.swift in Sources
    'ACB73F2462DC9DF613ADD471',  # PostManagementView.swift in Sources
    'F735647031DDA0C48A93D45E',  # TripTrashView.swift in Sources
}

file_ref_uuids = {
    '0EB23DFB6AF74D393C99489D',  # FeedbackView.swift
    '35F14A14281B49506AA1EB7C',  # TripTrashView.swift
    '438185579F430E5CBA286B06',  # TripTrashManager.swift
    '80D613453975679D632FF53B',  # SpinnerWheelView.swift
    '9C7FEB142189806B63E29A54',  # GeneralSettingsView.swift
    'B50FD054A3A2725B53F19F51',  # PostManagementView.swift
}

group_uuids = {
    '08A3A036657FAB65C244A682',  # Pubo group (script-created)
    'DD7A64DEFB2D8401AEA4F221',  # Views group (script-created)
    '6893B448DCDD199373A0F482',  # NewUI group (script-created)
    '758CA03882A2220FE5912D0E',  # Services group (script-created)
}

with open(pbx_path, 'r') as f:
    lines = f.readlines()

def should_skip_block(lines, start_idx):
    """Return the end index of a multi-line block to skip, or -1 if single line."""
    line = lines[start_idx]
    stripped = line.strip()
    # If the block opens with { on same line, find matching }
    if stripped.endswith('{') or ('{' in stripped and '};' not in stripped):
        depth = stripped.count('{') - stripped.count('}')
        i = start_idx + 1
        while i < len(lines) and depth > 0:
            depth += lines[i].count('{') - lines[i].count('}')
            i += 1
        return i - 1
    return start_idx

kept_lines = []
i = 0
removed_count = 0

while i < len(lines):
    line = lines[i]
    stripped = line.strip()
    skip = False

    # Check if this line contains a UUID we want to remove
    found_uuid = None
    all_uuids = build_file_uuids | file_ref_uuids | group_uuids
    for uuid in all_uuids:
        if uuid in line:
            found_uuid = uuid
            break

    if found_uuid:
        # Skip the entire block if it's a definition block
        end_idx = should_skip_block(lines, i)
        if end_idx > i:
            print(f"  🗑  Removing block (lines {i+1}-{end_idx+1}): {stripped[:60]}")
            i = end_idx + 1
            removed_count += 1
            continue
        else:
            # It's a single-line reference (e.g., inside a files list)
            print(f"  🗑  Removing line {i+1}: {stripped[:70]}")
            i += 1
            removed_count += 1
            continue

    kept_lines.append(line)
    i += 1

with open(pbx_path, 'w') as f:
    f.writelines(kept_lines)

print(f"\n✅ Removed {removed_count} entries. Project file saved.")
print(f"   Remaining lines: {len(kept_lines)}")
