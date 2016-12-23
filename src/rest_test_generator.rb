require "net/http"
require "uri"
require "pp"
require 'fileutils'
require_relative 'u.rb'
require_relative 'json_flattener.rb'

class Rest_Test
        attr_accessor :expected_response_text
        attr_accessor :name
        attr_accessor :original_server_url
        attr_accessor :src_dir
        attr_accessor :rest_of_url
        attr_accessor :xforms
        def initialize(rest_of_url, expected_response_text, original_server_url, xforms, src_dir)
                puts "Rest_Test(#{rest_of_url}, #{expected_response_text})" if Rest_Test_Generator.verbose
                self.rest_of_url = rest_of_url
                self.src_dir = src_dir
                self.name = Rest_Test.url2name(rest_of_url)
                self.original_server_url = original_server_url
                if xforms
                        self.xforms = xforms
                else
                        self.xforms = Rest_Test.default_xforms
                end
                self.expected_response_text = self.normalize_json(expected_response_text)
        end
        def ==(o)
                o.class == self.class && o.state == state
        end
        def assert_eq(actual, caller_msg=nil, no_raise_if_fail=false, silent=false)
                expected = self.expected_response_text
                if U.assert_eq(expected, actual, caller_msg, no_raise_if_fail, true)
                        puts "Rest_Test.assert_eq immediate success: #{actual}" if Rest_Test_Generator.verbose
                        return true
                end
                expected.gsub!(/^\s*/, '')
                expected << "\n" unless expected.end_with?("\n")
                if actual != expected
                        actual = self.normalize_json(actual)
                end
                if Rest_Test.reset_expected && actual != expected
                        puts "Resetting expected_response_text for #{self.name} based on response from #{self.original_server_url}"
                        self.expected_response_text = actual
                        self.save
                        success = true
                else
                        success = U.assert_eq(expected, actual, caller_msg, no_raise_if_fail, silent)
                        puts "Rest_Test_Generator.assert_eq: expected:\n#{expected}\nEOD\nactual:\n#{actual}\nEOD\n" if Rest_Test_Generator.verbose
                end
                success
        end
        def execute(server_url, save_diffs, is_retry=false)
                raise "require server_url" unless server_url
                url = server_url + "/" + self.rest_of_url
                puts "\tExecuting test #{self.name} at #{src_dir}" unless Rest_Test.silent_mode
                puts "\tFetching #{url}"                           unless Rest_Test.silent_mode
                actual_response_text = U.rest_get(url)
                ok = true
                begin
                        if save_diffs
                                if Rest_Test.test_output_dir
                                        tod = Rest_Test.test_output_dir
                                else
                                        tod = self.src_dir
                                end
                                U.next_diff_output = "#{tod}/diff"
                        end
                        if !self.assert_eq(actual_response_text, nil, true)
                                if !is_retry && Rest_Test.refresh_expected_on_test_diff
                                        self.refresh_expected_response_text()
                                        if !execute(server_url, save_diffs, true)
                                                ok = false
                                        end
                                else
                                        ok = false
                                end
                        end
                ensure
                        if ok && U.next_diff_output && File.exist?(U.next_diff_output)
                                File.unlink(U.next_diff_output)
                        end
                        U.next_diff_output = nil
                end
                puts "OK #{self.name}"
                return true
        end
        def get_xforms()
                if self.xforms
                        return self.xforms
                end
                Rest_Test.default_xforms
        end
        def normalize_json(json)
                begin
                        jh = Json_holder.new(nil, json)
                        json_flattened = jh.flatten()
                rescue
                        json_flattened = json
                end
                json_flattened << "\n" unless json_flattened.end_with?("\n")
                json_flattened.gsub!(/^\s*/, '')
                json_flattened = String_xform.apply(self.get_xforms(), json_flattened)
                json_flattened = Json_holder.sort_lines_to_make_it_predictable(json_flattened)
                json_flattened
        end
        def refresh_expected_response_text()
                url = self.original_server_url + "/" + self.rest_of_url
                self.expected_response_text = self.normalize_json(U.rest_get(url))
                self.save
                puts "Refreshed expected from #{url}" unless Rest_Test.silent_mode
        end
        def save()
                if !Rest_Test.generated_tests_dir
                        Rest_Test.generated_tests_dir = Dir.pwd + "/tests"
                end
                root = Rest_Test.generated_tests_dir + "/" + name
                if !File.directory?(root)
                        puts "\tCreating new test #{root} dir" unless Rest_Test.silent_mode
                        FileUtils.mkdir_p(root)
                else
                        puts "\tWriting test to directory #{root}" unless Rest_Test.silent_mode
                end
                IO.write("#{root}/expected", self.expected_response_text)
                IO.write("#{root}/rest_of_url",      self.rest_of_url)
                IO.write("#{root}/original_server_url",      self.original_server_url)
                String_xform.write_xforms_to_file(self.xforms, "#{root}/xforms")
        end
        def to_s()
                "Rest_Test(#{rest_of_url})"
        end
        protected

        def state
                [@expected_response_text, @name, @original_server_url, @rest_of_url]
        end
        class << self
                attr_accessor :default_xforms
                attr_accessor :silent_mode
                attr_accessor :generated_tests_dir
                attr_accessor :test_output_dir
                attr_accessor :refresh_expected_on_test_diff
                attr_accessor :reset_expected
                
                def add_xform(before_regexp_string, after)
                        if !Rest_Test.default_xforms
                                Rest_Test.default_xforms = []
                        end
                        xf = String_xform.new(before_regexp_string, after)
                        Rest_Test.default_xforms << xf
                end
                def assert_eq(expected, actual, caller_msg=nil, no_raise_if_fail=false, silent=false)
                        rt = Rest_Test.new("/some/rest/call", expected, "http://not_real_just_unit_testing:80801/api", nil, "/some/nonexistent/path")
                        return rt.assert_eq(actual, caller_msg, no_raise_if_fail, silent)
                end
                def from_dir(dir)
                        rest_of_url = IO.read("#{dir}/rest_of_url")
                        expected_response_text = IO.read("#{dir}/expected")
                        original_server_url = IO.read("#{dir}/original_server_url")
                        xforms = String_xform.parse_xforms_from_file("#{dir}/xforms")
                        Rest_Test.new(rest_of_url, expected_response_text, original_server_url, xforms, dir)
                end
                def from_url(server_url, generated_test_src_url)
                        raise "server_url required" unless server_url
                        raise "generated_test_src_url required" unless generated_test_src_url
                        url = server_url + "/" + generated_test_src_url
                        dir = Rest_Test.generated_tests_dir + "/" + url2name(generated_test_src_url)
                        puts "Creating test pointed at #{dir} based on #{url}" unless Rest_Test.silent_mode
                        expected_response_text = U.rest_get(url)
                        original_server_url = server_url
                        xforms = Rest_Test.default_xforms
                        rt = Rest_Test.new(generated_test_src_url, expected_response_text, original_server_url, xforms, dir)
                        rt.save
                        rt
                end
                def test_generate_test_from_url(server_url, generated_test_src_url)
                        U.assert(server_url)
                        if !Rest_Test.generated_tests_dir
                                Rest_Test.generated_tests_dir = Dir.mktmpdir
                                puts "test_generate_test_from_url created tmp dir #{Rest_Test.generated_tests_dir}" unless Rest_Test.silent_mode
                        end
                        U.assert(generated_test_src_url)
                        
                        from_url(server_url, generated_test_src_url)

                        test_location_on_disk = Rest_Test.generated_tests_dir + "/" + Rest_Test.url2name(generated_test_src_url)
                        U.assert_file_exists("#{test_location_on_disk}/expected")
                        U.assert_file_exists("#{test_location_on_disk}/original_server_url")
                        U.assert_file_exists("#{test_location_on_disk}/rest_of_url")
                        U.assert_file_exists("#{test_location_on_disk}/xforms")
                        puts "OK test_generate_test_from_url"
                end
                def url2name(rest_of_url)
                        rest_of_url.gsub(/\W/, '_').sub(/^_*/, '').sub(/_*$/, '')
                end
        end
