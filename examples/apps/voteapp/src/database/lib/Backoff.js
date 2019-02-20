// Exponential backoff implementation

const DefaultRetries = 5; // total of 6 connection attempts (slightly more than 1 minute total)
const DefaultTimeFactor = 1000; // ms
const DefaultStrategy = exponentialStrategy;

/**
 * Create a new instance of Backoff.
 */
class Backoff {
  constructor(connectFunc, options) {
    if (typeof connectFunc != 'function') throw new Error('arg must be a function: func');
    this.connectFunc = connectFunc;
    this.options = Object.assign({
      timeFactor: DefaultTimeFactor,
      retries: DefaultRetries,
      strategy: DefaultStrategy,
      retryIf: undefined
    }, options);
  }

  async connect() {
    let counter = 0;

    let connectFunc = this.connectFunc;
    let promise = () => {
      return new Promise(async (resolve, reject) => {
        try {
          resolve(connectFunc());
        } catch (err) {
          reject(err);
        }
      });
    };

    let options = this.options;
    while (true) {
      try {
        // 0..retries, inclusive
        return await promise();
      } catch (err) {
        if (options.retryIf && !options.retryIf(err)) {
          throw err; // failure, unanticipated error
        } else {
          console.warn('retrying to connect...');
          let p = options.strategy(counter, options.retries, options.timeFactor);
          if (p === -1) throw err; // failure, no more retries
          await pause(p);
          counter++;
        }
      }
    }
  }

}

module.exports = Backoff;

/**
 * 
 * @param {int} counter is the connection attempt, from initial (0) to maxRetries, inclusive
 * @param {int} maxRetries is the total number of retry attempts to try after initial
 * @param {int} factor is the time unit multiplier (ex: 1000 ms)
 * @return {int} the computed amount of time to pause, or -1 if retry attempts are exhausted
 */
function exponentialStrategy(counter, maxRetries, factor) {
  if (counter < 0) {
    throw new Error(`invalid counter: ${counter} (did you forget to exit a loop?)`);
  }
  if (counter >= maxRetries) {
    return -1;
  }
  let jitter = Math.random();
  return ((2 ** counter) + jitter) * factor;
}

/**
 * Wait for the specified pause.
 * @param {int} ms 
 */
async function pause(ms) {
  console.warn(`pausing for ${ms} ms...`);
  return new Promise(resolve => {
    setTimeout(resolve, ms);
  });
}
