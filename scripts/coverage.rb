#!/usr/bin/env ruby

# Copyright (c) Microsoft Corporation.
# All rights reserved.
#
# This code is licensed under the MIT License.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

# Mirrors Broker CI's per-scheme export and completeness checks. Native xccov
# selects production sources; the original LLVM profile supplies all hit counts.
require 'json'
require 'open3'
require 'fileutils'
require 'digest'
require 'rexml/document'

module CommonCoreCoverage
  EXPECTED_SCHEMES = {
    'ios_library' => ['IdentityCore iOS'],
    'mac_library' => ['IdentityCore Mac']
  }.freeze

  def self.report_name(scheme)
    scheme.gsub(/[^A-Za-z0-9._-]/, '_')
  end

  def self.run(*command)
    puts command.map(&:inspect).join(' ')
    stdout, stderr, status = Open3.capture3(*command)
    warn stderr unless stderr.empty?
    raise "#{command.first} failed (#{status.exitstatus}): #{stderr}" unless status.success?
    if stderr.match?(/profile data may be out of date|mismatched/i)
      raise "Coverage inputs do not match: #{stderr}"
    end
    stdout
  end

  def self.executed_architecture(result)
    actions = result.fetch('actions').fetch('_values').select do |action|
      action.fetch('actionResult', {}).key?('testsRef')
    end
    architectures = actions.map { |action| action.dig('runDestination', 'targetArchitecture', '_value') }.uniq
    unless architectures.length == 1 && architectures.first && !architectures.first.empty?
      raise "Expected one executed test architecture, found #{architectures.inspect}"
    end
    architectures.first
  end

  def self.production_products(scheme)
    document = REXML::Document.new(File.read(scheme))
    products = REXML::XPath.match(document, '//TestAction/CodeCoverageTargets/BuildableReference')
    if products.empty?
      products = REXML::XPath.match(document, '//BuildActionEntry[@buildForTesting="YES"]/BuildableReference')
    end
    products.map { |node| node.attributes.fetch('BuildableName').to_s }
            .reject { |name| name.end_with?('.xctest') }.uniq
  end

  def self.validate_report(path)
    document = REXML::Document.new(File.read(path))
    # Zero hits are valid. Missing executable mappings are not.
    unless document.root&.name == 'coverage' &&
           document.root.attributes['lines-valid'].to_i > 0 &&
           !REXML::XPath.match(document, '//class/lines/line').empty?
      raise "Missing executable source coverage in #{path}"
    end
  end

  def self.export(scheme, derived_data, result_bundle,
                  project_path: 'IdentityCore/IdentityCore.xcodeproj',
                  workspace: 'IdentityCore.xcworkspace', root: 'build/coverage')
    name = report_name(scheme)
    output = File.join(root, 'reports', name)
    diagnostics = File.join(root, 'diagnostics', name)
    FileUtils.mkdir_p([output, diagnostics])
    report = File.join(output, "#{name}.cobertura.xml")
    FileUtils.rm_f(report)
    provenance = {
      'scheme' => scheme, 'derived_data' => File.expand_path(derived_data),
      'result_bundle' => File.expand_path(result_bundle), 'status' => 'failed'
    }

    begin
      require 'slather'
      provenance['slather'] = Slather::VERSION
      metadata = run('xcrun', 'xcresulttool', 'get', 'object', '--legacy',
                     '--path', result_bundle, '--format', 'json')
      File.write(File.join(diagnostics, 'result.json'), metadata)
      architecture = executed_architecture(JSON.parse(metadata))
      provenance['architecture'] = architecture
      profiles = Dir[File.join(derived_data, 'Build/ProfileData/*/Coverage.profdata')]
      raise "Expected exactly one profile for #{scheme}, found #{profiles.inspect}" unless profiles.length == 1
      profile = File.realpath(profiles.first)
      provenance['profile'] = { 'path' => profile, 'sha256' => Digest::SHA256.file(profile).hexdigest }
      provenance['revision'] = run('git', 'rev-parse', 'HEAD').strip
      provenance['xcode'] = run('xcodebuild', '-version').strip
      native_json = run('xcrun', 'xccov', 'view', '--report', '--json', result_bundle)
      File.write(File.join(diagnostics, 'xccov.json'), native_json)
      native = JSON.parse(native_json)

      project = Slather::Project.open(project_path)
      project.workspace = workspace
      project.scheme = scheme
      project.configuration = 'Debug'
      project.build_directory = File.expand_path(derived_data)
      project.arch = architecture
      project.coverage_service = :cobertura_xml
      project.output_directory = output
      scheme_path = File.join(project_path, 'xcshareddata/xcschemes', "#{scheme}.xcscheme")
      products = production_products(scheme_path)
      raise "No production coverage products in #{scheme}" if products.empty?
      project.binary_basename = products
      project.configure
      unless File.realpath(project.send(:profdata_file)) == profile
        raise "Slather selected a different profile for #{scheme}"
      end
      raise "Missing production binaries for #{products.inspect}" unless project.binary_file.length == products.length
      provenance['binaries'] = []
      project.binary_file.each do |binary|
        architectures = run('xcrun', 'lipo', '-archs', binary).split
        entry = { 'path' => File.realpath(binary), 'architectures' => architectures,
                  'sha256' => Digest::SHA256.file(binary).hexdigest }
        provenance['binaries'] << entry
        raise "#{binary} does not contain executed architecture #{architecture}" unless architectures.include?(architecture)
        export_binary = binary
        if binary.end_with?('.a')
          # Common Core is static on both platforms. Coverage executes in the
          # linked XCTest payload (hosted on iOS), not in the archive.
          document = REXML::Document.new(File.read(scheme_path))
          testables = REXML::XPath.match(document, '//TestableReference[@skipped="NO"]/BuildableReference')
          names = testables.map { |node| node.attributes.fetch('BuildableName').to_s }.uniq
          raise "Expected one linked test payload for #{scheme}, found #{names.inspect}" unless names.length == 1
          bundles = Dir[File.join(File.dirname(binary), '**', names.first)].select { |path| File.directory?(path) }
          raise "Expected one linked test bundle for #{scheme}, found #{bundles.inspect}" unless bundles.length == 1
          export_binary = project.find_binary_file_in_bundle(bundles.first)
          unless export_binary && File.file?(export_binary)
            raise "Missing linked test payload in #{bundles.first}"
          end
          slices = run('xcrun', 'lipo', '-archs', export_binary).split
          raise "#{export_binary} does not contain executed architecture #{architecture}" unless slices.include?(architecture)
          entry['export_architectures'] = slices
        end
        entry['export_path'] = File.realpath(export_binary)
        entry['export_sha256'] = Digest::SHA256.file(export_binary).hexdigest
      end

      checkout = File.realpath('.')
      # Ownership, not filename patterns: this excludes tests/mocks (including
      # MSIDExternalSSOContextMock.m compiled into libIdentityCore.a), generated
      # sources and dependencies without excluding production names like *Test*.
      tracked = run('git', 'ls-files', '-z', '--', 'IdentityCore/src').split("\0")
                   .to_h { |path| [File.expand_path(path, checkout), true] }
      production_sources = {}
      provenance['binaries'].each do |binary|
        targets = native.fetch('targets').select { |target| target.fetch('buildProductPath') == binary.fetch('path') }
        raise "Missing native production target for #{binary.fetch('path')}" unless targets.length == 1
        sources = targets.first.fetch('files').filter_map do |file|
          next unless File.exist?(file.fetch('path'))
          path = File.realpath(file.fetch('path'))
          path if tracked.key?(path) && file.fetch('executableLines') > 0
        end
        raise "No native tracked production sources for #{scheme}" if sources.empty?
        sources.each { |path| production_sources[path] = true }
      end
      project.binary_file = provenance['binaries'].map { |binary| binary.fetch('export_path') }
      project.binary_file.each_with_index do |binary, index|
        data = run('xcrun', 'llvm-cov', 'export', '-instr-profile', profile, '--arch', architecture, binary)
        File.write(File.join(diagnostics, "binary-#{index}.json"), data)
        unless JSON.parse(data).fetch('data').any? { |chunk| !chunk.fetch('files').empty? }
          raise "No coverage mapping in #{binary}"
        end
      end
      files = project.coverage_files.select do |file|
        production_sources.key?(file.source_file_pathname.realpath.to_s)
      end
      missing = production_sources.keys - files.map { |file| file.source_file_pathname.realpath.to_s }
      raise "Missing native production source mappings: #{missing.inspect}" unless missing.empty?
      raise "No tracked source coverage for #{scheme}" if files.empty?
      project.store_report(project.create_xml_report(files))
      FileUtils.mv(File.join(output, 'cobertura.xml'), report)
      validate_report(report)
      provenance['status'] = 'complete'
      puts "Collected #{scheme}: #{files.length} tracked source files -> #{report}"
    rescue StandardError, LoadError => error
      provenance['error'] = error.message
      FileUtils.rm_f(report)
      raise
    ensure
      File.write(File.join(diagnostics, 'provenance.json'), JSON.pretty_generate(provenance))
    end
  end

  def self.verify(target, root: 'build/coverage')
    errors = []
    EXPECTED_SCHEMES.fetch(target).each do |scheme|
      name = report_name(scheme)
      begin
        validate_report(File.join(root, 'reports', name, "#{name}.cobertura.xml"))
        provenance = JSON.parse(File.read(File.join(root, 'diagnostics', name, 'provenance.json')))
        raise "Collection did not complete for #{scheme}" unless provenance.fetch('status') == 'complete'
      rescue StandardError => error
        errors << "#{scheme}: #{error.message}"
      end
    end
    raise errors.join("\n") unless errors.empty?
  end

  def self.verify_publication(root)
    errors = []
    EXPECTED_SCHEMES.values.flatten.each do |scheme|
      begin
        reports = Dir[File.join(root, '**', "#{report_name(scheme)}.cobertura.xml")]
        raise "Expected one retained report, found #{reports.length}" unless reports.length == 1
        validate_report(reports.first)
      rescue StandardError => error
        errors << "#{scheme}: #{error.message}"
      end
    end
    raise errors.join("\n") unless errors.empty?
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    case ARGV.shift
    when 'export'
      raise 'Usage: coverage.rb export SCHEME DERIVED_DATA RESULT_BUNDLE' unless ARGV.length == 3
      CommonCoreCoverage.export(*ARGV)
    when 'verify'
      raise 'Usage: coverage.rb verify BUILD_TARGET' unless ARGV.length == 1
      CommonCoreCoverage.verify(ARGV.first)
    when 'verify-publication'
      raise 'Usage: coverage.rb verify-publication REPORT_ROOT' unless ARGV.length == 1
      CommonCoreCoverage.verify_publication(ARGV.first)
    else
      raise 'Usage: coverage.rb export|verify|verify-publication ...'
    end
  rescue StandardError, LoadError => error
    warn "##vso[task.logissue type=error]Coverage collection failed: #{error.message}"
    warn error.backtrace.join("\n")
    exit 1
  end
end
