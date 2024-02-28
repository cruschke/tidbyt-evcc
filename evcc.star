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
    "locality": "Weltzeituhr Alexanderplatz",
}
DEFAULT_TIMEZONE = "Europe/Berlin"
DEFAULT_GRIDPOWERSCALE = 0

INFLUXDB_HOST_DEFAULT = "https://eu-central-1-1.aws.cloud2.influxdata.com/api/v2/query"

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

FONT = "tom-thumb"

CAR_ICON = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAYAAAAfSC3RAAAAAXNSR0IArs4c6QAAAMpJREFUOE+tkj0KAjEQhb8noqWFhZ2VWHgBT+BfY+0xPIrXsLVx1RMo1hZiY2mhYKmIIyvZZTcuLCwGAslkvnmZl4iCQwU5fkAzmwJ1oOSKvoGrpFlSJAWamQEH4O6BNaAjKc6PF2bWABaSulnXN7MtMJZ0Cc+TYKgWzidQ9eAHUAnzI1UfzPUqE4yCrte4SDL+X9BJnIAXcHT7NlAGWl9TnLOpHoPVhtGwn/kplsHahoPeL7jb7c/X262ZA84lTVLPkWunl1D4r34AxCFXD/jF0dwAAAAASUVORK5CYII=
""")

SUN_ICON = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAYAAAAfSC3RAAAAnmVYSWZNTQAqAAAACAAGARIAAwAAAAEAAQAAARoABQAAAAEAAABWARsABQAAAAEAAABeASgAAwAAAAEAAgAAATEAAgAAABoAAABmh2kABAAAAAEAAACAAAAAAAAAAGAAAAABAAAAYAAAAAFQaXhlbG1hdG9yIFBybyBEZW1vIDIuMC42AAACoAIABAAAAAEAAAAOoAMABAAAAAEAAAAOAAAAAEiayq8AAAAJcEhZcwAADsQAAA7EAZUrDhsAAANsaVRYdFhNTDpjb20uYWRvYmUueG1wAAAAAAA8eDp4bXBtZXRhIHhtbG5zOng9ImFkb2JlOm5zOm1ldGEvIiB4OnhtcHRrPSJYTVAgQ29yZSA2LjAuMCI+CiAgIDxyZGY6UkRGIHhtbG5zOnJkZj0iaHR0cDovL3d3dy53My5vcmcvMTk5OS8wMi8yMi1yZGYtc3ludGF4LW5zIyI+CiAgICAgIDxyZGY6RGVzY3JpcHRpb24gcmRmOmFib3V0PSIiCiAgICAgICAgICAgIHhtbG5zOmV4aWY9Imh0dHA6Ly9ucy5hZG9iZS5jb20vZXhpZi8xLjAvIgogICAgICAgICAgICB4bWxuczp4bXA9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8iCiAgICAgICAgICAgIHhtbG5zOnRpZmY9Imh0dHA6Ly9ucy5hZG9iZS5jb20vdGlmZi8xLjAvIj4KICAgICAgICAgPGV4aWY6UGl4ZWxZRGltZW5zaW9uPjE0PC9leGlmOlBpeGVsWURpbWVuc2lvbj4KICAgICAgICAgPGV4aWY6UGl4ZWxYRGltZW5zaW9uPjE0PC9leGlmOlBpeGVsWERpbWVuc2lvbj4KICAgICAgICAgPHhtcDpDcmVhdG9yVG9vbD5QaXhlbG1hdG9yIFBybyBEZW1vIDIuMC42PC94bXA6Q3JlYXRvclRvb2w+CiAgICAgICAgIDx4bXA6TWV0YWRhdGFEYXRlPjIwMjQtMDEtMjBUMTY6MTg6NTlaPC94bXA6TWV0YWRhdGFEYXRlPgogICAgICAgICA8dGlmZjpYUmVzb2x1dGlvbj45NjAwMDAvMTAwMDA8L3RpZmY6WFJlc29sdXRpb24+CiAgICAgICAgIDx0aWZmOlJlc29sdXRpb25Vbml0PjI8L3RpZmY6UmVzb2x1dGlvblVuaXQ+CiAgICAgICAgIDx0aWZmOllSZXNvbHV0aW9uPjk2MDAwMC8xMDAwMDwvdGlmZjpZUmVzb2x1dGlvbj4KICAgICAgICAgPHRpZmY6T3JpZW50YXRpb24+MTwvdGlmZjpPcmllbnRhdGlvbj4KICAgICAgPC9yZGY6RGVzY3JpcHRpb24+CiAgIDwvcmRmOlJERj4KPC94OnhtcG1ldGE+CmqJ14MAAAGeSURBVCgVdVLNThRBEO5phA3L1cSLT4AaEL3Ac3AlRBNOHjj5Q8IBTHgCoyHGmwcOkHiDx+CAc9De9biZBzDMdNfPZ80yTQbMdlKpv69+uqqcm/Eg+IyE4xlu57Ojqqolk4usm/TYPZCHWQdQANUS0MOYcUgkv4XoXQ+4bvaXWReRvcQ6riq0BW4qHjrXeKcnOue3MMEwAsuquhLj9RpifBrC+YBVtwvI9+NHrs7Jbjlw4FOSXVWQ0VgZf5iVRHDUtnoLvC/EGJ9ZZuEYN0PAwMADvuZNFk32XtzBC8s3A5wabZjzjWUfhRAGGdQGq2Cc6vQahHVVPjfMV28zYucwPwV63xSFw+VlQg68GI1cp3St+mSrkOyfcsu+zPa/OqXtsiwXWqr/1q9UlP9rtR95AHgb+z6pNCIaoBoUMFl2yxILfeyNbEsloY8p0ZVVnUPEk5TqnYaat6avGS0mop8Q+uD6051MJkNR/UXRHN2z1p4brWZdSN5b9dBdWGe2LFND75yg+MHEZzmw3XFlJ2eDnL3PFmxH/okb+ZID7/N/ek5GfM105qAAAAAASUVORK5CYII=
""")

