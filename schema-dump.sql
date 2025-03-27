/*M!999999\- enable the sandbox mode */ 
-- MariaDB dump 10.19-11.4.5-MariaDB, for debian-linux-gnu (x86_64)
--
-- Host: 127.0.0.1    Database: osef_data
-- ------------------------------------------------------
-- Server version	11.7.2-MariaDB-ubu2404

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*M!100616 SET @OLD_NOTE_VERBOSITY=@@NOTE_VERBOSITY, NOTE_VERBOSITY=0 */;

--
-- Table structure for table `champions`
--

DROP TABLE IF EXISTS `champions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `champions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  `championId` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`),
  UNIQUE KEY `championId` (`championId`)
) ENGINE=InnoDB AUTO_INCREMENT=3001 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `games`
--

DROP TABLE IF EXISTS `games`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `games` (
  `game_id` varchar(50) NOT NULL,
  `game_date` datetime NOT NULL,
  `result` enum('win','lose') NOT NULL,
  `duration` int(11) NOT NULL,
  `queue_id` bigint(20) DEFAULT NULL,
  `game_version` varchar(50) DEFAULT NULL,
  `game_mode` varchar(50) DEFAULT NULL,
  `game_type` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`game_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `match_teams`
--

DROP TABLE IF EXISTS `match_teams`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `match_teams` (
  `team_id` int(11) NOT NULL AUTO_INCREMENT,
  `game_id` varchar(50) NOT NULL,
  `team_id_api` varchar(10) NOT NULL,
  `win` tinyint(1) NOT NULL,
  `bans` varchar(255) DEFAULT NULL,
  `first_baron` tinyint(1) DEFAULT NULL,
  `first_dragon` tinyint(1) DEFAULT NULL,
  `dragon_kills` int(11) DEFAULT NULL,
  `baron_kills` int(11) DEFAULT NULL,
  PRIMARY KEY (`team_id`),
  KEY `match_teams_ibfk_1` (`game_id`),
  CONSTRAINT `match_teams_ibfk_1` FOREIGN KEY (`game_id`) REFERENCES `games` (`game_id`)
) ENGINE=InnoDB AUTO_INCREMENT=601 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `objectives`
--

