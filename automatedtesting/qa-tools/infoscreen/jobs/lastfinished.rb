#This file contains the function to determine the results of already run tests.
#The code to gather the information is somewhat similar to how the progress is determined,
#but I figured it would be easier to not try and use same function for these.
require "json"
#Function
def lastfinished(status, results)
  #For each SUT in HASH
  $sut.each do |ip, sut|
    #If the finished flag is changed from 1 to 0
    if $sut[ip][:finished] == 0
      #If the tests are still running, we skip results check and come back later
      if status[ip]['status'] == 'Autotest' || status[ip]['status'] == 'Stability'
        next
      else
        #Else we start getting results.
        #i is used to index the results.
        i = results.length
        #We change the finished flag to 1, so we wont be gathering the same results again later
        $sut[ip][:finished] = 1
        #If the last test was autotest
        if $sut[ip][:lasttest] == 'auto'
          #Last test results location
          latest = `ls -td #{$autotestpath}#{sut[:name]}*/ | head -n 1`[0...-1]
          latest = `ls -td #{latest}20*/ | head -n 1`[0...-1]
          #Imageversion
          imagever = `cat "$(ls -rt #{$autotestpath}#{sut[:name]}*/last_installed_zip.txt | tail -n 1)"`[0...-1]
          imagever = imagever.split('/')[7]
          imagever2 = imagever.split('-')[2]
          imagever = "#{imagever2.split('_')[0]}-#{imagever.split('-')[3]}"
          if imagever.include? '/'
            imagever = imagever.split('/')[0]
          end
          #Jira logs first line to determine the issue key. This will be changed later, because the jira log will be changed.
          firstlinejira = `cat #{latest}*jira_upload.log | head -n 1`[0...-1]
          jira = ''
          master = 0
          if firstlinejira[0...10] == 'Initiating' || firstlinejira == ''
            file = open("#{latest}issue_key.json")
            json = file.read
            json = JSON.parse(json)
            jira = json["key"]
          #New nightly continous tests have different way to store jira issue key
          else
            jira = firstlinejira.split('"')[9]
            lastlinejira = `cat #{latest}*jira_upload.log | tail -3 |head -1`[0...-1]
            if lastlinejira[0...18] == 'Importing issue to'
              jira = lastlinejira.split(' ')[3]
              master = 1
            end
          end
          #If the issue key already exists in results
          exists = `grep '#{jira}' results.yml`[0...-1]
          if jira != '' && exists != ''
            break
          end
          #Results for the test, passes, fails etc.
          prog = `grep '^Test ' #{latest}*#{sut[:name]}*TestRun.txt | tail -n 1`[0...-1]
          if prog == ''
            break
          end
          stat = `grep -A 1 '^Test ' #{latest}*#{sut[:name]}*TestRun.txt | tail -n 1`[0...-1]
          passes = stat.count('.')
          fails = stat.count('F')
          errors = stat.count('E')
          skips = stat.count('S')
          prog = prog.split(',')[0]
          prog[0...4] = ''
          #Initialization of results hash
          results[i] = {}
          #Lets save the name of the test device
          results[i]['resultssut'] = sut[:label]
          #There was something wrong if there is no jira issue, lets mark it with red. Otherwise save the results
          if jira == ''
            results[i]['results'] = "Error | #{DateTime.now.strftime('%d %b %Y %H:%M')} | #{imagever} | #{prog} (P:#{passes},F:#{fails},E:#{errors},S:#{skips})"
            results[i]['resultscolor'] = "color:red;"
          else
            if master == 0
              results[i]['results'] = "Smoke | #{DateTime.now.strftime('%d %b %Y %H:%M')} | #{imagever} | #{jira} | #{prog} (P:#{passes},F:#{fails},E:#{errors},S:#{skips})"
              results[i]['resultscolor'] = "color:yellow;"
            else
              results[i]['results'] = "Nightly | #{DateTime.now.strftime('%d %b %Y %H:%M')} | #{imagever} | #{jira} | #{prog} (P:#{passes},F:#{fails},E:#{errors},S:#{skips})"
              results[i]['resultscolor'] = "color:yellow;"
            end
          end
          next
          #If the last test was stability
        elsif $sut[ip][:lasttest] == 'stab'
          begin
            latest = `ls -td #{$stabilitypath}/#{ip}*/ | head -n 1`[0...-1]
            err = `grep 'Error' #{latest}/testrun.log`[0...-1]
            report = open("#{latest}/report.json")
            report = report.read
            json = JSON.parse(report)
            time = json.last['runtime']
            stress = json.last['load']
            time = time.to_f
            stress = stress.to_f
            if stress > 10.0
              stress = 'STRESS'
            elsif stress > 1
              stress = 'MEDIUM'
            else
              stress = 'IDLE'
            end
            pros = ((time / 432000) * 100).round
            val = [time.round / 3600, time.round/ 60 % 60, time.round % 60].map { |time| time.to_s.rjust(2,'0') }.join(':')
            if err != ''
              status[ip]['results'] = "#{val} (#{pros}%) | #{stress} | Error"
              status[ip]['resultcolor'] = "color:red;"
              return
            else
              #Otherwise we just tell the current progress
              status[ip]['results'] = "#{val} (#{pros}%) | #{stress}"
              status[ip]['resultcolor'] = "color:white;"
              return
            end
          rescue
            puts 'exception'
            next
          end
        end
      end
      #We just skip to the next SUT if the finished flag is 1
    else
      next
    end
  end
end
