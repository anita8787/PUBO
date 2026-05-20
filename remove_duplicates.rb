require 'xcodeproj'

project_path = '/Users/anita/Cursor/PUBO/ios/Pubo/Pubo.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'Pubo' }
source_phase = target.source_build_phase

# Find and remove duplicate build file references (same path appearing more than once)
seen = {}
to_remove = []

source_phase.files.each do |build_file|
  next unless build_file.file_ref
  path = build_file.file_ref.real_path.to_s rescue build_file.file_ref.path.to_s
  if seen[path]
    to_remove << build_file
    puts "🗑  Removing duplicate: #{File.basename(path)}"
  else
    seen[path] = true
  end
end

to_remove.each { |bf| source_phase.remove_build_file(bf) }

project.save
puts ""
puts "Removed #{to_remove.size} duplicate(s). Project saved."
