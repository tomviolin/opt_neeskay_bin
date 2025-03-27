/*!999999\- enable the sandbox mode */ 
-- MariaDB dump 10.19  Distrib 10.11.8-MariaDB, for debian-linux-gnu (x86_64)
--
-- Host: localhost    Database: neeskay
-- ------------------------------------------------------
-- Server version	10.11.8-MariaDB-0ubuntu0.24.04.1

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `compass`
--

DROP TABLE IF EXISTS `compass`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `compass` (
  `rec_id` bigint(20) NOT NULL AUTO_INCREMENT,
  `recdate` datetime NOT NULL,
  `nrecs` int(11) DEFAULT NULL,
  `avg_degrees` decimal(6,2) DEFAULT NULL,
  PRIMARY KEY (`rec_id`),
  UNIQUE KEY `recdate` (`recdate`)
) ENGINE=InnoDB AUTO_INCREMENT=1170841 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compass_readings`
--

DROP TABLE IF EXISTS `compass_readings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `compass_readings` (
  `rec_id` bigint(20) NOT NULL AUTO_INCREMENT,
  `recdate` datetime NOT NULL,
  `gyro` decimal(6,2) DEFAULT NULL,
  `flux` decimal(6,2) DEFAULT NULL,
  `src_image` varchar(256) DEFAULT NULL,
  `adp1` decimal(6,2) DEFAULT NULL,
  `adp2` decimal(6,2) DEFAULT NULL,
  PRIMARY KEY (`rec_id`)
) ENGINE=MyISAM AUTO_INCREMENT=152 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `trackingdata_flex`
--

DROP TABLE IF EXISTS `trackingdata_flex`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `trackingdata_flex` (
  `recordid` bigint(20) NOT NULL AUTO_INCREMENT,
  `recdate` datetime NOT NULL,
  `gpslat` decimal(10,7) DEFAULT NULL,
  `gpslng` decimal(10,7) DEFAULT NULL,
  `depthm` decimal(6,2) DEFAULT NULL,
  `tempc` decimal(5,2) DEFAULT NULL,
  `gpsfixquality` decimal(1,0) DEFAULT NULL,
  `gpsnsats` decimal(2,0) DEFAULT NULL,
  `gpshdop` decimal(5,2) DEFAULT NULL,
  `gpsalt` decimal(7,1) DEFAULT NULL,
  `gpsttmg` decimal(5,2) DEFAULT NULL,
  `gpsmtmg` decimal(5,2) DEFAULT NULL,
  `gpssogn` decimal(5,2) DEFAULT NULL,
  `gpssogk` decimal(5,2) DEFAULT NULL,
  `gpsmagvar` decimal(5,2) DEFAULT NULL,
  `ysi_layout_id` int(11) DEFAULT NULL,
  `ysi_01` varchar(10) DEFAULT NULL,
  `ysi_02` varchar(10) DEFAULT NULL,
  `ysi_03` varchar(10) DEFAULT NULL,
  `ysi_04` varchar(10) DEFAULT NULL,
  `ysi_05` varchar(10) DEFAULT NULL,
  `ysi_06` varchar(10) DEFAULT NULL,
  `ysi_07` varchar(10) DEFAULT NULL,
  `ysi_08` varchar(10) DEFAULT NULL,
  `ysi_09` varchar(10) DEFAULT NULL,
  `ysi_10` varchar(10) DEFAULT NULL,
  `ysi_11` varchar(10) DEFAULT NULL,
  `ysi_12` varchar(10) DEFAULT NULL,
  `ysi_13` varchar(10) DEFAULT NULL,
  `ysi_14` varchar(10) DEFAULT NULL,
  `ysi_15` varchar(10) DEFAULT NULL,
  `ysi_16` varchar(10) DEFAULT NULL,
  `ysi_17` varchar(10) DEFAULT NULL,
  `ysi_18` varchar(10) DEFAULT NULL,
  `ysi_19` varchar(10) DEFAULT NULL,
  `ysi_20` varchar(10) DEFAULT NULL,
  `ysi_21` varchar(10) DEFAULT NULL,
  `ysi_22` varchar(10) DEFAULT NULL,
  `ysi_23` varchar(10) DEFAULT NULL,
  `ysi_24` varchar(10) DEFAULT NULL,
  `recminute` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `rechour` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `recday` date NOT NULL DEFAULT '0000-00-00',
  PRIMARY KEY (`recordid`),
  UNIQUE KEY `recdate_uniq` (`recdate`),
  UNIQUE KEY `recordid` (`recordid`,`recdate`,`gpslat`),
  UNIQUE KEY `recordid_2` (`recordid`,`recdate`,`gpslat`),
  KEY `lat_lng` (`gpslat`,`gpslng`),
  KEY `depthm` (`depthm`),
  KEY `recminute` (`recminute`),
  KEY `rechour` (`rechour`),
  KEY `recdate_gps_lat` (`recdate`,`gpslat`,`gpslng`)
) ENGINE=InnoDB AUTO_INCREMENT=8355188 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `windraw`
--

