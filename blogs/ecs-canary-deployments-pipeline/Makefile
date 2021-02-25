set-env:
	@chmod +x ./setup/scripts/export_environment_variables.sh
	./setup/scripts/export_environment_variables.sh

create-vpc:
	@chmod +x ./setup/scripts/create_vpc.sh
	./setup/scripts/create_vpc.sh

create-ecs-mesh:
	@chmod +x ./setup/scripts/create_ecs_mesh.sh
	./setup/scripts/create_ecs_mesh.sh

create-monitoring-resources:
	@chmod +x ./setup/scripts/create_prometheus_env.sh
	./setup/scripts/create_prometheus_env.sh

create-shared-cloudformation-stack: 
	@chmod +x ./setup/scripts/create_shared_cloudformation_stack.sh
	./setup/scripts/create_shared_cloudformation_stack.sh

create-sample-microservice-pipeline-stack: 
	@chmod +x ./setup/scripts/create_sample_microservice_pipeline_stack.sh
	./setup/scripts/create_sample_microservice_pipeline_stack.sh

venv:
	: # Create venv if it doesn't exist
		test -d venv || python -m venv venv && . venv/bin/activate

delete-blog-contents: venv
	pip install -r requirements.txt && python ./setup/scripts/delete_blog_contents.py
