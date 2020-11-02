# Mesh components for Crystal backend
Certificate_Arn=$(aws acm list-certificates |jq -r '.CertificateSummaryList[] | select(.DomainName=="*.appmeshworkshop.hosted.local")'.CertificateArn);
CA_Arn=$(aws acm-pca list-certificate-authorities | jq -r '.CertificateAuthorities[] | select(.CertificateAuthorityConfiguration.Subject.CommonName=="appmeshworkshop.hosted.local")'.Arn);
SPEC=$(cat <<-EOF
  { 
    "serviceDiscovery": {
      "dns": { 
        "hostname": "crystal.appmeshworkshop.hosted.local"
      }
    },
    "backendDefaults": {
      "clientPolicy": {
        "tls": {
          "validation": {
            "trust": {
              "acm": {
                "certificateAuthorityArns": [
                  "$CA_Arn"
                ]
              }  
            }
          }
        }
      }
    },
    "logging": {
      "accessLog": {
        "file": {
          "path": "/dev/stdout"
        }
      }
    },      
    "listeners": [
      {
        "healthCheck": {
          "healthyThreshold": 3,
          "intervalMillis": 10000,
          "path": "/health",
          "port": 3000,
          "protocol": "http",
          "timeoutMillis": 5000,
          "unhealthyThreshold": 3
        },
        "portMapping": { "port": 3000, "protocol": "http" },
        "tls": {
          "mode": "PERMISSIVE",
          "certificate": {
            "acm": {
              "certificateArn": "$Certificate_Arn"
            } 
          }
        }  
      }
    ]
  }
EOF
); 
# Create app mesh virual node for crystal backend
aws appmesh create-virtual-node \
  --mesh-name appmesh-workshop \
  --virtual-node-name crystal-lb-vanilla \
  --spec "$SPEC"

#Virtual Service for crystal backend
  
SPEC=$(cat <<-EOF
  { 
    "provider": {
      "virtualNode": { 
        "virtualNodeName": "crystal-lb-vanilla"
      }
    }
  }
EOF
);
aws appmesh create-virtual-service   --mesh-name appmesh-workshop   --virtual-service-name crystal.appmeshworkshop.hosted.local   --spec "$SPEC"

## Now creating the Nodejs appmesh components

SPEC=$(cat <<-EOF
{ 
    "serviceDiscovery": {
      "dns": { 
        "hostname": "nodejs.appmeshworkshop.hosted.local"
      }
    },
    "backendDefaults": {
      "clientPolicy": {
        "tls": {
          "validation": {
            "trust": {
              "acm": {
                "certificateAuthorityArns": [
                  "$CA_Arn"
                ]
              }  
            }
          }
        }
      }
    },
    "logging": {
      "accessLog": {
        "file": {
          "path": "/dev/stdout"
        }
      }
    },      
    "listeners": [
      {
        "healthCheck": {
          "healthyThreshold": 3,
          "intervalMillis": 10000,
          "path": "/health",
          "port": 3000,
          "protocol": "http",
          "timeoutMillis": 5000,
          "unhealthyThreshold": 3
        },
        "portMapping": { "port": 3000, "protocol": "http" },
        "tls": {
          "mode": "PERMISSIVE",
          "certificate": {
            "acm": {
              "certificateArn": "$Certificate_Arn"
            } 
          }
        }  
      }
    ]
  }
EOF
);
# Creating Virtual Node for nodejs
aws appmesh create-virtual-node --mesh-name appmesh-workshop  --virtual-node-name nodejs-lb-strawberry --spec "$SPEC"
  
# Creating Virtual Service for nodejs
SPEC=$(cat <<-EOF
  { 
    "provider": {
      "virtualNode": { 
        "virtualNodeName": "nodejs-lb-strawberry"
      }
    }
  }
EOF
);
aws appmesh create-virtual-service   --mesh-name appmesh-workshop   --virtual-service-name nodejs.appmeshworkshop.hosted.local   --spec "$SPEC"

# Mesh Components for Frontend Ruby application

EXT_LOAD_BALANCER=$(jq < cfn-crystal.json -r '.ExternalLoadBalancerDNS');
SPEC=$(cat <<-EOF
  { 
    "serviceDiscovery": {
      "dns": { 
        "hostname": "$EXT_LOAD_BALANCER"
      }
    },
    "backendDefaults": {
      "clientPolicy": {
        "tls": {
          "validation": {
            "trust": {
              "acm": {
                "certificateAuthorityArns": [
                  "$CA_Arn"
                ]
              }  
            }
          }
        }
      }
    },
    "backends": [
      {
        "virtualService": {
          "virtualServiceName": "crystal.appmeshworkshop.hosted.local"
        }
      },
      {
        "virtualService": {
          "virtualServiceName": "nodejs.appmeshworkshop.hosted.local"
        }
      }
    ],      
    "logging": {
      "accessLog": {
        "file": {
          "path": "/dev/stdout"
        }
      }
    },      
    "listeners": [
      {
        "healthCheck": {
          "healthyThreshold": 3,
          "intervalMillis": 10000,
          "path": "/health",
          "port": 3000,
          "protocol": "http",
          "timeoutMillis": 5000,
          "unhealthyThreshold": 3
        },
        "portMapping": { "port": 3000, "protocol": "http" },
        "tls": {
          "mode": "PERMISSIVE",
          "certificate": {
            "acm": {
              "certificateArn": "$Certificate_Arn"
            } 
          }
        }  
      }
    ]
  }
EOF
); 
# Creating the virtual node
aws appmesh create-virtual-node --mesh-name appmesh-workshop   --virtual-node-name frontend  --spec "$SPEC"
# Creating the virtual service
SPEC=$(cat <<-EOF
  { 
    "provider": {
      "virtualNode": { 
        "virtualNodeName": "frontend"
      }
    }
  }
EOF
);
aws appmesh create-virtual-service --mesh-name appmesh-workshop --virtual-service-name frontend.appmeshworkshop.hosted.local --spec "$SPEC"
