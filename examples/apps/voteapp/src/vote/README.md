## Voting App terminal client.

This is a client for the Voting App that runs in a terminal.

## Build the image

    $ docker build -t subfuzion/vote .

## Run the client

If the Voting Application is running locally (i.e., `localhost:3000`):

    $ docker run -it --rm --network=host subfuzion/vote CMD

where CMD is either `vote` or `results` (missing command will print help).

If you need to specify the host and port for the Voting App, then omit the
`--network` option and specify environment variables like this:

    $ docker run -it --rm -e WEB_URI=http://<host>:<port> subfuzion/vote CMD

or

    $ docker run -it --rm -e WEB_HOST=<host> -e WEB_PORT=<port> subfuzion/vote CMD
