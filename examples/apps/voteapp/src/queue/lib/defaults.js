const config = {
  host: 'queue',
  port: 6379
};

// Exported objects are copies
module.exports.config = () => {
  return Object.assign({}, config);
};

