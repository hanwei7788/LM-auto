#This file contains function that gathers the data of autotest progress

#Function.
def autotestprogress(status, sut, ip)
  #Folder that has the latest results for the device. Autotest results path can be changed in config.rb
  #This is in two parts because of smoke tests having two different images per device.
  latest = `ls -td #{$autotestpath}#{sut[:name]}*/ | head -n 1`[0...-1]
  latest = `ls -td #{latest}20*/ | head -n 1`[0...-1]
  #If the test folder does not have log for results yet, we assume it is still flashing new image or initializing
  init = `find #{latest} -name *#{sut[:name]}*TestRun.txt`[0...-1]
  if init == ''
    flashing = `ps aux|grep #{$autotestflashingprogress}|grep #{sut[:name]}`[0...-1]
    if flashing != ''
      status[ip]['progress'] = "Flashing new image"
      status[ip]['progresscolor'] = "color:white;"
      return
    end
    status[ip]['progress'] = "Initializing test"
    status[ip]['progresscolor'] = "color:white;"
    return
  else
    #We grep the log file to determine the progress of the test
    prog = `grep '^Test ' #{latest}*#{sut[:name]}*TestRun.txt | tail -n 1`[0...-1]
    stat = `grep -A 1 '^Test ' #{latest}*#{sut[:name]}*TestRun.txt | tail -n 1`[0...-1]
    if prog != ''|| stat != ''
      #Calculate passes, fails, errors etc
      passes = stat.count('.')
      fails = stat.count('F')
      errors = stat.count('E')
      skips = stat.count('S')
      prog = prog.split(',')[0]
      prog[0...4] = ''
      #Get the imagetype from the last tested file
      imagever = `cat "$(ls -rt #{$autotestpath}#{sut[:name]}*/last_installed_zip.txt | tail -n 1)"`[0...-1]
      imagever = imagever.split('/')[7]
      imagever2 = imagever.split('-')[2]
      imagever = "#{imagever2.split('_')[0]}-#{imagever.split('-')[3]}"
      if imagever.include? '/'
        imagever = imagever.split('/')[0]
      end
      status[ip]['progress'] = "#{imagever} | #{prog} (P:#{passes} F:#{fails},E:#{errors},S:#{skips})"
      status[ip]['progresscolor'] = "color:white;"
      return
    else
      #If the log file is created, but there is not results yet, we tell this.
      status[ip]['progress'] = 'No results yet'
      status[ip]['progresscolor'] = "color:white;"
      return
    end
  end
end