end

class Rest_Test_Generator
        NONEXISTENT_URL = "http://some_server_that_will_be_recorded_as_the_source_of_the_log:8080/api"
        attr_accessor :log_files_to_parse
        attr_accessor :test_output_dir
        attr_accessor :save_diffs
        attr_accessor :server_url
        attr_accessor :tests

        def initialize()
                Rest_Test_Generator.init()
                if !File.directory?("tests")
                        FileUtils.mkdir("tests")
                end
                self.log_files_to_parse = []
        end
        def add_log_file_to_parse_later(log_fn)
                puts "add_log_file_to_parse_later(#{log_fn})" if Rest_Test_Generator.verbose
                if !File.exist?(log_fn)
                        raise "could not find #{log_fn} in #{Dir.pwd}"
                end
                self.log_files_to_parse << log_fn
        end
        def beginning_of_new_log_entry?(line)
                if line =~ / - Response /
                        return false
                else
                        line =~ /^\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d/      # starting with a timestamp indicates a new log line
                end
        end
        def execute()
                raise "no tests" if self.tests.empty?
                ok = true
                self.tests.each do | test |
                        if !test.execute(self.server_url, self.save_diffs)
                                ok = false
                        end
                end
                return ok
        end
        def parse_log_file(log_fn, url_to_rt)
                puts "parse_log_file(#{log_fn})" if Rest_Test_Generator.verbose
                rest_of_url = nil
                expected_response_text = nil
                IO.readlines(log_fn).each do | line |
                        line.chomp!
                        new_log_entry_starting = self.beginning_of_new_log_entry?(line)
                        puts "see #{line}" if Rest_Test_Generator.verbose
                        if rest_of_url
                                if new_log_entry_starting
                                        puts "end for #{rest_of_url} expected_response_text=#{expected_response_text}" if Rest_Test_Generator.verbose
                                        url_to_rt[rest_of_url] = Rest_Test.new(rest_of_url, expected_response_text, self.server_url, Rest_Test.default_xforms, nil)
                                        rest_of_url = expected_response_text = nil
                                else
                                        if line =~ /.* Response (.*)/
                                                expected_response_text << $1
                                        else
                                                expected_response_text << line
                                        end
                                        expected_response_text << "\n"
                                        puts "added: #{expected_response_text}" if Rest_Test_Generator.verbose
                                end
                        end
                        if new_log_entry_starting
                                puts "new entry detected..." if Rest_Test_Generator.verbose
                                if line =~ /.* - Requesting GET for path (.*) $/
                                        rest_of_url=$1
                                        expected_response_text = ''
                                        puts "new entry for #{rest_of_url}" if Rest_Test_Generator.verbose

                                end
                        end
                end
                if rest_of_url
                        puts "EOF, so end for #{rest_of_url} expected_response_text=#{expected_response_text}" if Rest_Test_Generator.verbose
                        url_to_rt[rest_of_url] = Rest_Test.new(rest_of_url, expected_response_text, self.server_url, Rest_Test.default_xforms, nil)
                end
        end
        def parse_log_files()
                raise "-server_url is required, as I must know the source url for the original server" unless self.server_url
                url_to_rt = Hash.new
                if self.log_files_to_parse.empty?
                        raise "no log files to parse"
                end
                self.log_files_to_parse.each do | log_file |
                        parse_log_file(log_file, url_to_rt)
                end
                tests = url_to_rt.values
                tests.each do | test |
                        test.save
                end
                tests
        end
        def read_tests_from()
                dir = Rest_Test.generated_tests_dir
                raise "-generated_tests_dir required" unless dir
                raise "cannot find directory #{dir}" unless File.directory?(dir)
                tests = []

                if File.exist?("#{dir}/rest_of_url")
                        tests << Rest_Test.from_dir(dir)
                        puts "\tReading test from #{dir}..." if Rest_Test_Generator.verbose
                else
                        tests_seen = false
                        Dir["#{dir}/*"].each do | test_dir |
                                if !File.directory?("#{test_dir}/rest_of_url")
                                        tests_seen = true
                                        tests << Rest_Test.from_dir(test_dir)
                                        puts "\tReading test from #{test_dir}..." if Rest_Test_Generator.verbose
                                end
                        end
                        raise "could not find any tests under #{dir}" unless tests_seen
                end
                raise "found no tests under #{dir}" if tests.empty?
                if self.tests
                        self.tests.concat(tests)
                else
                        self.tests = tests
                end
                tests
        end
        def test_parse_log()
                #Rest_Test.silent_mode = true
                saved_server_url = self.server_url
                begin
                        self.server_url = Rest_Test_Generator::NONEXISTENT_URL
                        Dir.mktmpdir do | tests_tmp_output_dir |
                                Rest_Test.generated_tests_dir = tests_tmp_output_dir
                                self.add_log_file_to_parse_later("log")

                                self.parse_log_files()

                                t1_root = "#{tests_tmp_output_dir}/v1_integrations_L1_summary/"
                                t2_root = "#{tests_tmp_output_dir}/v1_monitoring_integrations_count/"

                                U.assert_file_exists(t1_root + "rest_of_url")
                                U.assert_file_exists(t1_root + "original_server_url")
                                U.assert_file_exists(t1_root + "expected")
                                U.assert_file_exists(t1_root + "xforms")

                                U.assert_file_exists(t2_root + "rest_of_url")
                                U.assert_file_exists(t2_root + "original_server_url")
                                U.assert_file_exists(t2_root + "expected")
                                U.assert_file_exists(t2_root + "xforms")
                        end
                ensure
                        self.server_url = saved_server_url
                end
                puts "OK parse log"
        end
        def test()
                Rest_Test.silent_mode = true
                U.test
                Json_holder.test
                if Rest_Test_Generator.generated_test_src_url
                        Rest_Test.test_generate_test_from_url(self.server_url, Rest_Test_Generator.generated_test_src_url)
                end
                saved_server_url = self.server_url
                if !File.exist?("log")
                        raise "could not find the test log file \"#{log_fn}\" in #{Dir.pwd}, we need to be in the test directory"
                end
                Rest_Test.add_xform("Linux", "FreeBSD")
                Rest_Test.add_xform('integrations\[\d+\]', "integrations[0]")
                self.add_log_file_to_parse_later("log")
                self.server_url = "http://some_nonexistent_server:9234/api"
                
                Rest_Test.generated_tests_dir = Dir.mktmpdir
                tests = self.parse_log_files()
                U.assert_eq(2, tests.length)
                U.assert_eq("v1/monitoring/integrations/count", tests[0].rest_of_url)
                U.assert_eq("209 ", tests[0].expected_response_text)
                U.assert_eq('v1/integrations/L1/summary', tests[1].rest_of_url)
                U.assert_eq('[0].display_name = "Asclassic L1 FreeBSD.x64"
                [0].id = "5567cc82c2e66ad1e254c5bf"
                [0].url = "SERVER_AND_POSSIBLE_PORT/a/b/c"
                [0].z = "integrations[0]"' + "\n",
                tests[1].expected_response_text
                )
                tests_read_from_disk = self.read_tests_from()
                U.assert_eq(2, tests_read_from_disk.length)
                if tests[0] != tests_read_from_disk[1] && tests[0] != tests_read_from_disk[0]
                        U.assert(false, "unexpected test mismatch -- #{tests[0]}!=#{tests_read_from_disk[1]}, also !=#{tests_read_from_disk[0]}")
                end 
                if tests[1] != tests_read_from_disk[1] && tests[1] != tests_read_from_disk[0]
                        U.assert(false, "could not find t1")
                end 
                puts "OK rest_test_generator"
                if saved_server_url
                        self.server_url = saved_server_url
                #        puts "executing to #{self.server_url}"
                #        if !self.execute()
                #                exit
                #        end
                #        puts "made it here......"
                #        exit
                end
                FileUtils.rm_r(Rest_Test.generated_tests_dir) if Rest_Test.silent_mode
                test_parse_log
                Rest_Test.add_xform('integrations\[\d+\]', 'integrations[0]')
                Rest_Test.assert_eq('integrations[0].name = "bi"
                integrations[0].name = "bi2"
                ',
                '{
                "integrations" : [
                {
                "name" : "bi2"
                },
                {
                "name" : "bi"
                }
                ]
                }'
                )
                puts "OK rest_test_generator stop disordered arrays from making spurious mismatches"
        end
        class << self
                attr_accessor :generated_test_src_url
                attr_accessor :suppress_server_names
                attr_accessor :suppress_server_names_regexp_added
                attr_accessor :verbose
                def init()
                        if !Rest_Test_Generator.suppress_server_names_regexp_added
                                Rest_Test.add_xform("https?://[^/]*(:\d+)?", "SERVER_AND_POSSIBLE_PORT")
                                Rest_Test_Generator.suppress_server_names_regexp_added = true
                        end
                end
        end
