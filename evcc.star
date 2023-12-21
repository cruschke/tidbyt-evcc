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

DEFAULT_BUCKET   = "evcc"
DEFAULT_LOCATION = {
    "lat": 52.52136203907116,
    "lng": 13.413308033057413,
    "locality": "Weltzeituhr Alexanderlatz",
}
DEFAULT_TIMEZONE = "Europe/Berlin"
FONT             = "tom-thumb"
INFLUXDB_HOST    = "https://eu-central-1-1.aws.cloud2.influxdata.com/api/v2/query"
INFLUXDB_TOKEN   = "TVcTz0Q0KWFcJF8v3i1F0UY-4Jqp_ou5ThMBoHEt4Yw0zPXHl8IeX1LGP6uwK3eJ89Zeicq4CecPeoMRChXstg=="
TTL_FOR_LAST     = 60  # the TTL for up2date info
TTL_FOR_MAX      = 900  # how often the max values are being refreshed
TTL_FOR_SERIES   = 900  # how often the time series for pvPower and homePower are being refreshed

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

    consumption = get_gridPower_series(flux_defaults, api_key)

    phasesActive_last= get_last_value("phasesActive", flux_defaults, api_key) 
    chargePower_last = get_last_value("chargePower", flux_defaults, api_key) 
    chargePower_max  = get_max_value("chargePower", flux_defaults, api_key) 
    homePower_last   = get_last_value("homePower", flux_defaults, api_key)
    homePower_max    = get_max_value("homePower", flux_defaults, api_key)
    pvPower_last     = get_last_value("pvPower",flux_defaults, api_key) 
    pvPower_max      = get_max_value("pvPower", flux_defaults, api_key)

    # str(type(color)) == "string"
    print("phasesActive_last=%s" % phasesActive_last)
    print("chargePower_last=%s" % chargePower_last)
    print("chargePower_max=%s" % chargePower_max)
    print("homePower_last=%s" % homePower_last)
    print("homePower_max=%s" % homePower_max)
    print("pvPower_last=%s" % pvPower_last)
    print("pvPower_max=%s" % pvPower_max)

    render_graph = render.Stack(
        children = [
            render.Plot(data = consumption, width = 64, height = 32, color = "#0f0", color_inverted = "#f00", fill = True),
        ],
    )
    render_max = render.Column(children = [
        render.Text(chargePower_last, font = FONT, color = "#f00"),
        render.Text(pvPower_last, font = FONT, color = "#0f0"),
        render.Text(homePower_last, font = FONT, color = "#f00"),
    ])
    return render.Root(child = render.Stack(children = [render_max, render_graph]))

# https://github.com/evcc-io/docs/blob/main/docs/reference/configuration/messaging.md?plain=1#L156
# grid power - Current grid feed-in(-) or consumption(+) in watts (__float__)
# inverted the series for more natural display of the data series
# multiply by -1 to make it display logically correct in Plot

def get_gridPower_series(defaults, api_key):
    fluxql = defaults + ' \
        |> range(start: -12h)                                    \
        |> filter(fn: (r) => r._measurement == "gridPower")         \
        |> aggregateWindow(every: 15m, fn: mean)                    \
        |> fill(value: 0.0)                                         \
        |> map(fn: (r) => ({r with _value: (float(v: r._value) * -1.0) })) \
        |> keep(columns: ["_time", "_value"])'

    #print ("query=" + fluxql)
    return get_datatouples(fluxql, api_key, TTL_FOR_SERIES)

def get_max_value(measurement, defaults, api_key):
    fluxql = defaults + ' \
        |> range(start: -1d) \
        |> filter(fn: (r) => r._measurement == "' + measurement + '") \
        |> group() \
        |> max() \
        |> toInt() \
        |> keep(columns: ["_value"])'
    
    data = csv.read_all(readInfluxDB(fluxql, api_key, TTL_FOR_MAX))
    return data[1][3] if len(data) > 0 else "0000"

def get_last_value(measurement, defaults, api_key):
    fluxql = defaults + ' \
        |> range(start: -1m) \
        |> filter(fn: (r) => r._measurement == "' + measurement + '") \
        |> group() \
        |> last() \
        |> toInt() \
        |> keep(columns: ["_value"])'
    
    data = csv.read_all(readInfluxDB(fluxql, api_key, TTL_FOR_LAST))
    return data[1][3] if len(data) > 0 else "0000"

def readInfluxDB(query, api_key, ttl):
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
    result = readInfluxDB(query, api_key, ttl)
    return csv2touples(result)

# InfluxDB returns time series as CSV, we want touples instead
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
