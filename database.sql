-- --------------------------------------------------------
-- Host:                         127.0.0.1
-- Server version:               8.0.30 - MySQL Community Server - GPL
-- Server OS:                    Win64
-- HeidiSQL Version:             12.1.0.6537
-- --------------------------------------------------------

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8 */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

-- Dumping structure for table amadeus.aircraft
CREATE TABLE IF NOT EXISTS `aircraft` (
  `id` int NOT NULL AUTO_INCREMENT,
  `iata` varchar(3) NOT NULL,
  `icao` varchar(4) NOT NULL,
  `model` varchar(100) NOT NULL,
  `seats_f` int NOT NULL DEFAULT '0',
  `seats_c` int NOT NULL DEFAULT '0',
  `seats_y` int NOT NULL DEFAULT '0',
  `rows` int DEFAULT NULL,
  `columns` int DEFAULT NULL,
  `layout` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Dumping data for table amadeus.aircraft: ~5 rows (approximately)
INSERT INTO `aircraft` (`id`, `iata`, `icao`, `model`, `seats_f`, `seats_c`, `seats_y`, `rows`, `columns`, `layout`) VALUES
	(1, 'E90', 'E190', 'Embraer E190 Custom', 3, 6, 27, 12, 4, '1011 1011 1011 1011 1011 1011 1011 1011 1011 1011 1011 1011'),
	(2, 'CRJ', 'CRJ9', 'Bombardier CRJ-900', 8, 8, 24, 10, 5, '11011 11011 11011 11011 11011 11011 11011 11011 11011 11011'),
	(3, 'AT7', 'AT72', 'ATR 72-600', 2, 2, 2, 3, 5, '10001 10001 10001'),
	(4, 'E35', 'E135', 'Embraer Legacy 600', 20, 0, 0, 10, 3, '101'),
	(5, 'ER4', 'E145', 'Embraer ERJ-145', 0, 6, 39, 15, 4, '1011');

-- Dumping structure for table amadeus.airlines
CREATE TABLE IF NOT EXISTS `airlines` (
  `id` int NOT NULL AUTO_INCREMENT,
  `iata` varchar(3) NOT NULL,
  `icao` varchar(4) NOT NULL,
  `airline` varchar(100) NOT NULL,
  `callsign` varchar(100) NOT NULL,
  `country` varchar(100) NOT NULL,
  `comments` varchar(100) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Dumping data for table amadeus.airlines: ~5 rows (approximately)
INSERT INTO `airlines` (`id`, `iata`, `icao`, `airline`, `callsign`, `country`, `comments`) VALUES
	(1, 'DLA', 'DALS', 'Delta Air Lines', 'DELTA', 'USA', 'SkyTeam Alliance'),
	(2, 'LHA', 'DLHA', 'Lufthansa', 'LUFTHANSA', 'Germany', 'Star Alliance'),
	(3, 'EKS', 'UAES', 'Emirates', 'EMIRATES', 'UAE', 'Luxury Carrier'),
	(4, 'SQS', 'SIAS', 'Singapore Airlines', 'SINGAPORE', 'Singapore', 'Asian Hub'),
	(5, 'JLS', 'JALS', 'Japan Airlines', 'JAPANAIR', 'Japan', 'OneWorld Alliance');

-- Dumping structure for table amadeus.airline_users
CREATE TABLE IF NOT EXISTS `airline_users` (
  `id` int NOT NULL AUTO_INCREMENT,
  `airline_id` int NOT NULL,
  `username` varchar(50) NOT NULL,
  `password` varchar(250) NOT NULL,
  `role` varchar(50) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `FK_airline` (`airline_id`),
  CONSTRAINT `FK_airline` FOREIGN KEY (`airline_id`) REFERENCES `airlines` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=13 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Dumping data for table amadeus.airline_users: ~5 rows (approximately)
INSERT INTO `airline_users` (`id`, `airline_id`, `username`, `password`, `role`) VALUES
	(1, 1, 'delta_mgr', 'pass123', 'manager'),
	(2, 2, 'lufthansa_ops', 'pass123', 'manager'),
	(3, 3, 'emirates_admin', 'pass123', 'manager'),
	(4, 4, 'sq_staff', 'pass123', 'staff'),
	(5, 5, 'jal_planner', 'pass123', 'manager');

-- Dumping structure for table amadeus.airports
CREATE TABLE IF NOT EXISTS `airports` (
  `id` int NOT NULL AUTO_INCREMENT,
  `iata` varchar(3) NOT NULL,
  `icao` varchar(4) NOT NULL,
  `airport_name` varchar(100) NOT NULL,
  `location_served` varchar(100) NOT NULL,
  `time` varchar(100) NOT NULL,
  `dst` varchar(10) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Dumping data for table amadeus.airports: ~5 rows (approximately)
INSERT INTO `airports` (`id`, `iata`, `icao`, `airport_name`, `location_served`, `time`, `dst`) VALUES
	(1, 'JFK', 'KJFK', 'John F. Kennedy', 'New York, USA', 'UTC-5', 'Yes'),
	(2, 'LHR', 'EGLL', 'Heathrow', 'London, UK', 'UTC+0', 'Yes'),
	(3, 'HND', 'RJTT', 'Haneda', 'Tokyo, Japan', 'UTC+9', 'No'),
	(4, 'DXB', 'OMDB', 'Dubai Intl', 'Dubai, UAE', 'UTC+4', 'No'),
	(5, 'SIN', 'WSSS', 'Changi', 'Singapore', 'UTC+8', 'No');

-- Dumping structure for table amadeus.flight_routes
CREATE TABLE IF NOT EXISTS `flight_routes` (
  `id` int NOT NULL AUTO_INCREMENT,
  `airline_id` int NOT NULL,
  `origin_airport_id` int NOT NULL,
  `destination_airport_id` int NOT NULL,
  `round_trip` tinyint NOT NULL DEFAULT '1',
  `aircraft_id` int NOT NULL,
  PRIMARY KEY (`id`),
  KEY `FK_flight_routes_airline` (`airline_id`),
  KEY `FK_flight_routes_origin` (`origin_airport_id`),
  KEY `FK_flight_routes_dest` (`destination_airport_id`),
  KEY `FK_flight_routes_aircraft` (`aircraft_id`),
  CONSTRAINT `FK_flight_routes_aircraft` FOREIGN KEY (`aircraft_id`) REFERENCES `aircraft` (`id`) ON DELETE CASCADE,
  CONSTRAINT `FK_flight_routes_airline` FOREIGN KEY (`airline_id`) REFERENCES `airlines` (`id`) ON DELETE CASCADE,
  CONSTRAINT `FK_flight_routes_dest` FOREIGN KEY (`destination_airport_id`) REFERENCES `airports` (`id`) ON DELETE CASCADE,
  CONSTRAINT `FK_flight_routes_origin` FOREIGN KEY (`origin_airport_id`) REFERENCES `airports` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=21 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Dumping data for table amadeus.flight_routes: ~10 rows (approximately)
INSERT INTO `flight_routes` (`id`, `airline_id`, `origin_airport_id`, `destination_airport_id`, `round_trip`, `aircraft_id`) VALUES
	(1, 1, 1, 2, 1, 1),
	(2, 1, 2, 1, 1, 1),
	(3, 2, 2, 3, 1, 2),
	(4, 5, 3, 5, 1, 3),
	(5, 4, 5, 3, 1, 3),
	(6, 3, 4, 2, 1, 4),
	(7, 3, 2, 4, 1, 4),
	(8, 2, 2, 4, 0, 5),
	(9, 1, 1, 5, 0, 2),
	(10, 5, 3, 1, 1, 2);

-- Dumping structure for table amadeus.flight_schedules
CREATE TABLE IF NOT EXISTS `flight_schedules` (
  `id` int NOT NULL AUTO_INCREMENT,
  `airline_user_id` int NOT NULL,
  `flight_route_id` int NOT NULL,
  `aircraft_id` int DEFAULT NULL,
  `date_departure` varchar(50) NOT NULL,
  `time_departure` varchar(50) NOT NULL,
  `date_arrival` varchar(50) NOT NULL,
  `time_arrival` varchar(50) NOT NULL,
  `status` varchar(50) NOT NULL,
  `price_f` decimal(10,2) NOT NULL DEFAULT '0.00',
  `price_c` decimal(10,2) NOT NULL DEFAULT '0.00',
  `price_y` decimal(10,2) NOT NULL DEFAULT '0.00',
  PRIMARY KEY (`id`),
  KEY `FK_flight_schedules_user` (`airline_user_id`),
  KEY `FK_flight_schedules_route` (`flight_route_id`),
  KEY `FK_flight_schedules_aircraft` (`aircraft_id`),
  CONSTRAINT `FK_flight_schedules_aircraft` FOREIGN KEY (`aircraft_id`) REFERENCES `aircraft` (`id`),
  CONSTRAINT `FK_flight_schedules_route` FOREIGN KEY (`flight_route_id`) REFERENCES `flight_routes` (`id`) ON DELETE CASCADE,
  CONSTRAINT `FK_flight_schedules_user` FOREIGN KEY (`airline_user_id`) REFERENCES `airline_users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=41 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Dumping data for table amadeus.flight_schedules: ~10 rows (approximately)
INSERT INTO `flight_schedules` (`id`, `airline_user_id`, `flight_route_id`, `aircraft_id`, `date_departure`, `time_departure`, `date_arrival`, `time_arrival`, `status`, `price_f`, `price_c`, `price_y`) VALUES
	(1, 1, 1, 1, '2025-11-25', '08:00', '2025-11-25', '20:00', 'boarding', 3800.00, 1500.00, 400.00),
	(2, 2, 3, 2, '2025-11-26', '10:00', '2025-11-27', '05:00', 'Scheduled', 0.00, 1800.00, 500.00),
	(3, 5, 4, 3, '2025-11-28', '14:00', '2025-11-28', '22:00', 'Scheduled', 0.00, 0.00, 200.00),
	(4, 3, 6, 4, '2025-11-29', '09:00', '2025-11-29', '16:00', 'Scheduled', 5000.00, 0.00, 0.00),
	(5, 4, 5, 3, '2025-12-01', '07:00', '2025-12-01', '15:00', 'Delayed', 0.00, 0.00, 210.00),
	(6, 1, 2, 1, '2025-12-02', '12:00', '2025-12-02', '23:00', 'Scheduled', 0.00, 1500.00, 400.00),
	(7, 3, 7, 4, '2025-12-03', '18:00', '2025-12-04', '02:00', 'Scheduled', 5000.00, 0.00, 0.00),
	(8, 2, 8, 5, '2025-12-05', '06:00', '2025-12-05', '14:00', 'Cancelled', 0.00, 800.00, 300.00),
	(9, 1, 9, 2, '2025-12-06', '20:00', '2025-12-07', '10:00', 'Scheduled', 0.00, 1900.00, 550.00),
	(10, 5, 10, 2, '2025-12-08', '11:00', '2025-12-09', '01:00', 'Scheduled', 0.00, 1800.00, 500.00);

-- Dumping structure for table amadeus.passengers
CREATE TABLE IF NOT EXISTS `passengers` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(250) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT '0',
  `email` varchar(250) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT '0',
  `phone` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=22 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Dumping data for table amadeus.passengers: ~3 rows (approximately)
INSERT INTO `passengers` (`id`, `name`, `email`, `phone`) VALUES
	(1, 'Alice Johnson', 'alice@example.com', '555-0101'),
	(2, 'Bob Smith', 'bob@test.com', '555-0102'),
	(3, 'Charlie Brown', 'charlie@sample.net', '555-0103');

-- Dumping structure for table amadeus.seats
CREATE TABLE IF NOT EXISTS `seats` (
  `id` int NOT NULL AUTO_INCREMENT,
  `flight_schedule_id` int NOT NULL,
  `aircraft_id` int DEFAULT NULL,
  `ticket_id` varchar(50) DEFAULT NULL,
  `seat_no` varchar(10) NOT NULL,
  `class` enum('F','C','Y') NOT NULL,
  `status` enum('available','occupied','blocked') NOT NULL DEFAULT 'available',
  `price` int DEFAULT NULL,
  `customer_name` varchar(250) DEFAULT NULL,
  `customer_number` varchar(50) DEFAULT NULL,
  `agency_number` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `FK_seats_schedule` (`flight_schedule_id`),
  KEY `FK_seats_aircraft` (`aircraft_id`),
  CONSTRAINT `FK_seats_aircraft` FOREIGN KEY (`aircraft_id`) REFERENCES `aircraft` (`id`),
  CONSTRAINT `FK_seats_schedule` FOREIGN KEY (`flight_schedule_id`) REFERENCES `flight_schedules` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=77 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Dumping data for table amadeus.seats: ~76 rows (approximately)
INSERT INTO `seats` (`id`, `flight_schedule_id`, `aircraft_id`, `ticket_id`, `seat_no`, `class`, `status`, `price`, `customer_name`, `customer_number`, `agency_number`) VALUES
	(1, 1, 1, 'TKT-100', '1A', 'F', 'occupied', 500, 'Shimi Jallores', '09289287057', '09561434976'),
	(2, 1, 1, NULL, '1B', 'F', 'available', NULL, NULL, NULL, NULL),
	(3, 1, 1, NULL, '1C', 'F', 'occupied', 32000, 'Estephanie Anne M. De Torres', '09289287057', '09561434976'),
	(4, 1, 1, 'TKT-101', '2A', 'C', 'occupied', NULL, NULL, NULL, NULL),
	(5, 1, 1, 'TKT-102', '2B', 'C', 'occupied', NULL, NULL, NULL, NULL),
	(6, 1, 1, NULL, '2C', 'C', 'available', NULL, NULL, NULL, NULL),
	(7, 1, 1, NULL, '3A', 'C', 'available', NULL, NULL, NULL, NULL),
	(8, 1, 1, NULL, '3B', 'C', 'available', NULL, NULL, NULL, NULL),
	(9, 1, 1, NULL, '3C', 'C', 'available', NULL, NULL, NULL, NULL),
	(10, 1, 1, 'TKT-103', '4A', 'Y', 'occupied', NULL, NULL, NULL, NULL),
	(11, 1, 1, 'TKT-104', '4B', 'Y', 'occupied', NULL, NULL, NULL, NULL),
	(12, 1, 1, 'TKT-105', '4C', 'Y', 'occupied', NULL, NULL, NULL, NULL),
	(13, 1, 1, NULL, '5A', 'Y', 'available', NULL, NULL, NULL, NULL),
	(14, 1, 1, NULL, '5B', 'Y', 'available', NULL, NULL, NULL, NULL),
	(15, 1, 1, NULL, '5C', 'Y', 'available', NULL, NULL, NULL, NULL),
	(16, 1, 1, NULL, '6A', 'Y', 'blocked', NULL, NULL, NULL, NULL),
	(17, 1, 1, NULL, '6B', 'Y', 'blocked', NULL, NULL, NULL, NULL),
	(18, 1, 1, NULL, '6C', 'Y', 'blocked', NULL, NULL, NULL, NULL),
	(19, 1, 1, NULL, '7A', 'Y', 'available', NULL, NULL, NULL, NULL),
	(20, 1, 1, 'TKT-106', '7B', 'Y', 'occupied', NULL, NULL, NULL, NULL),
	(21, 1, 1, 'TKT-107', '7C', 'Y', 'occupied', NULL, NULL, NULL, NULL),
	(22, 1, 1, NULL, '8A', 'Y', 'available', NULL, NULL, NULL, NULL),
	(23, 1, 1, NULL, '8B', 'Y', 'available', NULL, NULL, NULL, NULL),
	(24, 1, 1, NULL, '8C', 'Y', 'available', NULL, NULL, NULL, NULL),
	(25, 1, 1, NULL, '9A', 'Y', 'available', NULL, NULL, NULL, NULL),
	(26, 1, 1, NULL, '9B', 'Y', 'available', NULL, NULL, NULL, NULL),
	(27, 1, 1, NULL, '9C', 'Y', 'available', NULL, NULL, NULL, NULL),
	(28, 1, 1, 'TKT-108', '10A', 'Y', 'occupied', NULL, NULL, NULL, NULL),
	(29, 1, 1, NULL, '10B', 'Y', 'available', NULL, NULL, NULL, NULL),
	(30, 1, 1, NULL, '10C', 'Y', 'available', NULL, NULL, NULL, NULL),
	(31, 1, 1, NULL, '11A', 'Y', 'available', NULL, NULL, NULL, NULL),
	(32, 1, 1, NULL, '11B', 'Y', 'available', NULL, NULL, NULL, NULL),
	(33, 1, 1, NULL, '11C', 'Y', 'available', NULL, NULL, NULL, NULL),
	(34, 1, 1, NULL, '12A', 'Y', 'available', NULL, NULL, NULL, NULL),
	(35, 1, 1, NULL, '12B', 'Y', 'available', NULL, NULL, NULL, NULL),
	(36, 1, 1, NULL, '12C', 'Y', 'available', NULL, NULL, NULL, NULL),
	(37, 2, 2, 'TKT-201', '1A', 'F', 'occupied', NULL, NULL, NULL, NULL),
	(38, 2, 2, 'TKT-202', '1B', 'F', 'occupied', NULL, NULL, NULL, NULL),
	(39, 2, 2, NULL, '1C', 'F', 'available', NULL, NULL, NULL, NULL),
	(40, 2, 2, NULL, '1D', 'F', 'available', NULL, NULL, NULL, NULL),
	(41, 2, 2, NULL, '2A', 'F', 'available', NULL, NULL, NULL, NULL),
	(42, 2, 2, NULL, '2B', 'F', 'available', NULL, NULL, NULL, NULL),
	(43, 2, 2, 'TKT-203', '2C', 'F', 'occupied', NULL, NULL, NULL, NULL),
	(44, 2, 2, 'TKT-204', '2D', 'F', 'occupied', NULL, NULL, NULL, NULL),
	(45, 2, 2, 'TKT-205', '3A', 'C', 'occupied', NULL, NULL, NULL, NULL),
	(46, 2, 2, 'TKT-206', '3B', 'C', 'occupied', NULL, NULL, NULL, NULL),
	(47, 2, 2, 'TKT-207', '3C', 'C', 'occupied', NULL, NULL, NULL, NULL),
	(48, 2, 2, 'TKT-208', '3D', 'C', 'occupied', NULL, NULL, NULL, NULL),
	(49, 2, 2, NULL, '4A', 'C', 'available', NULL, NULL, NULL, NULL),
	(50, 2, 2, NULL, '4B', 'C', 'available', NULL, NULL, NULL, NULL),
	(51, 2, 2, NULL, '4C', 'C', 'available', NULL, NULL, NULL, NULL),
	(52, 2, 2, NULL, '4D', 'C', 'available', NULL, NULL, NULL, NULL),
	(53, 2, 2, 'TKT-209', '5A', 'Y', 'occupied', NULL, NULL, NULL, NULL),
	(54, 2, 2, NULL, '5B', 'Y', 'available', NULL, NULL, NULL, NULL),
	(55, 2, 2, NULL, '5C', 'Y', 'available', NULL, NULL, NULL, NULL),
	(56, 2, 2, 'TKT-210', '5D', 'Y', 'occupied', NULL, NULL, NULL, NULL),
	(57, 2, 2, NULL, '6A', 'Y', 'blocked', NULL, NULL, NULL, NULL),
	(58, 2, 2, NULL, '6B', 'Y', 'blocked', NULL, NULL, NULL, NULL),
	(59, 2, 2, NULL, '6C', 'Y', 'blocked', NULL, NULL, NULL, NULL),
	(60, 2, 2, NULL, '6D', 'Y', 'blocked', NULL, NULL, NULL, NULL),
	(61, 2, 2, NULL, '7A', 'Y', 'available', NULL, NULL, NULL, NULL),
	(62, 2, 2, NULL, '7B', 'Y', 'available', NULL, NULL, NULL, NULL),
	(63, 2, 2, NULL, '7C', 'Y', 'available', NULL, NULL, NULL, NULL),
	(64, 2, 2, NULL, '7D', 'Y', 'available', NULL, NULL, NULL, NULL),
	(65, 2, 2, 'TKT-211', '8A', 'Y', 'occupied', NULL, NULL, NULL, NULL),
	(66, 2, 2, 'TKT-212', '8B', 'Y', 'occupied', NULL, NULL, NULL, NULL),
	(67, 2, 2, 'TKT-213', '8C', 'Y', 'occupied', NULL, NULL, NULL, NULL),
	(68, 2, 2, 'TKT-214', '8D', 'Y', 'occupied', NULL, NULL, NULL, NULL),
	(69, 2, 2, NULL, '9A', 'Y', 'available', NULL, NULL, NULL, NULL),
	(70, 2, 2, NULL, '9B', 'Y', 'available', NULL, NULL, NULL, NULL),
	(71, 2, 2, NULL, '9C', 'Y', 'available', NULL, NULL, NULL, NULL),
	(72, 2, 2, NULL, '9D', 'Y', 'available', NULL, NULL, NULL, NULL),
	(73, 2, 2, NULL, '10A', 'Y', 'available', NULL, NULL, NULL, NULL),
	(74, 2, 2, NULL, '10B', 'Y', 'available', NULL, NULL, NULL, NULL),
	(75, 2, 2, NULL, '10C', 'Y', 'available', NULL, NULL, NULL, NULL),
	(76, 2, 2, NULL, '10D', 'Y', 'available', NULL, NULL, NULL, NULL);

-- Dumping structure for table amadeus.users
CREATE TABLE IF NOT EXISTS `users` (
  `id` int NOT NULL AUTO_INCREMENT,
  `username` varchar(50) NOT NULL,
  `password` varchar(250) NOT NULL,
  `role` enum('user','admin','staff') NOT NULL DEFAULT 'user',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Dumping data for table amadeus.users: ~2 rows (approximately)
INSERT INTO `users` (`id`, `username`, `password`, `role`) VALUES
	(1, 'admin', 'admin123', 'admin'),
	(2, 'traveler', 'user123', 'user');

/*!40103 SET TIME_ZONE=IFNULL(@OLD_TIME_ZONE, 'system') */;
/*!40101 SET SQL_MODE=IFNULL(@OLD_SQL_MODE, '') */;
/*!40014 SET FOREIGN_KEY_CHECKS=IFNULL(@OLD_FOREIGN_KEY_CHECKS, 1) */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40111 SET SQL_NOTES=IFNULL(@OLD_SQL_NOTES, 1) */;
