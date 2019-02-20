## Steps

1. Prometheus runs on port: `9090`, Access promotheus using this url:  http://<load-balancer-dns-name>:9090/targets
2. Grafana runs on port: `3000` to access grafana.use this url - http://<load-balancer-dns-name>:3000/?orgId=1
3. Grafana first time setup:
    1. Login using `admin`/`admin` or you can alternatively click on **skip**
    2. Create DataSource as follows:
        1. **Name** - Enter a name that represents the prometheus data source. Example - `lattice-prometheus`
        2. **Type** - Select **Prometheus** from the dropdown.
        3. **URL** - This is the service discovery endpoint against prometheus port. Example - `http://web.default.svc.cluster.local:9090`. Note - Service discovery endpoint can be found under cluster and prometheus configured port is `9090`
        4. **Access** - This should be selected as **Server(Default)**
        5. Skip other prompts, scroll down and click on **Save & Test**. This will add the datasource and grafana should confirm that prometheus data source is accessible
    3. Add dashboard as follows:
        1. On the left hand panel, click on **+** symbol and select the option - **Import**
        2. Select the option **Upload .json File**. Select the file - `envoy_grafana.json` from the path `voting-app/samples/preview/apps/voteapp/metrics/`
        3. Select the prometheus-db source from the dropdown. This as per above example should be `lattice-prometheus`
        4. Select **Import** and the envoy-grafana dashboard will be imported
    4. Scripts to generate traffic ( voting-app/samples/preview/apps/voteapp/metrics/traffic/):
        Run results-cron.sh will ping /results service every 3 seconds
        Run vote-cron.sh to will trigger /vote service
    
 **Stats Exporter**
 1. Stats_Exporter has been implemented as a workaround to transform "|" separators that the Envoy/AppMesh emits into "_" .
 2. This is important because Prometheus can parse metrics that have only "_".
 3. Stats_Exporter is a spring boot application and added as a side-car to the votes-webapp. 
 4. It captures the metrics from /stats/prometheus and has a cron-run.sh to curl envoy port at 9901/stats/Prometheus, transforms and writes to a static file.
 5. The statis file is then made available for the scrape job in Prometheus at port 9099 to capture the transformed metrics.
 6. These metrics are then used for Prometheus and Grafana to build dashboards.


## Grafana Screenshots

