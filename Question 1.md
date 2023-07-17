# Question 1

1. To begin debugging the problem I would take the following debugging steps:
   1. Read the error messages from "Web_Application_Alive" tests - this would give an initial indication of the error.
   2. Do a DNS Lookup and Comparison- ensure that the DNA records are properly resolving to the load balancer
   3. Check the status of targets and backend: I would determine if any of the targets are down or unhealthy
   4. Ensure that security groups are properly configured and other network config: I would validate that none of the security groups are overly restrictive and all other network configurations (routing tables etc.) are properly configured.
   5. Check for AWS outages


2. I would use the following tools to troubleshoot and metrics to troubleshoot:
   1. VPC Flow Logs: I would use this to capture traffic going to and from the different netwokr interfaces in the VPC. I would use this to help detect too restrictive security goup rules and monitor the traffic reaching the instances.
   2. ALB Logs: This would be used to troubleshoot the application load balancer by tracking requests sent to it and provide valuable metrics with regards to latency, server responses. and request paths.
   3. Health Checks: 
   4. Cloudwatch: Cloudwatch Logs and Cloudwatch Metrics would be used to track Route 53 DNS queries and contain inportant information about the EC2 instances. We can track metrics such as CPU Uitlization, Disk Read Operations, Disk Write Operations, Network In and Network Out over time. We could use this to check the state of the EC2 instance before and after the downtime and use that to determine the potential source of the problem.
   5. CloudTrail : This tool would provide valuable information with regards to changes made within the system, users/groups/or services that made that change and when the change was made. This would help expose any bad actors or indicate if a service was making unintentional changes to the infrastructure resulting in this downtime.
   6. AWS Health Dashboard: This would be used to detect any AWS outages.
   7. External Logging tools

3. For this Architecture, I would recommend placing the two Web Servers within an Autoscaling group and place that autoscaling group as the target of of the application load balancer. This would help with scalability as it seems that the Web Applicationwas failed around 4:35 pm on a Friday. One very probale reason for this would be the Web App Servers were overwhelmed by the amount of requests coming from the application load balancer. By placing these servers in an autoscaling group, a new web server would instantiate and take on some of the load the other two servers were handling and when not needed, this instance can also be automatically terminated. This scaling policy can be configured to occur at specific hours of the day or based on specified metrics.
I would also add a notification system using Amazon SNS to notify admin users and other relevant people when there are problems (or foreshadowed problems) within the system. This would allow for problems to be detected more quickly.
My final recommendation would also be to use infrastructre as code to deply this infrastucture as it will be more easy to manage and implement change within the system.
   
After-Action Report

## CoalFire
### After-Action Report: Imaginary Application Downtime
### Jul 17, 202323

a. Overview
  Friday, July 14th 2023, customers reported being unable to access the Imaginary Application website and at 4:35 pm the "Web_Application_Alive" test attempts  began failing indicating critical issues within the system.

b. Participants
  The following individuals are stakeholders within this incident:
  - Security Engineer, Ally Hobbs
  - Cloud Infrastructure Architect

c. Timeline
  - July 14th 2023, 4:35 pm - Web Application is unresponsive
  - July 14th 2023, 9:00 pm - Troubleshooting and testing begins
  - July 14th 2023, 10:30 pm- Temporary fix of an additional two instances added to the Web Sever private subnets were added
  - July 15th 2023, 8:00 am- Meeting with Staekholders to determine a long term solutions
  - July 16th 2023 - new solution will be implemented

d. Root Cause Analysis
   After reading through Cloudwatch Logs and Cloudwatch metrics, it was determined that the CPUUtilization metric of the two EC2 instances was at 100% resulting in the two instances to be unresponsive. Our recommendation is to place the two instances in an autoscaling group to create new instances  when CPU Utilization reaches over 50% on both instances. This would allow for new instances to be created and offload the traffic being sent to the other two instances and prevent crashing in the future.