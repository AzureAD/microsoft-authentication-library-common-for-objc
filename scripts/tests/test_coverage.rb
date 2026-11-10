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
#
# Fixtures cover input provenance, production scope and CI handoff without Xcode.
require 'minitest/autorun'
require 'minitest/mock'
require 'tmpdir'
require 'pathname'
require 'slather'
require 'yaml'
require_relative '../coverage'

class CoverageTests < Minitest::Test
  REPO = File.expand_path('../..', __dir__)
  REPORT = '<coverage lines-valid="1" lines-covered="0"><sources><source>/build-agent/checkout</source></sources>' \
           '<packages><package><classes>' \
           '<class filename="IdentityCore/src/owned.m"><lines><line number="1" hits="0"/></lines></class>' \
           '</classes></package></packages></coverage>'

  class ProjectStub
    attr_accessor :workspace, :scheme, :configuration, :build_directory, :arch,
                  :coverage_service, :output_directory, :binary_basename,
                  :binary_file, :coverage_files, :profile, :exported_files
    def configure; end
    def profdata_file
      profile
    end
    def find_binary_file_in_bundle(bundle)
      File.join(bundle, 'test-payload')
    end
    def create_xml_report(files)
      self.exported_files = files
      REPORT
    end
    def store_report(report)
      File.write(File.join(output_directory, 'cobertura.xml'), report)
    end
  end

  def setup
    @directory = Dir.mktmpdir('common-core-coverage-test')
    @root = File.join(@directory, 'coverage')
    @derived = File.join(@directory, 'derived')
    @profile = File.join(@derived, 'Build/ProfileData/device/Coverage.profdata')
    FileUtils.mkdir_p(File.dirname(@profile))
    File.write(@profile, 'profile')
    @binary = File.join(@derived, 'libIdentityCore.a')
    @payload = File.join(@derived, 'IdentityCoreTests.xctest/test-payload')
    FileUtils.mkdir_p(File.dirname(@payload))
    File.write(@binary, 'archive')
    File.write(@payload, 'linked payload')
    @owned = Pathname(File.join(@directory, 'MSIDTestProduction.m'))
    @mock = Pathname(File.join(@directory, 'MSIDExternalSSOContextMock.m'))
    @generated = Pathname(File.join(@derived, 'GeneratedAssetSymbols.swift'))
    [@owned, @mock, @generated].each { |path| path.write('source') }
    @project = ProjectStub.new
    @project.profile = @profile
    @project.binary_file = [@binary]
    @project.coverage_files = [@owned, @mock, @generated].map do |path|
      Struct.new(:source_file_pathname).new(path)
    end
    @commands = []
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def with_method(object, name, implementation)
    original = object.method(name)
    object.define_singleton_method(name) { |*args| implementation.call(*args) }
    yield
  ensure
    object.define_singleton_method(name, original)
  end

  def result(*architectures)
    { 'actions' => { '_values' => architectures.map do |architecture|
      { 'actionResult' => { 'testsRef' => {} },
        'runDestination' => { 'targetArchitecture' => { '_value' => architecture } } }
    end } }
  end

  def command_result(*command)
    @commands << command
    return 'fixture-revision' if command == ['git', 'rev-parse', 'HEAD']
    return 'Xcode fixture' if command == ['xcodebuild', '-version']
    case command[1]
    when 'xcresulttool' then JSON.generate(result('arm64'))
    when 'xccov'
      JSON.generate('targets' => [{ 'buildProductPath' => File.realpath(@binary),
                                   'files' => [@owned, @mock].map do |path|
                                     { 'path' => path.realpath.to_s, 'executableLines' => 1 }
                                   end }])
    when 'lipo' then 'x86_64 arm64'
    when 'llvm-cov' then '{"data":[{"files":[{"filename":"owned.m"}]}]}'
    when 'ls-files' then "#{@owned.realpath}\0"
    else raise "Unexpected command: #{command.inspect}"
    end
  end

  def export(scheme = 'IdentityCore Mac', command: method(:command_result))
    project = @project
    with_method(Slather::Project, :open, ->(*) { project }) do
      with_method(CommonCoreCoverage, :run, command) do
        CommonCoreCoverage.export(scheme, @derived, 'result.xcresult',
                                  project_path: File.join(REPO, 'IdentityCore/IdentityCore.xcodeproj'),
                                  root: @root)
      end
    end
  end

  def report(scheme = 'IdentityCore Mac')
    name = CommonCoreCoverage.report_name(scheme)
    File.join(@root, 'reports', name, "#{name}.cobertura.xml")
  end

  def provenance(scheme = 'IdentityCore Mac')
    name = CommonCoreCoverage.report_name(scheme)
    JSON.parse(File.read(File.join(@root, 'diagnostics', name, 'provenance.json')))
  end

  def test_architecture_is_executed_slice_not_agent_cpu_or_build_action
    metadata = result('x86_64', 'x86_64')
    metadata['actions']['_values'] << { 'runDestination' => { 'targetArchitecture' => { '_value' => 'arm64' } } }
    assert_equal 'x86_64', CommonCoreCoverage.executed_architecture(metadata)
    [result, result(nil), result(''), result('arm64', 'x86_64')].each do |data|
      assert_raises(RuntimeError) { CommonCoreCoverage.executed_architecture(data) }
    end
  end

  def test_existing_schemes_select_production_archive_not_tests
    CommonCoreCoverage::EXPECTED_SCHEMES.values.flatten.each do |scheme|
      path = File.join(REPO, 'IdentityCore/IdentityCore.xcodeproj/xcshareddata/xcschemes', "#{scheme}.xcscheme")
      assert_equal ['libIdentityCore.a'], CommonCoreCoverage.production_products(path)
    end
    assert_equal %w[ios_library mac_library], CommonCoreCoverage::EXPECTED_SCHEMES.keys
  end

  def test_static_export_uses_original_profile_linked_payload_and_owned_native_scope
    %w[arm64 x86_64].each do |architecture|
      command = lambda do |*args|
        args[1] == 'xcresulttool' ? JSON.generate(result(architecture)) : command_result(*args)
      end
      export(command: command)
      assert_equal [@project.coverage_files.first], @project.exported_files
      assert_equal 'complete', provenance['status']
      assert_equal 'fixture-revision', provenance['revision']
      assert_equal architecture, @project.arch
      assert_equal Digest::SHA256.file(@profile).hexdigest, provenance['profile']['sha256']
      assert_equal File.realpath(@payload), provenance['binaries'].first['export_path']
      assert_includes @commands, ['xcrun', 'llvm-cov', 'export', '-instr-profile',
                                 File.realpath(@profile), '--arch', architecture, File.realpath(@payload)]
      assert_includes @commands, ['git', 'ls-files', '-z', '--', 'IdentityCore/src']
      CommonCoreCoverage.validate_report(report)
      @project.binary_file = [@binary]
    end
  end

  def test_hosted_ios_payload_is_resolved_inside_scheme_local_app
    hosted = File.join(@derived, 'MSIDTestsHostApp.app/PlugIns/IdentityCoreTests.xctest')
    FileUtils.mkdir_p(File.dirname(hosted))
    FileUtils.mv(File.dirname(@payload), hosted)
    export('IdentityCore iOS')
    assert_equal File.realpath(File.join(hosted, 'test-payload')),
                 provenance('IdentityCore iOS')['binaries'].first['export_path']
  end

  def test_missing_and_ambiguous_profiles_fail_without_guessing
    File.delete(@profile)
    assert_raises(RuntimeError) { export }
    assert_match 'exactly one profile', provenance['error']
    File.write(@profile, 'profile')
    FileUtils.mkdir_p(File.join(@derived, 'Build/ProfileData/other'))
    File.write(File.join(@derived, 'Build/ProfileData/other/Coverage.profdata'), 'profile')
    assert_raises(RuntimeError) { export }
    assert_match 'exactly one profile', provenance['error']
  end

  def test_slather_profile_mismatch_fails
    @project.profile = @binary
    assert_raises(RuntimeError) { export }
    assert_match 'different profile', provenance['error']
  end

  def test_missing_binary_slice_or_linked_payload_fails
    @project.binary_file = []
    assert_raises(RuntimeError) { export }
    @project.binary_file = [@binary]
    command = ->(*args) { args[1] == 'lipo' ? 'x86_64' : command_result(*args) }
    assert_raises(RuntimeError) { export(command: command) }
    assert_match 'executed architecture arm64', provenance['error']
    File.delete(@payload)
    assert_raises(RuntimeError) { export }
    assert_match 'Missing linked test payload', provenance['error']
  end

  def test_ambiguous_linked_bundles_fail_instead_of_selecting_first
    FileUtils.mkdir_p(File.join(@derived, 'Other.app/PlugIns/IdentityCoreTests.xctest'))
    assert_raises(RuntimeError) { export }
    assert_match 'Expected one linked test bundle', provenance['error']
  end

  def test_missing_or_ambiguous_native_target_fails
    [[], [1, 2]].each do |targets|
      command = lambda do |*args|
        if args[1] == 'xccov'
          JSON.generate('targets' => targets.map { { 'buildProductPath' => File.realpath(@binary) } })
        else
          command_result(*args)
        end
      end
      assert_raises(RuntimeError) { export(command: command) }
      assert_match 'Missing native production target', provenance['error']
    end
  end

  def test_missing_native_source_mapping_never_silently_drops_production
    @project.coverage_files.shift
    assert_raises(RuntimeError) { export }
    assert_match 'Missing native production source mappings', provenance['error']
    refute File.exist?(report)
  end

  def test_empty_mapping_or_failed_export_keeps_other_scheme_and_removes_stale_report
    export
    original = File.read(report)
    @project.binary_file = [@binary]
    write_complete('IdentityCore iOS')
    command = lambda do |*args|
      args[1] == 'llvm-cov' ? '{"data":[{"files":[]}]}' : command_result(*args)
    end
    assert_raises(RuntimeError) { export('IdentityCore iOS', command: command) }
    refute File.exist?(report('IdentityCore iOS'))
    assert_equal 'failed', provenance('IdentityCore iOS')['status']
    assert_equal original, File.read(report)
  end

  def write_complete(scheme)
    FileUtils.mkdir_p(File.dirname(report(scheme)))
    File.write(report(scheme), REPORT)
    name = CommonCoreCoverage.report_name(scheme)
    directory = File.join(@root, 'diagnostics', name)
    FileUtils.mkdir_p(directory)
    File.write(File.join(directory, 'provenance.json'), '{"status":"complete"}')
  end

  def test_zero_hits_are_valid_but_missing_failed_or_ambiguous_reports_are_not
    CommonCoreCoverage::EXPECTED_SCHEMES.values.flatten.each { |scheme| write_complete(scheme) }
    CommonCoreCoverage.verify('ios_library', root: @root)
    CommonCoreCoverage.verify('mac_library', root: @root)
    CommonCoreCoverage.verify_publication(File.join(@root, 'reports'))
    basenames = Dir[File.join(@root, 'reports/**/*.xml')].map { |path| File.basename(path) }
    assert_equal 2, basenames.uniq.length
    duplicate = File.join(@root, 'reports/duplicate')
    FileUtils.mkdir_p(duplicate)
    File.write(File.join(duplicate, File.basename(report)), REPORT)
    assert_raises(RuntimeError) { CommonCoreCoverage.verify_publication(File.join(@root, 'reports')) }
    FileUtils.remove_entry(duplicate)
    File.delete(report)
    assert_raises(StandardError) { CommonCoreCoverage.verify('mac_library', root: @root) }
    assert_raises(RuntimeError) { CommonCoreCoverage.verify_publication(File.join(@root, 'reports')) }
    write_complete('IdentityCore Mac')
    File.write(File.join(@root, 'diagnostics/IdentityCore_Mac/provenance.json'), '{"status":"failed"}')
    assert_raises(RuntimeError) { CommonCoreCoverage.verify('mac_library', root: @root) }
  end

  def test_empty_or_malformed_xml_fails
    path = File.join(@directory, 'report.xml')
    ['', '<coverage/>', '<coverage lines-valid="0"/>', '<broken'].each do |xml|
      File.write(path, xml)
      assert_raises(StandardError) { CommonCoreCoverage.validate_report(path) }
    end
  end

  def test_run_forwards_arguments_and_reports_command_failure
    command = ['xcrun', 'llvm-cov', 'export', 'binary with spaces']
    status = Minitest::Mock.new
    status.expect(:success?, false)
    status.expect(:exitstatus, 9)
    capture = lambda do |*args|
      assert_equal command, args
      ['partial output', 'export failed', status]
    end
    with_method(Open3, :capture3, capture) do
      _, stderr = capture_io do
        error = assert_raises(RuntimeError) { CommonCoreCoverage.run(*command) }
        assert_equal 'xcrun failed (9): export failed', error.message
      end
      assert_equal "export failed\n", stderr
    end
    status.verify
  end

  def test_run_rejects_mismatched_inputs_even_when_command_succeeds
    command = ['xcrun', 'llvm-cov', 'export', 'binary with spaces']
    warning = 'profile data may be out of date - object is newer'
    status = Minitest::Mock.new
    status.expect(:success?, true)
    capture = lambda do |*args|
      assert_equal command, args
      ['coverage output', warning, status]
    end
    with_method(Open3, :capture3, capture) do
      _, stderr = capture_io do
        error = assert_raises(RuntimeError) { CommonCoreCoverage.run(*command) }
        assert_equal "Coverage inputs do not match: #{warning}", error.message
      end
      assert_equal "#{warning}\n", stderr
    end
    status.verify
  end

  def publication_inputs
    CommonCoreCoverage::EXPECTED_SCHEMES.values.flatten.each { |scheme| write_complete(scheme) }
    source = File.join(@directory, 'IdentityCore/src/owned.m')
    FileUtils.mkdir_p(File.dirname(source))
    File.write(source, 'owned source')
  end

  def prepare_publication
    command = lambda do |*args|
      assert_equal ['git', '-C', File.realpath(@directory), 'ls-files', '-z', '--', 'IdentityCore/src'], args
      "IdentityCore/src/owned.m\0"
    end
    with_method(CommonCoreCoverage, :run, command) do
      CommonCoreCoverage.prepare_publication(File.join(@root, 'reports'),
                                             File.join(@directory, 'publication'),
                                             checkout: @directory)
    end
  end

  def test_publication_rebases_only_source_root_and_preserves_originals_and_zero_hits
    publication_inputs
    originals = Dir[File.join(@root, 'reports/**/*.xml')].to_h { |path| [path, File.read(path)] }
    prepare_publication
    originals.each do |path, xml|
      assert_equal xml, File.read(path)
      expected = REXML::Document.new(xml)
      REXML::XPath.first(expected, '/coverage/sources/source').text = File.realpath(@directory)
      normalized = File.read(File.join(@directory, 'publication', File.basename(path)))
      assert_equal expected.to_s, normalized
      document = REXML::Document.new(normalized)
      assert_equal '0', document.root.attributes['lines-covered']
      assert_equal 'IdentityCore/src/owned.m', REXML::XPath.first(document, '//class').attributes['filename']
      assert_equal '0', REXML::XPath.first(document, '//line').attributes['hits']
    end
    CommonCoreCoverage.verify_publication(File.join(@directory, 'publication'))
  end

  def test_publication_rejects_traversal_absolute_windows_and_unowned_sources_independently
    publication_inputs
    ['../owned.m', 'IdentityCore/src/../src/owned.m', '/IdentityCore/src/owned.m',
     'C:\\checkout\\IdentityCore\\src\\owned.m', 'IdentityCore//src/owned.m',
     'IdentityCore/tests/helper.m', 'IdentityCore/src/untracked.m'].each do |path|
      File.write(report, REPORT.sub('IdentityCore/src/owned.m', path))
      error = assert_raises(RuntimeError) { prepare_publication }
      assert_match 'Unowned or noncanonical source path', error.message
      refute File.exist?(File.join(@directory, 'publication', File.basename(report)))
      assert File.file?(File.join(@directory, 'publication', File.basename(report('IdentityCore iOS'))))
    end
  end

  def test_publication_rejects_missing_sources_and_symlinks_outside_checkout
    publication_inputs
    source = File.join(@directory, 'IdentityCore/src/owned.m')
    File.delete(source)
    error = assert_raises(RuntimeError) { prepare_publication }
    assert_match 'Missing or redirected source path', error.message
    Dir.mktmpdir('external-source') do |outside|
      external = File.join(outside, 'owned.m')
      File.write(external, 'not owned by checkout')
      File.symlink(external, source)
      error = assert_raises(RuntimeError) { prepare_publication }
      assert_match 'Missing or redirected source path', error.message
    end
  end

  def test_publication_clears_stale_copies_and_preserves_valid_peer_on_missing_or_duplicate_input
    publication_inputs
    prepare_publication
    File.delete(report)
    error = assert_raises(RuntimeError) { prepare_publication }
    assert_match 'found 0', error.message
    refute File.exist?(File.join(@directory, 'publication', File.basename(report)))
    assert File.file?(File.join(@directory, 'publication', File.basename(report('IdentityCore iOS'))))
    write_complete('IdentityCore Mac')
    duplicate = File.join(@root, 'reports/duplicate')
    FileUtils.mkdir_p(duplicate)
    File.write(File.join(duplicate, File.basename(report)), REPORT)
    error = assert_raises(RuntimeError) { prepare_publication }
    assert_match 'found 2', error.message
    refute File.exist?(File.join(@directory, 'publication', File.basename(report)))
  end

  def test_publication_requires_one_source_root_and_valid_xml
    publication_inputs
    [REPORT.sub('<source>/build-agent/checkout</source>', ''),
     REPORT.sub('</sources>', '<source>/other/root</source></sources>'),
     '<broken'].each do |xml|
      File.write(report, xml)
      assert_raises(RuntimeError) { prepare_publication }
      refute File.exist?(File.join(@directory, 'publication', File.basename(report)))
      assert File.file?(File.join(@directory, 'publication', File.basename(report('IdentityCore iOS'))))
    end
  end

  def test_publication_output_must_not_overlap_retained_inputs
    publication_inputs
    root = File.join(@root, 'reports')
    [root, File.join(root, 'normalized'), @root].each do |output|
      assert_raises(RuntimeError) do
        CommonCoreCoverage.prepare_publication(root, output, checkout: @directory)
      end
      assert_equal REPORT, File.read(report)
    end
    alias_path = File.join(@directory, 'retained-alias')
    File.symlink(root, alias_path)
    assert_raises(RuntimeError) do
      CommonCoreCoverage.prepare_publication(root, alias_path, checkout: @directory)
    end
    assert_equal REPORT, File.read(report)
  end

  def test_publication_removes_staged_xml_before_a_checkout_validation_failure
    publication_inputs
    prepare_publication
    output = File.join(@directory, 'publication')
    File.write(File.join(output, 'stale.cobertura.xml'), REPORT)
    command = ->(*) { raise 'git ownership validation failed' }
    with_method(CommonCoreCoverage, :run, command) do
      assert_raises(RuntimeError) do
        CommonCoreCoverage.prepare_publication(File.join(@root, 'reports'), output,
                                               checkout: @directory)
      end
    end
    assert_empty Dir[File.join(output, '*.cobertura.xml')]
    assert_equal REPORT, File.read(report)
  end

  def test_publication_rejects_tracked_symlink_to_unowned_source_inside_checkout
    publication_inputs
    source = File.join(@directory, 'IdentityCore/src/owned.m')
    File.delete(source)
    File.symlink(@mock, source)
    error = assert_raises(RuntimeError) { prepare_publication }
    assert_match 'Missing or redirected source path', error.message
    assert_empty Dir[File.join(@directory, 'publication/*.cobertura.xml')]
  end

  def pipeline
    YAML.load_file(File.join(REPO, 'azure_pipelines/pr-validation.yml'))
  end

  def collection_steps
    YAML.load_file(File.join(REPO, 'azure_pipelines/templates/coverage-collection.yml')).fetch('steps')
  end

  def publication
    pipeline.fetch('jobs').find { |job| job['job'] == 'Publish_coverage' }
  end

  def test_publication_is_dependent_only_and_runs_native_publisher_once
    assert_equal %w[Validate_Pull_Request_iOS Validate_Pull_Request_macOS], publication['dependsOn']
    assert_equal 'succeededOrFailed()', publication['condition']
    steps = publication.fetch('steps')
    publishers = steps.select { |step| step['task'] == 'PublishCodeCoverageResults@2' }
    assert_equal 1, publishers.length
    assert_equal true, publishers.first.fetch('inputs')['failIfCoverageEmpty']
    assert_equal 'succeededOrFailed()', publishers.first['condition']
    refute_match(/build.py|xcodebuild/, steps.to_s)
    prepare = steps.find { |step| step.dig('inputs', 'script').to_s.include?('prepare-publication') }
    assert_equal 'succeededOrFailed()', prepare['condition']
    assert steps.index(prepare) < steps.index(publishers.first)
    assert_includes prepare['inputs']['script'], 'build/coverage/reports build/coverage/publication-reports'
    assert_includes publishers.first['inputs']['summaryFileLocation'], '/publication-reports/*.cobertura.xml'
    refute collection_steps.any? { |step| step['task'] == 'PublishCodeCoverageResults@2' }
    jobs = pipeline.fetch('jobs').filter_map { |job| job['parameters'] }.reject { |job| job['jobName'] == 'Publish_coverage' }
    assert_equal 2, jobs.length
    jobs.each do |job|
      assert_equal 1, job['steps'].count { |step| step.dig('inputs', 'script').to_s.include?('./build.py') }
      assert_match(/--coverage --targets (ios|mac)_library/, job['steps'].to_s)
      assert job['steps'].any? { |step| step['template'] == 'templates/coverage-collection.yml' }
    end
  end

  def test_xml_is_retained_and_diagnostics_are_only_gated_on_collection_failure
    retained = collection_steps.find { |step| step['displayName'] == 'Retain scheme coverage reports' }
    assert_equal 'succeededOrFailed()', retained['condition']
    assert_match '/build/coverage/reports', retained.fetch('inputs')['targetPath']
    diagnostics = collection_steps.find { |step| step['displayName'] == 'Publish coverage collection diagnostics' }
    assert_equal "and(succeededOrFailed(), eq(variables['coverageCollectionFailed'], 'true'))", diagnostics['condition']
    verifier = collection_steps.find { |step| step['displayName'] == 'Verify all expected coverage reports' }
    assert_equal 'succeededOrFailed()', verifier['condition']
    assert_equal 'coverageReports', verifier['name']
    assert_equal '$(coverageReports.artifactName)', retained.fetch('inputs')['artifact']
    %w[ios_library mac_library].product([1, 2], [0, 1]).each do |target, attempt, status|
      script = verifier.fetch('inputs')['script'].gsub('${{ parameters.target }}', target)
                       .gsub('$(System.JobAttempt)', attempt.to_s)
      runner = "ruby() { return #{status}; }\n#{script}"
      stdout, _, result = Open3.capture3('bash', '-c', runner)
      assert_equal status, result.exitstatus
      assert_includes stdout, "variable=coverageCollectionFailed]#{status == 0 ? 'false' : 'true'}"
      assert_includes stdout, "variable=artifactName;isOutput=true]#{target} coverage reports - #{attempt}"
    end
  end

  def test_publication_downloads_only_each_producers_current_artifact
    downloads = publication.fetch('steps').select { |step| step['task'] == 'DownloadPipelineArtifact@2' }
    assert_equal 2, downloads.length
    [['ios', 'iOS', 'ios_library'], ['mac', 'macOS', 'mac_library']].each do |prefix, platform, target|
      variable = "#{prefix}CoverageArtifact"
      assert_equal "$[ dependencies.Validate_Pull_Request_#{platform}.outputs['coverageReports.artifactName'] ]",
                   publication.fetch('variables').fetch(variable)
      download = downloads.find { |step| step.dig('inputs', 'artifactName') == "$(#{variable})" }
      refute_nil download
      assert_equal "and(succeededOrFailed(), ne(variables['#{variable}'], ''))", download['condition']
      assert_equal 'current', download.fetch('inputs')['buildType']
      assert_equal '**/*.cobertura.xml', download.fetch('inputs')['itemPattern']
      assert_equal "$(Build.SourcesDirectory)/build/coverage/reports/#{target}",
                   download.fetch('inputs')['targetPath']
    end
  end

  def test_build_task_propagates_process_and_status_file_failures
    job = pipeline.fetch('jobs').find do |entry|
      entry.dig('parameters', 'jobName') == 'Validate_Pull_Request_macOS'
    end
    task = job.fetch('parameters').fetch('steps').find do |step|
      step['displayName'] == 'Run Build script & check for Errors'
    end
    assert_equal false, task.fetch('inputs')['failOnStderr']
    [[0, '0', 0], [1, '0', 1], [0, '1', 1], [1, nil, 1], [0, nil, 0]].each do |process_exit, status, expected|
      Dir.mktmpdir('common-core-build-status') do |directory|
        FileUtils.mkdir_p(File.join(directory, 'build'))
        # A stale success must never mask a new crash.
        File.write(File.join(directory, 'build/status.txt'), '0')
        fixture = "#!/bin/bash\n"
        fixture += "echo #{status} > build/status.txt\n" if status
        fixture += "echo 'fixture tool warning' >&2\nexit #{process_exit}\n"
        File.write(File.join(directory, 'build.py'), fixture)
        FileUtils.chmod(0o755, File.join(directory, 'build.py'))
        _, _, result = Open3.capture3('bash', '-c', task.fetch('inputs')['script'], chdir: directory)
        assert_equal expected, result.exitstatus
      end
    end
  end

  def test_separate_platform_html_uses_same_xmls_and_pinned_generator_after_native
    steps = publication.fetch('steps')
    native_index = steps.index { |step| step['task'] == 'PublishCodeCoverageResults@2' }
    { 'iOS' => 'IdentityCore_iOS', 'macOS' => 'IdentityCore_Mac' }.each do |platform, name|
      generate = steps.find { |step| step['displayName'] == "Generate #{platform} coverage HTML" }
      assert steps.index(generate) > native_index
      assert_equal 'succeededOrFailed()', generate['condition']
      assert_includes generate['inputs']['script'], "publication-reports/#{name}.cobertura.xml"
      assert_includes generate['inputs']['script'], "-targetdir:build/coverage/html/#{platform}"
      upload = steps.find { |step| step['displayName'] == "Publish #{platform} coverage HTML" }
      assert_equal 'succeededOrFailed()', upload['condition']
      assert_includes upload['inputs']['targetPath'], "html/#{platform}"
    end
    runtime = steps.find { |step| step['task'] == 'UseDotNet@2' }
    assert_equal '8.x', runtime.fetch('inputs')['version']
    manifest = JSON.parse(File.read(File.join(REPO, '.config/dotnet-tools.json')))
    assert_equal '5.4.18', manifest.dig('tools', 'dotnet-reportgenerator-globaltool', 'version')
  end

  def test_warning_only_baselines_are_independent_and_after_all_report_publication
    steps = publication.fetch('steps')
    baselines = steps.select { |step| step.dig('inputs', 'script').to_s.include?('check_coverage_baseline.py') }
    assert_equal 2, baselines.length
    last_upload = steps.rindex { |step| ['PublishPipelineArtifact@1', 'PublishCodeCoverageResults@2'].include?(step['task']) }
    [['iOS', 'IdentityCore_iOS', 'IdentityCore iOS', 71],
     ['macOS', 'IdentityCore_Mac', 'IdentityCore Mac', 63]].each do |platform, name, suite, minimum|
      task = baselines.find { |step| step['displayName'] == "Check #{platform} coverage baseline (warning only)" }
      assert steps.index(task) > last_upload
      assert_equal 'succeededOrFailed()', task['condition']
      refute task.key?('continueOnError')
      script = task.fetch('inputs').fetch('script')
      assert_includes script, '--report "build/coverage/publication-reports/' + name + '.cobertura.xml"'
      assert_includes script, "--suite \"#{suite}\" --minimum #{minimum}"
      assert_includes script, '--revision "$(Build.SourceVersion)"'
      refute_match(/build.py|xcodebuild/, script)
    end
    text = File.read(File.join(REPO, 'azure_pipelines/pr-validation.yml'))
    assert_includes text, 'floor(run1717201 measured percent) - 2 points'
    assert_includes text, '25322/34315'
    assert_includes text, '23186/35657'
  end
end
