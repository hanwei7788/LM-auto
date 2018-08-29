#This is the status file and it contains the function that is used to determine
#the test status of the SUTs

#Teststatus function
def teststatus(status)
  #Lets go though all the SUTs
  $sut.each do |ip, sut|
    #We grep the ps aux listing to determine what tests are running on each of the devices
    stability = `ps aux | grep #{ip} | grep #{$stabilityprocess}`[0...-1]
    autotest = `ps aux | grep #{sut[:name]} |grep #{$autotestprocess}`[0...-1]
    canwakeup = `ps aux |grep #{ip} |grep [C]anWakeupTest.sh`[0...-1]
    recovery = `ps aux |grep #{ip} |grep [R]ecoveryUpdateTest.sh`[0...-1]
    manual = `ps aux | grep '#{sut[:name]}$' |grep #{$manualprocess}`[0...-1]
    if autotest != ''
      #Same stuff as with stability
      $sut[ip][:finished] = 0
      $sut[ip][:lasttest] = 'auto'
      status[ip]['status'] = 'Autotest'
      status[ip]['statuscolor'] = "color:yellow;"
      next
    #If the test is stability, then...
    elsif stability != ''
      #Finished and lasttest flags are only used to help the results function.
      #This is why they are saved in gloval $sut hash.
      $sut[ip][:finished] = 0
      $sut[ip][:lasttest] = 'stab'
      #Save the wanted data to hash and give it a nice colour
      status[ip]['status'] = 'Stability'
      status[ip]['statuscolor'] = "color:yellow;"
      next
    elsif canwakeup != ''
      #Same stuff as with stability
      status[ip]['status'] = 'CanWakeupTest'
      status[ip]['statuscolor'] = "color:yellow;"
      next
    elsif recovery != ''
      #Same stuff as with stability
      status[ip]['status'] = 'RecoveryTest'
      status[ip]['statuscolor'] = "color:yellow;"
      next
    elsif manual != ''
      #Manual test does not show results, because they can be anywhere.
      #That is why there is no finished and last test flags.
      status[ip]['status'] = 'Manual'
      status[ip]['statuscolor'] = "color:yellow;"
      next
    else
      #Idle. Just Idle.
      status[ip]['status'] = "Idle"
      status[ip]['statuscolor'] = "color:white;"
      next
    end
  end
end