![](https://raw.githubusercontent.com/aws-samples/voting-app/master/images/grafana-dashboard/grafana-setup.jpeg?token=AAJv-gI4ZoOM5LwRR1mzAPqfSJhfx622ks5cBFDXwA%3D%3D)

There are four collapsible panels:

1. Server Statistics (global)

![](https://raw.githubusercontent.com/aws-samples/voting-app/master/images/grafana-dashboard/server-statistics.jpeg?token=AAJv-hZEfQa4_tiW_MSH8pGzOR9pAUnrks5cBFMvwA%3D%3D)
Server related information can be obtained from a combination of metrics specific to either 'envoy_cluster_membership_xx' or 'envoy_server_xx'

1. **Live Servers**: sum(envoy_server_live)
2. **Cluster State**: (sum(envoy_cluster_membership_total)-sum(envoy_cluster_membership_healthy)) == bool 0
3. **Unhealthy Clusters**: (sum(envoy_cluster_membership_healthy) - sum(envoy_cluster_membership_total))
4. **Avg uptime per node**: avg(envoy_server_uptime)
5. **Allocated Memory**: sum(envoy_server_memory_allocated)
6. **Heap Size**: sum(envoy_server_memory_heap_size)



2. Request/Response Summary (can be viewed by Service)

![](https://raw.githubusercontent.com/aws-samples/voting-app/master/images/grafana-dashboard/requests-response-summary.jpeg?token=AAJv-tDPSQ0q9_XUHZbHbY3mDIl-WwJAks5cBFMbwA%3D%3D)

Metrics under this section take envoy_cluster_name input and host from grafana template variables - which are named as service and host

1. **Total Requests**: sum(envoy_cluster_external_upstream_rq_completed{envoy_cluster_name=~"$cluster",host=~"$hosts"})
2. **Response - 2xx**: sum(envoy_cluster_external_upstream_rq{envoy_cluster_name=~"$cluster",host=~"$hosts",envoy_response_code="200"})
3. **Success Rate (non 5xx)**: 1 - (1 - (sum(envoy_cluster_external_upstream_rq{envoy_cluster_name=~"$cluster",host=~"$hosts",envoy_response_code="200"})/sum(envoy_cluster_external_upstream_rq{envoy_cluster_name=~"$cluster",host=~"$hosts",envoy_response_code=~".*"})))
4. **Response - 3xx**:  sum(envoy_cluster_external_upstream_rq{envoy_cluster_name=~"$cluster",host=~"$hosts",envoy_response_code=~"3.*"})
5. **Response - 4xx**: sum(envoy_cluster_external_upstream_rq{envoy_cluster_name=~"$cluster",host=~"$hosts",envoy_response_code=~"4.*"})
6. **Response - 5xx**: sum(envoy_cluster_external_upstream_rq{envoy_cluster_name=~"$cluster",host=~"$hosts",envoy_response_code=~"5.*"})



3. Network Traffic Patterns (Upstream: by service, DownStream: Global)

![](https://raw.githubusercontent.com/aws-samples/voting-app/master/images/grafana-dashboard/network-traffic-patterns-1.jpeg?token=AAJv-qfocMZLaKVYOc8WLk4DeHDPpnJ7ks5cBFLiwA%3D%3D)

![](https://raw.githubusercontent.com/aws-samples/voting-app/master/images/grafana-dashboard/network-traffic-patterns-2.jpeg?token=AAJv-hZthTZFv2xOntRlFFUdPjSci8Pwks5cBFMDwA%3D%3D)

1. **Egress CPS/RPS** - The graph depicts information related to total upstream connection sent vs total upstream connections received vs total upstream pending connections vs cluster lb health. The four specific metrics used are:
    1. **egress CPS**: sum(rate(envoy_cluster_upstream_cx_total{envoy_cluster_name=~"$cluster"}[10s]))
    2. **egress RPS**: sum(rate(envoy_cluster_upstream_rq_total{envoy_cluster_name=~"$cluster"}[10s]))
    3. **pending req to**: sum(rate(envoy_cluster_upstream_rq_pending_total{envoy_cluster_name=~"$cluster"}[10s]))
    4. **lb healthy panic RPS**:  sum(rate(envoy_cluster_lb_healthy_panic{envoy_cluster_name=~"$cluster"}[10s]))

2. **Upstream Received Requests (rate/10s)**: rate(envoy_cluster_upstream_rq_total{envoy_cluster_name=~"$cluster",host=~"$hosts"}[10s])
3. **Upstream Connection Summary**: sum(envoy_cluster_upstream_cx_active{envoy_cluster_name=~"$cluster"})
4. **Global Downstream Requests**: sum(rate(envoy_http_downstream_rq_total[10s]))

4. Network Traffic Details in Bytes ((Upstream: by service, DownStream: Global) 

![](https://raw.githubusercontent.com/aws-samples/voting-app/master/images/grafana-dashboard/network-traffic-details.jpeg?token=AAJv-ri4prUti-QR5416l2mVduDNV4cbks5cBFKowA%3D%3D)

1. **Upstream -Sent**: sum(envoy_cluster_upstream_cx_tx_bytes_total{envoy_cluster_name=~"$cluster"})
2. **Upstream - Sent Buffered**: sum(envoy_cluster_upstream_cx_tx_bytes_buffered{envoy_cluster_name=~"$cluster"})
3. **Upstream - Received**: sum(envoy_cluster_upstream_cx_rx_bytes_total{envoy_cluster_name=~"$cluster"})
4. **Upstream - Received Buffered**: sum(envoy_cluster_upstream_cx_rx_bytes_buffered{envoy_cluster_name=~"$cluster"})
5. **Downstream Global - Sent**: sum(envoy_http_downstream_cx_tx_bytes_total)
6. **Downstream Global - Sent Buffered**: sum(envoy_http_downstream_cx_tx_bytes_buffered)
7. **Downstream Global - Received**: sum(envoy_http_downstream_cx_rx_bytes_total)
8. **Downstream Global - Received Buffered**: sum(envoy_http_downstream_cx_rx_bytes_buffered)
9. **Upstream Network Traffic (bytes)**: Represents the upstream network traffic at 10s rate based on - irate(envoy_cluster_upstream_cx_rx_bytes_total{envoy_cluster_name=~"$cluster",host=~"$hosts"}[10s])
10. **Downstream Network Traffic (bytes)**: Represents the downstream network traffic at 10s rate based on -irate(envoy_http_downstream_cx_rx_bytes_total{}[10s])
