#!/bin/bash

if [ -f ../.env ]; then
    export $(grep -v '^#' ../.env | xargs)
else
    echo ".env file not found!"
    exit 1
fi

echo "Using API Key: ${API_KEY}"
echo "DB User: ${DB_USER}"

# Read CSV file
while IFS=";" read -r game_id date wl time side t_player j_player m_player b_player s_player \
                      t_champ j_champ m_champ b_champ s_champ \
                      ot_champ oj_champ om_champ ob_champ os_champ \
                      ban1 ban2 ban3 ban4 ban5 \
                      tt_rank tj_rank tm_rank tb_rank ts_rank \
                      ot_rank oj_rank om_rank ob_rank os_rank \
                      opp_avg_rank team_kills team_deaths team_assists \
                      opp_kills opp_deaths opp_assists \
                      feats t_kills t_deaths t_assist \
                      j_kills j_deaths j_assists \
                      m_kills m_deaths m_assists \
                      b_kills b_death b_assists \
                      s_kills s_deaths s_assists \
                      t_drakes o_drakes t_grubs g15 \
                      t_g15 j_g15 m_g15 b_g15 s_g15 \
                      t_cs15 j_cs15 m_cs15 b_cs15
do
    # Skip header
    if [[ "$game_id" == "game_id" ]]; then
        continue
    fi

    # Convert date format (DD/MM/YYYY -> YYYY-MM-DD)
    date=$(echo "$date" | awk -F"/" '{print $3"-"$2"-"$1}')

    # Trim whitespace from time
    time=$(echo "$time" | sed 's/ *$//')

    # Insert game
    mysql -h 127.0.0.1 -u"$DB_USER" -p"$DB_PASS" -D"$DB_NAME" -e "
    INSERT IGNORE INTO games (game_id, game_date, result, duration, side)
    VALUES ('$game_id', '$date', '$wl', '$time', '$side');
    "

    # Insert players
    for player in "$t_player" "$j_player" "$m_player" "$b_player" "$s_player"; do
        if [[ -n "$player" ]]; then
            mysql -h 127.0.0.1 -u"$DB_USER" -p"$DB_PASS" -D"$DB_NAME" -e "
            INSERT IGNORE INTO players (name) VALUES ('$player');
            "
        fi
    done

    # Insert champions
    for champ in "$t_champ" "$j_champ" "$m_champ" "$b_champ" "$s_champ" "$ot_champ" "$oj_champ" "$om_champ" "$ob_champ" "$os_champ" "$ban1" "$ban2" "$ban3" "$ban4" "$ban5"; do
        if [[ -n "$champ" ]]; then
            mysql -h 127.0.0.1 -u"$DB_USER" -p"$DB_PASS" -D"$DB_NAME" -e "
            INSERT IGNORE INTO champions (name) VALUES ('$champ');
            "
        fi
    done

    # Determine team names
    if [[ "$side" == "blue" ]]; then
        own_team="blue"
        enemy_team="red"
    else
        own_team="red"
        enemy_team="blue"
    fi

    # Insert game_players
    roles=("top" "jungle" "mid" "bot" "support")
    own_players=("$t_player" "$j_player" "$m_player" "$b_player" "$s_player")
    own_champs=("$t_champ" "$j_champ" "$m_champ" "$b_champ" "$s_champ")

    for i in {0..4}; do
        if [[ -n "${own_players[i]}" && -n "${own_champs[i]}" ]]; then
            mysql -h 127.0.0.1 -u"$DB_USER" -p"$DB_PASS" -D"$DB_NAME" -e "
            INSERT IGNORE INTO game_players (game_id, player_id, champion_id, role, team)
            VALUES (
                '$game_id',
                (SELECT id FROM players WHERE name='${own_players[i]}' LIMIT 1),
                (SELECT id FROM champions WHERE name='${own_champs[i]}' LIMIT 1),
                '${roles[i]}',
                '$own_team'
            );
            "
        fi
    done

    # Insert bans
    for ban in "$ban1" "$ban2" "$ban3" "$ban4" "$ban5"; do
        if [[ -n "$ban" ]]; then
            mysql -h 127.0.0.1 -u"$DB_USER" -p"$DB_PASS" -D"$DB_NAME" -e "
            INSERT IGNORE INTO bans (game_id, champion_id, team)
            VALUES ('$game_id', (SELECT id FROM champions WHERE name='$ban' LIMIT 1), '$own_team');
            "
        fi
    done

    # Insert ranks
    own_ranks=("$tt_rank" "$tj_rank" "$tm_rank" "$tb_rank" "$ts_rank")

    for i in {0..4}; do
        if [[ -n "${own_players[i]}" && -n "${own_ranks[i]}" ]]; then
            mysql -h 127.0.0.1 -u"$DB_USER" -p"$DB_PASS" -D"$DB_NAME" -e "
            INSERT IGNORE INTO ranks (game_id, player_id, rank, team)
            VALUES (
                '$game_id',
                (SELECT id FROM players WHERE name='${own_players[i]}' LIMIT 1),
                '${own_ranks[i]}',
                '$own_team'
            );
            "
        fi
    done

    # Insert team stats
    if [[ -n "$team_kills" && -n "$team_deaths" && -n "$team_assists" && -n "$opp_avg_rank" ]]; then
        mysql -h 127.0.0.1 -u"$DB_USER" -p"$DB_PASS" -D"$DB_NAME" -e "
        INSERT IGNORE INTO team_stats (game_id, team, kills, deaths, assists, avg_rank)
        VALUES ('$game_id', '$own_team', '$team_kills', '$team_deaths', '$team_assists', '$opp_avg_rank');
        "
    fi

    # Insert objectives
    if [[ -n "$t_drakes" && -n "$t_grubs" && -n "$g15" ]]; then
        mysql -h 127.0.0.1 -u"$DB_USER" -p"$DB_PASS" -D"$DB_NAME" -e "
        INSERT IGNORE INTO objectives (game_id, team, drakes, grubs, gold_at_15)
        VALUES ('$game_id', '$own_team', '$t_drakes', '$t_grubs', '$g15');
        "
    fi

done < "$CSV_FILE"

echo "Data import complete!"
