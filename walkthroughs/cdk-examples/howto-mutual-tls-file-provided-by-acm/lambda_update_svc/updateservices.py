import boto3
import os


ecs = boto3.client('ecs')
ecs_cluster = os.environ['CLUSTER']
color_gateway_svc = os.environ['SVC_GATEWAY']
color_teller_svc = os.environ['SVC_TELLER']
mesh_update = os.environ['MESH_UPDATE']


def lambda_handler(event, context):

    if mesh_update not in ['one-way-tls', 'mtls']:
        return

    ecs.update_service(
        cluster=ecs_cluster,
        service=color_teller_svc,
        forceNewDeployment=True)
    ecs.update_service(
        cluster=ecs_cluster,
        service=color_gateway_svc,
        forceNewDeployment=True)

    # Wait for the services to be stable
    waiter = ecs.get_waiter('services_stable')
    waiter.wait(cluster=ecs_cluster, services=[
                color_gateway_svc, color_teller_svc])
