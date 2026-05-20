require 'xcodeproj'

project_path = '/Users/anita/Cursor/PUBO/ios/Pubo/Pubo.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Files to add
new_files = {
  'Views/NewUI' => [
    '/Users/anita/Cursor/PUBO/ios/Pubo/Pubo/Views/NewUI/SpinnerWheelView.swift',
    '/Users/anita/Cursor/PUBO/ios/Pubo/Pubo/Views/NewUI/GeneralSettingsView.swift',
    '/Users/anita/Cursor/PUBO/ios/Pubo/Pubo/Views/NewUI/FeedbackView.swift',
    '/Users/anita/Cursor/PUBO/ios/Pubo/Pubo/Views/NewUI/PostManagementView.swift',
    '/Users/anita/Cursor/PUBO/ios/Pubo/Pubo/Views/NewUI/TripTrashView.swift',
  ],
  'Services' => [
    '/Users/anita/Cursor/PUBO/ios/Pubo/Pubo/Services/TripTrashManager.swift',
  ]
}

# Find the main target
target = project.targets.find { |t| t.name == 'Pubo' }
unless target
  puts "ERROR: Could not find target 'Pubo'"
  puts "Available targets: #{project.targets.map(&:name).join(', ')}"
  exit 1
end

# Helper: find or create a group by path segments
def find_group(project, path_segments)
  group = project.main_group
  path_segments.each do |segment|
    found = group.children.find { |c| c.is_a?(Xcodeproj::Project::Object::PBXGroup) && c.display_name == segment }
    unless found
      found = group.new_group(segment)
      puts "  Created group: #{segment}"
    end
    group = found
  end
  group
end

added = []
skipped = []

new_files.each do |group_path, file_paths|
  segments = ['Pubo'] + group_path.split('/')
  group = find_group(project, segments)

  file_paths.each do |file_path|
    file_name = File.basename(file_path)

    # Check if already in project
    already_exists = project.files.any? { |f| f.path && File.basename(f.path) == file_name }
    if already_exists
      skipped << file_name
      puts "  ⏭  Already in project: #{file_name}"
      next
    end

    file_ref = group.new_file(file_path)
    target.source_build_phase.add_file_reference(file_ref)
    added << file_name
    puts "  ✅ Added: #{file_name}"
  end
end

project.save

puts ""
puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
puts "Added   : #{added.join(', ')}"
puts "Skipped : #{skipped.join(', ')}"
puts "Done! Project saved."
