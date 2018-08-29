#Power file
#Takes care of updating the power and ping status of the SUTs..

#Required library for the ping function
require 'net/ping'

#Ping function, used  to determine whether the device is online or offline
def up?(host)
  check = Net::Ping::External.new(host)
  check.ping?
end

#Power function that is called from main.rb file
def power(status)
  #This is so that tdtool is not polled too much. Now only once per minute
  `tdtool -l > /tmp/tdtoollist.txt`
  #Lets go through all the SUTs
  $sut.each do |ip, sut|
    #Initialize HASH and save label of the device in it
    status[ip] = {}
    status[ip]['label'] = sut[:label]
    #Check the power status on the socket. Assuming that TDTOOLs data is updated.
    tdtool = `cat /tmp/tdtoollist.txt |grep -P '#{sut[:switch]}\t'`
    tdtool = tdtool.split("\t")[2].to_s
    tdtool.gsub!(/\s+/, '')
    #Lets give nice colours depending what the data is
    if tdtool == "ON"
      status[ip]['powercolor'] = "color:green;"
    elsif tdtool == "OFF"
      status[ip]['powercolor'] = "color:orange;"
    else
      #This is mainly for devices that do not have power socket installed yet, currently only ATP12
      tdtool = '???'
      status[ip]['powercolor'] = "color:white;"
    end
    status[ip]['power'] = tdtool
    #Lets pass the ip we got has to the ping function to determine whether the device is online or offline
    if up?(ip)
      #Save the gathered data, in this case ONLINE, to status HASH. Also give nice colours to the data.
      status[ip]['ping'] = "ONLINE"
      status[ip]['pingcolor'] = "color:green;"
      next
    else
      #Save the gathered data, in this case OFFLINE, to status HASH. Also give nice colours to the data.
      status[ip]['ping'] = "OFFLINE"
      status[ip]['pingcolor'] = "color:white;"
      next
    end
  end
end
