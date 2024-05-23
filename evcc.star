"""
Applet: evcc.io
Summary: shows evcc solar charging status
Description: Requires a public accessible InfluxDB, currently tested only with InfluxDB Cloud 2.0 free plan. 
Author: cruschke
"""

load("cache.star", "cache")
load("encoding/base64.star", "base64")
load("encoding/csv.star", "csv")
load("encoding/json.star", "json")
load("http.star", "http")
load("math.star", "math")
load("render.star", "render")
load("schema.star", "schema")

DEFAULT_BUCKET = "evcc"
DEFAULT_LOCATION = {
    "lat": 52.52136203907116,
    "lng": 13.413308033057413,
    "locality": "Weltzeituhr Alexanderplatz",
}
DEFAULT_TIMEZONE = "Europe/Berlin"

INFLUXDB_HOST_DEFAULT = "https://eu-central-1-1.aws.cloud2.influxdata.com/api/v2/query"

TTL_FOR_LAST = 60  # the TTL for up2date info
TTL_FOR_MAX = 60  # how often the max values are being refreshed
TTL_FOR_SERIES = 900  # how often the time series for pvPower and homePower are being refreshed

# COLOR DEFINITIONS

BLACK = "#000"
DARK_GREEN = "#062E03"
FIREBRICK = "E1121F"
GREY = "#1A1A1A"
RED = "#F00"
STEELBLUE = "39A2E4"
SUNGLOW = "FFCA3A"
WHITE = "#FFF"
YELLOW = "#FF0"
YELLOWGREEN = "AAE926"

FONT = "tom-thumb"

