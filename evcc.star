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
DEFAULT_GRIDPOWERSCALE = 0

INFLUXDB_HOST_DEFAULT = "https://eu-central-1-1.aws.cloud2.influxdata.com/api/v2/query"
INFLUXDB_TOKEN = "TVcTz0Q0KWFcJF8v3i1F0UY-4Jqp_ou5ThMBoHEt4Yw0zPXHl8IeX1LGP6uwK3eJ89Zeicq4CecPeoMRChXstg=="
TTL_FOR_LAST = 60  # the TTL for up2date info
TTL_FOR_MAX = 900  # how often the max values are being refreshed
TTL_FOR_SERIES = 900  # how often the time series for pvPower and homePower are being refreshed

# COLOR DEFINITIONS
BLACK = "#000"
DARK_GREEN = "#062E03"
GREEN = "#0F0"
GREY = "#1A1A1A"
RED = "#F00"
WHITE = "#FFF"
YELLOW = "#FF0"

CAR_ICON = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAYAAAAfSC3RAAAAAXNSR0IArs4c6QAAAMpJREFUOE+tkj0KAjEQhb8noqWFhZ2VWHgBT+BfY+0xPIrXsLVx1RMo1hZiY2mhYKmIIyvZZTcuLCwGAslkvnmZl4iCQwU5fkAzmwJ1oOSKvoGrpFlSJAWamQEH4O6BNaAjKc6PF2bWABaSulnXN7MtMJZ0Cc+TYKgWzidQ9eAHUAnzI1UfzPUqE4yCrte4SDL+X9BJnIAXcHT7NlAGWl9TnLOpHoPVhtGwn/kplsHahoPeL7jb7c/X262ZA84lTVLPkWunl1D4r34AxCFXD/jF0dwAAAAASUVORK5CYII=
""")

SUN_ICON = base64.decode("""
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
""")

PANEL_ICON = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAYAAAAfSC3RAAAAnmVYSWZNTQAqAAAACAAGARIAAwAAAAEAAQAAARoABQAAAAEAAABWARsABQAAAAEAAABeASgAAwAAAAEAAgAAATEAAgAAABoAAABmh2kABAAAAAEAAACAAAAAAAAAAEgAAAABAAAASAAAAAFQaXhlbG1hdG9yIFBybyBEZW1vIDIuMC42AAACoAIABAAAAAEAAAAOoAMABAAAAAEAAAAOAAAAAM2nMk0AAAAJcEhZcwAACxMAAAsTAQCanBgAAANsaVRYdFhNTDpjb20uYWRvYmUueG1wAAAAAAA8eDp4bXBtZXRhIHhtbG5zOng9ImFkb2JlOm5zOm1ldGEvIiB4OnhtcHRrPSJYTVAgQ29yZSA2LjAuMCI+CiAgIDxyZGY6UkRGIHhtbG5zOnJkZj0iaHR0cDovL3d3dy53My5vcmcvMTk5OS8wMi8yMi1yZGYtc3ludGF4LW5zIyI+CiAgICAgIDxyZGY6RGVzY3JpcHRpb24gcmRmOmFib3V0PSIiCiAgICAgICAgICAgIHhtbG5zOmV4aWY9Imh0dHA6Ly9ucy5hZG9iZS5jb20vZXhpZi8xLjAvIgogICAgICAgICAgICB4bWxuczp4bXA9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8iCiAgICAgICAgICAgIHhtbG5zOnRpZmY9Imh0dHA6Ly9ucy5hZG9iZS5jb20vdGlmZi8xLjAvIj4KICAgICAgICAgPGV4aWY6UGl4ZWxZRGltZW5zaW9uPjE0PC9leGlmOlBpeGVsWURpbWVuc2lvbj4KICAgICAgICAgPGV4aWY6UGl4ZWxYRGltZW5zaW9uPjE0PC9leGlmOlBpeGVsWERpbWVuc2lvbj4KICAgICAgICAgPHhtcDpDcmVhdG9yVG9vbD5QaXhlbG1hdG9yIFBybyBEZW1vIDIuMC42PC94bXA6Q3JlYXRvclRvb2w+CiAgICAgICAgIDx4bXA6TWV0YWRhdGFEYXRlPjIwMjQtMDItMTFUMTY6MDk6NThaPC94bXA6TWV0YWRhdGFEYXRlPgogICAgICAgICA8dGlmZjpYUmVzb2x1dGlvbj43MjAwMDAvMTAwMDA8L3RpZmY6WFJlc29sdXRpb24+CiAgICAgICAgIDx0aWZmOlJlc29sdXRpb25Vbml0PjI8L3RpZmY6UmVzb2x1dGlvblVuaXQ+CiAgICAgICAgIDx0aWZmOllSZXNvbHV0aW9uPjcyMDAwMC8xMDAwMDwvdGlmZjpZUmVzb2x1dGlvbj4KICAgICAgICAgPHRpZmY6T3JpZW50YXRpb24+MTwvdGlmZjpPcmllbnRhdGlvbj4KICAgICAgPC9yZGY6RGVzY3JpcHRpb24+CiAgIDwvcmRmOlJERj4KPC94OnhtcG1ldGE+CpdATFoAAADSSURBVCgVxVAxEgFBENxVZHxAooiQE3jAlYBQxgXKHzzHN7zAFygXSXzgSE6wutVObVPy66q+6Z7dneob52pBCCEHDU+ItZmo2TPkDNmISZeS+Aw9Fj+CvohfUHt+MGqO0qEG7uAL7NEAN7AFdmmA0nt/5KOpZYh1j1pI7wrNnmLCqNlnTvoUkP1k3QCaPUXmMUZj8vAEzvTWn17JqJVk4PY24k1yyw8zqBWj8scN3OjQjNTfzeobuQaJqSvyu5tcM8mk8GALt2MHuo31H9JpXeoNjHW8AvqRh98AAAAASUVORK5CYII=
""")

