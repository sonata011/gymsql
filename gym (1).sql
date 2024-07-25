-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Jul 25, 2024 at 12:02 PM
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `gym`
--

DELIMITER $$
--
-- Procedures
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `registerMemberForClass` (IN `p_MemberID` INT, IN `p_ClassName` VARCHAR(50))   BEGIN
    DECLARE v_ClassID INT;
    DECLARE v_MembershipType VARCHAR(50);
    DECLARE v_Message VARCHAR(100);

    
    SELECT ClassID INTO v_ClassID FROM classes WHERE ClassName = p_ClassName;

    
    SELECT TypeName INTO v_MembershipType 
    FROM members m
    JOIN membershiptypes mt ON m.MembershipTypeID = mt.MembershipTypeID
    WHERE m.MemberID = p_MemberID;

    
    IF v_ClassID IS NULL THEN
        SET v_Message = 'Error: Class does not exist.';
    ELSE
        CASE v_MembershipType
            WHEN 'Basic' THEN
                IF p_ClassName IN ('Yoga', 'Pilates') THEN
                    INSERT INTO registrations (MemberID, ClassID, RegistrationDate)
                    VALUES (p_MemberID, v_ClassID, CURDATE());
                    SET v_Message = 'Registration successful.';
                ELSE
                    SET v_Message = 'Error: Basic members can only register for Yoga or Pilates.';
                END IF;
            WHEN 'Premium' THEN
                IF p_ClassName != 'HIIT' THEN
                    INSERT INTO registrations (MemberID, ClassID, RegistrationDate)
                    VALUES (p_MemberID, v_ClassID, CURDATE());
                    SET v_Message = 'Registration successful.';
                ELSE
                    SET v_Message = 'Error: Premium members cannot register for HIIT.';
                END IF;
            WHEN 'VIP' THEN
                INSERT INTO registrations (MemberID, ClassID, RegistrationDate)
                VALUES (p_MemberID, v_ClassID, CURDATE());
                SET v_Message = 'Registration successful.';
            ELSE
                SET v_Message = 'Error: Unknown membership type.';
        END CASE;
    END IF;

    SELECT v_Message AS Message;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `updateMembershipStatus` ()   BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE memberID INT;
    DECLARE lastPaymentDate DATE;
    DECLARE curMembers CURSOR FOR 
        SELECT m.MemberID, MAX(p.PaymentDate) 
        FROM members m
        LEFT JOIN payments p ON m.MemberID = p.MemberID
        GROUP BY m.MemberID;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_NAME = 'members' AND COLUMN_NAME = 'Status') THEN
        ALTER TABLE members ADD COLUMN Status VARCHAR(10);
    END IF;

    OPEN curMembers;

    read_loop: LOOP
        FETCH curMembers INTO memberID, lastPaymentDate;
        IF done THEN
            LEAVE read_loop;
        END IF;

        IF lastPaymentDate IS NULL OR lastPaymentDate < DATE_SUB(CURDATE(), INTERVAL 1 MONTH) THEN
            UPDATE members SET Status = 'Inactive' WHERE MemberID = memberID;
        ELSE
            UPDATE members SET Status = 'Active' WHERE MemberID = memberID;
        END IF;
    END LOOP;

    CLOSE curMembers;
END$$

--
-- Functions
--
CREATE DEFINER=`root`@`localhost` FUNCTION `getMembershipPrice` (`memberID` INT, `monthCount` INT) RETURNS DECIMAL(10,2) DETERMINISTIC BEGIN
    DECLARE price DECIMAL(10,2);
    SELECT (mt.Price * monthCount) INTO price
    FROM members m
    JOIN membershiptypes mt ON m.MembershipTypeID = mt.MembershipTypeID
    WHERE m.MemberID = memberID;
    RETURN price;
END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `getTotalMembers` () RETURNS INT(11) DETERMINISTIC BEGIN
    DECLARE total INT;
    SELECT COUNT(*) INTO total FROM members;
    RETURN total;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `activity_log`
--