PANEL_ICON = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAYAAAAfSC3RAAAAnmVYSWZNTQAqAAAACAAGARIAAwAAAAEAAQAAARoABQAAAAEAAABWARsABQAAAAEAAABeASgAAwAAAAEAAgAAATEAAgAAABoAAABmh2kABAAAAAEAAACAAAAAAAAAAEgAAAABAAAASAAAAAFQaXhlbG1hdG9yIFBybyBEZW1vIDIuMC42AAACoAIABAAAAAEAAAAOoAMABAAAAAEAAAAOAAAAAM2nMk0AAAAJcEhZcwAACxMAAAsTAQCanBgAAANsaVRYdFhNTDpjb20uYWRvYmUueG1wAAAAAAA8eDp4bXBtZXRhIHhtbG5zOng9ImFkb2JlOm5zOm1ldGEvIiB4OnhtcHRrPSJYTVAgQ29yZSA2LjAuMCI+CiAgIDxyZGY6UkRGIHhtbG5zOnJkZj0iaHR0cDovL3d3dy53My5vcmcvMTk5OS8wMi8yMi1yZGYtc3ludGF4LW5zIyI+CiAgICAgIDxyZGY6RGVzY3JpcHRpb24gcmRmOmFib3V0PSIiCiAgICAgICAgICAgIHhtbG5zOmV4aWY9Imh0dHA6Ly9ucy5hZG9iZS5jb20vZXhpZi8xLjAvIgogICAgICAgICAgICB4bWxuczp4bXA9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8iCiAgICAgICAgICAgIHhtbG5zOnRpZmY9Imh0dHA6Ly9ucy5hZG9iZS5jb20vdGlmZi8xLjAvIj4KICAgICAgICAgPGV4aWY6UGl4ZWxZRGltZW5zaW9uPjE0PC9leGlmOlBpeGVsWURpbWVuc2lvbj4KICAgICAgICAgPGV4aWY6UGl4ZWxYRGltZW5zaW9uPjE0PC9leGlmOlBpeGVsWERpbWVuc2lvbj4KICAgICAgICAgPHhtcDpDcmVhdG9yVG9vbD5QaXhlbG1hdG9yIFBybyBEZW1vIDIuMC42PC94bXA6Q3JlYXRvclRvb2w+CiAgICAgICAgIDx4bXA6TWV0YWRhdGFEYXRlPjIwMjQtMDItMTFUMTY6MDk6NThaPC94bXA6TWV0YWRhdGFEYXRlPgogICAgICAgICA8dGlmZjpYUmVzb2x1dGlvbj43MjAwMDAvMTAwMDA8L3RpZmY6WFJlc29sdXRpb24+CiAgICAgICAgIDx0aWZmOlJlc29sdXRpb25Vbml0PjI8L3RpZmY6UmVzb2x1dGlvblVuaXQ+CiAgICAgICAgIDx0aWZmOllSZXNvbHV0aW9uPjcyMDAwMC8xMDAwMDwvdGlmZjpZUmVzb2x1dGlvbj4KICAgICAgICAgPHRpZmY6T3JpZW50YXRpb24+MTwvdGlmZjpPcmllbnRhdGlvbj4KICAgICAgPC9yZGY6RGVzY3JpcHRpb24+CiAgIDwvcmRmOlJERj4KPC94OnhtcG1ldGE+CpdATFoAAADSSURBVCgVxVAxEgFBENxVZHxAooiQE3jAlYBQxgXKHzzHN7zAFygXSXzgSE6wutVObVPy66q+6Z7dneob52pBCCEHDU+ItZmo2TPkDNmISZeS+Aw9Fj+CvohfUHt+MGqO0qEG7uAL7NEAN7AFdmmA0nt/5KOpZYh1j1pI7wrNnmLCqNlnTvoUkP1k3QCaPUXmMUZj8vAEzvTWn17JqJVk4PY24k1yyw8zqBWj8scN3OjQjNTfzeobuQaJqSvyu5tcM8mk8GALt2MHuo31H9JpXeoNjHW8AvqRh98AAAAASUVORK5CYII=
""")

GRID_ICON = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAYAAAAfSC3RAAAABGdBTUEAALGPC/xhBQAAACBjSFJNAAB6JgAAgIQAAPoAAACA6AAAdTAAAOpgAAA6mAAAF3CculE8AAAAlmVYSWZNTQAqAAAACAAFARIAAwAAAAEAAQAAARoABQAAAAEAAABKARsABQAAAAEAAABSATEAAgAAABEAAABah2kABAAAAAEAAABsAAAAAAAAAEgAAAABAAAASAAAAAF3d3cuaW5rc2NhcGUub3JnAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAADqADAAQAAAABAAAADgAAAACSN6n1AAAACXBIWXMAAAsTAAALEwEAmpwYAAADBGlUWHRYTUw6Y29tLmFkb2JlLnhtcAAAAAAAPHg6eG1wbWV0YSB4bWxuczp4PSJhZG9iZTpuczptZXRhLyIgeDp4bXB0az0iWE1QIENvcmUgNi4wLjAiPgogICA8cmRmOlJERiB4bWxuczpyZGY9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkvMDIvMjItcmRmLXN5bnRheC1ucyMiPgogICAgICA8cmRmOkRlc2NyaXB0aW9uIHJkZjphYm91dD0iIgogICAgICAgICAgICB4bWxuczp4bXA9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8iCiAgICAgICAgICAgIHhtbG5zOmV4aWY9Imh0dHA6Ly9ucy5hZG9iZS5jb20vZXhpZi8xLjAvIgogICAgICAgICAgICB4bWxuczp0aWZmPSJodHRwOi8vbnMuYWRvYmUuY29tL3RpZmYvMS4wLyI+CiAgICAgICAgIDx4bXA6Q3JlYXRvclRvb2w+d3d3Lmlua3NjYXBlLm9yZzwveG1wOkNyZWF0b3JUb29sPgogICAgICAgICA8ZXhpZjpQaXhlbFhEaW1lbnNpb24+MTY8L2V4aWY6UGl4ZWxYRGltZW5zaW9uPgogICAgICAgICA8ZXhpZjpDb2xvclNwYWNlPjE8L2V4aWY6Q29sb3JTcGFjZT4KICAgICAgICAgPGV4aWY6UGl4ZWxZRGltZW5zaW9uPjE2PC9leGlmOlBpeGVsWURpbWVuc2lvbj4KICAgICAgICAgPHRpZmY6WFJlc29sdXRpb24+NzI8L3RpZmY6WFJlc29sdXRpb24+CiAgICAgICAgIDx0aWZmOllSZXNvbHV0aW9uPjcyPC90aWZmOllSZXNvbHV0aW9uPgogICAgICAgICA8dGlmZjpPcmllbnRhdGlvbj4xPC90aWZmOk9yaWVudGF0aW9uPgogICAgICA8L3JkZjpEZXNjcmlwdGlvbj4KICAgPC9yZGY6UkRGPgo8L3g6eG1wbWV0YT4K455w4AAAATtJREFUKBVlkU1LAlEUhuemUEotw4VESJEV/pE+iFyVG/9PFEH9CrftQ/0NEoglROt2faEUTs97O2ea8oVn3jPna4Z7kzRNQ4LwGuxavCCXyMUY34GNn6w9SazBHYyhagMF4oLFVeIHeIRaHCMoQxdc57YvMwpnXsRvoaxfaVlyis9gAoc+RbxvOdXUI53q/9vWVMSnsAh1y8m2QTnV1CO19cWPuOP3MSTcgz70QF8cQV7vgbcDNqzADEowgC3ogHQCY2jABPSXrzAvlunALuECluY7kiTeoRdoKoYQvvAjcqug+jO5G695b+YU/KIrxPfg0v1V1IjHnmzIkvHEKF7ZhK5FSNf5nmyQgg8dE/tdfRILSd7MD///tE5LJyhpmd/biPhFSdefw1GSzcvYOmzqHWnREwf0Ft/s8Q36b0u+QFvvZAAAAABJRU5ErkJggg==
""")

