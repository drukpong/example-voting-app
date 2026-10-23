# Example Voting App

A simple distributed application running across multiple Docker containers.

## Getting started

Download [Docker Desktop](https://www.docker.com/products/docker-desktop) for Mac or Windows. [Docker Compose](https://docs.docker.com/compose) will be automatically installed. On Linux, make sure you have the latest version of [Compose](https://docs.docker.com/compose/install/).

This solution uses Python, Node.js, .NET, with Redis for messaging and Postgres for storage.

Run in this directory to build and run the app:

```shell
docker compose up
```

The `vote` app will be running at [http://localhost:8080](http://localhost:8080), and the `results` will be at [http://localhost:8081](http://localhost:8081).

Alternately, if you want to run it on a [Docker Swarm](https://docs.docker.com/engine/swarm/), first make sure you have a swarm. If you don't, run:

```shell
docker swarm init
```

Once you have your swarm, in this directory run:

```shell
docker stack deploy --compose-file docker-stack.yml vote
```

## Run the app in Kubernetes

The folder k8s-specifications contains the YAML specifications of the Voting App's services.

Run the following command to create the deployments and services. Note it will create these resources in your current namespace (`default` if you haven't changed it.)

```shell
kubectl create -f k8s-specifications/
```

The `vote` web app is then available on port 31000 on each host of the cluster, the `result` web app is available on port 31001.

To remove them, run:

```shell
kubectl delete -f k8s-specifications/
```

## Architecture

![Architecture diagram](architecture.excalidraw.png)

* A front-end web app in [Python](/vote) which lets you vote between two options
* A [Redis](https://hub.docker.com/_/redis/) which collects new votes
* A [.NET](/worker/) worker which consumes votes and stores them in…
* A [Postgres](https://hub.docker.com/_/postgres/) database backed by a Docker volume
* A [Node.js](/result) web app which shows the results of the voting in real time

## Notes

The voting application only accepts one vote per client browser. It does not register additional votes if a vote has already been submitted from a client.

This isn't an example of a properly architected perfectly designed distributed app... it's just a simple
example of the various types of pieces and languages you might see (queues, persistent data, etc), and how to
deal with them in Docker at a basic level.

---

## DevOps Capstone Project 1

This project extends the Example Voting App with container hardening, automated image builds, Terraform-managed AWS EKS infrastructure, Kubernetes deployment, and Helm release management.

### Infrastructure and deployment

- Terraform configuration: `terraform/eks/`
- Kubernetes manifests: `k8s-specifications/`
- Helm chart: `helm/voting-app/`
- CI workflows: `.github/workflows/`
- Container images: GitHub Container Registry (GHCR)

### Kubernetes verification

The production application was verified in the `default` namespace. The vote and result services returned HTTP 200 OK through their NodePort endpoints (31000 and 31001).


```bash
kubectl get nodes
kubectl get pods
kubectl get services
kubectl get endpoints vote result
```

### Helm verification

The chart passed `helm lint` and rendered successfully. The `voting-test` release was installed in the separate `voting-helm-test` namespace.

A test upgrade timed out because both worker nodes had reached their pod capacity. Helm rollback to revision 1 succeeded, creating release revision 3. The five test application pods were subsequently running.


```bash
helm lint helm/voting-app
helm status voting-test -n voting-helm-test
helm history voting-test -n voting-helm-test
```

### Operational safety

- Never commit AWS credentials, Kubernetes Secret values, Terraform state, or sensitive variable files.
- Review Terraform plans before applying or destroying infrastructure.
- Check persistent volume claims before deleting database resources.
- AWS EKS and related resources can incur charges while running; review costs before leaving infrastructure provisioned.