DROP TABLE IF EXISTS `windraw`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `windraw` (
  `rec_id` bigint(20) NOT NULL AUTO_INCREMENT,
  `recdate` datetime NOT NULL,
  `nrecs` int(11) DEFAULT NULL,
  `avg_degrees` decimal(6,2) DEFAULT NULL,
  `avg_speed` decimal(6,2) DEFAULT NULL,
  PRIMARY KEY (`rec_id`),
  UNIQUE KEY `recdate` (`recdate`)
) ENGINE=InnoDB AUTO_INCREMENT=2230251 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `ysi_fields`
--

DROP TABLE IF EXISTS `ysi_fields`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ysi_fields` (
  `ysi_field_id` int(11) NOT NULL AUTO_INCREMENT,
  `ysi_field_desc` varchar(20) NOT NULL,
  PRIMARY KEY (`ysi_field_id`)
) ENGINE=MyISAM AUTO_INCREMENT=219 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `ysi_layout`
--

DROP TABLE IF EXISTS `ysi_layout`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ysi_layout` (
  `ysi_layout_id` int(11) NOT NULL AUTO_INCREMENT,
  `recdate` datetime NOT NULL,
  `ysi_01_fld` int(11) DEFAULT NULL,
  `ysi_02_fld` int(11) DEFAULT NULL,
  `ysi_03_fld` int(11) DEFAULT NULL,
  `ysi_04_fld` int(11) DEFAULT NULL,
  `ysi_05_fld` int(11) DEFAULT NULL,
  `ysi_06_fld` int(11) DEFAULT NULL,
  `ysi_07_fld` int(11) DEFAULT NULL,
  `ysi_08_fld` int(11) DEFAULT NULL,
  `ysi_09_fld` int(11) DEFAULT NULL,
  `ysi_10_fld` int(11) DEFAULT NULL,
  `ysi_11_fld` int(11) DEFAULT NULL,
  `ysi_12_fld` int(11) DEFAULT NULL,
  `ysi_13_fld` int(11) DEFAULT NULL,
  `ysi_14_fld` int(11) DEFAULT NULL,
  `ysi_15_fld` int(11) DEFAULT NULL,
  `ysi_16_fld` int(11) DEFAULT NULL,
  `ysi_17_fld` int(11) DEFAULT NULL,
  `ysi_18_fld` int(11) DEFAULT NULL,
  `ysi_19_fld` int(11) DEFAULT NULL,
  `ysi_20_fld` int(11) DEFAULT NULL,
  `ysi_21_fld` int(11) DEFAULT NULL,
  `ysi_22_fld` int(11) DEFAULT NULL,
  `ysi_23_fld` int(11) DEFAULT NULL,
  `ysi_24_fld` int(11) DEFAULT NULL,
  PRIMARY KEY (`ysi_layout_id`)
) ENGINE=MyISAM AUTO_INCREMENT=89 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2025-03-27 16:37:28
