# Web log to tests

This tool looks at a webapp's log to determine its current behavior and generate tests to flag deviations from that behavior. The tool works well for the situation where 

the web application under test has complicated behavior that is not well understood 
there are no significant side effects (e.g., database updates) to the application's functionality

The tool can parse an arbitrary number of log files. It will not create duplicate tests for repeated queries. It will record the most recent returned output as the "current" output.  When run with the -reset_expected flag, the tool can query the application to update its reckoning of the "correct" output for each of its tests, so if the application has evolving functionality, it is a quick and easy task to update the test to reflect the latest behavior.

##Overcoming expected variability of output.

 - You can suppress or replace textual strings as defined by regular expressions to, for example, eliminate timestamps.

 - The tool does not assume that JSON arrays will have any particular order, so it is possible to test applications which give equivalent but differently ordered output across different servers. This fits particularly well with applications which are running on top of MongoDB.
.
