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

    print(f"Updating mesh TLS to {mesh_update}...")

    for svc in [color_gateway_svc, color_teller_svc]:
        print(f"Updating service: {svc}")
        ecs.update_service(
            cluster=ecs_cluster,
            service=svc,
            forceNewDeployment=True)
