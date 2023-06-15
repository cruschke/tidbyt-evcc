INFLUXDB_HOST="https://eu-central-1-1.aws.cloud2.influxdata.com//api/v2/query"

INFLUX_TOKEN="TVcTz0Q0KWFcJF8v3i1F0UY-4Jqp_ou5ThMBoHEt4Yw0zPXHl8IeX1LGP6uwK3eJ89Zeicq4CecPeoMRChXstg=="

curl --request -G ${INFLUXDB_HOST} \
  --header "Authorization: Token ${INFLUX_TOKEN}" \
  --header 'Accept: application/json' \
  --header 'Content-type: application/json' \
  --data-urlencode "q=SELECT value FROM iox.\"homePower\""


