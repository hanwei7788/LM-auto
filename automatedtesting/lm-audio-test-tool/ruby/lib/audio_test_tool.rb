#*!
#* \file
#* \brief audio_test_tool.rb foo
#*
#* Copyright of Link Motion Ltd. All rights reserved.
#*
#* Contact: info@link-motion.com
#*
#* \author Niko Vähäsarja <niko.vahasarja@nomovok.com>
#*
#* any other legal text to be defined later
#*

require 'open3'
require 'tempfile'

# * AudioTestTool module for utilizing audio analysis in automated tests.
module AudioTestTool
  begin
    ANALYZERS= File.join(Gem::Specification.find_by_name('audio_test_tool').full_gem_path, 'analyzers')
  rescue LoadError
    ANALYZERS= './analyzers'
  end
  @@DEVICE = 'hw:1,0'
  @@SAMPLERATE = '192000'
  @@CHANNELS = '4'
  @@TIME = '5' # 5 seconds default recording time

  private
# Execute the audio test tool commands, and check for errors
#
# Internal helper executing commands
  def self.execute(*cmd)
    cmd_text = [cmd].join(' ')
    output,status = Open3.capture2e(cmd_text)
    if status != 0
      raise ExecutionError.new(output)
    end
    output
  end

  public
# Change AudioTestTool settings
#
# == Parameters:
# device::
#   alsa device to use (default hw:1,0)
# samplerate::
#   samplerate in samples per second (default 192000)
# channels::
#   number of channels to record (default 4)
# time::
#   how many seconds to record (default 5)
# == Example:
# AudioTestTool.configure(device: 'hw:0,0', samplerate: '48000', channels: '2')
#
  def self.configure(device: @@DEVICE, samplerate: @@SAMPLERATE, channels: @@CHANNELS, time: @@TIME)
    @@DEVICE=device
    @@SAMPLERATE=samplerate
    @@CHANNELS=channels
    @@TIME=time
    return
  end

# Execute record command
#
# == Parameters:
# testname::
#   Name of the test being executed. Used as filename prefix.
# == Returns:
# A string containing the filename of recorded audio file.
# Unique between executions, even with same testname parameter.
  def self.record(testname)
    f = Dir::Tmpname.create([testname, '.wav']) {} # Create unique filename
    cmd=['ffmpeg', '-loglevel', 'error',
                   '-f', 'alsa',
                   '-acodec', 'pcm_s32le',
                   '-ac', @@CHANNELS,
                   '-ar', @@SAMPLERATE,
                   '-i', @@DEVICE,
                   '-t', @@TIME,
                   f]
    self.execute(cmd)
    f
  end

# Run external analyzer program with THD+N calculator.
#
# == Parameters:
# file::
#   Name of the file to be analyzed.
# == Returns:
# A hash containing mean values of "Frequency" and "THD+N", and "Channels" array.
# Example:
# {"Frequency"=>996.826, "THD+N"=>0.0481635, "Channels"=> [
#    {"Channel"=>"ch1", "Frequency"=>"996.826", "THD+N"=>"0.0473986"},
#    {"Channel"=>"ch2", "Frequency"=>"996.826", "THD+N"=>"0.0480907"},
#    {"Channel"=>"ch3", "Frequency"=>"996.826", "THD+N"=>"0.0480546"},
#    {"Channel"=>"ch4", "Frequency"=>"996.826", "THD+N"=>"0.04911"}]
# }
  def self.analyze_thdn(file)
    cmd=['octave', File.join(ANALYZERS, 'thdn.m'), file]
    out=self.execute(cmd)
    a= out.lines
    ret={}

    # Assign mean values to hash
    ret['Frequency'] = a[0].split[0].to_f
    ret['THD+N']= a[0].split[1].to_f

    # Assign array of channel values to hash
    chans=a[1].to_i
    chan_data=a[2, chans]
    ret["Channels"]=chan_data.map { |l| {'Channel'=>l.split[0], 'Frequency'=>l.split[1], 'THD+N'=> l.split[2]} }

    ret
  end


# Execution Error exception
# Raised if errors reported by the external command
# TODO: create specific exceptions after the range of possible errors stabilize
    class ExecutionError < StandardError
      end

end
