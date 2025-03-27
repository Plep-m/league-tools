#!/bin/bash

if [ -f ../.env ]; then
    export $(grep -v '^#' ../.env | xargs)
else
    echo ".env file not found!"
    exit 1
fi

echo "Using API Key: ${API_KEY}"
echo "DB User: ${DB_USER}"

# Rate limit constants
MAX_REQUESTS_PER_SECOND=20
MAX_REQUESTS_PER_2_MINUTES=100
WAIT_TIME=1
WAIT_TIME_2MIN=120

# Get player PUUIDs from the database
PUIDS=("HLGeoCys0MnTW-Y_7YKHLy9zSjriQ7zV6KdU3GeHT_n2B7ic5aFlqidRojkglKZLZEtIp653hPPmqg")

# Function to handle rate limiting and send requests
make_request() {
    local url=$1
    local sleep_duration=$2
    response=$(curl -s "$url")
    echo "$response"
    sleep $sleep_duration
}

# Function to update progress bar
show_progress() {
    local current=$1
    local total=$2
    local percent=$(( (current * 100) / total ))
    local filled=$(( (percent * 50) / 100 ))
    local empty=$(( 50 - filled ))
    printf "\rProgress: [%-${filled}s%${empty}s] %d%%" "#" "-" $percent
}

# Function to escape strings for SQL
mysql_escape() {
    echo "$1" | sed -e "s/'/''/g" -e 's/\\/\\\\/g'
}