# the main function
def main(config):

    # read the configuration
    influxdb_host = config.str("influxdb", INFLUXDB_HOST_DEFAULT)
    api_key = config.str("api_key", "UNDEFINED")
    bucket = config.get("bucket", DEFAULT_BUCKET)

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

    if api_key == "UNDEFINED":
        chargingSeries = [
            (0, 0.0),
            (1, 0.0),
            (2, 0.0),
            (3, 0.0),
            (4, 0.0),
            (5, 0.0),
            (6, 0.0),
            (7, 0.0),
            (8, 0.0),
            (9, 0.0),
            (10, 0.0),
            (11, 0.0),
            (12, 0.0),
            (13, 0.0),
            (14, 0.0),
            (15, 0.0),
            (16, 0.0),
            (17, 0.0),
            (18, 0.0),
            (19, 0.0),
            (20, 0.0),
            (21, 0.0),
            (22, 0.0),
            (23, 0.0),
            (24, 0.0),
            (25, 0.0),
            (26, 0.0),
            (27, 0.0),
            (28, 0.0),
            (29, 0.0),
            (30, 0.0),
            (31, 0.0),
            (32, 0.0),
            (33, 0.0),
            (34, 0.0),
            (35, 0.0),
            (36, 0.0),
            (37, 0.0),
            (38, 0.0),
            (39, 0.0),
            (40, 0.0),
            (41, 0.0),
            (42, 0.0),
            (43, 0.0),
            (44, 0.0),
            (45, 0.0),
            (46, 0.0),
            (47, 0.0),
            (48, 0.0),
        ]

        # TODO generate a realistic power consumptionSeries series
        consumptionSeries = [
            (0, 0.0),
            (1, 0.0),
            (2, 0.0),
            (3, 0.0),
            (4, 0.0),
            (5, 0.0),
            (6, 0.0),
            (7, 0.0),
            (8, 0.0),
            (9, 0.0),
            (10, 0.0),
            (11, 0.0),
            (12, 0.0),
            (13, 0.0),
            (14, 0.0),
            (15, 0.0),
            (16, 0.0),
            (17, 0.0),
            (18, 0.0),
            (19, 0.0),
            (20, 0.0),
            (21, 0.0),
            (22, 0.0),
            (23, 0.0),
            (24, 0.0),
            (25, 0.0),
            (26, 0.0),
            (27, 0.0),
            (28, 0.0),
            (29, 0.0),
            (30, 0.0),
            (31, 0.0),
            (32, 0.0),
            (33, 0.0),
            (34, 0.0),
            (35, 0.0),
            (36, 0.0),
            (37, 0.0),
            (38, 0.0),
            (39, 0.0),
            (40, 0.0),
            (41, 0.0),
            (42, 0.0),
            (43, 0.0),
            (44, 0.0),
            (45, 0.0),
            (46, 0.0),
            (47, 0.0),
            (48, 0.0),
        ]
        chargePowerLast = 3600
        gridPowerLast = 685
        gridPowerMax = 1000
        homePowerLast = 0
        phasesActive = 0
        pvPowerLast = 2964
        pvPowerMax = 6000
        vehicleSocLast = 80

    else:
        chargePowerLast = getLastValue(influxdb_host, "chargePower", flux_defaults, api_key)
        chargingSeries = getchargePoweSeries(influxdb_host, flux_defaults, api_key)
        consumptionSeries = getgridPowerSeries(influxdb_host, flux_defaults, api_key)
        gridPowerLast = getLastValue(influxdb_host, "gridPower", flux_defaults, api_key)
        gridPowerMax = getMaxValue(influxdb_host, "gridPower", flux_defaults, api_key)
        homePowerLast = getLastValue(influxdb_host, "homePower", flux_defaults, api_key)
        phasesActive = getLastValue(influxdb_host, "phasesActive", flux_defaults, api_key)
        pvPowerLast = getLastValue(influxdb_host, "pvPower", flux_defaults, api_key) 
        pvPowerMax = getMaxValue(influxdb_host, "pvPower", flux_defaults, api_key) 
        # TODO: max can be lower than last, as max is calculated every 15mins, while last is every 1min
        vehicleSocLast = getLastValue(influxdb_host, "vehicleSoc", flux_defaults, api_key)

    # the main display

    # color coding for the columns
    if pvPowerLast > homePowerLast:
        col2_icon = SUN_ICON
        col2_color = GREEN
    else:
        col2_icon = GRID_ICON
        col2_color = RED

    col3_phase1 = DARK_GREEN
    col3_phase2 = DARK_GREEN
    col3_phase3 = DARK_GREEN
    if phasesActive >= 1:
        col3_phase1 = GREEN
    if phasesActive >= 2:
        col3_phase2 = GREEN
    if phasesActive >= 3:
        col3_phase3 = GREEN
    else:  # no charging or error case
        col3_phase1 = RED
        col3_phase2 = RED
        col3_phase3 = RED

    if scale_gridPower > 0:  # use dedicated scale
        render_graph = render.Stack(
            children = [
                render.Plot(data = consumptionSeries, width = 64, height = 32, color = GREEN, color_inverted = RED, fill = True, y_lim = (-1 * scale_gridPower, scale_gridPower)),
            ],
        )
    else:  # use autoscale
        render_graph = render.Column(
            children = [
                render.Plot(data = consumptionSeries, width = 64, height = 15, color = GREEN, color_inverted = RED, fill = True),
                render.Box(width = 64, height = 1, color = BLACK),
                render.Box(width = 64, height = 1, color = GREY),
                render.Plot(data = chargingSeries, width = 64, height = 15, color = YELLOW, fill = True, y_lim = (0, 1000)),
            ],
        )
    
    # the main columns

    column_pvPower = [
        # this is the PV power column
        render.Image(src = PANEL_ICON),
        render.Box(width = 2, height = 2, color = BLACK),  # for better horizontal alignment
        render.Text(str(pvPowerLast), color = WHITE, font = FONT),
        render.Box(width = 1, height = 2, color = BLACK),
        render.Text(str(pvPowerMax), color = YELLOW, font = FONT),
    ]
    column_consumption = [
        # this is the grid power column
        render.Image(src = col2_icon),
        render.Box(width = 2, height = 2, color = BLACK),  # for better horizontal alignment
        render.Text(str(abs(gridPowerLast)), color = col2_color, font = FONT),  # abs() because I don't want to report negative numbers, thats why we have the color coding
        render.Box(width = 1, height = 2, color = BLACK),
        render.Text(str(gridPowerMax), color = YELLOW, font = FONT),
    ]
    column_charging = [
        # this is the car charging column
        render.Image(src = CAR_ICON),
        render.Row(
            children = [
                render.Box(width = 1, height = 1, color = col3_phase1),
                render.Box(width = 1, height = 1, color = col3_phase2),
                render.Box(width = 1, height = 1, color = col3_phase3),
            ],
        ),
        render.Box(width = 2, height = 1, color = BLACK),  # for better horizontal alignment
        render.Text(str(chargePowerLast), color = WHITE, font = FONT),
        render.Box(width = 1, height = 2, color = BLACK),
        render.Text(str(vehicleSocLast) + "%", color = WHITE, font = FONT),
    ]

    columns = render.Row(
        children = [
            render.Column(
                children = column_pvPower,
                main_align = "center",
                cross_align = "center",
            ),
            render.Column(
                children = [render.Box(width = 1, height = 32, color = GREY)],
            ),
            render.Column(
                children = column_consumption,
                main_align = "center",
                cross_align = "center",
            ),
            render.Column(
                children = [render.Box(width = 1, height = 32, color = GREY)],
            ),
            render.Column(
                children = column_charging,
                main_align = "center",
                cross_align = "center",
            ),
        ],
        main_align = "space_evenly",
        expanded = True,
    )

    #print(config.str("variant"))
    if config.str("variant") == "opt_columns":
        return render.Root(render.Column(children = [columns]))
    elif config.str("variant") == "opt_gridPower":
        return render.Root(render_graph)

    elif config.str("variant") == "opt_gridPower":
        return render.Root(render_graph)

    else:
        return render.Root(render.Column(children = [columns]))