# ICONS
CAR0_ICON = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAYAAAAfSC3RAAAAeElEQVR4AZ1SAQ6AIAjkiv8/WRKXDRGyvM3pgONOlGgT8AGpCOoEwEEZEpLGUVf5RcrIB22CV0oOuOsFxsqXBs+QtIOSu/dO9tO2cT2fsEq1GwL1puIFeGgrMr2riQ+5PuKQ8IISWkuKYa3zlA2+lrtfAy9UBr7dLwTUVenBTJ9cAAAAAElFTkSuQmCC
""")
CAR1_ICON = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAYAAAAfSC3RAAAAkUlEQVR4AZ1RQQ6AIAyjkw8YY/T/r9N48AdMIIITQZQmBDLWdhSlGoG0wBaZPgZAqoQCydVhl/lFKpFJNULXnBLg7GeIUb4IxJCcgiOH2QM5TVvW3bmDdLJqyLh7l9RA32SZH/8q6re7EHGW8ALjCYbNNa7VyrpeQTKByI86rUNs2Ob98bfj0sv3eegoWAfL/QChZ1j82OfjxgAAAABJRU5ErkJggg==
""")
CAR2_ICON = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAYAAAAfSC3RAAAAkElEQVR4AZ1QQQ6AIAxbkQ94MPHLxo+aePDimcmI6FwgqCUEUta1jOgnYAmOKNQxAEc1VETCI+7wSVQTO/oJ33IywFnPUFHeNLiGJB1EnLNnsZ225uXeQTvFbii4Jxdr4JjuNSw9ZGsu8/M+PXgpDIVoLYQkiOJHtEpxbs7ruDlvX4W0nERV/0vwDRcqJEnnATcWZx2JqhxtAAAAAElFTkSuQmCC
""")
CAR3_ICON = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAYAAAAfSC3RAAAAmElEQVR4AZ1RWw7DMAjDWS6wj0m7/+km7WMnGAxYG1FE1IertpHBsUOILgKZEEXRJwAazTARGQ99+ZRoJm50EX3PKQFLvyBEObLBGFJ7vO5gYVW5znezdXwCb71sGuhnOL2fH08QORMo7wa65uGcmtZhxdFb/Ub/O/+uXF8KKARjIAUvZTSqgRi956qRmUvnc/Qdl028+P8BftRmENnjoX0AAAAASUVORK5CYII=
""")
CAR4_ICON = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAYAAAAfSC3RAAAAjUlEQVR4AZ2QUQ6AIAxDV+ACfph4/9OZ+OEJFEGdmQ0EpYnRDN5aK9Ip8CAmFe5FAE5qqkB5jvTsv6Aa7KRToeVEwn0/PuWM8/BlQVym9UyJBGRYsyvMbdt5/vbOQJK36caCizfwBoqo0E5uXgGdhfsABUCMA8+vcsi1VhJs9MCnhX8UKvBUaLi84tn3ARsQTesvZiGmAAAAAElFTkSuQmCC
""")
CAR5_ICON = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAYAAAAfSC3RAAAAkElEQVR4AZ2R0QmAMAxEc2kX8ENw/+kEP5xAa6tG0tAoNiDKJS93tkSdBSukXI25BIDJKwcqOvKz/4I8mKmzMM7D47RMK7zBPFd64pigGq9RBcjLWRyrTZLEAkov34EVVKKybGy4BAVvMBEF2o1bEEC0eDfQAEg5WP06HOPqHRJ09Gi7jX+0V3FW/HCp4un3AZDJS/xYE5rcAAAAAElFTkSuQmCC
""")
CAR6_ICON = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAYAAAAfSC3RAAAAkklEQVR4AZ2QUQqEMAxEM20vsB8Le//TLfjhCTS2aiQOqYoDRUn6MtOIvBS4oFXBPQWQpKcO1OqoZw6h7/+jcqHaRz0HnOSlyp0TCft9hYvyZIAOvzHZhAZbdoN5277e/nNykLRpNjFwyQ6eQBENmsktG2C1sjcQAOIcuL4th1x7S4KPXrgbvFFogavKjcspnv8uRv5EQG6f/z0AAAAASUVORK5CYII=
""")
CAR7_ICON = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAYAAAAfSC3RAAAAi0lEQVR4AZ2SUQqAMAxD220X8EPw/qcT/PAEOq2uUsPKdAVRsr0mBIk6h1EY5yFX7uVlWgN540Ci8/nsvyAPDtQ5qeUEw+V+ZhPly4KnJNkgsGZXGNu2unzHYCCSbZXa1SUaeGOIqNAOblEB1VI54ApAxgH1uxxw9UpiGz3hae3XggKvSQ2XVzz7PgBNxz5zgJqOmAAAAABJRU5ErkJggg==
""")
ENERGY_ICON = base64.decode("""
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
""")
FLASH_ICON = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAYAAAAfSC3RAAAAnmVYSWZNTQAqAAAACAAGARIAAwAAAAEAAQAAARoABQAAAAEAAABWARsABQAAAAEAAABeASgAAwAAAAEAAgAAATEAAgAAABoAAABmh2kABAAAAAEAAACAAAAAAAAAAEgAAAABAAAASAAAAAFQaXhlbG1hdG9yIFBybyBEZW1vIDIuMC42AAACoAIABAAAAAEAAAAOoAMABAAAAAEAAAAOAAAAAM2nMk0AAAAJcEhZcwAACxMAAAsTAQCanBgAAANsaVRYdFhNTDpjb20uYWRvYmUueG1wAAAAAAA8eDp4bXBtZXRhIHhtbG5zOng9ImFkb2JlOm5zOm1ldGEvIiB4OnhtcHRrPSJYTVAgQ29yZSA2LjAuMCI+CiAgIDxyZGY6UkRGIHhtbG5zOnJkZj0iaHR0cDovL3d3dy53My5vcmcvMTk5OS8wMi8yMi1yZGYtc3ludGF4LW5zIyI+CiAgICAgIDxyZGY6RGVzY3JpcHRpb24gcmRmOmFib3V0PSIiCiAgICAgICAgICAgIHhtbG5zOmV4aWY9Imh0dHA6Ly9ucy5hZG9iZS5jb20vZXhpZi8xLjAvIgogICAgICAgICAgICB4bWxuczp4bXA9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8iCiAgICAgICAgICAgIHhtbG5zOnRpZmY9Imh0dHA6Ly9ucy5hZG9iZS5jb20vdGlmZi8xLjAvIj4KICAgICAgICAgPGV4aWY6UGl4ZWxZRGltZW5zaW9uPjE0PC9leGlmOlBpeGVsWURpbWVuc2lvbj4KICAgICAgICAgPGV4aWY6UGl4ZWxYRGltZW5zaW9uPjE0PC9leGlmOlBpeGVsWERpbWVuc2lvbj4KICAgICAgICAgPHhtcDpDcmVhdG9yVG9vbD5QaXhlbG1hdG9yIFBybyBEZW1vIDIuMC42PC94bXA6Q3JlYXRvclRvb2w+CiAgICAgICAgIDx4bXA6TWV0YWRhdGFEYXRlPjIwMjQtMDItMTFUMTU6MzU6MDJaPC94bXA6TWV0YWRhdGFEYXRlPgogICAgICAgICA8dGlmZjpYUmVzb2x1dGlvbj43MjAwMDAvMTAwMDA8L3RpZmY6WFJlc29sdXRpb24+CiAgICAgICAgIDx0aWZmOlJlc29sdXRpb25Vbml0PjI8L3RpZmY6UmVzb2x1dGlvblVuaXQ+CiAgICAgICAgIDx0aWZmOllSZXNvbHV0aW9uPjcyMDAwMC8xMDAwMDwvdGlmZjpZUmVzb2x1dGlvbj4KICAgICAgICAgPHRpZmY6T3JpZW50YXRpb24+MTwvdGlmZjpPcmllbnRhdGlvbj4KICAgICAgPC9yZGY6RGVzY3JpcHRpb24+CiAgIDwvcmRmOlJERj4KPC94OnhtcG1ldGE+CtlVVGMAAAEUSURBVCgVjZKxSsRAEIbXIEThKlstLCwVW8UH8AW0sbOytbe5xtZesLBRrvAFxDewsLYTuQc4IyHZ7OzM+OeO4U6PTZwEZjPzf/tnlnUuEcx8rxYyXVwnpPNyUzZ7i4yIfMy7HStVvp2ZqAqeGMJ5h3zW8t7vwKEyx8j80Au1AkBPBglsWfmCqDpsVHdRz5ObsEhp4DSLsDDwwJf4zpbAseo6hzhqXTDWr5AYn/8Cq1bY+nJ5HPBbVHrPs7WDFeeO2x7+9XVSFKem68ywe8Gsires63q7U2zNiugIBAH+noSwb/XejBvziBF9jM1Zr9gEcMlwhJ9EdGW1f2WAJz6GOx0Ol489tQOgTSJ/UxTjjZRmsf4DHk73Q3PzaAUAAAAASUVORK5CYII=
""")
SOLARENERGY_ICON = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAYAAAAfSC3RAAAAnmVYSWZNTQAqAAAACAAGARIAAwAAAAEAAQAAARoABQAAAAEAAABWARsABQAAAAEAAABeASgAAwAAAAEAAgAAATEAAgAAABoAAABmh2kABAAAAAEAAACAAAAAAAAAAEgAAAABAAAASAAAAAFQaXhlbG1hdG9yIFBybyBEZW1vIDIuMC42AAACoAIABAAAAAEAAAAOoAMABAAAAAEAAAAOAAAAAM2nMk0AAAAJcEhZcwAACxMAAAsTAQCanBgAAANsaVRYdFhNTDpjb20uYWRvYmUueG1wAAAAAAA8eDp4bXBtZXRhIHhtbG5zOng9ImFkb2JlOm5zOm1ldGEvIiB4OnhtcHRrPSJYTVAgQ29yZSA2LjAuMCI+CiAgIDxyZGY6UkRGIHhtbG5zOnJkZj0iaHR0cDovL3d3dy53My5vcmcvMTk5OS8wMi8yMi1yZGYtc3ludGF4LW5zIyI+CiAgICAgIDxyZGY6RGVzY3JpcHRpb24gcmRmOmFib3V0PSIiCiAgICAgICAgICAgIHhtbG5zOmV4aWY9Imh0dHA6Ly9ucy5hZG9iZS5jb20vZXhpZi8xLjAvIgogICAgICAgICAgICB4bWxuczp4bXA9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8iCiAgICAgICAgICAgIHhtbG5zOnRpZmY9Imh0dHA6Ly9ucy5hZG9iZS5jb20vdGlmZi8xLjAvIj4KICAgICAgICAgPGV4aWY6UGl4ZWxZRGltZW5zaW9uPjE0PC9leGlmOlBpeGVsWURpbWVuc2lvbj4KICAgICAgICAgPGV4aWY6UGl4ZWxYRGltZW5zaW9uPjE0PC9leGlmOlBpeGVsWERpbWVuc2lvbj4KICAgICAgICAgPHhtcDpDcmVhdG9yVG9vbD5QaXhlbG1hdG9yIFBybyBEZW1vIDIuMC42PC94bXA6Q3JlYXRvclRvb2w+CiAgICAgICAgIDx4bXA6TWV0YWRhdGFEYXRlPjIwMjQtMDItMTFUMTY6MDk6NThaPC94bXA6TWV0YWRhdGFEYXRlPgogICAgICAgICA8dGlmZjpYUmVzb2x1dGlvbj43MjAwMDAvMTAwMDA8L3RpZmY6WFJlc29sdXRpb24+CiAgICAgICAgIDx0aWZmOlJlc29sdXRpb25Vbml0PjI8L3RpZmY6UmVzb2x1dGlvblVuaXQ+CiAgICAgICAgIDx0aWZmOllSZXNvbHV0aW9uPjcyMDAwMC8xMDAwMDwvdGlmZjpZUmVzb2x1dGlvbj4KICAgICAgICAgPHRpZmY6T3JpZW50YXRpb24+MTwvdGlmZjpPcmllbnRhdGlvbj4KICAgICAgPC9yZGY6RGVzY3JpcHRpb24+CiAgIDwvcmRmOlJERj4KPC94OnhtcG1ldGE+CpdATFoAAADSSURBVCgVxVAxEgFBENxVZHxAooiQE3jAlYBQxgXKHzzHN7zAFygXSXzgSE6wutVObVPy66q+6Z7dneob52pBCCEHDU+ItZmo2TPkDNmISZeS+Aw9Fj+CvohfUHt+MGqO0qEG7uAL7NEAN7AFdmmA0nt/5KOpZYh1j1pI7wrNnmLCqNlnTvoUkP1k3QCaPUXmMUZj8vAEzvTWn17JqJVk4PY24k1yyw8zqBWj8scN3OjQjNTfzeobuQaJqSvyu5tcM8mk8GALt2MHuo31H9JpXeoNjHW8AvqRh98AAAAASUVORK5CYII=
""")
SUN_ICON = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAA0AAAANCAYAAABy6+R8AAAASElEQVR4Aa1SQQoAIAgb0gf7/7GHGB08xdqKBBGc21AESOToybDAQ4SjfMQLWLXSEdwGrgms36SSELSd5IBNsK+nHKzdv7/RBFeDVlFpPWcXAAAAAElFTkSuQmCC
""")

####

PANEL_ICON = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAYAAAAfSC3RAAAAnmVYSWZNTQAqAAAACAAGARIAAwAAAAEAAQAAARoABQAAAAEAAABWARsABQAAAAEAAABeASgAAwAAAAEAAgAAATEAAgAAABoAAABmh2kABAAAAAEAAACAAAAAAAAAAEgAAAABAAAASAAAAAFQaXhlbG1hdG9yIFBybyBEZW1vIDIuMC42AAACoAIABAAAAAEAAAAOoAMABAAAAAEAAAAOAAAAAM2nMk0AAAAJcEhZcwAACxMAAAsTAQCanBgAAANsaVRYdFhNTDpjb20uYWRvYmUueG1wAAAAAAA8eDp4bXBtZXRhIHhtbG5zOng9ImFkb2JlOm5zOm1ldGEvIiB4OnhtcHRrPSJYTVAgQ29yZSA2LjAuMCI+CiAgIDxyZGY6UkRGIHhtbG5zOnJkZj0iaHR0cDovL3d3dy53My5vcmcvMTk5OS8wMi8yMi1yZGYtc3ludGF4LW5zIyI+CiAgICAgIDxyZGY6RGVzY3JpcHRpb24gcmRmOmFib3V0PSIiCiAgICAgICAgICAgIHhtbG5zOmV4aWY9Imh0dHA6Ly9ucy5hZG9iZS5jb20vZXhpZi8xLjAvIgogICAgICAgICAgICB4bWxuczp4bXA9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8iCiAgICAgICAgICAgIHhtbG5zOnRpZmY9Imh0dHA6Ly9ucy5hZG9iZS5jb20vdGlmZi8xLjAvIj4KICAgICAgICAgPGV4aWY6UGl4ZWxZRGltZW5zaW9uPjE0PC9leGlmOlBpeGVsWURpbWVuc2lvbj4KICAgICAgICAgPGV4aWY6UGl4ZWxYRGltZW5zaW9uPjE0PC9leGlmOlBpeGVsWERpbWVuc2lvbj4KICAgICAgICAgPHhtcDpDcmVhdG9yVG9vbD5QaXhlbG1hdG9yIFBybyBEZW1vIDIuMC42PC94bXA6Q3JlYXRvclRvb2w+CiAgICAgICAgIDx4bXA6TWV0YWRhdGFEYXRlPjIwMjQtMDItMTFUMTY6MDk6NThaPC94bXA6TWV0YWRhdGFEYXRlPgogICAgICAgICA8dGlmZjpYUmVzb2x1dGlvbj43MjAwMDAvMTAwMDA8L3RpZmY6WFJlc29sdXRpb24+CiAgICAgICAgIDx0aWZmOlJlc29sdXRpb25Vbml0PjI8L3RpZmY6UmVzb2x1dGlvblVuaXQ+CiAgICAgICAgIDx0aWZmOllSZXNvbHV0aW9uPjcyMDAwMC8xMDAwMDwvdGlmZjpZUmVzb2x1dGlvbj4KICAgICAgICAgPHRpZmY6T3JpZW50YXRpb24+MTwvdGlmZjpPcmllbnRhdGlvbj4KICAgICAgPC9yZGY6RGVzY3JpcHRpb24+CiAgIDwvcmRmOlJERj4KPC94OnhtcG1ldGE+CpdATFoAAADSSURBVCgVxVAxEgFBENxVZHxAooiQE3jAlYBQxgXKHzzHN7zAFygXSXzgSE6wutVObVPy66q+6Z7dneob52pBCCEHDU+ItZmo2TPkDNmISZeS+Aw9Fj+CvohfUHt+MGqO0qEG7uAL7NEAN7AFdmmA0nt/5KOpZYh1j1pI7wrNnmLCqNlnTvoUkP1k3QCaPUXmMUZj8vAEzvTWn17JqJVk4PY24k1yyw8zqBWj8scN3OjQjNTfzeobuQaJqSvyu5tcM8mk8GALt2MHuo31H9JpXeoNjHW8AvqRh98AAAAASUVORK5CYII=
""")

