#!/bin/bash
if [ $# -lt 1 ]; then
    echo "Usage: $0 <puuid> [env_file_path]"
    exit 1
fi

PUUID=$1
ENV_FILE=${2:-"../.env"}  # Default to ../.env if not specified

# Load environment variables
if [ -f "$ENV_FILE" ]; then
    export $(grep -v '^#' "$ENV_FILE" | xargs)
else
    echo "Error: .env file not found at $ENV_FILE!"
    exit 1
fi

# Rate limit wait time
WAIT_TIME=1

# Function to make API request
make_request() {
    local url=$1
    response=$(curl -s "$url")
    echo "$response"
    sleep $WAIT_TIME
}

if [ -z "$1" ]; then
    echo "Usage: $0 <puuid>"
    exit 1
fi

# Get last 20 games from Riot API
MATCH_IDS=$(make_request "https://europe.api.riotgames.com/lol/match/v5/matches/by-puuid/${PUUID}/ids?queue=440&start=0&count=20&api_key=${API_KEY}")

# Convert JSON array to Bash array
MATCH_IDS=($(echo "$MATCH_IDS" | jq -r '.[]'))

# Check which games are missing in the database
MISSING_GAMES=()
for GAME_ID in "${MATCH_IDS[@]}"; do
    EXISTS=$(mysql -u$DB_USER -p$DB_PASS -h$DB_HOST $DB_NAME -se "SELECT COUNT(*) FROM games WHERE game_id='$GAME_ID';")
    if [ "$EXISTS" -eq 0 ]; then
        MISSING_GAMES+=("$GAME_ID")
    fi
done

# Print missing game IDs as JSON array
echo $(jq -n --argjson ids "$(printf '%s\n' "${MISSING_GAMES[@]}" | jq -R . | jq -s .)" '{missing_games: $ids}')
