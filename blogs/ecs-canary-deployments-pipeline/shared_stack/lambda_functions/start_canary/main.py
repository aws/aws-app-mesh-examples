""" Function to deploy the canary version. """
import logging
import boto3
from botocore.exceptions import ClientError

# Logging
LOGGER = logging.getLogger(__name__)
LOGGER.setLevel(logging.INFO)

#Client connections
APPMESH_CLIENT = boto3.client('appmesh')

def _perform_canary(event, current_vn_weight, new_vn_weight, current_vn, new_vn):
    """ Function to perform Canary. """

    new_vn = event['MicroserviceName']+'-'+event['Sha']
    try:
        if event['Protocol'].lower() == 'http':
            spec={
                'httpRoute': {
                    'action': {
                        'weightedTargets': [
                            {
                                'virtualNode':current_vn,
                                'weight':current_vn_weight
                            },
                            {
                                'virtualNode':new_vn,
                                'weight':new_vn_weight
                            }
                        ]
                    },
                    "match": {
                                "prefix": "/"
                            },
                    'retryPolicy': {
                        'httpRetryEvents': [
                            'server-error',
                            'client-error',
                            'gateway-error'
                        ],
                        'maxRetries': 2,
                        'perRetryTimeout': {
                            'unit': 'ms',
                            'value': 2000
                        }
                    }
                }
            }
        else:
            spec={
                'tcpRoute': {
                    'action': {
                        'weightedTargets': [
                            {
                                'virtualNode':current_vn,
                                'weight':current_vn_weight
                            },
                            {
                                'virtualNode':new_vn,
                                'weight':new_vn_weight
                            }
                        ]
                    },
                    'timeout': {
                        'idle': {
                            'unit': 'ms',
                            'value': 2000
                        }
                    }
                }
            }

        APPMESH_CLIENT.update_route(
            meshName=event['EnvironmentName'],
            routeName=event['MicroserviceName']+'-'+'route',
            spec=spec,
            virtualRouterName=event['MicroserviceName']+'-'+'vr'
        )
        return True
    except ClientError as _ex:
        LOGGER.error("Update route failed during subsequent canary rollouts")
        return False

def lambda_handler(event, _context):
    """ Main handler. """

    if event['deployment']['new_version'] == 1:
        LOGGER.info("Detected its first revision of the app, hence settings weight to 100.")
        try:
            if event['Protocol'].lower() == 'http':
                spec={
                    'httpRoute': {
                        'action': {
                            'weightedTargets': [
                                {
                                    'virtualNode': event['MicroserviceName']+'-'+event['Sha'],
                                    'weight': 100
                                },
                            ]
                        },
                        "match": {
                                    "prefix": "/"
                                },
                        'retryPolicy': {
                            'httpRetryEvents': [
                                'server-error',
                                'client-error',
                                'gateway-error'
                            ],
                            'maxRetries': 2,
                            'perRetryTimeout': {
                                'unit': 'ms',
                                'value': 2000
                            }
                        }
                    }
                }
            else:
                spec={
                    'tcpRoute': {
                        'action': {
                            'weightedTargets': [
                                {
                                    'virtualNode': event['MicroserviceName']+'-'+event['Sha'],
                                    'weight': 100
                                },
                            ]
                        },
                        'timeout': {
                            'idle': {
                                'unit': 'ms',
                                'value': 2000
                            }
                        }
                    }
                }

            APPMESH_CLIENT.create_route(
                meshName=event['EnvironmentName'],
                routeName=event['MicroserviceName']+'-'+'route',
                spec=spec,
                virtualRouterName=event['MicroserviceName']+'-'+'vr'
            )
            return {
                    "new_vn_weight": 100
                }
        except ClientError as ex:
            LOGGER.error("Exception occured during creating a route for initial deployment")
            raise ex
    else:
        LOGGER.info("Executing the subsequent deployments")
        route = event['Protocol']+'Route'
        entries = APPMESH_CLIENT.describe_route(
            meshName=event['EnvironmentName'],
            routeName=event['MicroserviceName']+'-'+'route',
            virtualRouterName=event['MicroserviceName']+'-'+'vr'
        )['route']['spec'][route]['action']['weightedTargets']
        print(entries)
        for entry in entries:
            if entry['weight'] == 100:
                current_vn = entry['virtualNode']
                current_vn_weight = 100-int(event['PercentageStep'])
                current_vn_sha = entry['virtualNode'].split('-')[-1]
                new_vn_weight = 0+int(event['PercentageStep'])
                new_vn = event['MicroserviceName']+'-'+event['Sha']

                if _perform_canary(event, current_vn_weight, new_vn_weight, current_vn, new_vn):
                    LOGGER.info("Performing the Canary, new virtualNode weight is %s", new_vn_weight)
                    return {
                            "new_vn_weight":new_vn_weight,
                            "current_vn_weight":current_vn_weight,
                            "current_vn_sha":current_vn_sha
                        }
                else:
                    return {
                        "status":"FAIL"
                    }
            else:
                if entry['virtualNode'].endswith(event['Sha']):
                    new_vn_weight = 100 if (entry['weight']+int(event['PercentageStep'])) > 100 else (entry['weight']+int(event['PercentageStep']))
                    new_vn = entry['virtualNode']
                    current_vn_weight = 0 if (int(event['canary_results']['current_vn_weight'])-int(event['PercentageStep'])) < 0  else (int(event['canary_results']['current_vn_weight'])-int(event['PercentageStep']))
                    current_vn = event['MicroserviceName']+'-'+event['canary_results']['current_vn_sha']
                    if _perform_canary(event, current_vn_weight, new_vn_weight, current_vn, new_vn):
                        LOGGER.info("Performing the Canary, new virtualNode weight is %s", new_vn_weight)
                        return {
                            "new_vn_weight":new_vn_weight,
                            "current_vn_weight":current_vn_weight,
                            "current_vn_sha":event['canary_results']['current_vn_sha']
                        }
                    else:
                        return {
                            "status":"FAIL"
                        }
