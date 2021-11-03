# terraformGroupExercise

>> MegaFile.tf contains all the provisioning of the infrastructure required for the task set.
>> "aws_diagram.jpg" contains the infrastructure design that this terraform code aims to provision.


Attempts were made to provision the following services but could not be achieved.
   - CLOUDFRONT (Route 53 required)
   - ROUTE 53 (Did not have an available domain name for testing)
   - Link between cloudwatch and S3 should be done manually (with lambda)
   - Currently no way to link ECR to S3 from codepipeline, this would have to be done manually
   
   ![AWS infrastructure design ("aws_diagram.jpg" within the root directory)](/aws_diagram.jpg)
