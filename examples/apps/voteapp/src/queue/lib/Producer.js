const Queue = require('./Queue');

class Producer extends Queue {
  /**
   * Create a new Producer with a connection to the queue.
   * @param {object | string} [config] An object with host, port, and timeout properites or uri string.
   * @param {object} [config] An object with Redis constructor properites.
   */
  constructor(topic, config, opts) {
    super(topic, config, opts);
  }

  /**
   * Enqueue a message to the back of the queue.
   * @param {string|object} message
   * @return {Promise<void>}
   */
  async send(message) {
    let t = typeof message;
    switch (t) {
    case 'string':
      break;
    case 'object':
      message = JSON.stringify(message);
      break;
    default:
      throw new Error("message must be of type 'string' or 'object'");
    }
    await this.client.rpush(this.topic, message);
  }
}

module.exports = Producer;
