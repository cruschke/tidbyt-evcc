# tidbyt-evcc
[evcc](https://evcc.io/en/) is a popular open source project, allowing you to charge your BEV using as much self-generated power as possible. The project loves 💚 good UIs, a [Tidbyt](https://tidbyt.com/products/tidbyt) app displaying the most important statistics (excess solar power, charging power, state of charge) makes totally sense that's why 😀.

# App design considerations

* MUST be installable from official Tidbyt app store
* MUST not create additional security risks by having to expose the evcc API endpoint to the public internet
* MUST be configurable by a regular evcc user, no coding skills required
* MUST support free InfluxDB plans
* MUST not exceed API rate limits exposed by free InfluxDB plans by leverating caching

# Setup

## Signup to InfluxDB Cloud Serverless

Tidbyt apps are designed to query data only from public API endpoints, not from any local LAN device. However for security reasons exposing the evcc API endpoint to the public internet using DynDNS or so is not ideal too.

The approach is to use a [InfluxDB Cloud Serverless](https://www.influxdata.com/influxdb-cloud-pricing/) with a "Free Plan", allowing to keep 30 days of data and sufficient API requests for reading and writing data.

* Signup for InfluxDB Cloud [InfluxDB Signup page](https://cloud2.influxdata.com/signup)
* select a region of your choice (EU Frankfurt, US East (Virginia))
* create an organisation and bucket (for simplicity I called both `evcc`) 
* create an API token for writing into the evcc bucket (for evcc)
* create an API token for reading from the evcc bucket (for the Tidbyt app) 

## Setup evcc InfluxDB v2.x integration

Following [evcc InfluxDB v2.x](https://docs.evcc.io/docs/reference/configuration/influx/#influxdb-v2x) documentation, the `evcc.yaml` is configured like this:

```
influx:
  url: https://eu-central-1-1.aws.cloud2.influxdata.com # make sure this fits to the region you picked
  database: evcc # InfluxDB v2.x uses term `bucket` but for compatibility still named `database` here
  token: <YOUR WRITE TOKEN HERE>
  org: evcc # if you named your organisation differently, please adjust here
```

Restart your evcc and check the logs for errors.

## Verify your setup

Use the InfluxDB "Data Explorer" to verify evcc is able to send metrics.

* select the bucket `evcc`
* pick measurement `gridPower` 
* run the query

You should see some query results matching the statistics of your evcc installation.

# Using the app

* three-columns screen
  * single values -  the last known value 
* graphs screen
  * single values-  the max value in the last 12 hours
  * graphing the last 12 hours mean value over an aggregate window of 15 minutes

## InfluxDB measurements taken into consideration

TODO: check if all are used

|metric|description|
| -------- | ------- |
|gridPower|Current grid feed-in (green) or consumption (red)|
|chargePower|Current charging power|
|homePower|Current house consumption power (without wallbox consumption)|
|phasesActive|Currently active number of current phases of the charging point|
|pvPower|Current solar system output|
|vehicleSoc|Current vehicle state of charge (Soc) in percent|

For more details on measurements check out the [evcc  messaging](https://github.com/evcc-io/docs/blob/main/docs/reference/configuration/messaging.md) documentation.

# open issues
* make up my mind if gridPower or homePower should be plotted
* error handling (like wrong API key) is very basic
* improving the icons
  * animated car when the car is charging  
  * the second column icon depends on whether I produce more solar energy or if I take it from grid, need to make up my mind what icons to present
  * better icons in general
 * the elephant in the room: publishing the app to the [community apps](https://tidbyt.dev/docs/publish/community-apps) store


# Credits

Icons from [FLATICON](https://www.flaticon.com/)