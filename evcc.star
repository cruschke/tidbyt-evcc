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
DEFAULT_BUCKET = "evcc"
TTL_SERIES = 900  # how often the time series for pvPower and homePower are being refreshed
TTL_MAXVALUE = 900  # how often the max values are being refreshed
TTL_LATEST = 60  # the TTL for up2date info

FONT = "tom-thumb"

DEFAULT_LOCATION = {
    "lat": 52.52136203907116,
    "lng": 13.413308033057413,
    "locality": "Weltzeituhr Alexanderlatz",
}
DEFAULT_TIMEZONE = "Europe/Berlin"

def main(config):
    api_key = config.str("api_key") or INFLUXDB_TOKEN
    bucket = config.get("bucket") or DEFAULT_BUCKET

    location = config.get("location")
    loc = json.decode(location) if location else DEFAULT_LOCATION
    timezone = loc.get("timezone", DEFAULT_TIMEZONE)

    # some FluxQL query parameters that every single query needs
    flux_defaults = '                                                     \
        import "timezone"                                               \
        option location = timezone.location(name: "' + timezone + '")   \
        from(bucket:"' + bucket + '")'

    #print("timezone=%s" % timezone)
    homePower = get_homePower_series(flux_defaults, api_key, TTL_SERIES)
    pvPower = get_pvPower_series(flux_defaults, api_key, TTL_SERIES)
    consumption = subtract_lists(pvPower, homePower)

    pvPower_max = get_pvPower_max(flux_defaults, api_key, TTL_MAXVALUE)
    homePower_max = get_homePower_max(flux_defaults, api_key, TTL_MAXVALUE)

    # str(type(color)) == "string"
    #print("pvPower_max=%s" % pvPower_max)
    #print("homePower_max=%s" % homePower_max)

    render_graph = render.Stack(
        children = [
            render.Plot(data = consumption, width = 64, height = 32, color = "#0f0", color_inverted = "#f00", fill = True),
        ],
    )
    render_max = render.Column(children = [
        render.Text(pvPower_max, font = FONT, color = "#0f0"),
        render.Text(homePower_max, font = FONT, color = "#f00"),
    ])
    return render.Root(child = render.Stack(children = [render_max, render_graph]))

def get_pvPower_series(defaults, api_key, ttl):
    fluxql = defaults + ' \
        |> range(start: -1d)                                    \
        |> filter(fn: (r) => r._measurement == "pvPower")           \
        |> group()                                                  \
        |> aggregateWindow(every: 15m, fn: mean)                    \
        |> fill(value: 0.0)                                         \
        |> keep(columns: ["_time", "_value"])'

    return get_datatouples(fluxql, api_key, ttl)

def get_homePower_series(defaults, api_key, ttl):
    fluxql = defaults + ' \
        |> range(start: -1d)                                    \
        |> filter(fn: (r) => r._measurement == "homePower")         \
        |> aggregateWindow(every: 15m, fn: mean)                    \
        |> fill(value: 0.0)                                         \
        |> keep(columns: ["_time", "_value"])'

    #print ("query=" + fluxql)
    return get_datatouples(fluxql, api_key, ttl)

def get_pvPower_max(defaults, api_key, ttl):
    fluxql = defaults + ' \
        |> range(start: -1d)                                    \
        |> filter(fn: (r) => r._measurement == "pvPower")         \
        |> group()                                                  \
        |> max()                                                    \
        |> toInt() \
        |> keep(columns: ["_value"])'
    data = csv.read_all(get_fluxdata(fluxql, api_key, ttl))
    #,result,table,_value
    #,_result,0,4520

    if len(data) > 0:
        return data[1][3]  # not the most elegant CSV parsing
    else:
        return "0000"

def get_homePower_max(defaults, api_key, ttl):
    fluxql = defaults + ' \
        |> range(start: -1d)                                    \
        |> filter(fn: (r) => r._measurement == "homePower")         \
        |> max()                                                    \
        |> toInt() \
        |> keep(columns: ["_value"])'
    data = csv.read_all(get_fluxdata(fluxql, api_key, ttl))
    #,result,table,_value
    #,_result,0,4520

    if len(data) > 0:
        return data[1][3]  # not the most elegant CSV parsing
    else:
        return "0000"

def get_fluxdata(query, api_key, ttl):
    key = base64.encode(api_key + query)
    data = cache.get(key)

    if data != None:  # the cache key does exist and has not expired
        #print("Cache HIT for %s" % query)
        return base64.decode(data)

    #print("Cache MISS for %s" % query)

    rep = http.post(
        INFLUXDB_HOST,
        headers = {
            "Authorization": "Token " + api_key,
            "Accept": "application/json",
            "Content-type": "application/json",
        },
        json_body = {"query": query, "type": "flux"},
    )

    #print(rep.status_code)
    #print(rep.body())

    if rep.status_code != 200:
        fail("InfluxDB API request failed with status {}".format(rep.status_code))
        return None
    cache.set(key, base64.encode(rep.body()), ttl_seconds = ttl)

    return rep.body()

def get_datatouples(query, api_key, ttl):
    result = get_fluxdata(query, api_key, ttl)
    return csv2touples(result)

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

def subtract_lists(list1, list2):
    result = []
    for tup1, tup2 in zip(list1, list2):
        id1, value1 = tup1
        id2, value2 = tup2
        subtracted_value = value1 - value2
        result.append((id1, subtracted_value))
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
                desc = "The name of the InfluxDB bucket, default \"evcc\"",
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