# https://github.com/evcc-io/docs/blob/main/docs/reference/configuration/messaging.md?plain=1#L156
# grid power - Current grid feed-in(-) or consumption(+) in watts (__float__)
# inverted the series for more natural display of the data series
# multiply by -1 to make it display logically correct in Plot

def getgridPowerSeries(dbhost, defaults, api_key):
    fluxql = defaults + ' \
        |> range(start: -12h)                                    \
        |> filter(fn: (r) => r._measurement == "gridPower")         \
        |> aggregateWindow(every: 15m, fn: mean)                    \
        |> fill(value: 0.0)                                         \
        |> map(fn: (r) => ({r with _value: (float(v: r._value) * -1.0) })) \
        |> keep(columns: ["_time", "_value"])'

    #print ("query=" + fluxql)
    return getTouples(dbhost, fluxql, api_key, TTL_FOR_SERIES)

def getchargePoweSeries(dbhost, defaults, api_key):
    fluxql = defaults + ' \
        |> range(start: -12h)                                    \
        |> filter(fn: (r) => r._measurement == "chargePower")         \
        |> aggregateWindow(every: 15m, fn: mean)                    \
        |> fill(value: 0.0)                                         \
        |> map(fn: (r) => ({r with _value: (float(v: r._value)) })) \
        |> keep(columns: ["_time", "_value"])'

    #print ("query=" + fluxql)
    return getTouples(dbhost, fluxql, api_key, TTL_FOR_SERIES)