end
rtg = Rest_Test_Generator.new
j = 0
Rest_Test_Generator.suppress_server_names = true
while ARGV.size > j do
        arg = ARGV[j]
        case arg
        when "-execute"
                rtg.read_tests_from()
                exit_code = rtg.execute() ? 0 : 1
                exit(exit_code)
        when "-fail_at_end"
                U.fail_at_end()
        when "-generated_test_src_url"
                j += 1
                Rest_Test_Generator.generated_test_src_url = ARGV[j]
        when "-generate_test_from_url"
                Rest_Test.from_url(rtg.server_url, Rest_Test_Generator.generated_test_src_url)
        when "-generated_tests_dir"
                j += 1
                dir = ARGV[j]
                raise "cannot find directory '#{dir}'" unless File.directory?(dir)
                Rest_Test.generated_tests_dir = dir
        when "-no_default_server_suppression"
                rtg.suppress_server_names = false
        when /^-test_output_dir|-o$/
                j += 1
                rtg.test_output_dir = ARGV[j]
        when "-parse_log"
                ARGV[j+1..-1].each do | log_fn |
                        rtg.add_log_file_to_parse_later(log_fn)
                end
                rtg.parse_log_files()
                exit
        when "-refresh_expected_on_test_diff"
                Rest_Test.refresh_expected_on_test_diff = true
        when "-reset_expected"
                Rest_Test.reset_expected = true
        when "-save_diffs"
                rtg.save_diffs = true
        when "-server_url"
                j += 1
                rtg.server_url = ARGV[j]
        when "-suppress_string"
                j += 1
                string_to_suppress = ARGV[j]
                Rest_Test.add_xform(string_to_suppress, '')
        when "-test"
                rtg.test()
                exit(0)
        when "-v"
                Rest_Test_Generator.verbose = true
        when "-xform"
                j += 1
                before_regexp_string = ARGV[j]

                j += 1
                after = ARGV[j]

                Rest_Test.add_xform(before_regexp_string, after)
        else
                raise "did not understand #{arg}"
        end
        j += 1
end
