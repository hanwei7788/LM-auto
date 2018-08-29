#! /usr/bin/env ruby

require 'json'

def usage(target=STDOUT)
  target.puts
  target.puts "USAGE: #{$0} <old.json> <new.json> <directory for diff files>"
  target.puts
end

if ARGV.length != 3
  usage(STDERR)
  exit -1
end

fn1=ARGV[0]
fn2=ARGV[1]
diff_dir=ARGV[2]


def read_test_run_from_json_to_hash(name)
  if not File.file?(name)
    STDERR.puts "ERROR: '#{name}' is not a file"
    usage(STDERR)
    exit -2
  end
  
  data = File.open(name, 'r') do |f|
    JSON.load(f)
  end
  Hash[*data['tests'].map {|i| [i['testKey'], i]}.flatten]
end


def gen_diff_fname(key)
  return key + ".txt"
end

JIRA_COLORS={ "A" => "Wheat", "D" => "Honeydew", "F" => "PaleGreen", "C" => "Khaki", "R" => "Salmon"}
def print_test_diff(key, delta, diff_dir)
  diff_fname = gen_diff_fname(key)
  puts "{panel:bgColor=#{JIRA_COLORS[delta[0]]}}#{key} #{delta}, [compare|^#{diff_fname}]{panel}"
end


def create_diff_file(dir, key, t1, t2)
  diff_fname = gen_diff_fname(key)
  open("#{dir}/#{diff_fname}", "w") do |f|
    f.puts "* OLD: #{t1['status']}\n#{t1['comment']}" if t1
    if t1 and t2
      f.puts ""
      f.puts "--------------------------------------------------------------------------------"
      f.puts ""
    end
    f.puts "* NEW: #{t2['status']}\n#{t2['comment']}" if t2
  end
end


# Read files to hashes
data1=read_test_run_from_json_to_hash(fn1)
data2=read_test_run_from_json_to_hash(fn2)

# All keys sorted
all_keys = (data1.keys | data2.keys).sort


all_keys.each do |key|
  i1 = data1[key]
  i2 = data2[key]

  delta = if not i1 
    "ADDED"
  elsif not i2
    "DELETED"
  elsif i1['status'] == i2['status'] 
    "CHANGED" if i1['status'] != 'PASS' and i1['comment'] != i2['comment']
  elsif i1['status'] == 'PASS'
    "REGRESSED"
  elsif i2['status'] == 'PASS'
    "FIXED"
  end
  if delta
    print_test_diff(key, delta, diff_dir)
    create_diff_file(diff_dir, key, i1, i2)
  end
end

