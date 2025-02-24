-- IMPORTANT: Change DATABASE_USER_STRONG_PASSWORD (below) to a strong, unique password!
-- SQL passwords cannot contain the following special characters:
-- Backslash (\), Semicolon (;), Single (') and Double (") Quotes.
SET @userPass = 'DATABASE_USER_STRONG_PASSWORD';
-- IMPORTANT: Change PHPIPAM_SERVER to the server's IP or FQDN
SET @appServer = 'PHPIPAM_SERVER'; 

SET @userName = 'local_phpipam'; -- Database Username
SET @dbName = 'db_phpipam'; -- Databse Name
SET @hashedPass = SHA2(@userPass, 256); -- Hash the password

-- Create Database
SET @createDB = CONCAT('CREATE DATABASE ', @dbName);
PREPARE stmt FROM @createDB;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Create User with generated password
SET @createUser = CONCAT('CREATE USER "', @userName, '"@"', @appServer, '" IDENTIFIED WITH caching_sha2_password BY "', @userPass, '"');
PREPARE stmt FROM @createUser;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Grant privileges
SET @grantPrivileges = CONCAT('GRANT ALL PRIVILEGES ON ', @dbName, '.* TO "', @userName, '"@"', @appServer, '"');
PREPARE stmt FROM @grantPrivileges;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

FLUSH PRIVILEGES;

-- Display generated password (ensure this is logged securely)
SELECT @userPass AS 'Generated Password', @hashedPass AS 'Hashed Password';