GRID_ICON = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAYAAAAfSC3RAAAABGdBTUEAALGPC/xhBQAAACBjSFJNAAB6JgAAgIQAAPoAAACA6AAAdTAAAOpgAAA6mAAAF3CculE8AAAAlmVYSWZNTQAqAAAACAAFARIAAwAAAAEAAQAAARoABQAAAAEAAABKARsABQAAAAEAAABSATEAAgAAABEAAABah2kABAAAAAEAAABsAAAAAAAAAEgAAAABAAAASAAAAAF3d3cuaW5rc2NhcGUub3JnAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAADqADAAQAAAABAAAADgAAAACSN6n1AAAACXBIWXMAAAsTAAALEwEAmpwYAAADBGlUWHRYTUw6Y29tLmFkb2JlLnhtcAAAAAAAPHg6eG1wbWV0YSB4bWxuczp4PSJhZG9iZTpuczptZXRhLyIgeDp4bXB0az0iWE1QIENvcmUgNi4wLjAiPgogICA8cmRmOlJERiB4bWxuczpyZGY9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkvMDIvMjItcmRmLXN5bnRheC1ucyMiPgogICAgICA8cmRmOkRlc2NyaXB0aW9uIHJkZjphYm91dD0iIgogICAgICAgICAgICB4bWxuczp4bXA9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8iCiAgICAgICAgICAgIHhtbG5zOmV4aWY9Imh0dHA6Ly9ucy5hZG9iZS5jb20vZXhpZi8xLjAvIgogICAgICAgICAgICB4bWxuczp0aWZmPSJodHRwOi8vbnMuYWRvYmUuY29tL3RpZmYvMS4wLyI+CiAgICAgICAgIDx4bXA6Q3JlYXRvclRvb2w+d3d3Lmlua3NjYXBlLm9yZzwveG1wOkNyZWF0b3JUb29sPgogICAgICAgICA8ZXhpZjpQaXhlbFhEaW1lbnNpb24+MTY8L2V4aWY6UGl4ZWxYRGltZW5zaW9uPgogICAgICAgICA8ZXhpZjpDb2xvclNwYWNlPjE8L2V4aWY6Q29sb3JTcGFjZT4KICAgICAgICAgPGV4aWY6UGl4ZWxZRGltZW5zaW9uPjE2PC9leGlmOlBpeGVsWURpbWVuc2lvbj4KICAgICAgICAgPHRpZmY6WFJlc29sdXRpb24+NzI8L3RpZmY6WFJlc29sdXRpb24+CiAgICAgICAgIDx0aWZmOllSZXNvbHV0aW9uPjcyPC90aWZmOllSZXNvbHV0aW9uPgogICAgICAgICA8dGlmZjpPcmllbnRhdGlvbj4xPC90aWZmOk9yaWVudGF0aW9uPgogICAgICA8L3JkZjpEZXNjcmlwdGlvbj4KICAgPC9yZGY6UkRGPgo8L3g6eG1wbWV0YT4K455w4AAAATtJREFUKBVlkU1LAlEUhuemUEotw4VESJEV/pE+iFyVG/9PFEH9CrftQ/0NEoglROt2faEUTs97O2ea8oVn3jPna4Z7kzRNQ4LwGuxavCCXyMUY34GNn6w9SazBHYyhagMF4oLFVeIHeIRaHCMoQxdc57YvMwpnXsRvoaxfaVlyis9gAoc+RbxvOdXUI53q/9vWVMSnsAh1y8m2QTnV1CO19cWPuOP3MSTcgz70QF8cQV7vgbcDNqzADEowgC3ogHQCY2jABPSXrzAvlunALuECluY7kiTeoRdoKoYQvvAjcqug+jO5G695b+YU/KIrxPfg0v1V1IjHnmzIkvHEKF7ZhK5FSNf5nmyQgg8dE/tdfRILSd7MD///tE5LJyhpmd/biPhFSdefw1GSzcvYOmzqHWnREwf0Ft/s8Q36b0u+QFvvZAAAAABJRU5ErkJggg==
""")

CAR_ICON = [CAR0_ICON, CAR1_ICON, CAR2_ICON, CAR3_ICON, CAR4_ICON, CAR5_ICON, CAR6_ICON, CAR7_ICON]

# the main function
def main(config):
    # read the configuration
    influxdb_host = config.str("influxdb", INFLUXDB_HOST_DEFAULT)
    api_key = config.str("api_key", "UNDEFINED")
    vehicle = config.str("vehicle", "mycar")
    bucket = config.get("bucket", DEFAULT_BUCKET)

    location = config.get("location")
    loc = json.decode(location) if location else DEFAULT_LOCATION
    timezone = loc.get("timezone", DEFAULT_TIMEZONE)

    # some FluxQL query parameters that every single query needs
    flux_defaults = '                                                     \
        import "timezone"                                               \
        option location = timezone.location(name: "' + timezone + '")   \
        from(bucket:"' + bucket + '")'

    if api_key == "UNDEFINED":
        gridPowerSeries = [(0, 382.5), (1, 437.3), (2, 142.13333333333333), (3, 907.15), (4, 758.7142857142857), (5, 632.3333333333334), (6, -0.0), (7, 745.3333333333334), (8, 674.7692307692307), (9, 781.7333333333333), (10, 985.5333333333333), (11, 547.2666666666667), (12, 967.9666666666667), (13, 1043.1333333333334), (14, 604.5333333333333), (15, 2709.409090909091), (16, 2267.9666666666667), (17, 1763.4), (18, -142.76666666666668), (19, 179.60714285714286), (20, 546.2962962962963), (21, 387.6666666666667), (22, 287.6896551724138), (23, 409.2413793103448), (24, 166.86666666666667), (25, 297.6333333333333), (26, -571.5666666666667), (27, 180.46666666666667), (28, 387.76666666666665), (29, 1046.4666666666667), (30, 1674.4333333333334), (31, 2046.5333333333333), (32, 844.3666666666667), (33, 1942.5), (34, 765.7666666666667), (35, 551.4333333333333), (36, 710.4666666666667), (37, 384.3333333333333), (38, -36.166666666666664), (39, 213.86666666666667), (40, -1974.8666666666666), (41, -1451.0333333333333), (42, -1165.8666666666666), (43, -614.5), (44, -20.566666666666666), (45, -223.6), (46, -211.66666666666666), (47, -308.8333333333333), (48, -300.7857142857143)]
        chargePowerSeries = [(0, 0.0), (1, 0.0), (2, 0.0), (3, 0.0), (4, 0.0), (5, 0.0), (6, 0.0), (7, 0.0), (8, 0.0), (9, 0.0), (10, 0.0), (11, 0.0), (12, 0.0), (13, 0.0), (14, 0.0), (15, 0.0), (16, 0.0), (17, 0.0), (18, 0.0), (19, 0.0), (20, 812.1333328386148), (21, 1973.1000224749248), (22, 3367.1851599657975), (23, 3514.0999952952066), (24, 3320.827603340149), (25, 3503.333361943563), (26, 2691.6333754857383), (27, 2979.0666898091636), (28, 2185.4999780654907), (29, 2787.9666646321616), (30, 1790.7666504383087), (31, 0.0), (32, 0.0), (33, 0.0), (34, 0.0), (35, 0.0), (36, 0.0), (37, 0.0), (38, 0.0), (39, 0.0), (40, 0.0), (41, 0.0), (42, 0.0), (43, 0.0), (44, 0.0), (45, 0.0), (46, 0.0), (47, 0.0), (48, 0.0)]

        chargePowerLast = 2474
        chargePowerMax = 3584
        gridPowerLast = 348
        gridPowerMax = 12766
        homePowerLast = 0
        phasesActive = 1
        pvPowerLast = 465
        pvPowerMax = 4448
        vehicleSocLast = 77

    else:
        # individual queries for the values
        chargePowerLast = getLastValue("chargePower", influxdb_host, flux_defaults, api_key)
        chargePowerMax = getMaxValue("chargePower", influxdb_host, flux_defaults, api_key)
        gridPowerLast = getLastValue("gridPower", influxdb_host, flux_defaults, api_key)
        gridPowerMax = getMaxValue("gridPower", influxdb_host, flux_defaults, api_key)
        homePowerLast = getLastValue("homePower", influxdb_host, flux_defaults, api_key)
        phasesActive = getLastValue("phasesActive", influxdb_host, flux_defaults, api_key)
        pvPowerLast = getLastValue("pvPower", influxdb_host, flux_defaults, api_key)
        pvPowerMax = getMaxValue("pvPower", influxdb_host, flux_defaults, api_key)
        vehicleSocLast = getLastValueCar("vehicleSoc", vehicle, influxdb_host, flux_defaults, api_key)
        vehicleRangeLast = getLastValueCar("vehicleRange", vehicle, influxdb_host, flux_defaults, api_key)  # buildifier: disable=unused-variable

        # the time series for the plots
        chargePowerSeries = getSeries("chargePower", influxdb_host, flux_defaults, api_key)
        gridPowerSeries = getgridPowerSeries(influxdb_host, flux_defaults, api_key)

    # the main display

    # color coding for the columns
    if pvPowerLast > homePowerLast:
        col2_icon = SUN_ICON
        col2_color = YELLOWGREEN
    else:
        col2_icon = GRID_ICON
        col2_color = FIREBRICK

    col3_phase1 = DARK_GREEN
    col3_phase2 = DARK_GREEN
    col3_phase3 = DARK_GREEN
    if phasesActive >= 1:
        col3_phase1 = YELLOWGREEN
    if phasesActive >= 2:
        col3_phase2 = YELLOWGREEN
    if phasesActive >= 3:
        col3_phase3 = YELLOWGREEN

    if vehicleSocLast == 0:
        str_vehicleSocLast = "-"
        car_icon_index = 0
    else:
        str_vehicleSocLast = str(vehicleSocLast) + "%"
        # setting the car icon accorind to the charging state, we have 8 different icons
        # based on the vehicleSocLast value

    car_icon_index = int(math.round(vehicleSocLast / 12.5)) - 1  # 8 icons, 100/8=12.5, off by one
    CAR_ICON_DYNAMIC = CAR_ICON[car_icon_index]

    ############################################################
    # the screen1 main columns
    ############################################################
    screen_1_1 = [
        # this is the PV power column
        render.Image(src = PANEL_ICON),
        render.Box(width = 2, height = 2, color = BLACK),  # for better horizontal alignment
        render.Text(humanize(pvPowerLast), color = YELLOWGREEN),
        render.Box(width = 1, height = 2, color = BLACK),
        #render.Text(str(pvPowerMax), color = YELLOW, font = FONT),
    ]
    screen_1_2 = [
        # this is the grid power column
        render.Image(src = col2_icon),
        render.Box(width = 2, height = 2, color = BLACK),  # for better horizontal alignment
        render.Text(humanize(abs(gridPowerLast)), color = col2_color),  # abs() because I don't want to report negative numbers, thats why we have the color coding
        render.Box(width = 1, height = 2, color = BLACK),
        #render.Text(str(gridPowerMax), color = YELLOW, font = FONT),
    ]

    screen_1_3 = [
        # this is the car charging column
        render.Image(src = CAR_ICON_DYNAMIC),
        render.Row(
            children = [
                render.Box(width = 1, height = 1, color = col3_phase1),
                render.Box(width = 1, height = 1, color = col3_phase2),
                render.Box(width = 1, height = 1, color = col3_phase3),
            ],
        ),
        render.Box(width = 2, height = 1, color = BLACK),  # for better horizontal alignment
        render.Text(humanize(vehicleRangeLast), color = WHITE, font = FONT),
        render.Box(width = 1, height = 2, color = BLACK),
        render.Text(str_vehicleSocLast, color = YELLOWGREEN, font = FONT),
    ]

    screen_1 = render.Row(
        children = [
            render.Column(
                children = screen_1_1,
                main_align = "center",
                cross_align = "center",
            ),
            render.Column(
                children = [render.Box(width = 1, height = 32, color = GREY)],
            ),
            render.Column(
                children = screen_1_2,
                main_align = "center",
                cross_align = "center",
            ),
            render.Column(
                children = [render.Box(width = 1, height = 32, color = GREY)],
            ),
            render.Column(
                children = screen_1_3,
                main_align = "center",
                cross_align = "center",
            ),
        ],
        main_align = "space_evenly",
        expanded = True,
    )

    ############################################################
    # the screen2 main columns
    ############################################################

    # pvPowerMax + gridPowerMax
    screen_2_1_1 = [
        render.Text(humanize(pvPowerMax), color = YELLOWGREEN, font = FONT),
        render.Box(width = 5, height = 1),  # some extra space
        render.Text(humanize(gridPowerMax), color = FIREBRICK, font = FONT),
    ]

    # chargePowerMax
    screen_2_1_2 = [
        render.Text(humanize(chargePowerMax), color = STEELBLUE, font = FONT),
    ]

    # gridPowerSeries
    screen_2_2_1 = [
        render.Box(
            child = render.Plot(
                data = gridPowerSeries,
                width = 47,
                height = 16,
                color = YELLOWGREEN,
                color_inverted = FIREBRICK,
            ),
            width = 45,
            height = 16,
        ),
    ]

    # chargePowerSeries
    screen_2_2_2 = [
        render.Box(
            child = render.Plot(
                data = chargePowerSeries,
                width = 47,
                height = 15,
                color = STEELBLUE,
            ),
            width = 45,
            height = 15,
        ),
    ]

    screen2_columns_1 = render.Row(
        children = [
            render.Box(
                child = render.Column(
                    # pvPowerMax + gridPowerMax
                    children = screen_2_1_1,
                    main_align = "center",
                    cross_align = "center",
                ),
                width = 15,
                height = 15,
            ),
            render.Column(
                children = [render.Box(width = 1, height = 16, color = GREY)],
            ),
            render.Column(
                # pvPowerSeries
                children = screen_2_2_1,
                main_align = "center",
                cross_align = "center",
            ),
        ],
        main_align = "space_evenly",
        expanded = True,
    )

    screen2_columns_2 = render.Row(
        children = [
            render.Box(
                child = render.Column(
                    # chargePowerMax
                    children = screen_2_1_2,
                    main_align = "center",
                    cross_align = "center",
                ),
                width = 15,
                height = 15,
            ),
            render.Column(
                children = [render.Box(width = 1, height = 32, color = GREY)],
            ),
            render.Column(
                # chargePowerSeries
                children = screen_2_2_2,
                main_align = "center",
                cross_align = "center",
            ),
        ],
        main_align = "space_evenly",
        expanded = True,
    )

    screen_2 = render.Column(
        children = [
            screen2_columns_1,
            render.Column(
                children = [render.Box(width = 64, height = 1, color = GREY)],
            ),
            screen2_columns_2,
        ],
    )

    return render.Root(
        delay = 7 * 1000,
        show_full_animation = True,
        child = render.Column(
            children = [
                render.Animation(
                    children = [screen_1, screen_2],
                ),
            ],
        ),
    )

# https://github.com/evcc-io/docs/blob/main/docs/reference/configuration/messaging.md?plain=1#L156
# grid power - Current grid feed-in(-) or consumption(+) in watts (__float__)
# inverted the series for more natural display of the data series
# multiply by -1 to make it display logically correct in Plot

def getSeries(measurement, dbhost, defaults, api_key):
    fluxql = defaults + ' \
        |> range(start: -12h)                                    \
        |> filter(fn: (r) => r._measurement == "' + measurement + '") \
        |> group() \
        |> aggregateWindow(every: 15m, fn: mean)                    \
        |> fill(value: 0.0)                                         \
        |> map(fn: (r) => ({r with _value: (float(v: r._value)) })) \
        |> keep(columns: ["_time", "_value"])'

    #print ("query=" + fluxql)
    return getTouples(dbhost, fluxql, api_key, TTL_FOR_SERIES)

# this one is special as I need inverted numbers (multiply by -1)
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

def getMaxValue(measurement, dbhost, defaults, api_key):
    fluxql = defaults + ' \
        |> range(start: today()) \
        |> filter(fn: (r) => r._measurement == "' + measurement + '") \
        |> group() \
        |> max() \
        |> toInt() \
        |> keep(columns: ["_value"])'

    data = csv.read_all(readInfluxDB(dbhost, fluxql, api_key, TTL_FOR_MAX))
    value = data[1][3] if len(data) > 0 else "0"
    print("%sMax = %s" % (measurement, value))
    return int(value)

def getLastValue(measurement, dbhost, defaults, api_key):
    fluxql = defaults + ' \
        |> range(start: -1m) \
        |> filter(fn: (r) => r._measurement == "' + measurement + '") \
        |> group() \
        |> last() \
        |> toInt() \
        |> keep(columns: ["_value"])'

    data = csv.read_all(readInfluxDB(dbhost, fluxql, api_key, TTL_FOR_LAST))
    value = data[1][3] if len(data) > 0 else "0"
    print("%sLast = %s" % (measurement, value))
    return int(value)

# TODO revert back to 1min
# TODO make vehicle a parameter
# TODO make loadpoint a parameter
def getLastValueCar(measurement, vehicle, dbhost, defaults, api_key):
    fluxql = defaults + ' \
        |> range(start: -12h) \
        |> filter(fn: (r) => r._measurement == "' + measurement + '"  and r.vehicle == "' + vehicle + '" and r._value > 0) \
        |> last() \
        |> toInt() \
        |> keep(columns: ["_value"])'

    data = csv.read_all(readInfluxDB(dbhost, fluxql, api_key, TTL_FOR_LAST))
    value = data[1][3] if len(data) > 0 else "0"
    print("%sLast = %s" % (measurement, value))
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

def custom_round(number):
    integer_part = number // 1000
    remainder = number % 1000
    if remainder == 0:
        return str(integer_part) + "k"
    else:
        # Manually round to nearest thousand
        if remainder >= 500:
            integer_part += 1
        return str(integer_part) + "k"

def humanize(number):
    #print("number=" + str(number))
    if number < 10000:
        return str(number)
    else:
        rounded_number = custom_round(number)

        #print("rounded_number=" + str(rounded_number))
        return str(rounded_number)

options_screen = [
    schema.Option(
        display = "3 columns",
        value = "screen_1",
    ),
    schema.Option(
        display = "gridPower and chargePower graphs (last 12 hours)",
        value = "screen_2",
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
            schema.Text(
                id = "vehicle",
                name = "vehicle name",
                desc = "The vehicle you want to display",
                icon = "car",
                default = "mycar",
            ),
            schema.Location(
                id = "location",
                name = "Location",
                desc = "Your device location",
                icon = "locationDot",
            ),
        ],
    )