GRID_ICON = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAYAAAAfSC3RAAAAnmVYSWZNTQAqAAAACAAGARIAAwAAAAEAAQAAARoABQAAAAEAAABWARsABQAAAAEAAABeASgAAwAAAAEAAgAAATEAAgAAABoAAABmh2kABAAAAAEAAACAAAAAAAAAAEgAAAABAAAASAAAAAFQaXhlbG1hdG9yIFBybyBEZW1vIDIuMC42AAACoAIABAAAAAEAAAAOoAMABAAAAAEAAAAOAAAAAM2nMk0AAAAJcEhZcwAACxMAAAsTAQCanBgAAANsaVRYdFhNTDpjb20uYWRvYmUueG1wAAAAAAA8eDp4bXBtZXRhIHhtbG5zOng9ImFkb2JlOm5zOm1ldGEvIiB4OnhtcHRrPSJYTVAgQ29yZSA2LjAuMCI+CiAgIDxyZGY6UkRGIHhtbG5zOnJkZj0iaHR0cDovL3d3dy53My5vcmcvMTk5OS8wMi8yMi1yZGYtc3ludGF4LW5zIyI+CiAgICAgIDxyZGY6RGVzY3JpcHRpb24gcmRmOmFib3V0PSIiCiAgICAgICAgICAgIHhtbG5zOmV4aWY9Imh0dHA6Ly9ucy5hZG9iZS5jb20vZXhpZi8xLjAvIgogICAgICAgICAgICB4bWxuczp4bXA9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8iCiAgICAgICAgICAgIHhtbG5zOnRpZmY9Imh0dHA6Ly9ucy5hZG9iZS5jb20vdGlmZi8xLjAvIj4KICAgICAgICAgPGV4aWY6UGl4ZWxZRGltZW5zaW9uPjE0PC9leGlmOlBpeGVsWURpbWVuc2lvbj4KICAgICAgICAgPGV4aWY6UGl4ZWxYRGltZW5zaW9uPjE0PC9leGlmOlBpeGVsWERpbWVuc2lvbj4KICAgICAgICAgPHhtcDpDcmVhdG9yVG9vbD5QaXhlbG1hdG9yIFBybyBEZW1vIDIuMC42PC94bXA6Q3JlYXRvclRvb2w+CiAgICAgICAgIDx4bXA6TWV0YWRhdGFEYXRlPjIwMjQtMDItMTFUMTU6MzU6MDJaPC94bXA6TWV0YWRhdGFEYXRlPgogICAgICAgICA8dGlmZjpYUmVzb2x1dGlvbj43MjAwMDAvMTAwMDA8L3RpZmY6WFJlc29sdXRpb24+CiAgICAgICAgIDx0aWZmOlJlc29sdXRpb25Vbml0PjI8L3RpZmY6UmVzb2x1dGlvblVuaXQ+CiAgICAgICAgIDx0aWZmOllSZXNvbHV0aW9uPjcyMDAwMC8xMDAwMDwvdGlmZjpZUmVzb2x1dGlvbj4KICAgICAgICAgPHRpZmY6T3JpZW50YXRpb24+MTwvdGlmZjpPcmllbnRhdGlvbj4KICAgICAgPC9yZGY6RGVzY3JpcHRpb24+CiAgIDwvcmRmOlJERj4KPC94OnhtcG1ldGE+CtlVVGMAAAEUSURBVCgVjZKxSsRAEIbXIEThKlstLCwVW8UH8AW0sbOytbe5xtZesLBRrvAFxDewsLYTuQc4IyHZ7OzM+OeO4U6PTZwEZjPzf/tnlnUuEcx8rxYyXVwnpPNyUzZ7i4yIfMy7HStVvp2ZqAqeGMJ5h3zW8t7vwKEyx8j80Au1AkBPBglsWfmCqDpsVHdRz5ObsEhp4DSLsDDwwJf4zpbAseo6hzhqXTDWr5AYn/8Cq1bY+nJ5HPBbVHrPs7WDFeeO2x7+9XVSFKem68ywe8Gsires63q7U2zNiugIBAH+noSwb/XejBvziBF9jM1Zr9gEcMlwhJ9EdGW1f2WAJz6GOx0Ol489tQOgTSJ/UxTjjZRmsf4DHk73Q3PzaAUAAAAASUVORK5CYII=
""")

# LAYOUT DEFINITIONS
BAR_WIDTH = 60

def main(config):
    influxdb_host = config.str("influxdb") or INFLUXDB_HOST_DEFAULT
    api_key = config.str("api_key") or INFLUXDB_TOKEN
    bucket = config.get("bucket") or DEFAULT_BUCKET

    location = config.get("location")
    loc = json.decode(location) if location else DEFAULT_LOCATION
    timezone = loc.get("timezone", DEFAULT_TIMEZONE)
    if config.str("scale_gridPower"):  # make sure its set and not None
        scale_gridPower = int(config.str("scale_gridPower"))
    else:
        scale_gridPower = DEFAULT_GRIDPOWERSCALE

    # some FluxQL query parameters that every single query needs
    flux_defaults = '                                                     \
        import "timezone"                                               \
        option location = timezone.location(name: "' + timezone + '")   \
        from(bucket:"' + bucket + '")'

    consumption = get_gridPower_series(influxdb_host, flux_defaults, api_key)
    charging = get_chargePower_series(influxdb_host, flux_defaults, api_key)
    print(charging)

    phasesActive = get_last_value(influxdb_host, "phasesActive", flux_defaults, api_key)
    chargePower = get_last_value(influxdb_host, "chargePower", flux_defaults, api_key)
    gridPower = get_last_value(influxdb_host, "gridPower", flux_defaults, api_key)
    homePower = get_last_value(influxdb_host, "homePower", flux_defaults, api_key)
    pvPower = get_last_value(influxdb_host, "pvPower", flux_defaults, api_key)

    if pvPower > homePower:
        col2_icon = SUN_ICON
    else:
        col2_icon = GRID_ICON

    col3_color1 = DARK_GREEN
    col3_color2 = DARK_GREEN
    col3_color3 = DARK_GREEN
    if phasesActive >= 1:
        col3_color1 = GREEN
    if phasesActive >= 2:
        col3_color2 = GREEN
    if phasesActive >= 3:
        col3_color3 = GREEN
    else:  # no charging or error case
        col3_color1 = RED
        col3_color2 = RED
        col3_color3 = RED

    if scale_gridPower > 0:  # use dedicated scale
        render_graph = render.Stack(
            children = [
                render.Plot(data = consumption, width = 64, height = 32, color = GREEN, color_inverted = RED, fill = True, y_lim = (-1 * scale_gridPower, scale_gridPower)),
            ],
        )
    else:  # use autoscale
        render_graph = render.Column(
            children = [
                render.Plot(data = consumption, width = 64, height = 15, color = GREEN, color_inverted = RED, fill = True),
                render.Box(width = 64, height = 1, color = BLACK),
                render.Box(width = 64, height = 1, color = GREY),
                render.Plot(data = charging, width = 64, height = 15, color = YELLOW, fill = True, y_lim = (0, 1000)),
            ],
        )
    column1 = [
        # this is the PV power column
        render.Image(src = PANEL_ICON),
        render.Box(width = 2, height = 2, color = BLACK),  # for better horizontal alignment
        render.Text(str(pvPower), color = get_power_color(pvPower * -1)),  # pvPower needs to be reversed
    ]
    column2 = [
        # this is the grid power column
        render.Image(src = col2_icon),
        render.Box(width = 2, height = 2, color = BLACK),  # for better horizontal alignment
        render.Text(str(abs(gridPower)), color = get_power_color(gridPower)),  # abs() because I don't want to report negative numbers, thats why we have the color coding
    ]
    column3 = [
        # this is the car charging column
        render.Image(src = CAR_ICON),
        render.Row(
            children = [
                render.Box(width = 1, height = 1, color = col3_color1),
                render.Box(width = 1, height = 1, color = col3_color2),
                render.Box(width = 1, height = 1, color = col3_color3),
            ],
        ),
        render.Box(width = 2, height = 1, color = BLACK),  # for better horizontal alignment
        render.Text(str(chargePower) + "%", color = get_power_color(chargePower)),
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

    print(config.str("variant"))
    if config.str("variant") == "opt_columns":
        return render.Root(render.Column(children = [columns]))
    elif config.str("variant") == "opt_gridPower":
        return render.Root(render_graph)

    elif config.str("variant") == "opt_gridPower":
        return render.Root(render_graph)

    else:
        return render.Root(render.Column(children = [columns]))

def get_power_color(power):
    if power > 0:
        color = RED
    elif power < 0:
        color = GREEN
    else:
        color = YELLOW
    return color

# https://github.com/evcc-io/docs/blob/main/docs/reference/configuration/messaging.md?plain=1#L156
# grid power - Current grid feed-in(-) or consumption(+) in watts (__float__)
# inverted the series for more natural display of the data series
# multiply by -1 to make it display logically correct in Plot

def get_gridPower_series(dbhost, defaults, api_key):
    fluxql = defaults + ' \
        |> range(start: -12h)                                    \
        |> filter(fn: (r) => r._measurement == "gridPower")         \
        |> aggregateWindow(every: 15m, fn: mean)                    \
        |> fill(value: 0.0)                                         \
        |> map(fn: (r) => ({r with _value: (float(v: r._value) * -1.0) })) \
        |> keep(columns: ["_time", "_value"])'

    #print ("query=" + fluxql)
    return get_datatouples(dbhost, fluxql, api_key, TTL_FOR_SERIES)

def get_chargePower_series(dbhost, defaults, api_key):
    fluxql = defaults + ' \
        |> range(start: -12h)                                    \
        |> filter(fn: (r) => r._measurement == "chargePower")         \
        |> aggregateWindow(every: 15m, fn: mean)                    \
        |> fill(value: 0.0)                                         \
        |> map(fn: (r) => ({r with _value: (float(v: r._value)) })) \
        |> keep(columns: ["_time", "_value"])'

    #print ("query=" + fluxql)
    return get_datatouples(dbhost, fluxql, api_key, TTL_FOR_SERIES)

def get_max_value(dbhost, measurement, defaults, api_key):
    fluxql = defaults + ' \
        |> range(start: -1d) \
        |> filter(fn: (r) => r._measurement == "' + measurement + '") \
        |> group() \
        |> max() \
        |> toInt() \
        |> keep(columns: ["_value"])'

    data = csv.read_all(readInfluxDB(dbhost, fluxql, api_key, TTL_FOR_MAX))
    value = data[1][3] if len(data) > 0 else "0"
    print("%s (max) = %s" % (measurement, value))
    return int(value)

def get_last_value(dbhost, measurement, defaults, api_key):
    fluxql = defaults + ' \
        |> range(start: -1m) \
        |> filter(fn: (r) => r._measurement == "' + measurement + '") \
        |> group() \
        |> last() \
        |> toInt() \
        |> keep(columns: ["_value"])'

    data = csv.read_all(readInfluxDB(dbhost, fluxql, api_key, TTL_FOR_LAST))
    value = data[1][3] if len(data) > 0 else "0"
    print("%s (last) = %s" % (measurement, value))
    return int(value)

def readInfluxDB(dbhost, query, api_key, ttl):
    key = base64.encode(api_key + query)
    data = cache.get(key)

    if data != None:  # the cache key does exist and has not expired
        #print("Cache HIT for %s" % query)
        return base64.decode(data)

    #print("Cache MISS for %s" % query)

    rep = http.post(
        dbhost,
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

def get_datatouples(dbhost, query, api_key, ttl):
    result = readInfluxDB(dbhost, query, api_key, ttl)
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

options_variant = [
    schema.Option(
        display = "3 columns",
        value = "opt_columns",
    ),
    schema.Option(
        display = "gridPower and charging graph (last 12 hours)",
        value = "opt_gridPower",
    ),
]

# see https://docs.influxdata.com/influxdb/cloud-serverless/reference/regions/

options_influxdb = [
    schema.Option(
        display = "EU Frankfurt",
        value = "https://eu-central-1-1.aws.cloud2.influxdata.com/api/v2/query",
    ),
    schema.Option(
        display = "US East (Virginia)",
        value = "https://us-east-1-1.aws.cloud2.influxdata.com/api/v2/query",
    ),
]

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Dropdown(
                id = "influxdb",
                name = "InfluxDB region",
                desc = "InfluxDB Cloud region",
                icon = "brush", # FIXME
                default = options_influxdb[0].value,
                options = options_influxdb,
            ),
            schema.Text(
                id = "api_key",
                name = "InfluxDB API key",
                desc = "API key for InfluxDB Cloud",
                icon = "key",
            ),
            schema.Text(
                id = "bucket",
                name = "InfluxDB bucket",
                desc = "The name of the InfluxDB bucket",
                icon = "database",
                default = "evcc",
            ),
            schema.Location(
                id = "location",
                name = "Location",
                desc = "Your device location",
                icon = "locationDot",
            ),
            schema.Dropdown(
                id = "variant",
                name = "display variant",
                desc = "Which variant to display",
                icon = "brush", # FIXME
                default = options_variant[0].value,
                options = options_variant,
            ),
            schema.Text(
                id = "scale_gridPower",
                name = "gridPower scale",
                desc = "the maximum expected value for gridPower, required for nice graphing. Set to 0 for autoscaling.",
                icon = "gear", # FIXME
                default = str(DEFAULT_GRIDPOWERSCALE),
            ),
        ],
    )
