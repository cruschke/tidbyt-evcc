"""
Applet: evcc.io
Summary: shows evcc.io status
Description: Requires a public accessible InfluxDB, currently tested only with InfluxDB Cloud 2.0 free plan. 
Author: cruschke
"""

load("cache.star", "cache")
load("encoding/csv.star", "csv")
load("encoding/base64.star", "base64")
load("encoding/json.star", "json")
load("http.star", "http")
load("humanize.star", "humanize")
load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")

INFLUXDB_HOST = "https://eu-central-1-1.aws.cloud2.influxdata.com/api/v2/query"
INFLUXDB_TOKEN = "TVcTz0Q0KWFcJF8v3i1F0UY-4Jqp_ou5ThMBoHEt4Yw0zPXHl8IeX1LGP6uwK3eJ89Zeicq4CecPeoMRChXstg=="
DEFAULT_BUCKET="evcc"

DEFAULT_LOCATION = json.encode({
	"lat": "52.52136203907116",
	"lng": "13.413308033057413",
	"description": "Berlin, Berlin, Germany",
	"locality": "Weltzeituhr Alexanderolatz",
	"place_id": "ChIJmbztRB9OqEcRGBgdJ67pifE",
	"timezone": "Europe/Berlin"
})


def main(config):
    api_key = config.str("api_key") or INFLUXDB_TOKEN
    bucket = config.get("bucket") or DEFAULT_BUCKET

    location = config.get("location", DEFAULT_LOCATION)
    loc = json.decode(location)
    timezone = loc["timezone"]

    #print("timezone=%s" % timezone)
    homePower = get_homePower(bucket,timezone)
    pvPower = get_pvPower(bucket,timezone)

    return render.Root(
        render.Stack(
            children = [
                render.Plot(data = pvPower, width = 64, height = 32, color = "#f00", color_inverted = "#f00", x_lim = (0, 96), y_lim = (0, 5000), fill = False),
                render.Plot(data = homePower, width = 64, height = 32, color = "#0f0", color_inverted = "#f00", x_lim = (0, 96), y_lim = (0, 5000), fill = False),
            ],
        ),
    )

#

def get_homePower(bucket,timezone):
    fluxql = '                                                      \
    import "timezone"                                               \
    option location = timezone.location(name: "' + timezone + '")   \
    from(bucket:"' + bucket + '")                                   \
        |> range(start: today())                                    \
        |> filter(fn: (r) => r._measurement == "pvPower")           \
        |> group()                                                  \
        |> aggregateWindow(every: 15m, fn: mean)                    \
        |> fill(value: 0.0)                                         \
        |> keep(columns: ["_time", "_value"])'

    print(fluxql)
    return get_datatouples(fluxql)

def get_pvPower(bucket,timezone):
    fluxql = '                                                      \
    import "timezone"                                               \
    option location = timezone.location(name: "' + timezone + '")   \
    from(bucket:"' + bucket + '")                                   \
        |> range(start: today())                                    \
        |> fill(value: 0.0)                                         \
        |> filter(fn: (r) => r._measurement == "homePower")         \
        |> aggregateWindow(every: 15m, fn: mean)                    \
        |> fill(value: 0.0)                                         \
        |> keep(columns: ["_time", "_value"])'

    return get_datatouples(fluxql)

def get_datatouples(query):
    rep = http.post(
        INFLUXDB_HOST,
        headers = {
            "Authorization": "Token " + INFLUXDB_TOKEN,
            "Accept": "application/json",
            "Content-type": "application/json",
        },
        json_body = {"query": query, "type": "flux"},
    )

    #print(rep.status_code)
    print(rep.body())

    # TODO Error handling
    if rep.status_code != 200:
        print("%s Error, could not get data for %s!!!!" % (rep.status_code))
        return None

    return csv2touples(rep.body())

def csv2touples(csvinput):

    data = csv.read_all(csvinput)
    result = []
    line_number = 0
    for row in data[1:]:
        value = row[-1]

        #print(value)
        result.append((line_number, float(value)))
        line_number += 1

    #print(result)
    return result

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(
                id = "api_key",
                name = "API key",
                desc = "API key for InfluxDB Cloud 2.0",
                icon = "key",
            ),
            schema.Text(
                id = "bucket",
                name = "bucket name",
                desc = "The name of the InfluxDB bucket, what is configured in evcc.yaml as parameter \"database\". Default \"evcc\"",
                icon = "database",
                default = "evcc",
            ),
            schema.Location(
                id = "location",
                name = "Location",
                desc = "Location for which to display time.",
                icon = "locationDot",
            ),
        ],
    )