DROP TABLE IF EXISTS `objectives`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `objectives` (
  `game_id` varchar(50) NOT NULL,
  `team_id` int(11) NOT NULL,
  `objective_type` enum('dragon','baron','herald','tower') NOT NULL,
  `count` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`game_id`,`team_id`,`objective_type`),
  CONSTRAINT `objectives_ibfk_1` FOREIGN KEY (`game_id`) REFERENCES `games` (`game_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `participant_challenges`
--

DROP TABLE IF EXISTS `participant_challenges`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `participant_challenges` (
  `participant_id` int(11) NOT NULL,
  `kda` decimal(5,2) DEFAULT NULL,
  `kill_participation` decimal(5,2) DEFAULT NULL,
  `total_heal` int(11) DEFAULT NULL,
  `vision_per_minute` decimal(5,2) DEFAULT NULL,
  `gold_per_minute` decimal(7,2) DEFAULT NULL,
  `damage_per_minute` decimal(7,2) DEFAULT NULL,
  `turret_takedowns` int(11) DEFAULT NULL,
  `ability_uses` int(11) DEFAULT NULL,
  `aces_before_15_minutes` int(11) DEFAULT NULL,
  `allied_jungle_monster_kills` int(11) DEFAULT NULL,
  `baron_takedowns` int(11) DEFAULT NULL,
  `blast_cone_opposite_opponent` int(11) DEFAULT NULL,
  `bounty_gold` int(11) DEFAULT NULL,
  `buffs_stolen` int(11) DEFAULT NULL,
  `complete_support_quest_in_time` int(11) DEFAULT NULL,
  `control_wards_placed` int(11) DEFAULT NULL,
  `damage_self_mitigated` int(11) DEFAULT NULL,
  `damage_taken_on_team_percent` decimal(5,2) DEFAULT NULL,
  `danced_with_rift_herald` int(11) DEFAULT NULL,
  `deaths_by_enemy_champs` int(11) DEFAULT NULL,
  `double_aces` int(11) DEFAULT NULL,
  `dragon_takedowns` int(11) DEFAULT NULL,
  `earliest_baron` decimal(9,2) DEFAULT NULL,
  `early_laning_phase_gold_adv` int(11) DEFAULT NULL,
  `effective_heal_and_shielding` decimal(9,2) DEFAULT NULL,
  `elder_dragon_multikills` int(11) DEFAULT NULL,
  `enemy_champion_immobilizations` int(11) DEFAULT NULL,
  `enemy_jungle_monster_kills` int(11) DEFAULT NULL,
  `epic_monster_steals` int(11) DEFAULT NULL,
  `first_turret_killed` int(11) DEFAULT NULL,
  `first_turret_killed_time` decimal(9,2) DEFAULT NULL,
  `flawless_aces` int(11) DEFAULT NULL,
  `full_team_takedown` int(11) DEFAULT NULL,
  `game_length` decimal(9,2) DEFAULT NULL,
  `get_takedowns_in_all_lanes` int(11) DEFAULT NULL,
  `highest_champion_damage` int(11) DEFAULT NULL,
  `immobilize_and_kill_with_ally` int(11) DEFAULT NULL,
  `initial_crab_count` int(11) DEFAULT NULL,
  `jungle_cs_before_10_min` decimal(7,2) DEFAULT NULL,
  `jungler_takedowns_near_epic` int(11) DEFAULT NULL,
  `kturrets_destroyed_before_plates` int(11) DEFAULT NULL,
  `land_skill_shots_early_game` int(11) DEFAULT NULL,
  `lane_minions_first10` int(11) DEFAULT NULL,
  `legendary_count` int(11) DEFAULT NULL,
  `lost_an_inhibitor` int(11) DEFAULT NULL,
  `max_cs_advantage_lane_opponent` int(11) DEFAULT NULL,
  `max_level_lead_lane_opponent` int(11) DEFAULT NULL,
  `more_enemy_jungle_than_opponent` int(11) DEFAULT NULL,
  `multi_kill_one_spell` int(11) DEFAULT NULL,
  `multikills` int(11) DEFAULT NULL,
  `multikills_after_aggro_flash` int(11) DEFAULT NULL,
  `outer_turret_executes_before10` int(11) DEFAULT NULL,
  `outnumbered_kills` int(11) DEFAULT NULL,
  `perfect_dragon_souls` int(11) DEFAULT NULL,
  `pick_kill_with_ally` int(11) DEFAULT NULL,
  `played_champ_select_position` int(11) DEFAULT NULL,
  `poro_explosions` int(11) DEFAULT NULL,
  `quick_cleanse` int(11) DEFAULT NULL,
  `quick_solo_kills` int(11) DEFAULT NULL,
  `rift_herald_takedowns` int(11) DEFAULT NULL,
  `save_ally_from_death` int(11) DEFAULT NULL,
  `scuttle_crab_kills` int(11) DEFAULT NULL,
  `skillshots_dodged` int(11) DEFAULT NULL,
  `skillshots_hit` int(11) DEFAULT NULL,
  `snowballs_hit` int(11) DEFAULT NULL,
  `solo_baron_kills` int(11) DEFAULT NULL,
  `solo_kills` int(11) DEFAULT NULL,
  `stealth_wards_placed` int(11) DEFAULT NULL,
  `survived_three_immobilizes` int(11) DEFAULT NULL,
  `takedowns_first_x_minutes` int(11) DEFAULT NULL,
  `takedowns_in_alcove` int(11) DEFAULT NULL,
  `team_baron_kills` int(11) DEFAULT NULL,
  `team_damage_percent` decimal(5,2) DEFAULT NULL,
  `three_immobilizes_one_fight` int(11) DEFAULT NULL,
  `took_large_damage_survived` int(11) DEFAULT NULL,
  `turret_plates_taken` int(11) DEFAULT NULL,
  `turrets_taken_with_herald` int(11) DEFAULT NULL,
  `twenty_minions_3_sec` int(11) DEFAULT NULL,
  `unseen_recalls` int(11) DEFAULT NULL,
  `vision_score_advantage_lane` decimal(5,2) DEFAULT NULL,
  `void_monster_kill` int(11) DEFAULT NULL,
  `ward_takedowns` int(11) DEFAULT NULL,
  `ward_takedowns_before20` int(11) DEFAULT NULL,
  `wards_guarded` int(11) DEFAULT NULL,
  PRIMARY KEY (`participant_id`),
  CONSTRAINT `participant_challenges_ibfk_1` FOREIGN KEY (`participant_id`) REFERENCES `participants` (`participant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `participant_items`
--

DROP TABLE IF EXISTS `participant_items`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `participant_items` (
  `participant_id` int(11) NOT NULL,
  `slot_number` int(11) NOT NULL,
  `item_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`participant_id`,`slot_number`),
  CONSTRAINT `participant_items_ibfk_1` FOREIGN KEY (`participant_id`) REFERENCES `participants` (`participant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `participant_perks_selections`
--

DROP TABLE IF EXISTS `participant_perks_selections`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `participant_perks_selections` (
  `participant_id` int(11) NOT NULL,
  `style_type` enum('primary','sub') NOT NULL,
  `perk_id` int(11) DEFAULT NULL,
  `var1` int(11) DEFAULT NULL,
  `var2` int(11) DEFAULT NULL,
  `var3` int(11) DEFAULT NULL,
  `selection_order` int(11) NOT NULL,
  PRIMARY KEY (`participant_id`,`style_type`,`selection_order`),
  CONSTRAINT `participant_perks_selections_ibfk_1` FOREIGN KEY (`participant_id`, `style_type`) REFERENCES `participant_perks_styles` (`participant_id`, `style_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `participant_perks_styles`
--

DROP TABLE IF EXISTS `participant_perks_styles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `participant_perks_styles` (
  `participant_id` int(11) NOT NULL,
  `style_type` enum('primary','sub') NOT NULL,
  `style_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`participant_id`,`style_type`),
  CONSTRAINT `participant_perks_styles_ibfk_1` FOREIGN KEY (`participant_id`) REFERENCES `participants` (`participant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `participants`
--

DROP TABLE IF EXISTS `participants`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `participants` (
  `participant_id` int(11) NOT NULL AUTO_INCREMENT,
  `game_id` varchar(50) NOT NULL,
  `player_id` int(11) DEFAULT NULL,
  `champion_id` int(11) NOT NULL,
  `team_id` int(11) NOT NULL,
  `puuid` varchar(255) NOT NULL,
  `kills` int(11) NOT NULL,
  `deaths` int(11) NOT NULL,
  `assists` int(11) NOT NULL,
  `champ_level` int(11) NOT NULL,
  `gold_earned` int(11) NOT NULL,
  `total_damage` int(11) NOT NULL,
  `damage_taken` int(11) NOT NULL,
  `creep_score` int(11) NOT NULL,
  `vision_score` int(11) NOT NULL,
  `summoner1_id` int(11) DEFAULT NULL,
  `summoner2_id` int(11) DEFAULT NULL,
  `role` varchar(20) NOT NULL,
  `individual_position` varchar(20) NOT NULL,
  `lane` varchar(20) NOT NULL,
  PRIMARY KEY (`participant_id`),
  KEY `champion_id` (`champion_id`),
  KEY `summoner1_id` (`summoner1_id`),
  KEY `summoner2_id` (`summoner2_id`),
  KEY `player_id` (`player_id`),
  KEY `participants_ibfk_1` (`game_id`),
  CONSTRAINT `participants_ibfk_1` FOREIGN KEY (`game_id`) REFERENCES `games` (`game_id`),
  CONSTRAINT `participants_ibfk_2` FOREIGN KEY (`champion_id`) REFERENCES `champions` (`id`),
  CONSTRAINT `participants_ibfk_5` FOREIGN KEY (`player_id`) REFERENCES `players` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3001 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `players`
--

DROP TABLE IF EXISTS `players`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `players` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  `puuid` varchar(255) NOT NULL,
  `summonerId` varchar(255) DEFAULT NULL,
  `profileIcon` int(11) DEFAULT NULL,
  `summonerLevel` int(11) DEFAULT NULL,
  `riotIdGameName` varchar(255) DEFAULT NULL,
  `riotIdTagline` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `puuid` (`puuid`),
  UNIQUE KEY `summonerId` (`summonerId`)
) ENGINE=InnoDB AUTO_INCREMENT=3001 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `summoner_spells`
--

DROP TABLE IF EXISTS `summoner_spells`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `summoner_spells` (
  `id` int(11) NOT NULL,
  `spell_id` int(11) NOT NULL,
  `name` varchar(50) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*M!100616 SET NOTE_VERBOSITY=@OLD_NOTE_VERBOSITY */;

-- Dump completed on 2025-03-27 22:43:49
