require 'xcodeproj'

project_path = 'ios/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the Runner group
runner_group = project.main_group.find_subpath('Runner', false)
if runner_group.nil?
  puts "Runner group not found!"
  exit 1
end

# Check if InfoPlist.strings already exists (as a VariantGroup)
variant_group = runner_group.children.find { |c| c.is_a?(Xcodeproj::Project::Object::PBXVariantGroup) && c.name == 'InfoPlist.strings' }

if variant_group.nil?
  variant_group = runner_group.new_variant_group('InfoPlist.strings')
end

# Add localized files
languages = ['en', 'zh-Hans', 'ar']
languages.each do |lang|
  file_path = "#{lang}.lproj/InfoPlist.strings"
  
  # Check if file reference already exists in the variant group
  # Note: variant group children are PBXFileReference
  ref = variant_group.children.find { |c| c.path == file_path }
  
  if ref.nil?
    # Create new reference inside the variant group
    ref = variant_group.new_reference(file_path)
    ref.name = lang
    puts "Added #{lang} to InfoPlist.strings"
  else
    puts "#{lang} already exists in InfoPlist.strings"
  end
end

# Add to Resources build phase
target = project.targets.find { |t| t.name == 'Runner' }
if target
  resources_phase = target.resources_build_phase
  # Check if variant group is already in resources
  # Note: resources_phase.files returns PBXBuildFile, we need to check their file_ref
  build_file = resources_phase.files.find { |f| f.file_ref == variant_group }
  
  if build_file.nil?
    resources_phase.add_file_reference(variant_group)
    puts "Added InfoPlist.strings to Resources build phase"
  else
    puts "InfoPlist.strings already in Resources build phase"
  end
end

project.save
puts "Successfully updated Xcode project."
