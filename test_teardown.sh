app="testpostgres"
if docker ps | awk -v app="$app" 'NR > 1 && $NF == app{ret=1; exit} END{exit !ret}'; then
  docker stop "$app" && docker rm -f "$app"
fi