#!/bin/bash
if [ $# -lt 1 ]; then
    echo "Usage: $0 <puuid> [env_file_path] [y/N]"
    exit 1
fi

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

ENV_FILE=${2:-"../.env"}  # Default to ../.env if not specified
SKIP_PROMPT=${3:-""}  # y/N argument to skip user input

# Load environment variables
if [ -f "$ENV_FILE" ]; then
    export $(grep -v '^#' "$ENV_FILE" | xargs)
else
    echo "Error: .env file not found at $ENV_FILE!"
    exit 1
fi

WAIT_TIME=1

make_request() {
    local url=$1
    response=$(curl -s "$url")
    echo "$response"
    sleep $WAIT_TIME
}

PUUID=$1

MATCH_IDS=$(make_request "https://europe.api.riotgames.com/lol/match/v5/matches/by-puuid/${PUUID}/ids?queue=440&start=0&count=100&api_key=${API_KEY}")

MATCH_IDS=($(echo "$MATCH_IDS" | jq -r '.[]'))

MISSING_GAMES=()
for GAME_ID in "${MATCH_IDS[@]}"; do
    EXISTS=$(mysql -u$DB_USER -p$DB_PASS -h$DB_HOST -P$DB_PORT $DB_NAME -se "SELECT COUNT(*) FROM games WHERE game_id='$GAME_ID';")
    if [ "$EXISTS" -eq 0 ]; then
        MISSING_GAMES+=("$GAME_ID")
    fi
done

# Handle automatic yes/no based on argument
if [ "${SKIP_PROMPT,,}" == "y" ]; then
    for game_id in "${MISSING_GAMES[@]}"; do
        echo "Importing $game_id..."
        "$SCRIPT_DIR/import_by_match_id.sh" "$game_id"
    done
    exit 0
elif [ "${SKIP_PROMPT,,}" == "n" ]; then
    echo $(jq -n --argjson ids "$(printf '%s\n' "${MISSING_GAMES[@]}" | jq -R . | jq -s .)" '{missing_games: $ids}')
    exit 0
fi

# Interactive handling if no y/N argument was provided
if [ -t 0 ] && [ ${#MISSING_GAMES[@]} -gt 0 ]; then
    echo "Found ${#MISSING_GAMES[@]} missing games."
    read -p "Would you like to import them now? [Y/n] " answer
    case "$answer" in
        [Yy]*|"")
            for game_id in "${MISSING_GAMES[@]}"; do
                echo "Importing $game_id..."
                "$SCRIPT_DIR/import_by_match_id.sh" "$game_id"
            done
            exit 0
            ;;
        *)
            # Continue to output JSON
            ;;
    esac
else
    echo "No missing games found."
fi

# Output JSON for non-interactive or declined import
echo $(jq -n --argjson ids "$(printf '%s\n' "${MISSING_GAMES[@]}" | jq -R . | jq -s .)" '{missing_games: $ids}')
