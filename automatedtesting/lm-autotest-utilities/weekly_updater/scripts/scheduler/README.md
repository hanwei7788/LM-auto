---- README file for scheduler tool ----

Scheduler is supposed to be used with weekly image testing. During the weekly tests
there are some time frames when certain functions are not allowed to be done. These time frames 
are configured in the test case folder under a text file schedule.txt. Time frame template has 3 parts
1. start of the frame, 2. end of the frame and 3. what is allowed to do during that frame.

What is allowed to do is in two booleans. first "is is allowed to interrupt test run" and second 
"is allowed to upload test results". This is echoed to the caller and the caller is acting according to
the return value (echo value).

Examples: 1. 	1-1 is allowed to interrupt test run, is allowed to upload results
		0-1 not allowed to interrupt test run, allowed to upload results
		... 
 
		echoing -1 meaning there is something wrong with the schedule.txt, or something else.
