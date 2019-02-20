const app = require('commander');
const axios = require('axios');
const format = require('util').format;
const inquirer = require('inquirer');
const pkg = require('./package.json');

let apiOptions = {
  host: process.env.WEB_HOST || 'localhost',
  port: process.env.WEB_PORT || 3000
};

let uri = process.env.WEB_URI;
if (uri && !uri.endsWith('/')) {
  uri += '/';
}

let apiURL = uri ? uri : `http://${apiOptions.host}:${apiOptions.port}/`;
let voteURL = apiURL + 'vote/';
let resultsURL = apiURL + 'results/';

let ax = axios.create({
  baseURL: apiURL
});

/**
 * Log error message. Print 'error:' followed by remaining arguments,
 * separated by spaces. If the first argument is a format string, then
 * the remaining argument values will replace format string placeholders.
 * @param {*} args Variable arguments
 */
function logError(...args) {
  console.log('error:', format(...args));
}

/**
 * Exit process. 
 * @param {*E} code Optional exit code (default: 0)
 * @param {*} args Optional string arguments (first string can be a format string)
 */
function exit(code, ...args) {
  if (typeof code === 'string') {
    args.unshift(code);
    code = 0;
  }
  if (code === 0) {
    console.log(format(...args));
  } else {
    logError(...args);
  }
  process.exit(code);
}

// Handle the vote command and submit request to API.
/*eslint no-unused-vars: ["error", { "args": "none" }]*/
async function doVoteCmd(cmd, opts) {
  // question holds the prompt settings for the question
  // question.filter is used to transform user-friendly prompt choices to
  // the required values: 'cats' -> 'a',  'dogs' -> 'b',  '(quit)' -> 'q'
  let question = {
    type: 'list',
    name: 'vote',
    message: 'What do you like better?',
    choices: ['(quit)', 'cats', 'dogs'],
    filter: val => ( val === '(quit)' ? 'q' : ( val === 'cats' ? 'a' : 'b' ) )
  };
  let a = await inquirer.prompt(question);

  // if the answer is quit then exit
  if (a.vote === 'q') process.exit();

  try {
    // otherwise submit the answer to vote
    let res = await ax.post(voteURL, a);
    if (!res.data.success) {
      exit(1, 'command "vote" %s', res.data.reason);
    }
    console.log(voteToString(res.data.result));
  } catch (err) {
    exit(1, 'command "vote" %s', err.message);
  }
}

// Handle the results command and submit request to API.
/*eslint no-unused-vars: ["error", { "args": "none" }]*/
async function doResultsCmd(cmd, opts) {
  try {
    let res = await ax.get(resultsURL);
    if (!res.data.success) {
      exit(1, 'command "vote" %s', res.data.reason);
    }
    console.log(tallyToString(res.data.result));
  } catch (err) {
    exit(1, 'command "results" %s', err.message);
  }
}

// Pretty-print vote.
function voteToString(vote) {
  if (!vote) return 'error: empty vote result';
  let id = vote.voter_id ? `${vote.voter_id}` : '-';
  let choice = ( vote.vote === 'a' ? 'cats' : 'dogs' );
  return `Voter (id: ${id}) voted for: ${choice}`;
}

// Pretty-print vote tally.
function tallyToString(tally) {
  if (!tally) return 'error: empty tally result';
  let a = tally.a, b = tally.b;
  let winner = ( a > b  ? 'CATS WIN!' : ( b > a ? 'DOGS WIN!' : 'IT\'S A TIE!' ) );

  let s = `Cats: ${a}, Dogs: ${b} ... ${winner}`;

  if (tally.version) {
    s = `[API v${tally.version}] Total votes cast: ${tally.totalVotes}: ${s}`
  }

  return s;
}

function main() {
  // Ensure any unhandled promise rejections get logged.
  process.on('unhandledRejection', error => {
    logError('(unhandledRejection)', error);
  });

  // if no args, print help
  if (!process.argv.slice(2).length) {
    app.outputHelp();
    console.log();
    process.exit();
  }

  app.version(pkg.version);

  app.command('vote')
    .description('vote for cats or dogs')
    .action(doVoteCmd);

  app.command('results')
    .description('tally the votes')
    .action(doResultsCmd);

  app.command('*')
    .action((cmd) => {
      exit(1, 'unrecognized command ', cmd);
    });

  // parsing command line args invokes the app handlers
  try {
    app.parse(process.argv);
  } catch (err) {
    exit(1, err);
  }
}

main();