# make it today() instead -12
def getMaxValue(dbhost, measurement, defaults, api_key):
    fluxql = defaults + ' \
        |> range(start: -12h) \
        |> filter(fn: (r) => r._measurement == "' + measurement + '") \
        |> group() \
        |> max() \
        |> toInt() \
        |> keep(columns: ["_value"])'

    data = csv.read_all(readInfluxDB(dbhost, fluxql, api_key, TTL_FOR_MAX))
    value = data[1][3] if len(data) > 0 else "0"
    print("%s (max) = %s" % (measurement, value))
    return int(value)

def getLastValue(dbhost, measurement, defaults, api_key):
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

    # check if the request was successful
    if rep.status_code != 200:
        fail("InfluxDB API request failed with status {}".format(rep.status_code))
        return None # TODO: proper error handling
    cache.set(key, base64.encode(rep.body()), ttl_seconds = ttl)

    return rep.body()

def getTouples(dbhost, query, api_key, ttl):
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
                icon = "cloud",
                default = options_influxdb[0].value,
                options = options_influxdb,
            ),
            schema.Text(
                id = "api_key",
                name = "InfluxDB API key",
                desc = "API key for InfluxDB Cloud, if not set the app is in DEMO MODE",
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
                icon = "display",
                default = options_variant[0].value,
                options = options_variant,
            ),
            schema.Text(
                id = "scale_gridPower",
                name = "gridPower scale",
                desc = "the maximum expected value for gridPower, required for nice graphing. Set to 0 for autoscaling.",
                icon = "up-right-and-down-left-from-center",
                default = str(DEFAULT_GRIDPOWERSCALE),
            ),
        ],
    )
