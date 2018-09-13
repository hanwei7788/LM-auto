#This is the main file that handles initialization of the infoscreen and timing of the screen update,,
#along with sendin the data to the frontend.

#YAML is required for the result saving in a yml file
require 'yaml'

#Initialization of the results and status hashes globally, so that they can be used by both SCHEDULER tasks
results = {}
status = {}

#Initialization of finished flag(needed to determine when to gather the results) and
#reading of the old results from the yml file
SCHEDULER.in '5s' do
  $sut.each do |ip, sut|
    $sut[ip][:finished] = 1
  end
  results =  YAML.load_file('results.yml')
  #YAML gives false if the file is empty. Initialize manually.
  if results == false
    results = {}
  end
end

#Lets run this main task once a minute
SCHEDULER.every '1m' do
  #Power status of SUTs. Function itself is in power.rb file
  power(status)
  #Test status of the SUTs. Function itself is in status.rb file
  teststatus(status)
  #Progress of the tests on SUTs. Function itself is in progress.rb file
  progress(status)
  #Results of tests. Function itself is in lastfinished.rb file
  lastfinished(status, results)
  #This is to make sure there aren't too many results sent to frontend,
  #so that the UI does not get confused
  resultstemp = {}
  i = results.length - 1
  until resultstemp.length == 22 do
    if i == -1
      break
    elsif results[i] == {}
      i = i - 1
      next
    else
      resultstemp[i] = results[i]
    end
    i = i - 1
  end
  #Lets order the results so that the newest ones are on top
  #resultstemp = Hash[resultstemp.sort_by {|k,v| k.to_i }.reverse!]
  #Send all the data to frontend
  send_event('status', {items: status.values})
  send_event('results', {items: resultstemp.values})
  #Save the results to yml file
  File.write('results.yml', results.to_yaml)
end
