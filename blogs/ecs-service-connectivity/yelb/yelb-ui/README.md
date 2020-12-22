This is the user interface module. It's an Angular2 application that uses the VMware open source [Clarity framework](https://clarity.design/).

The way this works may be a bit cumbersome. I basically clone the Clarity seed, I check out a specific commit (one that I have tested) and then copy/replace the files that are in the directory `clarity-seed-newfiles`. These files are both code and configuration of my app. You can look at the mechanics of how this happens either in the `Dockerfile` in this directory or in the `yelb-ui.sh` script in the `deployments/platformdeployment/Linux` directory. 

Depending on the deployment model being used the compile of the Angular2 application happens at different times. 

For the EC2 deployment model, the UI gets compiled at deployment time via running the setup via cloud-init scripts. This is why the app may take a while to become available even though the CFN stack says it's all green and good. The instance where the UI is deployed takes about 5 minutes (or more depending on the instance type) to compile everything and start vending the javascript code. 

For the container deployment model, the UI gets compiled at container image build time. This actually uses a two phase build where the resulting javascript code is copied into a brand new image based off of the `nginx` official image. Check out the Dockerfile to see how that works. 

For the serverless deployment model the UI gets compiled once and pushed to an S3 bucket. This (public) bucket is then used as a source for deploying a new bucket that vends the code to the browser that makes the request. This requires an additional tweak because by default the application is configured to use the IP/FQDN of the UI web server to make the application API calls. This works fine for the EC2 and container deployments because the nginx will act as a proxy but in this case the UI needs to be pre-configured with the end-point of the API Gateway that makes available the API calls (which in turns call the Lambdas). Check out the serverless deployment model for more details on how that tweak works. 

