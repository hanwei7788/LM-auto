#*!
#* \file
#* \brief file cansimng_syncstate.rb
#*
#* Copyright of Link Motion Ltd. All rights reserved.
#*
#* Contact: info@link-motion.com
#*
#* \author Niko Vähäsarja <niko.vahasarja@nomovok.com>
#*
#* any other legal text to be defined later
#*

require "thread"

# * CanSimNG module for utilizing CAN simulator in automated tests.
# * Requires can0 adapter installed and initialized before use.
#     # ip link set can0 down
#     # ip link set can0 type can bitrate 500000
#     # ip link set can0 up
module SyncState

  SEMAFORE = Mutex.new
  VALUES = Hash.new
  CTRL = Hash.new
  @@EXCEPTION=nil

# Helpers for thread safe handling of value objects
  def self.getValues
    SEMAFORE.synchronize {
      return VALUES.clone
    }
  end
  def self.getValue(var)
    SEMAFORE.synchronize {
      return VALUES[var]
    }
  end
  def self.setValue(var, val)
    SEMAFORE.synchronize {
      VALUES[var] = val
    }
  end
  def self.clearValues
    SEMAFORE.synchronize {
      VALUES.clear
    }
  end
  def self.setException(exception)
    SEMAFORE.synchronize {
      @@EXCEPTION=exception
    }
  end
# Return exception if exists, nil if not
  def self.getException
    SEMAFORE.synchronize {
      ret=@@EXCEPTION
      @@EXCEPTION=nil
      return ret
    }
  end

# Helpers for thread safe handling of running bit.
  def self.isRunning
    SEMAFORE.synchronize {
      return CTRL['running']
    }
  end
  def self.setRunning(running)
    SEMAFORE.synchronize {
      if CTRL['running'] == running
        return false
      else
        CTRL['running'] = running
        return true
      end
    }
  end

# TODO thread safe handling of input to external command
  def self.setCanSimInput(input)
    SEMAFORE.synchronize {
      CTRL['input'] = input
    }
  end
  def self.getCanSimInput
    SEMAFORE.synchronize {
      return CTRL['input']
    }
  end

end
