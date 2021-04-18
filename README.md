devops-nginx
------------

[![Build Status](https://travis-ci.com/codylane/devops-nginx.svg?branch=main)](https://travis-ci.com/codylane/devops-nginx)

# Getting Started

- Ensure that you have docker and the docker client libraries installed.
  - https://docs.docker.com/get-docker/
- Ensure that `docker-compose` is installed.
  - https://docs.docker.com/compose/install/
- Ensure that `dig` is installed
- Ensure awscli is installed
  - https://aws.amazon.com/cli/

# Environment Variables

| Environment variable   | Default                             | Required      | Description                                                                         |
| ---------------------- | -------------                       | ------------- | -----------------------------------------------------------                         |
| LANG                   | en_US.UTF-8                         | Y             | Locale                                                                              |
| NGINX_HOST             | devops-nginx                        | Y             | The DNS hostname to use for serving content                                         |
| NGINX_PORT             | 80                                  | Y             | The TCP port (inside the container)                                                 |
| NGINX_EXPOSED_PORT     | 80                                  | Y             | The TCP port served via your docker host (external facing)                          |
| EXTERNAL_IP            |                                     | N             | The external ip address that may be used to serve your content                      |
| AWS_ACCESS_KEY_ID      | "${AWS_ACCESS_KEY_ID:-}"            | Y             | This is your AWS access key id provided in the IAM console                          |
| AWS_SECRET_ACCESS_KEY  | "${AWS_SECRET_ACCESS_KEY:-}"        | Y             | This is your AWS secret access key provided in the IAM console                      |
| AWS_REGION             | "${AWS_REGION:-us-east-2}"          | N             | This is the default AWS region you want to use                                      |
| MY_DOMAIN              | "${MY_DOMAIN:-codylane-devops.com}" | Y             | The domain to use when configuring NGINX. `codylane-devops.com` is a private domain |

## The following variables are customizable outside of [envs/common](envs/common)

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION`
- `MY_DOMAIN`

# Usage

- Before running the container, we need to first source an environment
  configuration.

- All environment variables for this demo are controlled in an
  environment directory called `envs` and configuration can be
  inherited or modified as desired.
  Please see [Environment Variables](#envrionment-variables) for all the
  variables you can set.

- Once we have the right configuration files in place, we can source
  that environment.

```
. envs/common

```

- Next, we initialize the awscli to use our AWS account.
- **NOTE:** This utility is not smart enough to update AWS credentials
  if the files already exist on disk.  If they do, you will need to
  modify them by hand.  See the [Makefile](Makefile) for details.

```
make init
```

- Then we source source the python environment that will provision our
  infrastructure in EC2.

```
. ./init.sh
```

### How to deploy this code to EC2

```
make ec2
```

### How to run the services on your local workstation

#### Ensure all the prerequisites are installed

```
make prereqs
```


#### A one-shot command to [clean, init, build, run] the container

```
make
```


#### Build the container

- This step creates the base image for serving up our demo via nginx.

```
make build
```


#### Remove and delete the container

- **NOTE:** This step does not delete files or directories for the bind
            mounted storage as noted in the `volumes`
            section of [docker-compose.yml](docker-compose.yml)

```
make clean
```


#### Show the logs for the running container

```
make log
```


#### Running the container also invokes [build]

```
make run
```


#### Interactively login to the container via a shell

- **NOTE:** This step assumes the container is running.

```
make shell
```


#### Show status of the container

```
make status
```


# Validation

- If provisioning in EC2 was successful you should be able to open your
  browser to the following public endpoints assuming this is running
  from the same workstation that you deployed this code.

- **NOTE:** due to time constraints the SSL cert is a self-signed
  certificate that is generated when the container is started.
  - https://ec2-nginx-demo.us-east-2.compute.amazonaws.com/
  - http://ec2-nginx-demo.us-east-2.compute.amazonaws.com/