CREATE TABLE `activity_log` (
  `LogID` int(11) NOT NULL,
  `TableName` varchar(50) DEFAULT NULL,
  `ActionType` varchar(10) DEFAULT NULL,
  `RecordID` int(11) DEFAULT NULL,
  `OldValue` text DEFAULT NULL,
  `NewValue` text DEFAULT NULL,
  `LogDate` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `classes`
--

CREATE TABLE `classes` (
  `ClassID` int(11) NOT NULL,
  `ClassName` varchar(50) DEFAULT NULL,
  `Schedule` varchar(50) DEFAULT NULL,
  `Instructor` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `classes`
--

INSERT INTO `classes` (`ClassID`, `ClassName`, `Schedule`, `Instructor`) VALUES
(5, 'HIIT', 'Sunday 9 AM', 'Cahyadi'),
(2, 'Pilates', 'Wednesday 6 PM', 'Aditya Wiguna'),
(3, 'Spin', 'Friday 6 PM', 'Rojali'),
(1, 'Yoga', 'Monday 6 PM', 'Edy'),
(4, 'Zumba', 'Saturday 10 AM', 'Jojo');

--
-- Triggers `classes`
--
DELIMITER $$
CREATE TRIGGER `before_class_delete` BEFORE DELETE ON `classes` FOR EACH ROW BEGIN
    IF EXISTS (SELECT 1 FROM registrations WHERE ClassID = OLD.ClassID) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot delete class with active registrations';
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `members`
--

CREATE TABLE `members` (
  `MemberID` int(11) NOT NULL,
  `Name` varchar(50) DEFAULT NULL,
  `Email` varchar(50) DEFAULT NULL,
  `Phone` varchar(15) DEFAULT NULL,
  `MembershipTypeID` int(11) DEFAULT NULL,
  `Status` varchar(10) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `members`
--

INSERT INTO `members` (`MemberID`, `Name`, `Email`, `Phone`, `MembershipTypeID`, `Status`) VALUES
(1, 'Rudy Hartono', 'rudy@example.com', '123-456-7890', 1, 'Active'),
(2, 'Samanudin', 'saman@example.com', '098-765-4321', 2, 'Active'),
(3, 'Sigit Budiarto', 'sigit@example.com', '111-222-3333', 3, 'Active'),
(4, 'Waluyo Hadi', 'waluyo@example.com', '444-555-6666', 1, 'Active'),
(5, 'Jamaludin', 'jamal@example.com', '777-888-9999', 2, 'Active');

--
-- Triggers `members`
--
DELIMITER $$
CREATE TRIGGER `after_member_update` AFTER UPDATE ON `members` FOR EACH ROW BEGIN
    INSERT INTO activity_log (TableName, ActionType, RecordID, OldValue, NewValue)
    VALUES ('members', 'UPDATE', NEW.MemberID,
            CONCAT('Name: ', OLD.Name, ', Email: ', OLD.Email, ', Phone: ', OLD.Phone, ', MembershipTypeID: ', OLD.MembershipTypeID),
            CONCAT('Name: ', NEW.Name, ', Email: ', NEW.Email, ', Phone: ', NEW.Phone, ', MembershipTypeID: ', NEW.MembershipTypeID));
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `before_member_insert` BEFORE INSERT ON `members` FOR EACH ROW BEGIN
    IF NEW.Email NOT LIKE '%@%.%' THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Invalid email format';
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `membershiptypes`
--

CREATE TABLE `membershiptypes` (
  `MembershipTypeID` int(11) NOT NULL,
  `TypeName` varchar(50) DEFAULT NULL,
  `Price` decimal(10,2) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `membershiptypes`
--

INSERT INTO `membershiptypes` (`MembershipTypeID`, `TypeName`, `Price`) VALUES
(1, 'Basic', 30.00),
(2, 'Premium', 50.00),
(3, 'VIP', 80.00);

--
-- Triggers `membershiptypes`
--
DELIMITER $$
CREATE TRIGGER `before_membershiptype_update` BEFORE UPDATE ON `membershiptypes` FOR EACH ROW BEGIN
    IF NEW.Price < OLD.Price THEN
        SET NEW.Price = OLD.Price;
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `member_payments`
--

CREATE TABLE `member_payments` (
  `PaymentID` int(11) NOT NULL,
  `MemberID` int(11) DEFAULT NULL,
  `Amount` decimal(10,2) DEFAULT NULL,
  `PaymentDate` date DEFAULT NULL,
  `PaymentMethod` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `payments`
--

CREATE TABLE `payments` (
  `PaymentID` int(11) NOT NULL,
  `MemberID` int(11) DEFAULT NULL,
  `Amount` decimal(10,2) DEFAULT NULL,
  `PaymentDate` date DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `payments`
--

INSERT INTO `payments` (`PaymentID`, `MemberID`, `Amount`, `PaymentDate`) VALUES
(1, 1, 30.00, '2024-07-01'),
(2, 2, 50.00, '2024-07-03'),
(3, 3, 80.00, '2024-07-05'),
(4, 4, 30.00, '2024-07-02'),
(5, 5, 50.00, '2024-07-04');

--
-- Triggers `payments`
--
DELIMITER $$
CREATE TRIGGER `after_payment_insert` AFTER INSERT ON `payments` FOR EACH ROW BEGIN
    INSERT INTO activity_log (TableName, ActionType, RecordID, NewValue)
    VALUES ('payments', 'INSERT', NEW.PaymentID, 
            CONCAT('MemberID: ', NEW.MemberID, ', Amount: ', NEW.Amount, ', Date: ', NEW.PaymentDate));
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `registrations`
--

CREATE TABLE `registrations` (
  `RegistrationID` int(11) NOT NULL,
  `MemberID` int(11) DEFAULT NULL,
  `ClassID` int(11) DEFAULT NULL,
  `RegistrationDate` date DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `registrations`
--

INSERT INTO `registrations` (`RegistrationID`, `MemberID`, `ClassID`, `RegistrationDate`) VALUES
(1, 1, 1, '2024-07-01'),
(6, 1, 1, '2024-07-25'),
(2, 2, 2, '2024-07-03'),
(3, 3, 3, '2024-07-05'),
(4, 4, 4, '2024-07-02'),
(5, 5, 5, '2024-07-04');

--
-- Triggers `registrations`
--
DELIMITER $$
CREATE TRIGGER `after_registration_delete` AFTER DELETE ON `registrations` FOR EACH ROW BEGIN
    INSERT INTO activity_log (TableName, ActionType, RecordID, OldValue)
    VALUES ('registrations', 'DELETE', OLD.RegistrationID, 
            CONCAT('MemberID: ', OLD.MemberID, ', ClassID: ', OLD.ClassID, ', Date: ', OLD.RegistrationDate));
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Stand-in structure for view `vw_all_payments`
-- (See below for the actual view)
--
CREATE TABLE `vw_all_payments` (
`PaymentType` varchar(18)
,`PayerName` varchar(50)
,`Amount` decimal(10,2)
,`PaymentDate` date
);

-- --------------------------------------------------------

--
-- Stand-in structure for view `vw_member_details`
-- (See below for the actual view)
--
CREATE TABLE `vw_member_details` (
`MemberID` int(11)
,`MemberName` varchar(50)
,`Email` varchar(50)
,`Phone` varchar(15)
,`MembershipType` varchar(50)
,`MembershipPrice` decimal(10,2)
,`ClassesRegistered` bigint(21)
);

-- --------------------------------------------------------

--
-- Stand-in structure for view `vw_member_payment_summary`
-- (See below for the actual view)
--
CREATE TABLE `vw_member_payment_summary` (
`MemberID` int(11)
,`MemberName` varchar(50)
,`MembershipType` varchar(50)
,`ClassesRegistered` bigint(21)
,`TotalPayments` bigint(21)
,`TotalAmountPaid` decimal(32,2)
);

-- --------------------------------------------------------

--
-- Structure for view `vw_all_payments`
--
DROP TABLE IF EXISTS `vw_all_payments`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vw_all_payments`  AS SELECT 'Membership' AS `PaymentType`, `m`.`Name` AS `PayerName`, `p`.`Amount` AS `Amount`, `p`.`PaymentDate` AS `PaymentDate` FROM (`payments` `p` join `members` `m` on(`p`.`MemberID` = `m`.`MemberID`))union all select 'Class Registration' AS `PaymentType`,`m`.`Name` AS `PayerName`,50.00 AS `Amount`,`r`.`RegistrationDate` AS `PaymentDate` from (`registrations` `r` join `members` `m` on(`r`.`MemberID` = `m`.`MemberID`))  ;

-- --------------------------------------------------------

--
-- Structure for view `vw_member_details`
--
DROP TABLE IF EXISTS `vw_member_details`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vw_member_details`  AS SELECT `m`.`MemberID` AS `MemberID`, `m`.`Name` AS `MemberName`, `m`.`Email` AS `Email`, `m`.`Phone` AS `Phone`, `mt`.`TypeName` AS `MembershipType`, `mt`.`Price` AS `MembershipPrice`, (select count(0) from `registrations` `r` where `r`.`MemberID` = `m`.`MemberID`) AS `ClassesRegistered` FROM (`members` `m` join `membershiptypes` `mt` on(`m`.`MembershipTypeID` = `mt`.`MembershipTypeID`)) ;

-- --------------------------------------------------------

--
-- Structure for view `vw_member_payment_summary`
--
DROP TABLE IF EXISTS `vw_member_payment_summary`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vw_member_payment_summary`  AS SELECT `md`.`MemberID` AS `MemberID`, `md`.`MemberName` AS `MemberName`, `md`.`MembershipType` AS `MembershipType`, `md`.`ClassesRegistered` AS `ClassesRegistered`, (select count(0) from `vw_all_payments` `ap` where `ap`.`PayerName` = `md`.`MemberName`) AS `TotalPayments`, (select sum(`ap`.`Amount`) from `vw_all_payments` `ap` where `ap`.`PayerName` = `md`.`MemberName`) AS `TotalAmountPaid` FROM `vw_member_details` AS `md` ;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `activity_log`
--
ALTER TABLE `activity_log`
  ADD PRIMARY KEY (`LogID`);

--
-- Indexes for table `classes`
--
ALTER TABLE `classes`
  ADD PRIMARY KEY (`ClassID`),
  ADD KEY `idx_class_schedule` (`ClassName`,`Schedule`,`Instructor`);

--
-- Indexes for table `members`
--
ALTER TABLE `members`
  ADD PRIMARY KEY (`MemberID`),
  ADD KEY `MembershipTypeID` (`MembershipTypeID`);

--
-- Indexes for table `membershiptypes`
--
ALTER TABLE `membershiptypes`
  ADD PRIMARY KEY (`MembershipTypeID`);

--
-- Indexes for table `member_payments`
--
ALTER TABLE `member_payments`
  ADD PRIMARY KEY (`PaymentID`),
  ADD KEY `idx_member_payment` (`MemberID`,`PaymentDate`,`Amount`);

--
-- Indexes for table `payments`
--
ALTER TABLE `payments`
  ADD PRIMARY KEY (`PaymentID`),
  ADD KEY `MemberID` (`MemberID`);

--
-- Indexes for table `registrations`
--
ALTER TABLE `registrations`
  ADD PRIMARY KEY (`RegistrationID`),
  ADD KEY `MemberID` (`MemberID`),
  ADD KEY `ClassID` (`ClassID`),
  ADD KEY `idx_registration_details` (`MemberID`,`ClassID`,`RegistrationDate`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `activity_log`
--
ALTER TABLE `activity_log`
  MODIFY `LogID` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `classes`
--
ALTER TABLE `classes`
  MODIFY `ClassID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `members`
--
ALTER TABLE `members`
  MODIFY `MemberID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `membershiptypes`
--
ALTER TABLE `membershiptypes`
  MODIFY `MembershipTypeID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `member_payments`
--
ALTER TABLE `member_payments`
  MODIFY `PaymentID` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `payments`
--
ALTER TABLE `payments`
  MODIFY `PaymentID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `registrations`
--
ALTER TABLE `registrations`
  MODIFY `RegistrationID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `members`
--
ALTER TABLE `members`
  ADD CONSTRAINT `members_ibfk_1` FOREIGN KEY (`MembershipTypeID`) REFERENCES `membershiptypes` (`MembershipTypeID`);

--
-- Constraints for table `payments`
--
ALTER TABLE `payments`
  ADD CONSTRAINT `payments_ibfk_1` FOREIGN KEY (`MemberID`) REFERENCES `members` (`MemberID`);

--
-- Constraints for table `registrations`
--
ALTER TABLE `registrations`
  ADD CONSTRAINT `registrations_ibfk_1` FOREIGN KEY (`MemberID`) REFERENCES `members` (`MemberID`),
  ADD CONSTRAINT `registrations_ibfk_2` FOREIGN KEY (`ClassID`) REFERENCES `classes` (`ClassID`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
