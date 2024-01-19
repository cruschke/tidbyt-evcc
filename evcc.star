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
BS_GRAY_BRIGHT = "#F3F3F7"
BS_GRAY_DARK = "#28293E"
BS_GRAY_DEEP = "#010322"
BS_GRAY_LIGHT = "#B5B6C3"
BS_GRAY_MEDIUM = "#93949E"
EVCC_DARK_YELLOW = "#BBB400"
EVCC_SELF = "#0FDE41"
EVCC_YELLOW = "#FAF000"

CAR_ICON = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAAXNSR0IArs4c6QAAAGlJREFUOE+tk9EOQCEEQPk+Ppfvc9dDW8lcLT2G0zFCeDz4WA/9ABExIgrFVBWYeXv0MDAzQ8TQLIr1ATJ138/aymaQ6U+IzwkBEWjelQDZbvwCKou1TuloYQCyMfp4L6Ci73P6/8KtxQc+MVIRuOdZPAAAAABJRU5ErkJggg==
""")

SUN_ICON = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAAXNSR0IArs4c6QAAALRJREFUOE+tk+sRwjAMg6UN6AawAYzSiWAkNoEN6AawgSFc3VNdJ1ce/RnbXxRZJX782Jo3Myt1ktW+RcHM7gA2ZUgBL9YJwDHCUnIZjI0j7EyyV9UToNxMsltjiV6ggNl7Xb4DXVH0pfoENa9l5hsQG2oeZCr+A4jGJYouAPZZHtTE2Z6jiQAOJK/j+cM3Frew2HOibgvg5mo+DdKO5JAGyQ9DfKdsaMSbAC1+9TOtibL2PAEOz40RgUO7WwAAAABJRU5ErkJggg==
""")

POWER_ICON = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAAXNSR0IArs4c6QAAAI1JREFUOE+9ktENgCAMRO82kJHcQDd1A0fCDTAl1mCpYEIif1Du9XItMXg4qIcLSCklD0yy+l89GPF8gfYCuJLc9H4DvK7asaiJcBGx1jLgzXIvH4E0M7AOPmXQcvQvwHaTnD456AVqIe4eyCcHFADEJsCKnD3Iky0hDwcKaIw3ApgABJJHhvWWpVcfBpwmV00RXHy7wQAAAABJRU5ErkJggg==
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
            #render.Plot(data = consumption, width = 64, height = 4, color = "#0f0", color_inverted = "#f00", fill = True),
            render.Plot(data = consumption, width = 64, height = 16, color = "#0f0", color_inverted = "#f00", fill = True),
        ],
    )
    render_max = render.Column(
        children = [
            render.Text(str(chargePower), font = FONT, color = "#f00"),
            render.Text(str(pvPower), font = FONT, color = "#0f0"),
            render.Text(str(homePower), font = FONT, color = "#f00"),
        ],
    )

    # TODO use columns instead of pixel-perfect alignment
    upper_row = render.Row(
        children = [
            render.Box(width = 3, height = 16, color = "#000"),
            render.Image(src = SUN_ICON),
            render.Box(width = 4, height = 16, color = "#000"),
            render.Image(src = POWER_ICON),
            render.Box(width = 4, height = 16, color = "#000"),
            render.Image(src = CAR_ICON),
        ],
    )

    lower_row = render.Row(
        expanded = True,
        main_align = "space_evenly",
        cross_align = "center",
        children = [
            render.Column(
                expanded = True,
                main_align = "space_around",
                cross_align = "center",
                children = [
                    render.Text(str(pvPower), font = FONT, color = "#0f0"),
                ],
            ),
            render.Column(
                expanded = True,
                main_align = "space_around",
                cross_align = "center",
                children = [
                    render.Text(str(homePower), font = FONT, color = "#f00"),
                ],
            ),
            render.Column(
                expanded = True,
                main_align = "space_around",
                cross_align = "center",
                children = [
                    render.Text(str(chargePower), font = FONT, color = "#f00"),
                ],
            ),
        ],
    )

    #lower_columns =

    basic_frame = render.Column(
        #children=[upper_row,lower_row, render_graph],
        children = [upper_row, lower_row],
    )

    #return render.Root(child = render.Stack(children = [render_max, render_graph]))
    return render.Root(basic_frame)
    #return render.Root(render.Image(src=POWER_ICON))

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
