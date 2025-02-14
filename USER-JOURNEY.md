# API Owner Flow

The following steps walk an API Owner through setting up an API on the BC Gov API Gateway in our Test instance.  If you are ready to deploy to our Production instance, use the links [here](#production-links).

## 1. Register a new namespace

A `namespace` represents a collection of Kong Services and Routes that are managed independently.

To create a new namespace, go to the [API Services Portal](https://gwa-apps-gov-bc-ca.test.api.gov.bc.ca/int).

After login (and selection of an existing namespace if you have one already assigned), go to the `New Namespace` tab and click the `Create Namespace` button.

The namespace must be an alphanumeric string between 5 and 15 characters (RegExp reference: `^[a-z][a-z0-9-]{4,14}$`).

Logout by clicking your username at the top right of the page.  When you login again, you should be able to select the new namespace from the `API Programme Services` project selector.

## 2. Generate a Service Account

Go to the `Service Accounts` tab and click the `Create Service Account`.  A new credential will be created - make a note of the `ID` and `Secret`.

The credential has the following access:
* `Gateway.Write` : Permission to publish gateway configuration to Kong
* `Access.Write`  : Permission to update the Access Control List for controlling access to viewing metrics, service configuration and service account management
* `Catalog.Write` : Permission to update BC Data Catalog datasets for describing APIs available for consumption

## 3. Prepare configuration

The gateway configuration can be hand-crafted or you can use a command line interface that we developed called `gwa` to convert your Openapi v3 spec to a Kong configuration.

### 3.1. Hand-crafted (recommended if you don't have an Openapi spec)

**Simple Example**

``` bash
export NS="my_namespace"
export NAME="a-service-for-$NS"
echo "
services:
- name: $NAME
  host: httpbin.org
  tags: [ ns.$NS ]
  port: 443
  protocol: https
  retries: 0
  routes:
  - name: $NAME-route
    tags: [ ns.$NS ]
    hosts:
    - $NAME.api.gov.bc.ca
    paths:
    - /
    strip_path: false
    https_redirect_status_code: 426
    path_handling: v0
" > sample.yaml
```

> To view common plugin config go to [COMMON-CONFIG.md](/docs/COMMON-CONFIG.md)

> To view some other plugin examples go [here](/docs/samples/service-plugins).

> **Declarative Config** Behind the scenes, DecK is used to sync your configuration with Kong.  For reference: https://docs.konghq.com/deck/overview/

> **Splitting Your Config:** A namespace `tag` with the format `ns.$NS` is mandatory for each service/route/plugin.  But if you have separate pipelines for your environments (i.e./ dev, test and prod), you can split your configuration and update the `tags` with the qualifier.  So for example, you can use a tag `ns.$NS.dev` to sync Kong configuration for `dev` Service and Routes only.

> **Upstream Services on OCP4:** If your service is running on OCP4, you should specify the Kubernetes Service in the `Service.host`.  It must have the format: `<name>.<ocp-namespace>.svc`.  Also make sure your `Service.port` matches your Kubernetes Service Port.  Any Security Policies for egress from the Gateway will be setup automatically on the API Gateway side.
> The Aporeto Network Security Policies are being removed in favor of the Kubernetes Security Policies (KSP).  You will need to create a KSP on your side looking something like this to allow the Gateway's test and prod environments to route traffic to your API:

``` yaml
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: allow-traffic-from-gateway-to-your-api
spec:
  podSelector:
    matchLabels:
      name: my-upstream-api
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              environment: test
              name: 264e6f
    - from:
        - namespaceSelector:
            matchLabels:
              environment: prod
              name: 264e6f
```

> **Migrating from OCP3 to OCP4?** Please review the [OCP4-Migration](docs/OCP4-MIGRATION.md) instructions to help with transitioning to OCP4 and the new APS Gateway.

> **Require mTLS between the Gateway and your Upstream Service?** To support mTLS on your Upstream Service, you will need to provide client certificate details and if you want to verify the upstream endpoint then the `ca_certificates` and `tls_verify` is required as well.  An example:

``` yaml
services:
- name: my-upstream-service
  host: my-upstream.site
  tags: [ _NS_ ]
  port: 443
  protocol: https
  tls_verify: true
  ca_certificates: [ 0a780ee0-626c-11eb-ae93-0242ac130012 ]
  client_certificate: 8fc131ef-9752-43a4-ba70-eb10ba442d4e
  routes: [ ... ]
certificates:
- cert: "<PEM FORMAT>"
  key: "<PEM FORMAT>"
  tags: [ _NS_ ]
  id: 8fc131ef-9752-43a4-ba70-eb10ba442d4e
ca_certificates:
- cert: "<PEM FORMAT>"
  tags: [ _NS_ ]
  id: 0a780ee0-626c-11eb-ae93-0242ac130012
```

> NOTE: You must generate a UUID (`python -c 'import uuid; print(uuid.uuid4())'`) for each certificate and ca_certificate you create (set the `id`) and reference it in your `services` details.

> HELPER: Python command to get a PEM file on one line: `python -c 'import sys; import json; print(json.dumps(open(sys.argv[1]).read()))' my.pem`

### 3.2. gwa Command Line

Run: `gwa new` and follow the prompts.

Example:

``` bash
gwa new -o sample.yaml \
  --route-host myapi.api.gov.bc.ca \
  --service-url https://httpbin.org \
  https://bcgov.github.io/gwa-api/openapi/simple.yaml
```

> See below for the `gwa` CLI install instructions.

## 4. Apply gateway configuration

The Swagger console for the `gwa-api` can be used to publish Kong Gateway configuration, or the `gwa Command Line` can be used.

### 4.1. gwa Command Line (recommended)

**Install (for Linux)**

``` bash
GWA_CLI_VERSION=v1.2.0; curl -L -O https://github.com/bcgov/gwa-cli/releases/download/${GWA_CLI_VERSION}/gwa_${GWA_CLI_VERSION}_linux_x64.zip
unzip gwa_${GWA_CLI_VERSION}_linux_x64.zip
./gwa --version
```

> **Using MacOS or Windows?** Download here: https://github.com/bcgov/gwa-cli/releases/tag/v1.2.0

> NOTE: Version 1.2.0 introduces support for v2 of our api.  To continue using v1 of the api, ensure that the API Version is set to 1 (see below)


**Configure**

Create a `.env` file and update the CLIENT_ID and CLIENT_SECRET with the new credentials that were generated in step #2:

``` bash
echo "
GWA_NAMESPACE=$NS
CLIENT_ID=<YOUR SERVICE ACCOUNT ID>
CLIENT_SECRET=<YOUR SERVICE ACCOUNT SECRET>
GWA_ENV=test
API_VERSION=1
" > .env

OR run:

gwa init -T --api-version=1 --namespace=$NS --client-id=<YOUR SERVICE ACCOUNT ID> --client-secret=<YOUR SERVICE ACCOUNT SECRET>

```

> NOTE: The `-T` indicates our Test environment.  For production use `-P`.

**Publish**

``` bash
gwa pg sample.yaml 
```

If you want to see the expected changes but not actually apply them, you can run:

``` bash
gwa pg --dry-run sample.yaml
```

### 4.2. Swagger Console

Go to <a href="https://gwa-api-gov-bc-ca.test.api.gov.bc.ca/api/doc" target="_blank">gwa-api Swagger Console</a>.

Select the `PUT` `/namespaces/{namespace}/gateway` API.

The Service Account uses the OAuth2 Client Credentials Grant Flow.  Click the `lock` link on the right and enter in the Service Account credentials that were generated in step #2.

For the `Parameter namespace`, enter the namespace that you created in step #1.

Select `dryRun` to `true`.

Select a `configFile` file.

Send the request.

### 4.3. Postman

From the Postman App, click the `Import` button and go to the `Link` tab.

Enter a URL: https://openapi-to-postman-api-gov-bc-ca.test.api.gov.bc.ca/?url=https://gwa-api-gov-bc-ca.test.api.gov.bc.ca/api/doc/swagger.json

After creation, go to `Collections` and right-click on the `Gateway Administration (GWA) API` collection and select `edit`.

Go to the `Authorization` tab, enter in your `Client ID` and `Client Secret` and click `Get New Access Token`.

You should get a successful dialog to proceed.  Click `Proceed` and `Use Token`.

You can then verify that the token works by going to the Collection `Return key information about authenticated identity` and click `Send`.

## 5. Verify routes

To verify that the Gateway can access the upstream services, run the command: `gwa status`.

In our test environment, the hosts that you defined in the routes get altered; to see the actual hosts, log into the <a href="https://gwa-apps-gov-bc-ca.test.api.gov.bc.ca/int" target="_blank">API Services Portal</a> and view the hosts under `Services`.

``` bash
curl https://${NAME}-api-gov-bc-ca.test.api.gov.bc.ca/headers

ab -n 20 -c 2 https://${NAME}-api-gov-bc-ca.test.api.gov.bc.ca/headers

```

To help with troubleshooting, you can use the GWA API to get a health check for each of the upstream services to verify the Gateway is connecting OK.

Go to the <a href="https://gwa-api-gov-bc-ca.test.api.gov.bc.ca/api/doc#/Service%20Status/get_namespaces__namespace__services">GWA API</a>, enter in the new credentials that were generated in step #2, click `Try it out`, enter your namespace and click `Execute`.  The results are returned in a JSON object.

## 6. View metrics

The following metrics can be viewed in real-time for the Services that you configure on the Gateway:

* Request Rate : Requests / Second (by Service/Route, by HTTP Status)
* Latency : Standard deviations measured for latency inside Kong and on the Upstream Service (by Service/Route)
* Bandwidth : Ingress/egress bandwidth (by Service/Route)
* Total Requests : In 5 minute windows (by Consumer, by User Agent, by Service, by HTTP Status)

All metrics can be viewed by an arbitrary time window - defaults to `Last 24 Hours`.

Go to <a href="https://grafana-apps-gov-bc-ca.test.api.gov.bc.ca" target="_blank">Grafana</a> to view metrics for your configured services.

You can also access the metrics from the `API Services Portal`.

## 7. Grant access to others

The `acl` command provides a way to update the access for the namespace.  It expects an all-inclusive membership list, so if a user is not either part of the `--users` list or the `--managers` list, they will be removed from the namespace.

For elevated privileges (such as managing Service Accounts), add the usernames to the `--managers` argument.

``` bash
gwa acl --users jjones@idir --managers acope@idir
```

The result will show the ACL changes.  The Add/Delete counts represent the membership changes of registered users.  The Missing count represents the users that will automatically be added to the namespace once they have logged into the `APS Services Portal`.

## 8. Add to your CI/CD Pipeline

Update your CI/CD pipelines to run the `gwa-cli` to keep your services updated on the gateway.

### 8.1. Github Actions Example

In the repository that you maintain your CI/CD Pipeline configuration, use the Service Account details from `Step 2` to set up two `Secrets`:

* GWA_ACCT_ID

* GWA_ACCT_SECRET

Add a `.gwa` folder (can be called anything) that will be used to hold your gateway configuration.

An example Github Workflow:

``` yaml
env:
  NS: "<your namespace>"
  
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
      with:
        fetch-depth: 0
        
    - uses: actions/setup-node@v1
      with:
        node-version: 10
        TOKEN: ${{ secrets.GITHUB_TOKEN }}

    - name: Get GWA Command Line
      run: |
        curl -L -O https://github.com/bcgov/gwa-cli/releases/download/v1.1.3/gwa_v1.1.3_linux_x64.zip
        unzip gwa_v1.1.3_linux_x64.zip
        export PATH=`pwd`:$PATH

    - name: Apply Namespace Configuration
      run: |
        export PATH=`pwd`:$PATH
        cd .gwa/$NS

        gwa init -T \
          --namespace=$NS \
          --client-id=${{ secrets.TEST_GWA_ACCT_ID }} \
          --client-secret=${{ secrets.TEST_GWA_ACCT_SECRET }}

        gwa pg

        gwa acl --managers acope@idir
       
```

## 9. Share your API for Discovery

Package your APIs and make them available for discovery through the API Portal and BC Data Catalog.

**Coming soon!**

# Production Links

* <a href="https://gwa2.apps.gov.bc.ca/int" target="_blank">API Services Portal</a>
* <a href="https://gwa.api.gov.bc.ca/api/doc" target="_blank">gwa-api Swagger Console</a>
* OpenAPI to Postman Converter: https://openapi-to-postman.api.gov.bc.ca/?u=https://gwa.api.gov.bc.ca/api/doc/swagger.json
* <a href="https://grafana.apps.gov.bc.ca" target="_blank">APS Metrics - Grafana</a>
