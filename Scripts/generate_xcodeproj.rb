#!/usr/bin/env ruby

require 'fileutils'
require 'pathname'
require 'rubygems'

root = File.expand_path('..', __dir__)
vendor_bundle = File.join(root, 'vendor', 'bundle')

if Dir.exist?(vendor_bundle)
  Gem.use_paths(vendor_bundle, [vendor_bundle])
end

begin
  require 'xcodeproj'
rescue LoadError
  warn 'error: missing ruby gem `xcodeproj`'
  warn 'hint: install with `gem install xcodeproj` or run bundle install in this repo'
  exit 1
end

PROJECT_NAME = 'Cusp'
APP_NAME = 'Cusp'
EXTENSION_NAME = 'CuspTunnel'

PROJECT_PATH = File.join(root, "#{PROJECT_NAME}.xcodeproj")

FileUtils.rm_rf(PROJECT_PATH)
project = Xcodeproj::Project.new(PROJECT_PATH)
project.root_object.attributes['LastSwiftUpdateCheck'] = '2640'
project.root_object.attributes['LastUpgradeCheck'] = '2640'

main_group = project.main_group
app_group = main_group.new_group('CuspApp', 'CuspApp')
extension_group = main_group.new_group('CuspTunnel', 'CuspTunnel')
sources_group = main_group.new_group('Sources', 'Sources')
shared_group = sources_group.new_group('CuspShared', 'CuspShared')
resources_group = main_group.new_group('Resources', 'Resources')
docs_group = main_group.new_group('Docs', 'Docs')
scripts_group = main_group.new_group('Scripts', 'Scripts')

def add_refs(group, base_path, glob)
  Dir.glob(File.join(base_path, glob)).sort.map do |path|
    relative_path = Pathname(path).relative_path_from(Pathname(base_path)).to_s
    group.new_reference(relative_path)
  end
end

app_target = project.new_target(:application, APP_NAME, :osx, '14.0')
extension_target = project.new_target(:app_extension, EXTENSION_NAME, :osx, '14.0')

project.root_object.attributes['TargetAttributes'] = {
  app_target.uuid => { 'ProvisioningStyle' => 'Automatic' },
  extension_target.uuid => { 'ProvisioningStyle' => 'Automatic' }
}

shared_source_refs = add_refs(shared_group, File.join(root, 'Sources', 'CuspShared'), '*.swift')
app_source_refs = add_refs(app_group, File.join(root, 'CuspApp'), '**/*.swift')
extension_source_refs = add_refs(extension_group, File.join(root, 'CuspTunnel'), '*.swift')

[
  'Info.plist',
  'Cusp.entitlements'
].each { |path| app_group.new_reference(path) }

[
  'Info.plist',
  'CuspTunnel.entitlements'
].each { |path| extension_group.new_reference(path) }

resource_refs = add_refs(resources_group, File.join(root, 'Resources'), '**/*')
docs_group.new_reference('MVP-Setup.md')
scripts_group.new_reference('generate_xcodeproj.rb')

app_target.add_file_references(shared_source_refs + app_source_refs)
extension_target.add_file_references(shared_source_refs + extension_source_refs)

resource_refs.each do |ref|
  next if File.directory?(File.join(root, 'Resources', ref.path))
  app_target.resources_build_phase.add_file_reference(ref, true)
  extension_target.resources_build_phase.add_file_reference(ref, true)
end

[app_target, extension_target].each do |target|
  target.build_configurations.each do |config|
    settings = config.build_settings
    settings['SWIFT_VERSION'] = '6.0'
    settings['MARKETING_VERSION'] = '0.1.0'
    settings['CURRENT_PROJECT_VERSION'] = '1'
    settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
    settings['CLANG_ENABLE_MODULES'] = 'YES'
    settings['CODE_SIGN_STYLE'] = 'Automatic'
    settings['ENABLE_HARDENED_RUNTIME'] = 'YES'
  end
end

app_target.build_configurations.each do |config|
  settings = config.build_settings
  settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.example.Cusp'
  settings['INFOPLIST_FILE'] = 'CuspApp/Info.plist'
  settings['CODE_SIGN_ENTITLEMENTS'] = 'CuspApp/Cusp.entitlements'
  settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  settings['LD_RUNPATH_SEARCH_PATHS'] = [
    '$(inherited)',
    '@executable_path/../Frameworks'
  ]
  settings['PRODUCT_NAME'] = APP_NAME
  settings['SWIFT_EMIT_LOC_STRINGS'] = 'YES'
end

extension_target.build_configurations.each do |config|
  settings = config.build_settings
  settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.example.Cusp.CuspTunnel'
  settings['INFOPLIST_FILE'] = 'CuspTunnel/Info.plist'
  settings['CODE_SIGN_ENTITLEMENTS'] = 'CuspTunnel/CuspTunnel.entitlements'
  settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
  settings['LD_RUNPATH_SEARCH_PATHS'] = [
    '$(inherited)',
    '@executable_path/../../Frameworks',
    '@loader_path/../../Frameworks'
  ]
  settings['SKIP_INSTALL'] = 'YES'
  settings['PRODUCT_NAME'] = EXTENSION_NAME
end

project.recreate_user_schemes
project.save

puts "Generated #{PROJECT_PATH}"
