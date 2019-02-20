const defaults = require('./defaults');
const EventEmitter = require('events').EventEmitter;
const Redis = require('ioredis');

class Queue extends EventEmitter {
  /**
   * Create a new instance with a connection to the queue.
   * @param {string} topic The queue topic to associate with this instance.
   * @param {object | string} [config] An object with host, port, and timeout properites or uri string.
   * @param {object} [config] An object with Redis constructor properites.
   */
  constructor(topic, config, opts) {
    super();
    this._topic = topic;

    // wrangling with the flexibility of ioredis constructor and ensuring that if a string uri is supplied,
    // it will take precedence over host (for example, as with AWS ElastiCache for Redis URIs).
    if (config && typeof config.toString() === 'string') {
      this._config = Object.assign({}, Queue.defaults().config(), opts, { uri: config });
      delete this._config.host;
    } else {
      this._config = Object.assign({}, Queue.defaults().config(), config, opts);
      delete this._config.uri;
    }

    // explicitly construct with the uri, if configured, else just pass the entire config
    // TODO: retry strategies: review the following for auto-reconnect, reconnect on errors
    // (special attention also to Amazon ElastiCache)
    // https://github.com/luin/ioredis#auto-reconnect
    // https://github.com/luin/ioredis#reconnect-on-error
    if (this.config.uri) {
      this._client = new Redis(this.config.uri, this._config);
    } else {
      this._client = new Redis(this.config);
    }

    // keep isClosed in sync with connection state
    this._client.on('connect', () => {
      this._isClosed = false;
    });
    this._client.on('close', () => {
      this._isClosed = true;
    });

    // re-emit client events
    let that = this;
    [ 'connect', 'ready', 'error', 'close', 'reconnecting', 'end', '+node', '-node', 'node error' ].forEach(evt => {
      this._client.on(evt, (...args) => {
        that.emit(evt, ...args);
      });
    });
  }

  /**
   * Get a copy of the database defaults object
   * @return {{}}
   */
  static defaults() {
    return Object.assign({}, defaults);
  }

  /**
   * Creates a config object initialized with the defaults, then overridden the following
   * environment variables, then finally overridden by any explicit props set by the 
   * supplied config object.
   * For environment variables, it checks first for QUEUE_URI and sets the uri property;
   * else if not present, then checks for QUEUE_HOST and QUEUE_PORT and sets the
   * host and port properties.
   * @param {object} config, a configuration object with properties that override all else.
   * @returns {{}}
   */
  static createStdConfig(config) {
    let c = Queue.defaults().config();

    if (process.env.QUEUE_URI) {
      c.uri = process.env.QUEUE_URI;
      delete c.host;
    } else {
      c.host = process.env.QUEUE_HOST || c.host;
      c.port = process.env.QUEUE_PORT || c.port;
    }

    // When connecting, we check first for a uri, so if the config object has explicitly
    // specified host and port, then we need to explicitly delete the uri property.
    if (config && config.host && config.port) {
      delete c.uri;
    }

    return Object.assign(c, config || {});
  }

  /**
   * Return false until the quit method has been called, then true.
   * @return {boolean}
   */
  get isClosed() {
    return this._isClosed;
  }

  /**
   * Get a copy of the config object.
   * @return {{}}
   */
  get config() {
    return this._config;
  }

  /**
   * Get access to the internal queue client.
   * @return {*}
   */
  get client() {
    return this._client;
  }

  /**
   * Get the topic associated with this instance.
   * @return {string}
   */
  get topic() {
    return this._topic;
  }

  /**
   * Attempt to close client and server ends of the connection gracefully.
   * Calling any other methods will throw 'Connection is closed' errors after this.
   * @return {Promise<*>}
   */
  async quit() {
    this._isClosed = true;
    return this._client.quit();
  }

  /**
   * Forcibly close the connection, if necessary. Use quit for graceful disconnect
   * Calling any other methods will throw 'Connection is closed' errors after this.
   */
  disconnect() {
    this._isClosed = true;
    this._client.disconnect();
  }

  /**
   * Ping the queue to confirm the connection works.
   * @return {Promise<string>} Returns 'PONG' if successful.
   */
  async ping() {
    return this._client.ping();
  }

}

module.exports = Queue;
