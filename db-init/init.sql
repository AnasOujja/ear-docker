-- Root is required to run this once at first boot.
-- Slurm accounting DB + user
CREATE DATABASE IF NOT EXISTS slurm_acct_db;
CREATE USER IF NOT EXISTS 'slurm'@'%' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON slurm_acct_db.* TO 'slurm'@'%';

-- EAR DB + user (matches ear.conf)
CREATE DATABASE IF NOT EXISTS EAR_DB;
CREATE USER IF NOT EXISTS 'ear'@'%' IDENTIFIED BY 'ear_pass';
GRANT ALL PRIVILEGES ON EAR_DB.* TO 'ear'@'%';
FLUSH PRIVILEGES;