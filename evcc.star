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

DEFAULT_BUCKET = "evcc"
DEFAULT_LOCATION = {
    "lat": 52.52136203907116,
    "lng": 13.413308033057413,
    "locality": "Weltzeituhr Alexanderlatz",
}
DEFAULT_TIMEZONE = "Europe/Berlin"
FONT = "tom-thumb"
INFLUXDB_HOST = "https://eu-central-1-1.aws.cloud2.influxdata.com/api/v2/query"
INFLUXDB_TOKEN = "TVcTz0Q0KWFcJF8v3i1F0UY-4Jqp_ou5ThMBoHEt4Yw0zPXHl8IeX1LGP6uwK3eJ89Zeicq4CecPeoMRChXstg=="
TTL_FOR_LAST = 60  # the TTL for up2date info
TTL_FOR_MAX = 900  # how often the max values are being refreshed
TTL_FOR_SERIES = 900  # how often the time series for pvPower and homePower are being refreshed

# COLOR DEFINITIONS
BLACK = "#000"
GREEN = "#0F0"
GREY = "#5A5A5A"
RED = "#F00"
WHITE = "#FFF"
YELLOW = "#FF0"



CAR_ICON = base64.decode("""
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
""")

SUN_ICON = base64.decode("""
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
""")

POWER_ICON = base64.decode("""
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
""")

# LAYOUT DEFINITIONS
BAR_WIDTH = 60

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

    phasesActive = get_last_value("phasesActive", flux_defaults, api_key)
    chargePower = get_last_value("chargePower", flux_defaults, api_key)
    gridPower = get_last_value("gridPower", flux_defaults, api_key)
    homePower = get_last_value("homePower", flux_defaults, api_key)
    pvPower = get_last_value("pvPower", flux_defaults, api_key)

    # gridPower positive means I am consuming from the power grid
    if gridPower > 0:
        in_total = gridPower + pvPower
    else:
        in_total = pvPower
    print("in_total = %s" % in_total)

    render_graph = render.Stack(
        children = [
            render.Plot(data = consumption, width = 64, height = 32, color = RED, color_inverted = GREEN, fill = True),
        ],
    )

    column1 = [
        render.Image(src = SUN_ICON),
        render.Box(width = 2, height = 2, color = BLACK), # for better horizontal alignment
        render.Text(str(pvPower), font = FONT, color = GREEN),
    ]
    column2 = [
        render.Image(src = POWER_ICON),
        render.Box(width = 2, height = 2, color = BLACK), # for better horizontal alignment
        render.Text(str(gridPower), font = FONT, color = get_power_color(gridPower)),  
        render.Text(str(homePower), font = FONT, color = WHITE),
    ]
    column3 = [
        render.Image(src = CAR_ICON),
        render.Box(width = 2, height = 2, color = BLACK), # for better horizontal alignment
        render.Text(str(chargePower) + "%", font = FONT, color = get_power_color(chargePower)),
        render.Text(str(phasesActive) + "/3", font = FONT, color = RED),
    ]

    columns = render.Row(
        children = [
            render.Column(
                children = column1,
                main_align = "center",
                cross_align = "center",
            ),
            render.Column(
                children = [render.Box(width = 1, height = 32, color = GREY)],
            ),
            render.Column(
                children = column2,
                main_align = "center",
                cross_align = "center",
            ),
            render.Column(
                children = [render.Box(width = 1, height = 32, color = GREY)],
            ),
            render.Column(
                children = column3,
                main_align = "center",
                cross_align = "center",
            ),
        ],
        main_align = "space_evenly",
        expanded = True,
    )

    basic_frame = render.Column(
        #children=[upper_row,lower_row, render_graph],
        #children = [upper_row, lower_row],
        children = [columns],
    )

    #return render.Root(child = render.Stack(children = [basic_frame, render_graph]))
    return render.Root(basic_frame)

def get_power_color(power):
    if power > 0:
        color = RED
    elif power < 0:
        color = GREEN
    else:
        color = YELLOW
    return color

def get_phases_color(phases):
    if phases == 0:
        color = RED
    elif phases == 1:
        color = YELLOW
    elif phases == 2:
        color = YELLOW
    elif phases == 3:
        color = GREEN
        
    else:
        phases = GREY # this should never happen
    return color



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
    value = data[1][3] if len(data) > 0 else "0000"
    print("%s (max) = %s" % (measurement, value))
    return int(value)

def get_last_value(measurement, defaults, api_key):
    fluxql = defaults + ' \
        |> range(start: -1m) \
        |> filter(fn: (r) => r._measurement == "' + measurement + '") \
        |> group() \
        |> last() \
        |> toInt() \
        |> keep(columns: ["_value"])'

    data = csv.read_all(readInfluxDB(fluxql, api_key, TTL_FOR_LAST))
    value = data[1][3] if len(data) > 0 else "0000"
    print("%s (last) = %s" % (measurement, value))
    return int(value)

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
