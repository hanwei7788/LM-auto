#*!
#* \file
#* \brief file cansimng.rb
#*
#* Copyright of Link Motion Ltd. All rights reserved.
#*
#* Contact: info@link-motion.com
#*
#* \author Niko Vähäsarja <niko.vahasarja@nomovok.com>
#*
#* any other legal text to be defined later
#*

require "open3"
require "thread"
require "cansimng_syncstate"
require "cansimng_demosequencer"

# * CanSimNG module for utilizing CAN simulator in automated tests.
# * Requires can0 adapter installed and initialized before use.
#     # ip link set can0 down
#     # ip link set can0 type can bitrate 500000
#     # ip link set can0 up
module CanSimNG
  CMD = File.join(Gem::Specification.find_by_name('cansimng').full_gem_path, 'bin', 'can-simulator-ng')

  @@CFG='can.cfg'
  @@DBC='can.dbc'
  @@IFACE='can0'
  @@NATIVE=nil
  @@EXCEPTIONS_ENABLED=true

# List of warning codes considered as fatal as errors.
# - +3+ Variable name not found in CAN message mapping file
# - +4+ Invalid input
  FATAL_WARNINGS=['3','4']

  private
# Execute the CAN Simulator ng command, and check for errors
#
# Internal helper executing commands
  def self.execute(*cmd)
    cmd_text = [CMD, @@NATIVE, '--cfg', @@CFG, '--dbc', @@DBC, '--interface', @@IFACE, cmd].join(' ')
    output,status = Open3.capture2e(cmd_text)
    re = /(warning|error)=(\d+) ?([^\n]*)/
    issues = output.scan(re)
    exception = self.create_exception(issues)
    if exception or status != 0
      puts 'Error running: %s' % cmd_text
      puts "Output:\n%s" % output
      raise exception or CanSimError.new('External process execution error: %s' % output)
    end
    true
  end

# Internal helper for selecting errors and relevant warnings
# Returns the first error or fatal warning found.
  def self.create_exception(issues)
    for issue in issues
      if issue[0] == 'error' or (issue[0] == 'warning' and FATAL_WARNINGS.include?(issue[1]))
        return CanSimError.new('%s from cansim-ng: %s - %s' % issue)
      end
    end
    return nil
  end

  public
# Starts can-simulator-ng process and processes its output.
  def self.start
    if not SyncState.setRunning(true)
        return false
    end

    cmd_start = [CMD, @@NATIVE, '--cfg', @@CFG, '--dbc', @@DBC, '--verbosity=3', '--interface', @@IFACE, 'prompt'].join(' ')

    @thread = Thread.fork {
      Open3.popen2(cmd_start) {|input,output,thread|
        SyncState.setCanSimInput(input)
        while SyncState.isRunning
          ios = IO.select([output], [], [], 0.1)
          if ios
            ios.first.each {|r|
              str = r.gets
              if str
                str.split("\n").each {|line|
                  re = /(warning|error)=(\d+) ?([^\n]*)/
                  issues = line.scan(re)
                  exception = self.create_exception(issues)
                  if exception
                    puts "Output:\n%s" % line
                    if @@EXCEPTIONS_ENABLED
                      SyncState.setException(exception)
                    end
                  end
                  var, val = line.split('=')
                  SyncState.setValue(var, val)
                }
              end
            }
          end
        end
        SyncState.setCanSimInput(nil)
        input.write "quit\n"
        thread.join
        SyncState.clearValues
      }
    }
    return true
  end

# Stop can-simulator-ng process and clean up values received
  def self.stop
    if SyncState.setRunning(false)
      @thread.join
      @thread = nil
      return true
    else
    return false
    end
  end

# Enable CAN native units
  def self.set_native(state)
    if state == true
        @@NATIVE='--native'
    else
        @@NATIVE=nil
    end
  end

# Set exception suppression state
  def self.set_suppress_exception(suppress)
    @@EXCEPTIONS_ENABLED = !suppress
  end

# Select CAN interface
  def self.set_iface(iface)
    @@IFACE=iface
  end

# Simplified selecting of dir with can.cfg and can.dbc
  def self.set_candir(dir)
    self.set_canspec("#{dir}/can.cfg", "#{dir}/can.dbc")
  end

# Select used .cfg and .dbc locations
  def self.set_canspec(cfg, dbc)
    @@CFG=cfg
    @@DBC=dbc
    puts "Canspec set CFG: '#{cfg}' DBC: '#{dbc}'"
    if not (File.file?(cfg) and File.file?(dbc))
      raise CanSimError.new("Canspec file(s) not found: (CFG: '#{cfg}' DBC: '#{dbc}')")
    end
  end

# Get hash of received values
  def self.getValues
    SyncState.getValues
    exception=SyncState.getException and raise exception
  end

# Sends CAN messages to CAN-bus using the running CAN simulator in prompt mode.
  def self.setValues(*msgs)
    caninput = SyncState.getCanSimInput
    caninput.write "#{msgs.join(' ')}\n"
    exception=SyncState.getException and raise exception
  end

# Sends CAN messages to CAN-bus
#    CanSimNG.send("speed=10", "rpm=5000", ...)
  def self.send(*msgs)
    self.execute('send', *msgs)
  end

# Sends all default values to CAN-bus
#
# Shorthand for:
#    CanSimNG.send('reset')
  def self.reset
    self.send('reset')
  end

# Running while block is in scope. Simplest way to ensure stopping the
# external can-simulator-ng process when something fails.
  def self.run
    started_by_me = self.start
    sleep 0.1 if started_by_me
    yield self
    ensure
      self.stop if started_by_me
  end

# Shorthand for receiving CAN values single time.
  def self.receive
    run {
      sleep 1
      return self.getValues
    }
  end

# Run demo script.
  def self.run_demo(scenes, fps=1, rounds=1, echo_signals=false)
    puts 'Running demo with %d scenes, fps: %d, rounds: %0.0f' % [scenes.length, fps, rounds]
    #CAN setup
    self.run do |can|
      DemoSequencer.run_scenes(scenes, fps, rounds) do |frame|
        if frame.any?
          signals=frame.compact.map { |part| part[1] == nil ? part[0] : "%s=%s" % [part[0], part[1].round(10)] }
          puts "  * %s *" % signals.join(' ') if echo_signals
          can.setValues(*signals)
        end
      end
    end
    puts 'Demo ended'
  end

# CanSimNG Error exception
# Raised if errors reported by the external command
# TODO: create specific exceptions after the range of possible errors stabilize
  class CanSimError < StandardError
  end

end
