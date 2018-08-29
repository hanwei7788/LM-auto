#Progress file
#Determines the progress of the tests.

#Progress function
def progress(status)
  #For each SUT
  $sut.each do |ip, sut|
    #We check the status that we determined earlier,
    #depending on it we call the progress functions
    if status[ip]['status'] == 'Autotest'
      autotestprogress(status, sut, ip)
    elsif status[ip]['status'] == 'Stability'
      stabilityprogress(status, sut, ip)
    elsif status[ip]['status'] == 'CanWakeupTest'
      status[ip]['progress'] == 'Not implemented'
    elsif status[ip]['status'] == 'Manual'
      #If the test is manual, we just say it is not implemented yet. Do not know if it ever will,
      #because it is kind of impossible to know where manual test results will be saved.
      status[ip]['progress'] = 'Not implemented'
    elsif status[ip]['status'] == "Idle"
      latest = `ls -td #{$autotestpath}#{sut[:name]}*/ | head -n 1`[0...-1]
      latest = `ls -td #{latest}2017*/ | head -n 1`[0...-1]
      failed = `find #{latest} -name *TestRun.txt`[0...-1]
      if failed == '' && latest != ''
        status[ip]['progress'] = "Last test failed to proceed"
        status[ip]['progresscolor'] = "color:red;"
      else
        #Idle will be shown as empty in progress tab
        status[ip]['progress'] = ' '
        status[ip]['progresscolor'] = "color:white;"
      end
    end
  end
end
