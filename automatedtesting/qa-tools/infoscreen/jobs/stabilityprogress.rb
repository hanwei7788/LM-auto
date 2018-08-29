#File that has stability progress function in it, to determine the progress of plotfaster stability tests

#Function.
def stabilityprogress(status, sut, ip)
  begin
    latest = `ls -td #{$stabilitypath}/#{ip}*/ |head -n 1`[0...-1]
    #Grep for errors
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
      status[ip]['progress'] = "#{val} (#{pros}%) | #{stress} | Error"
      status[ip]['progresscolor'] = "color:red;"
      return
    else
      #Otherwise we just tell the current progress
      status[ip]['progress'] = "#{val} (#{pros}%) | #{stress}"
      status[ip]['progresscolor'] = "color:white;"
      return
    end
  rescue
    puts 'exception'
  end
end
