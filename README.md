# employee
Employee Challenge

Deployment Instructions and Requirements.

1. Download jdk 8 and install. http://www.oracle.com/technetwork/java/javase/downloads/jdk8-downloads-2133151.html?printOnly=1
2 Download Apache Tomcat and install. https://tomcat.apache.org/download-70.cgi
3 Download and install postgresql 9.4.
4 Download and unzip employee system from http:// and unzip to tomcat installation folder/webapps.
5 Copy postgres jar file from employee folder WEB-INF/lib to you tomcat installation folder/lib.
6 Restart your tomcat and employee system will be deployed, then on your browser type localhost:8080/employee to access the system.
7. Create database name employee in postgres and run employee.sql file to create table and default data. Root credential are username: root and password: baraza.

Employee System Assumptions

1. In this system we assume that the employee receive and verified his/her email.:-
	- The configuration for emails require an active server where the application can be deployed 	and email setup is well configure. Where emails to be send should be defined on configuration  	emails tab on the system.
2. We also assume that SMSs are send for employee details verification.