# Main processing loop
total_puuid_count=${#PUIDS[@]}
counter=0

for puuid in "${PUIDS[@]}"; do
    counter=$((counter + 1))
    
    # Get match IDs
    match_ids=$(make_request "https://europe.api.riotgames.com/lol/match/v5/matches/by-puuid/${puuid}/ids?queue=440&start=0&count=100&api_key=${API_KEY}" $WAIT_TIME)
    
    if [ -z "$match_ids" ] || [ "$match_ids" = "null" ]; then
        echo "No matches found for PUUID: $puuid"
        continue
    fi

    # Process each match
    match_count=0
    for match_id in $(echo "$match_ids" | jq -r '.[]'); do
        match_count=$((match_count + 1))
        
        # Fetch match data
        match_data=$(make_request "https://europe.api.riotgames.com/lol/match/v5/matches/${match_id}?api_key=${API_KEY}" $WAIT_TIME)
        
        # Extract metadata and info
        metadata=$(echo "$match_data" | jq '.metadata')
        info=$(echo "$match_data" | jq '.info')

        # --------------------------------------------------
        # Insert basic game info
        # --------------------------------------------------
        game_id=$(echo "$metadata" | jq -r '.matchId')
        game_creation=$(echo "$info" | jq -r '.gameCreation')
        game_date=$(date -d "@$((game_creation/1000))" "+%Y-%m-%d %H:%M:%S")
        duration=$(echo "$info" | jq -r '.gameDuration')
        queue_id=$(echo "$info" | jq -r '.queueId')
        game_version=$(echo "$info" | jq -r '.gameVersion')
        game_mode=$(echo "$info" | jq -r '.gameMode')
        game_type=$(echo "$info" | jq -r '.gameType')
        
        # Determine result (simplified - would need proper team analysis)
        result=$(echo "$info" | jq -r '.teams[0].win')
        if [ "$result" = "true" ]; then
            result="win"
        else
            result="lose"
        fi

        mysql -h $DB_HOST -u $DB_USER -p$DB_PASS -D $DB_NAME -e \
        "INSERT INTO games (game_id, game_date, result, duration, queue_id, game_version, game_mode, game_type)
        VALUES ('$game_id', '$game_date', '$result', $duration, $queue_id, '$(mysql_escape "$game_version")', '$(mysql_escape "$game_mode")', '$(mysql_escape "$game_type")')
        ON DUPLICATE KEY UPDATE game_date=VALUES(game_date), result=VALUES(result), duration=VALUES(duration);"

        # --------------------------------------------------
        # Process teams
        # --------------------------------------------------
        echo "$info" | jq -c '.teams[]' | while read -r team; do
            team_id_api=$(echo "$team" | jq -r '.teamId')
            win=$(echo "$team" | jq -r '.win | if . == true then 1 else 0 end')
            bans=$(echo "$team" | jq -c '[.bans[].championId]')
            first_baron=$(echo "$team" | jq -r '.objectives.baron.first | if . == true then 1 else 0 end')
            first_dragon=$(echo "$team" | jq -r '.objectives.dragon.first | if . == true then 1 else 0 end')
            dragon_kills=$(echo "$team" | jq -r '.objectives.dragon.kills')
            baron_kills=$(echo "$team" | jq -r '.objectives.baron.kills')

            mysql -h $DB_HOST -u $DB_USER -p$DB_PASS -D $DB_NAME -e \
            "INSERT INTO match_teams (game_id, team_id_api, win, bans, first_baron, first_dragon, dragon_kills, baron_kills)
            VALUES ('$game_id', '$team_id_api', $win, '$(mysql_escape "$bans")', $first_baron, $first_dragon, $dragon_kills, $baron_kills)
            ON DUPLICATE KEY UPDATE win=VALUES(win), bans=VALUES(bans), first_baron=VALUES(first_baron), first_dragon=VALUES(first_dragon), dragon_kills=VALUES(dragon_kills), baron_kills=VALUES(baron_kills);"

            # Get inserted team ID
            team_id=$(mysql -h $DB_HOST -u $DB_USER -p$DB_PASS -D $DB_NAME -sN -e \
            "SELECT team_id FROM match_teams WHERE game_id = '$game_id' AND team_id_api = '$team_id_api';")

            if [ -z "$team_id" ]; then
                echo "Error: Could not find team_id for game_id=$game_id and team_id_api=$team_id_api"
                continue
            fi

            # Insert objectives
            for objective_type in dragon baron herald tower; do
                count=$(echo "$team" | jq -r ".objectives.${objective_type}.kills")
                if [ "$count" != "null" ]; then
                    mysql -h $DB_HOST -u $DB_USER -p$DB_PASS -D $DB_NAME -e \
                    "INSERT INTO objectives (game_id, team_id, objective_type, count)
                    VALUES ('$game_id', $team_id, '$objective_type', $count)
                    ON DUPLICATE KEY UPDATE count=VALUES(count);"
                fi
            done
        done

        # --------------------------------------------------
        # Process participants
        # --------------------------------------------------
        echo "$info" | jq -c '.participants[]' | while read -r participant; do
            # Player info
            puuid_val=$(echo "$participant" | jq -r '.puuid')
            summoner_name=$(echo "$participant" | jq -r '.summonerName')
            summoner_name_escaped=$(mysql_escape "$summoner_name")
            summoner_id=$(echo "$participant" | jq -r '.summonerId')
            profile_icon=$(echo "$participant" | jq -r '.profileIcon')
            summoner_level=$(echo "$participant" | jq -r '.summonerLevel')
            riot_id_game=$(echo "$participant" | jq -r '.riotIdGameName')
            riot_id_tag=$(echo "$participant" | jq -r '.riotIdTagline')

            # Insert/update player
            mysql -h $DB_HOST -u $DB_USER -p$DB_PASS -D $DB_NAME -e \
            "INSERT INTO players (puuid, name, summonerId, profileIcon, summonerLevel, riotIdGameName, riotIdTagline)
            VALUES ('$puuid_val', '$summoner_name_escaped', '$summoner_id', $profile_icon, $summoner_level, 
                    '$(mysql_escape "$riot_id_game")', '$(mysql_escape "$riot_id_tag")')
            ON DUPLICATE KEY UPDATE
                name = VALUES(name),
                summonerLevel = VALUES(summonerLevel),
                profileIcon = VALUES(profileIcon);"

            # Participant data
            champion_id=$(echo "$participant" | jq -r '.championId')
            champion_name=$(echo "$participant" | jq -r '.championName')
            champion_name_escaped=$(mysql_escape "$champion_name")
            team_id_api=$(echo "$participant" | jq -r '.teamId')
            
            # Get team ID
            team_id=$(mysql -h $DB_HOST -u $DB_USER -p$DB_PASS -D $DB_NAME -sN -e \
            "SELECT team_id FROM match_teams WHERE game_id = '$game_id' AND team_id_api = '$team_id_api';")

            if [ -z "$team_id" ]; then
                echo "Error: Could not find team_id for game_id=$game_id and team_id_api=$team_id_api"
                continue
            fi

            # Insert champion
            mysql -h $DB_HOST -u $DB_USER -p$DB_PASS -D $DB_NAME -e \
            "INSERT INTO champions (name, championId)
            VALUES ('$champion_name_escaped', $champion_id)
            ON DUPLICATE KEY UPDATE name = VALUES(name);"

            # Get champion DB ID
            champion_db_id=$(mysql -h $DB_HOST -u $DB_USER -p$DB_PASS -D $DB_NAME -sN -e \
            "SELECT id FROM champions WHERE championId = $champion_id;")

            # Get player DB ID
            player_db_id=$(mysql -h $DB_HOST -u $DB_USER -p$DB_PASS -D $DB_NAME -sN -e \
            "SELECT id FROM players WHERE puuid = '$puuid_val';")

            # Insert participant
            role=$(echo "$participant" | jq -r '.role')
            individual_position=$(echo "$participant" | jq -r '.individualPosition')
            lane=$(echo "$participant" | jq -r '.lane')
            
            mysql -h $DB_HOST -u $DB_USER -p$DB_PASS -D $DB_NAME -e \
            "INSERT INTO participants (
                game_id, player_id, champion_id, team_id, puuid,
                kills, deaths, assists, champ_level, gold_earned,
                total_damage, damage_taken, creep_score, vision_score,
                summoner1_id, summoner2_id, role, individual_position, lane
            )
            VALUES (
                '$game_id',
                $player_db_id,
                $champion_db_id,
                $team_id,
                '$puuid_val',
                $(echo "$participant" | jq -r '.kills'),
                $(echo "$participant" | jq -r '.deaths'),
                $(echo "$participant" | jq -r '.assists'),
                $(echo "$participant" | jq -r '.champLevel'),
                $(echo "$participant" | jq -r '.goldEarned'),
                $(echo "$participant" | jq -r '.totalDamageDealtToChampions'),
                $(echo "$participant" | jq -r '.totalDamageTaken'),
                $(echo "$participant" | jq -r '.totalMinionsKilled + .neutralMinionsKilled'),
                $(echo "$participant" | jq -r '.visionScore'),
                $(echo "$participant" | jq -r '.summoner1Id'),
                $(echo "$participant" | jq -r '.summoner2Id'),
                '$(mysql_escape "$role")',
                '$(mysql_escape "$individual_position")',
                '$(mysql_escape "$lane")'
            )
            ON DUPLICATE KEY UPDATE
                kills = VALUES(kills),
                deaths = VALUES(deaths),
                assists = VALUES(assists);"

            # Get participant ID
            participant_id=$(mysql -h $DB_HOST -u $DB_USER -p$DB_PASS -D $DB_NAME -sN -e \
            "SELECT participant_id FROM participants WHERE game_id = '$game_id' AND puuid = '$puuid_val';")

            if [ -z "$participant_id" ]; then
                echo "Error: Could not find participant_id for game_id=$game_id and puuid=$puuid_val"
                continue
            fi

            # Insert items
            for slot in {0..6}; do
                item_id=$(echo "$participant" | jq -r ".item$slot")
                if [ "$item_id" -ne 0 ] && [ "$item_id" != "null" ]; then
                    mysql -h $DB_HOST -u $DB_USER -p$DB_PASS -D $DB_NAME -e \
                    "INSERT INTO participant_items (participant_id, slot_number, item_id)
                    VALUES ($participant_id, $slot, $item_id)
                    ON DUPLICATE KEY UPDATE item_id = VALUES(item_id);"
                fi
            done

            # Insert challenges
            challenges=$(echo "$participant" | jq '.challenges')
            if [ "$challenges" != "null" ]; then
                # Extract all challenge values with default fallbacks
                kda=$(echo "$challenges" | jq -r '.kda // 0')
                kill_participation=$(echo "$challenges" | jq -r '.killParticipation // 0')
                total_heal=$(echo "$challenges" | jq -r '.totalHeal // 0')
                vision_per_minute=$(echo "$challenges" | jq -r '.visionScorePerMinute // 0')
                gold_per_minute=$(echo "$challenges" | jq -r '.goldPerMinute // 0')
                damage_per_minute=$(echo "$challenges" | jq -r '.damagePerMinute // 0')
                turret_takedowns=$(echo "$challenges" | jq -r '.turretTakedowns // 0')
                ability_uses=$(echo "$challenges" | jq -r '.abilityUses // 0')
                aces_before_15_minutes=$(echo "$challenges" | jq -r '.acesBefore15Minutes // 0')
                allied_jungle_monster_kills=$(echo "$challenges" | jq -r '.alliedJungleMonsterKills // 0')
                baron_takedowns=$(echo "$challenges" | jq -r '.baronTakedowns // 0')
                blast_cone_opposite_opponent=$(echo "$challenges" | jq -r '.blastConeOppositeOpponentCount // 0')
                bounty_gold=$(echo "$challenges" | jq -r '.bountyGold // 0')
                buffs_stolen=$(echo "$challenges" | jq -r '.buffsStolen // 0')
                complete_support_quest_in_time=$(echo "$challenges" | jq -r '.completeSupportQuestInTime // 0')
                control_wards_placed=$(echo "$challenges" | jq -r '.controlWardsPlaced // 0')
                damage_taken_on_team_percent=$(echo "$challenges" | jq -r '.damageTakenOnTeamPercentage // 0')
                danced_with_rift_herald=$(echo "$challenges" | jq -r '.dancedWithRiftHerald // 0')
                deaths_by_enemy_champs=$(echo "$challenges" | jq -r '.deathsByEnemyChamps // 0')
                double_aces=$(echo "$challenges" | jq -r '.doubleAces // 0')
                dragon_takedowns=$(echo "$challenges" | jq -r '.dragonTakedowns // 0')
                earliest_baron=$(echo "$challenges" | jq -r '.earliestBaron // 0')
                early_laning_phase_gold_adv=$(echo "$challenges" | jq -r '.earlyLaningPhaseGoldExpAdvantage // 0')
                effective_heal_and_shielding=$(echo "$challenges" | jq -r '.effectiveHealAndShielding // 0')
                elder_dragon_multikills=$(echo "$challenges" | jq -r '.elderDragonMultikills // 0')
                enemy_champion_immobilizations=$(echo "$challenges" | jq -r '.enemyChampionImmobilizations // 0')
                enemy_jungle_monster_kills=$(echo "$challenges" | jq -r '.enemyJungleMonsterKills // 0')
                epic_monster_steals=$(echo "$challenges" | jq -r '.epicMonsterSteals // 0')
                first_turret_killed=$(echo "$challenges" | jq -r '.firstTurretKilled // 0')
                first_turret_killed_time=$(echo "$challenges" | jq -r '.firstTurretKilledTime // 0')
                flawless_aces=$(echo "$challenges" | jq -r '.flawlessAces // 0')
                full_team_takedown=$(echo "$challenges" | jq -r '.fullTeamTakedown // 0')
                game_length=$(echo "$challenges" | jq -r '.gameLength // 0')
                get_takedowns_in_all_lanes=$(echo "$challenges" | jq -r '.getTakedownsInAllLanesEarlyJungleAsLaner // 0')
                highest_champion_damage=$(echo "$challenges" | jq -r '.highestChampionDamage // 0')
                immobilize_and_kill_with_ally=$(echo "$challenges" | jq -r '.immobilizeAndKillWithAlly // 0')
                initial_crab_count=$(echo "$challenges" | jq -r '.initialCrabCount // 0')
                jungle_cs_before_10_min=$(echo "$challenges" | jq -r '.jungleCsBefore10Minutes // 0')
                jungler_takedowns_near_epic=$(echo "$challenges" | jq -r '.junglerTakedownsNearDamagedEpicMonster // 0')
                kturrets_destroyed_before_plates=$(echo "$challenges" | jq -r '.kTurretsDestroyedBeforePlatesFall // 0')
                land_skill_shots_early_game=$(echo "$challenges" | jq -r '.landSkillShotsEarlyGame // 0')
                lane_minions_first10=$(echo "$challenges" | jq -r '.laneMinionsFirst10Minutes // 0')
                legendary_count=$(echo "$challenges" | jq -r '.legendaryCount // 0')
                lost_an_inhibitor=$(echo "$challenges" | jq -r '.lostAnInhibitor // 0')
                max_cs_advantage_lane_opponent=$(echo "$challenges" | jq -r '.maxCsAdvantageOnLaneOpponent // 0')
                max_level_lead_lane_opponent=$(echo "$challenges" | jq -r '.maxLevelLeadLaneOpponent // 0')
                more_enemy_jungle_than_opponent=$(echo "$challenges" | jq -r '.moreEnemyJungleThanOpponent // 0')
                multi_kill_one_spell=$(echo "$challenges" | jq -r '.multiKillOneSpell // 0')
                multikills=$(echo "$challenges" | jq -r '.multikills // 0')
                multikills_after_aggro_flash=$(echo "$challenges" | jq -r '.multikillsAfterAggressiveFlash // 0')
                outer_turret_executes_before10=$(echo "$challenges" | jq -r '.outerTurretExecutesBefore10Minutes // 0')
                outnumbered_kills=$(echo "$challenges" | jq -r '.outnumberedKills // 0')
                perfect_dragon_souls=$(echo "$challenges" | jq -r '.perfectDragonSoulsTaken // 0')
                pick_kill_with_ally=$(echo "$challenges" | jq -r '.pickKillWithAlly // 0')
                played_champ_select_position=$(echo "$challenges" | jq -r '.playedChampSelectPosition // 0')
                poro_explosions=$(echo "$challenges" | jq -r '.poroExplosions // 0')
                quick_cleanse=$(echo "$challenges" | jq -r '.quickCleanse // 0')
                quick_solo_kills=$(echo "$challenges" | jq -r '.quickSoloKills // 0')
                rift_herald_takedowns=$(echo "$challenges" | jq -r '.riftHeraldTakedowns // 0')
                save_ally_from_death=$(echo "$challenges" | jq -r '.saveAllyFromDeath // 0')
                scuttle_crab_kills=$(echo "$challenges" | jq -r '.scuttleCrabKills // 0')
                skillshots_dodged=$(echo "$challenges" | jq -r '.skillshotsDodged // 0')
                skillshots_hit=$(echo "$challenges" | jq -r '.skillshotsHit // 0')
                snowballs_hit=$(echo "$challenges" | jq -r '.snowballsHit // 0')
                solo_baron_kills=$(echo "$challenges" | jq -r '.soloBaronKills // 0')
                solo_kills=$(echo "$challenges" | jq -r '.soloKills // 0')
                stealth_wards_placed=$(echo "$challenges" | jq -r '.stealthWardsPlaced // 0')
                survived_three_immobilizes=$(echo "$challenges" | jq -r '.survivedThreeImmobilizesInFight // 0')
                takedowns_first_x_minutes=$(echo "$challenges" | jq -r '.takedownsFirstXMinutes // 0')
                takedowns_in_alcove=$(echo "$challenges" | jq -r '.takedownsInAlcove // 0')
                team_baron_kills=$(echo "$challenges" | jq -r '.teamBaronKills // 0')
                team_damage_percent=$(echo "$challenges" | jq -r '.teamDamagePercentage // 0')
                three_immobilizes_one_fight=$(echo "$challenges" | jq -r '.threeImmobilizesOneFight // 0')
                took_large_damage_survived=$(echo "$challenges" | jq -r '.tookLargeDamageSurvived // 0')
                turret_plates_taken=$(echo "$challenges" | jq -r '.turretPlatesTaken // 0')
                turrets_taken_with_herald=$(echo "$challenges" | jq -r '.turretsTakenWithRiftHerald // 0')
                twenty_minions_3_sec=$(echo "$challenges" | jq -r '.twentyMinionsIn3SecondsCount // 0')
                unseen_recalls=$(echo "$challenges" | jq -r '.unseenRecalls // 0')
                vision_score_advantage_lane=$(echo "$challenges" | jq -r '.visionScoreAdvantageLaneOpponent // 0')
                void_monster_kill=$(echo "$challenges" | jq -r '.voidMonsterKill // 0')
                ward_takedowns=$(echo "$challenges" | jq -r '.wardTakedowns // 0')
                ward_takedowns_before20=$(echo "$challenges" | jq -r '.wardTakedownsBefore20M // 0')
                wards_guarded=$(echo "$challenges" | jq -r '.wardsGuarded // 0')

                mysql -h $DB_HOST -u $DB_USER -p$DB_PASS -D $DB_NAME -e \
                "INSERT INTO participant_challenges (
                    participant_id, kda, kill_participation, total_heal,
                    vision_per_minute, gold_per_minute, damage_per_minute, turret_takedowns,
                    ability_uses, aces_before_15_minutes, allied_jungle_monster_kills,
                    baron_takedowns, blast_cone_opposite_opponent, bounty_gold, buffs_stolen,
                    complete_support_quest_in_time, control_wards_placed, damage_taken_on_team_percent,
                    danced_with_rift_herald, deaths_by_enemy_champs, double_aces, dragon_takedowns,
                    earliest_baron, early_laning_phase_gold_adv, effective_heal_and_shielding,
                    elder_dragon_multikills, enemy_champion_immobilizations, enemy_jungle_monster_kills,
                    epic_monster_steals, first_turret_killed, first_turret_killed_time, flawless_aces,
                    full_team_takedown, game_length, get_takedowns_in_all_lanes, highest_champion_damage,
                    immobilize_and_kill_with_ally, initial_crab_count, jungle_cs_before_10_min,
                    jungler_takedowns_near_epic, kturrets_destroyed_before_plates, land_skill_shots_early_game,
                    lane_minions_first10, legendary_count, lost_an_inhibitor, max_cs_advantage_lane_opponent,
                    max_level_lead_lane_opponent, more_enemy_jungle_than_opponent, multi_kill_one_spell,
                    multikills, multikills_after_aggro_flash, outer_turret_executes_before10, outnumbered_kills,
                    perfect_dragon_souls, pick_kill_with_ally, played_champ_select_position, poro_explosions,
                    quick_cleanse, quick_solo_kills, rift_herald_takedowns, save_ally_from_death,
                    scuttle_crab_kills, skillshots_dodged, skillshots_hit, snowballs_hit, solo_baron_kills,
                    solo_kills, stealth_wards_placed, survived_three_immobilizes, takedowns_first_x_minutes,
                    takedowns_in_alcove, team_baron_kills, team_damage_percent, three_immobilizes_one_fight,
                    took_large_damage_survived, turret_plates_taken, turrets_taken_with_herald,
                    twenty_minions_3_sec, unseen_recalls, vision_score_advantage_lane, void_monster_kill,
                    ward_takedowns, ward_takedowns_before20, wards_guarded
                )
                VALUES (
                    $participant_id,
                    $kda,
                    $kill_participation,
                    $total_heal,
                    $vision_per_minute,
                    $gold_per_minute,
                    $damage_per_minute,
                    $turret_takedowns,
                    $ability_uses,
                    $aces_before_15_minutes,
                    $allied_jungle_monster_kills,
                    $baron_takedowns,
                    $blast_cone_opposite_opponent,
                    $bounty_gold,
                    $buffs_stolen,
                    $complete_support_quest_in_time,
                    $control_wards_placed,
                    $damage_taken_on_team_percent,
                    $danced_with_rift_herald,
                    $deaths_by_enemy_champs,
                    $double_aces,
                    $dragon_takedowns,
                    $earliest_baron,
                    $early_laning_phase_gold_adv,
                    $effective_heal_and_shielding,
                    $elder_dragon_multikills,
                    $enemy_champion_immobilizations,
                    $enemy_jungle_monster_kills,
                    $epic_monster_steals,
                    $first_turret_killed,
                    $first_turret_killed_time,
                    $flawless_aces,
                    $full_team_takedown,
                    $game_length,
                    $get_takedowns_in_all_lanes,
                    $highest_champion_damage,
                    $immobilize_and_kill_with_ally,
                    $initial_crab_count,
                    $jungle_cs_before_10_min,
                    $jungler_takedowns_near_epic,
                    $kturrets_destroyed_before_plates,
                    $land_skill_shots_early_game,
                    $lane_minions_first10,
                    $legendary_count,
                    $lost_an_inhibitor,
                    $max_cs_advantage_lane_opponent,
                    $max_level_lead_lane_opponent,
                    $more_enemy_jungle_than_opponent,
                    $multi_kill_one_spell,
                    $multikills,
                    $multikills_after_aggro_flash,
                    $outer_turret_executes_before10,
                    $outnumbered_kills,
                    $perfect_dragon_souls,
                    $pick_kill_with_ally,
                    $played_champ_select_position,
                    $poro_explosions,
                    $quick_cleanse,
                    $quick_solo_kills,
                    $rift_herald_takedowns,
                    $save_ally_from_death,
                    $scuttle_crab_kills,
                    $skillshots_dodged,
                    $skillshots_hit,
                    $snowballs_hit,
                    $solo_baron_kills,
                    $solo_kills,
                    $stealth_wards_placed,
                    $survived_three_immobilizes,
                    $takedowns_first_x_minutes,
                    $takedowns_in_alcove,
                    $team_baron_kills,
                    $team_damage_percent,
                    $three_immobilizes_one_fight,
                    $took_large_damage_survived,
                    $turret_plates_taken,
                    $turrets_taken_with_herald,
                    $twenty_minions_3_sec,
                    $unseen_recalls,
                    $vision_score_advantage_lane,
                    $void_monster_kill,
                    $ward_takedowns,
                    $ward_takedowns_before20,
                    $wards_guarded
                )
                ON DUPLICATE KEY UPDATE
                    kda = VALUES(kda),
                    kill_participation = VALUES(kill_participation),
                    total_heal = VALUES(total_heal),
                    vision_per_minute = VALUES(vision_per_minute),
                    gold_per_minute = VALUES(gold_per_minute),
                    damage_per_minute = VALUES(damage_per_minute),
                    turret_takedowns = VALUES(turret_takedowns),
                    ability_uses = VALUES(ability_uses),
                    aces_before_15_minutes = VALUES(aces_before_15_minutes),
                    allied_jungle_monster_kills = VALUES(allied_jungle_monster_kills),
                    baron_takedowns = VALUES(baron_takedowns),
                    blast_cone_opposite_opponent = VALUES(blast_cone_opposite_opponent),
                    bounty_gold = VALUES(bounty_gold),
                    buffs_stolen = VALUES(buffs_stolen),
                    complete_support_quest_in_time = VALUES(complete_support_quest_in_time),
                    control_wards_placed = VALUES(control_wards_placed),
                    damage_taken_on_team_percent = VALUES(damage_taken_on_team_percent),
                    danced_with_rift_herald = VALUES(danced_with_rift_herald),
                    deaths_by_enemy_champs = VALUES(deaths_by_enemy_champs),
                    double_aces = VALUES(double_aces),
                    dragon_takedowns = VALUES(dragon_takedowns),
                    earliest_baron = VALUES(earliest_baron),
                    early_laning_phase_gold_adv = VALUES(early_laning_phase_gold_adv),
                    effective_heal_and_shielding = VALUES(effective_heal_and_shielding),
                    elder_dragon_multikills = VALUES(elder_dragon_multikills),
                    enemy_champion_immobilizations = VALUES(enemy_champion_immobilizations),
                    enemy_jungle_monster_kills = VALUES(enemy_jungle_monster_kills),
                    epic_monster_steals = VALUES(epic_monster_steals),
                    first_turret_killed = VALUES(first_turret_killed),
                    first_turret_killed_time = VALUES(first_turret_killed_time),
                    flawless_aces = VALUES(flawless_aces),
                    full_team_takedown = VALUES(full_team_takedown),
                    game_length = VALUES(game_length),
                    get_takedowns_in_all_lanes = VALUES(get_takedowns_in_all_lanes),
                    highest_champion_damage = VALUES(highest_champion_damage),
                    immobilize_and_kill_with_ally = VALUES(immobilize_and_kill_with_ally),
                    initial_crab_count = VALUES(initial_crab_count),
                    jungle_cs_before_10_min = VALUES(jungle_cs_before_10_min),
                    jungler_takedowns_near_epic = VALUES(jungler_takedowns_near_epic),
                    kturrets_destroyed_before_plates = VALUES(kturrets_destroyed_before_plates),
                    land_skill_shots_early_game = VALUES(land_skill_shots_early_game),
                    lane_minions_first10 = VALUES(lane_minions_first10),
                    legendary_count = VALUES(legendary_count),
                    lost_an_inhibitor = VALUES(lost_an_inhibitor),
                    max_cs_advantage_lane_opponent = VALUES(max_cs_advantage_lane_opponent),
                    max_level_lead_lane_opponent = VALUES(max_level_lead_lane_opponent),
                    more_enemy_jungle_than_opponent = VALUES(more_enemy_jungle_than_opponent),
                    multi_kill_one_spell = VALUES(multi_kill_one_spell),
                    multikills = VALUES(multikills),
                    multikills_after_aggro_flash = VALUES(multikills_after_aggro_flash),
                    outer_turret_executes_before10 = VALUES(outer_turret_executes_before10),
                    outnumbered_kills = VALUES(outnumbered_kills),
                    perfect_dragon_souls = VALUES(perfect_dragon_souls),
                    pick_kill_with_ally = VALUES(pick_kill_with_ally),
                    played_champ_select_position = VALUES(played_champ_select_position),
                    poro_explosions = VALUES(poro_explosions),
                    quick_cleanse = VALUES(quick_cleanse),
                    quick_solo_kills = VALUES(quick_solo_kills),
                    rift_herald_takedowns = VALUES(rift_herald_takedowns),
                    save_ally_from_death = VALUES(save_ally_from_death),
                    scuttle_crab_kills = VALUES(scuttle_crab_kills),
                    skillshots_dodged = VALUES(skillshots_dodged),
                    skillshots_hit = VALUES(skillshots_hit),
                    snowballs_hit = VALUES(snowballs_hit),
                    solo_baron_kills = VALUES(solo_baron_kills),
                    solo_kills = VALUES(solo_kills),
                    stealth_wards_placed = VALUES(stealth_wards_placed),
                    survived_three_immobilizes = VALUES(survived_three_immobilizes),
                    takedowns_first_x_minutes = VALUES(takedowns_first_x_minutes),
                    takedowns_in_alcove = VALUES(takedowns_in_alcove),
                    team_baron_kills = VALUES(team_baron_kills),
                    team_damage_percent = VALUES(team_damage_percent),
                    three_immobilizes_one_fight = VALUES(three_immobilizes_one_fight),
                    took_large_damage_survived = VALUES(took_large_damage_survived),
                    turret_plates_taken = VALUES(turret_plates_taken),
                    turrets_taken_with_herald = VALUES(turrets_taken_with_herald),
                    twenty_minions_3_sec = VALUES(twenty_minions_3_sec),
                    unseen_recalls = VALUES(unseen_recalls),
                    vision_score_advantage_lane = VALUES(vision_score_advantage_lane),
                    void_monster_kill = VALUES(void_monster_kill),
                    ward_takedowns = VALUES(ward_takedowns),
                    ward_takedowns_before20 = VALUES(ward_takedowns_before20),
                    wards_guarded = VALUES(wards_guarded)
                ;"
            fi

            # Insert perks
            echo "$participant" | jq -c '.perks.styles[]' | while read -r style; do
                style_type=$(echo "$style" | jq -r '.description | sub("primaryStyle"; "primary") | sub("subStyle"; "sub")')
                style_id=$(echo "$style" | jq -r '.style')

                mysql -h $DB_HOST -u $DB_USER -p$DB_PASS -D $DB_NAME -e \
                "INSERT INTO participant_perks_styles (participant_id, style_type, style_id)
                VALUES ($participant_id, '$style_type', $style_id)
                ON DUPLICATE KEY UPDATE style_id = VALUES(style_id);"

                order=0
                echo "$style" | jq -c '.selections[]' | while read -r selection; do
                    perk_id=$(echo "$selection" | jq -r '.perk')
                    var1=$(echo "$selection" | jq -r '.var1')
                    var2=$(echo "$selection" | jq -r '.var2')
                    var3=$(echo "$selection" | jq -r '.var3')

                    mysql -h $DB_HOST -u $DB_USER -p$DB_PASS -D $DB_NAME -e \
                    "INSERT INTO participant_perks_selections (
                        participant_id, style_type, perk_id, var1, var2, var3, selection_order
                    )
                    VALUES (
                        $participant_id,
                        '$style_type',
                        $perk_id,
                        $var1,
                        $var2,
                        $var3,
                        $order
                    )
                    ON DUPLICATE KEY UPDATE 
                        perk_id = VALUES(perk_id),
                        var1 = VALUES(var1),
                        var2 = VALUES(var2),
                        var3 = VALUES(var3);"
                    order=$((order+1))
                done
            done
        done

        show_progress $match_count 100
    done

    show_progress $counter $total_puuid_count
    echo ""

    # Rate limit handling
    if ((counter % MAX_REQUESTS_PER_2_MINUTES == 0)); then
        sleep $WAIT_TIME_2MIN
    fi
done

echo "Data population completed successfully!"