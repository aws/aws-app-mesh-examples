# Running the Vote App under different environments

## Running locally with Docker

Get Docker for free from the [Docker Store].
This app will work with versions from either the Stable or the Edge channels.

> If you're using [Docker for Windows] on Windows 10 pro or later, you must
also switch to [Linux containers].

Run in this directory:

    $ docker-compose up

You can test it with the `voter` CLI
```
$ docker run -it --rm --network=host subfuzion/voter vote
? What do you like better? (Use arrow keys)
  (quit)
❯ cats
  dogs
```

You can print voting results:

```
$ docker run -it --rm --network=host subfuzion/voter results
Total votes -> cats: 4, dogs: 0 ... CATS WIN!
```

When you are finished:

Press `Ctrl-C` to stop the stack, then enter:

    $ docker-compose -f docker-compose.yml rm -f

For more details, see this [orientation].

## Running on Amazon ECS with Fargate

See [deploy with Fargate].

## Running on Amazon EKS with Kubernetes

Kubernetes and Helm chart support has been added to the repo (under the
`kubernetes`directory).

This was working at one point, but has not been maintained or tested recently.
Contributors to help test and document are welcome.


[Docker Store]:           https://www.docker.com/community-edition#/download
[Docker for Windows]:     https://docs.docker.com/docker-for-windows
[Linux containers]:       https://docs.docker.com/docker
[orientation]:            http://bit.ly/vote-app-orientation
[deploy with Fargate]:    https://read.acloud.guru/deploy-the-voting-app-to-aws-ecs-with-fargate-cb75f226408f


