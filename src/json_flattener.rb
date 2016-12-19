# ruby -w json_flattener.rb test

require 'tempfile'
require 'rubygems'
require 'pp'
require 'json'
require_relative 'u'

class Json_holder
        attr_accessor :name
        attr_accessor :json
        attr_accessor :json_parsed_into_a_ruby_obj
        attr_accessor :flattened_json_fn
        def initialize(name, json, flattened_json_fn=nil)
                raise "json required" if !json
                self.json = json
                self.name = name
                self.json_parsed_into_a_ruby_obj = JSON.parse(json)
        end
        def flatten(robj = nil, stem = nil)
                if flattened_json_fn
                        return IO.read(flattend_json_fn)
                end

                if stem
                        not_a_recursive_call = false
                else
                        not_a_recursive_call = true
                        if self.name
                                stem = self.name
                        else
                                stem = ''
                        end
                        if robj
                                raise "expected robj and stem to be nil together on first call"
                        end
                        robj = self.json_parsed_into_a_ruby_obj
                end
                fully_qualified_assignment_strings = []
                case
                when robj.class == Fixnum || robj.class == Float || robj.class == TrueClass || robj.class == FalseClass
                        return "#{stem} = #{robj}\n"
                when robj.class == String
                        return "#{stem} = \"#{robj}\"\n"
                when robj.class == Array
                        array_string = ''
                        robj.each_with_index do | robj_cell, j |
                                array_string << self.flatten(robj_cell, stem + "[#{j}]")
                        end
                        return array_string
                when robj.class == Hash
                        puts "Hash is #{robj}" if Json_holder.trace
                        robj.keys.each do | key |
                                new_stem = stem + (stem=="" ? "" : ".") + key
                                fully_qualified_assignment_strings << self.flatten(robj[key], new_stem)
                        end
                when robj.class == NilClass
                        return ''
                else
                        raise "saw robj.class=#{robj.class}"
                end
                flattened_json = fully_qualified_assignment_strings.join

                if not_a_recursive_call
                        flattened_json = Json_holder.sort_lines_to_make_it_predictable(flattened_json)
                        self.save_to_disk(flattened_json)
                end
                return flattened_json
        end
        def save_to_disk(flattened_json)
                t = Tempfile.new("json_flattener.save_to_disk")
                self.flattened_json_fn = t.path
                t.write(flattened_json)
                t.flush
                # t.close(json)  # if you close it, the temp file gets deleted
                if !self.flattened_json_fn
                        raise "no flattened_json_fn for name=#{name}"
                end
        end
        def test_json1(test_name, expected_flattened_json, string_from_expected_exception=nil)
                actual_flattened_json = self.flatten()
                if !expected_flattened_json.end_with?("\n")
                        expected_flattened_json << "\n" #       a little odd, I know -- makes formatting easier in the caller
                end
                U.assert_eq(expected_flattened_json, actual_flattened_json, "#{self.name} json flattening failed: ")
                puts "OK #{test_name}"
        end
        class << self
                attr_accessor :trace

                def sort_lines_to_make_it_predictable(s)
                        s.split("\n").sort.join("\n") + "\n"
                end
                def from_file(fn)
                        if !File.exist?(fn)
                                raise "cannot find #{fn}"
                        end
                        name = fn.sub(/.*\//, '').sub(/\.[^\.]*$/, '').sub(/.*\./, '')
                        json_string = IO.read(fn)
                        Json_holder.new(name, json_string)
                end
                def test_json1(name, json, expected_flattened_json, string_from_expected_exception=nil)
                        expected_flattened_json.sub!(/^\s*/, '')
                        expected_flattened_json.gsub!(/\n\s*/, "\n")
                        
                        jh = Json_holder.new(name, json)
                        jh.test_json1(name, expected_flattened_json, string_from_expected_exception)
                end
                def test()
                        Rest_Test.assert_eq(
                        '_id = "5567cc7fc2e66ad1e254c5b2"
                        _id2 = "123"
                        ',
                        '{
                        "_id2" : "123",
                        "_id"           : "5567cc7fc2e66ad1e254c5b2"
                        }'
                        )
                        puts "OK flatten should reorder"
                        
                        test_json1("abc_array",
                        '[
                        {
                        "_id" : "5567cc7fc2e66ad1e254c5b2"
                        },
                        {
                        "_id2" : "5567cc7fc2e66ad1e254c5XX"
                        },
                        true,
                        false,
                        {
                        "_class" : "com.acme.syseng.configuration.model.Integration"
                        },
                        99,
                        {
                        "name_float" : 9.9
                        }]',
                        'abc_array[0]._id = "5567cc7fc2e66ad1e254c5b2"
                        abc_array[1]._id2 = "5567cc7fc2e66ad1e254c5XX"
                        abc_array[2] = true
                        abc_array[3] = false
                        abc_array[4]._class = "com.acme.syseng.configuration.model.Integration"
                        abc_array[5] = 99
                        abc_array[6].name_float = 9.9
                        '
                        )
                        U.assert_eq("a\nb\nc\n", Json_holder.sort_lines_to_make_it_predictable("c\na\nb\n"), "sort_lines_to_make_it_predictable")
                        puts "OK sort_lines_to_make_it_predictable"
                        
                        Rest_Test.assert_eq(
                        '{
                        "_id" : "5567cc7fc2e66ad1e254c5b2"
                        }',
                        '{
                        "_id"           : "5567cc7fc2e66ad1e254c5b2"
                        }'
                        )
                        puts "OK flatten should stop white space diffs"
                        
                        
                        test_json1("abc_hash_with_array",
                        '{
                        "an_array_field" : [
                        {
                        "_id" : "5567cc7fc2e66ad1e254c5b2"
                        }]}',

                        'abc_hash_with_array.an_array_field[0]._id = "5567cc7fc2e66ad1e254c5b2"
                        '
                        )

                        test_json1("xyz",
                        '{
                        "_id" : "5567cc7fc2e66ad1e254c5b2",
                        "_class" : "com.acme.syseng.configuration.model.Integration",
                        "name_count" : 99,
                        "name_float" : 9.9 }',

                        'xyz._class = "com.acme.syseng.configuration.model.Integration"
                        xyz._id = "5567cc7fc2e66ad1e254c5b2"
                        xyz.name_count = 99
                        xyz.name_float = 9.9
                        '
                        )
                end
                def main(argv)
                        case
                        when argv[0] == "test"
                                Json_holder.test
                        else
                                jh = Json_holder.from_file(argv[0])
                                print jh.flatten
                        end
                end
        end
end
