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

INFLUXDB_HOST = "https://eu-central-1-1.aws.cloud2.influxdata.com/api/v2/query"
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
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
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
    api_key = config.str("api_key") or INFLUXDB_TOKEN
    bucket = config.get("bucket") or DEFAULT_BUCKET

    location = config.get("location")
    loc = json.decode(location) if location else DEFAULT_LOCATION
    timezone = loc.get("timezone", DEFAULT_TIMEZONE)
    scale_gridPower = int(config.str("scale_gridPower"))

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

    if pvPower > homePower:
        col2_icon = PANEL_ICON
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
    else:  # error case, phases should be in range 0-3 only
        col3_color1 = RED
        col3_color2 = RED
        col3_color3 = RED

    render_graph = render.Stack(
        children = [
            render.Plot(data = consumption, width = 64, height = 32, color = GREEN, color_inverted = RED, fill = True, y_lim = (-1 * scale_gridPower, scale_gridPower)),
        ],
    )

    column1 = [
        # this is the PV power column
        render.Image(src = SUN_ICON),
        render.Box(width = 2, height = 2, color = BLACK),  # for better horizontal alignment
        render.Text(str(pvPower), color = get_power_color(pvPower)),
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

    

    if config.str("variant") == "opt_columns":
        basic_frame = render.Column(children = [columns])
        return render.Root(basic_frame)
    elif config.str("variant") == "opt_gridPower":
        return render.Root(render_graph)

    elif config.str("variant") == "opt_gridPower":
        return render.Root(render_graph)

    else:
        return render.Root(render_graph)

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
    value = data[1][3] if len(data) > 0 else "0"
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
    value = data[1][3] if len(data) > 0 else "0"
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

options = [
    schema.Option(
        display = "3 column display",
        value = "opt_columns",
    ),
    schema.Option(
        display = "gridPower consumption graph (last 12 hours)",
        value = "opt_gridPower",
    ),
    schema.Option(
        display = "charging graph",
        value = "opt_chargePower",
    ),
]

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
            schema.Dropdown(
                id = "variant",
                name = "application variant",
                desc = "Which variant to display",
                icon = "brush",
                default = options[0].value,
                options = options,
            ),
            schema.Text(
                id = "scale_gridPower",
                name = "gridPower scale",
                desc = "the maximum expected value for gridPower, required for nice graphing",
                icon = "gear",
                default = "5000",
            ),
        ],
    )
