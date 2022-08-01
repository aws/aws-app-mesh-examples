import json
import boto3
import base64
import os
import cfnresponse

sm = boto3.client('secretsmanager')
cm = boto3.client('acm')
pca = boto3.client('acm-pca')
gate_cm = os.environ['COLOR_GATEWAY_ACM_ARN']
teller_cm = os.environ['COLOR_TELLER_ACM_ARN']
teller_pca_cm = os.environ['COLOR_TELLER_ACM_PCA_ARN']
gateway_pca_cm = os.environ['COLOR_GATEWAY_ACM_PCA_ARN']
acc_id = os.environ['AWS_ACCOUNT']
secret = os.environ['SECRET']


print('gate_cm -> ', gate_cm)
print('teller_cm -> ', teller_cm)
print('teller_pca_cm -> ', teller_pca_cm)
print('gateway_pca_cm -> ', gateway_pca_cm)
print('acc_id -> ', acc_id)
print('secret -> ', secret)


def lambda_handler(event, context):
    print(json.dumps(event))
    if (event['RequestType'] == 'Delete') or (event['RequestType'] == 'Update'):
        cfnresponse.send(event, context, cfnresponse.SUCCESS, {}, '')
    elif event['RequestType'] == 'Create':
        try:
            pca.create_permission(
                CertificateAuthorityArn=teller_pca_cm,
                Principal='acm.amazonaws.com',
                SourceAccount=acc_id,
                Actions=[
                    'IssueCertificate',
                    'GetCertificate',
                    'ListPermissions'
                ]
            )
            pca.create_permission(
                CertificateAuthorityArn=gateway_pca_cm,
                Principal='acm.amazonaws.com',
                SourceAccount=acc_id,
                Actions=[
                    'IssueCertificate',
                    'GetCertificate',
                    'ListPermissions'
                ]
            )
            passphrase = sm.get_random_password(ExcludePunctuation=True)[
                'RandomPassword']
            passphrase_enc = base64.b64encode(passphrase.encode('utf-8'))
            cm.export_certificate(CertificateArn=teller_cm,
                                  Passphrase=passphrase_enc)
            gate_rsp = cm.export_certificate(
                CertificateArn=gate_cm, Passphrase=passphrase_enc)
            sm_value = {}
            sm_value['GatewayCertificate'] = gate_rsp['Certificate']
            sm_value['GatewayCertificateChain'] = gate_rsp['CertificateChain']
            sm_value['GatewayPrivateKey'] = gate_rsp['PrivateKey']
            sm_value['Passphrase'] = passphrase
            sm.put_secret_value(
                SecretId=secret, SecretString=json.dumps(sm_value))
            cfnresponse.send(event, context, cfnresponse.SUCCESS, {}, '')

        except Exception as e:
            print(e)
            cfnresponse.send(event, context, cfnresponse.FAILED, {}, '')