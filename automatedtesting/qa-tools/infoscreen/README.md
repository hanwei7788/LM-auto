# Infoscreen logger for automatedtesting
Used to show the needed data from autotest server.  
The program shows the power status, test status and test progress of the stability and autotests.
This program assumes the data is always in the same format on the filesystem.  
Any changes to the file system or reporting system will lead in changing of code.

#Config
New devices can be added by adding them in jobs/config.rb file.  
Just make sure the devices and IPs have same indexes and everything should be fine.

#Usage
The software uses dashing gem (http://dashing.io) to show the data in frontend.  
Dashboard can be seen at port 3030 (192.168.125.128:3030/autotest).  
