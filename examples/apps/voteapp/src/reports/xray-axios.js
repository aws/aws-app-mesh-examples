const xray = require('aws-xray-sdk-core');
const segmentUtils = xray.SegmentUtils;

let captureAxios = function(axios) {

  //add a request interceptor on POST
  axios.interceptors.request.use(function (config) {
    var parent = xray.getSegment();
    var subsegment = parent.addNewSubsegment(config.baseURL + config.url.substr(1));
    subsegment.namespace = 'remote';

    let root = parent.segment ? parent.segment : parent;
    let header = 'Root=' + root.trace_id + ';Parent=' + subsegment.id + ';Sampled=' + (!root.notTraced ? '1' : '0');
    config.headers.get={ 'x-amzn-trace-id': header };
    config.headers.post={ 'x-amzn-trace-id': header };

    xray.setSegment(subsegment);

    return config;
  }, function (error) {
    var subsegment = xray.getSegment().addNewSubsegment("Intercept request error");
    subsegment.close(error);

    return Promise.reject(error);
  });

  // Add a response interceptor
  axios.interceptors.response.use(function (response) {
    var subsegment = xray.getSegment();
    const res = { statusCode: response.status, headers: response.headers };

    subsegment.addRemoteRequestData(response.request, res, true);
    subsegment.close();
    return response;
  }, function (error) {
    var subsegment = xray.getSegment();
    subsegment.close(error);

    return Promise.reject(error);
  });
};

module.exports = captureAxios;
