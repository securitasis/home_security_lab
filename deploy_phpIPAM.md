
# Secure Deployment of phpIPAM on Ubuntu with Remote MySQL

## **Document Information**

- **Title:** Secure Deployment of phpIPAM on Ubuntu with Remote MySQL
- **File Name:** phpipam_deploy.md
- **Author:** [**Jerry P. Collins, Jr. \[@securitasis\]**](https://github.com/securitasis)
- **Version:** 1.0
- **Last Updated:** 2025-02-23
- **Purpose:** 
  This document outlines the step-by-step procedure for securely deploying phpIPAM on an Ubuntu system while hosting its database on a remote MySQL server.
- **License:**
  This documentation is licensed under the **GNU Free Documentation License (GFDL) v1.3 or later**. You are free to **copy, modify, and distribute** this document, provided that credit is given to the original author(s). See [https://www.gnu.org/licenses/fdl-1.3.html](https://www.gnu.org/licenses/fdl-1.3.html) for the full license.
- **Repository:** 
  The latest version of this document and related source code can be found at: [GitHub - Securitasis/home_security_lab](https://github.com/securitasis/home_security_lab)

## **Assumptions**

- The user has basic knowledge of Linux command-line operations.
- The Ubuntu server is freshly installed and has internet access.
- A separate MySQL database server is available for hosting phpIPAM’s database.
- Proper network access is configured between the phpIPAM application server and the remote MySQL server.
- The deployment will follow security best practices, including firewall configurations, database authentication, and encryption where applicable.
- **Enabling HTTPS is not covered in this instruction set.** However, it is **highly recommended** to deploy an SSL certificate, either locally on the Apache server or using a reverse proxy such as Nginx or Traefik, to secure access to phpIPAM.
## **Prerequisites**

1. **Operating System:** Ubuntu 20.04 or later (recommended)
2. **System Access:** Root or a sudo-enabled user account
3. **Database Server:** A remote MySQL server (MySQL 8.0+ or MariaDB 10.5+)
4. **Required Network Ports:**
    - **Apache Web Server:** TCP port `80` (HTTP) or `443` (HTTPS)
    - **MySQL Remote Access:** TCP port `3306` (ensure it is firewalled and limited to allowed IPs)
5. **Installed Packages:**
    - Apache (`apache2`), PHP (`php` with required extensions), Git, OpenSSL
6. **Security Considerations:**
    - MySQL remote authentication using hashed passwords
    - UFW or iptables configured to allow only trusted sources
    - SSL/TLS enabled for secure web access

---
# **Installation Steps**
---
## Step 1: Prepare Your Ubuntu System

1. **Update package lists and upgrade installed packages:**
    
    ```bash
    sudo apt update && sudo apt upgrade -y
    ```
    
2. **Install essential utilities:**
    
    ```bash
    sudo apt install -y git curl wget unzip
    ```
 
---
## Step 2: Install Apache, PHP, and Required PHP Extensions

1. **Install Apache:**
    
    ```bash
    sudo apt install -y apache2
    ```
    
2. **Install PHP and required modules:**
    
    phpIPAM requires PHP along with several modules. Install PHP and these common extensions:
    
    ```bash
    sudo apt install -y php php-cli php-common php-gd php-mbstring php-xml php-mysql php-zip php-curl php-gmp php-pear
    ```
    
3. **Restart Apache to load PHP modules:**
    
    ```bash
    sudo systemctl restart apache2
    ```
    
---
### 3.1 Generate a MySQL Native Password Hash

**Before executing the SQL query, make the following changes:**
- Replace `Plaintext_Password` with your desired password.

Then, run the following query in your MySQL environment:

```sql
-- Generate a MySQL native password hash (mysql_native_password format)
SELECT CONCAT('*', UPPER(SHA1(UNHEX(SHA1('Plaintext_Password'))))) AS mysql_native_hash;
```

**Instructions:**
- **Copy the resulting hash.** You will use it both when creating the MySQL user and later in the phpIPAM configuration.

> **Disclaimer:**  
> Passwords should never be saved or transmitted in cleartext because they can be intercepted and compromised. Hashing passwords ensures that even if the data is intercepted, the actual password remains secure. Always use strong, hashed passwords to protect sensitive information.

### 3.2 Create the phpIPAM Database User and a Databse User Password**

**Before executing these commands, make the following changes:**
- Replace `YOUR_DATABASE_USER_PASSWORD` with the hash you obtained in step **3.1**.
- Replace both `YOUR_PHPIPAM_SERVER_IP_OR_FQDN` with the actual IP address or Fully Qualified Domain Name (FQDN) of your phpIPAM server.

Now, execute the following commands:

```sql
CREATE USER 'local_phpipam'@'YOUR_PHPIPAM_SERVER_IP_OR_FQDN' IDENTIFIED BY 'YOUR_DATABASE_USER_PASSWORD';
GRANT ALL PRIVILEGES ON *.* TO 'local_phpipam'@'YOUR_PHPIPAM_SERVER_IP_OR_FQDN' WITH GRANT OPTION;
```

### 3.3 Allow Remote Connections

Verify that the MySQL configuration file has the bind address set appropriately and adjust your firewall settings as needed.

1. **Open `mysql.cnf` and edit (if necessary).**

    ```bash
    sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf
    ```

>     NOTE: By default, the 'bind-address = 127.0.0.1' which does not allow any remote access to a MySQL database server.

2. **Set the `bind-address` to `0.0.0.0` to allow MySQL to listen on all network interfaces:**
    
    ```conf
    [mysqld]
    bind-address = 0.0.0.0
    ```

> [!NOTE]
> **Security Risks:**
>    1. **Increased Attack Surface:**
>        - By setting `bind-address` to `0.0.0.0` or a specific external IP, MySQL listens on all network interfaces or the specified interface, respectively. This change exposes the MySQL service to external networks, potentially allowing unauthorized access attempts.
>    2. **Potential Misconfigurations:**
>        - Ensuring that only intended IP addresses have access requires meticulous configuration. Any oversight, such as granting privileges to a broader IP range than intended, can inadvertently open access to malicious entities.

---

## Step 4: Download and Configure phpIPAM

### 4.1 Clone the phpIPAM Repository into Your Web Root

On your Ubuntu system, run the following commands:

```bash
cd /var/www/html
sudo git clone https://github.com/phpipam/phpipam.git
sudo mv phpipam phpipam-app
```

### 4.2 Set Appropriate Ownership and Permissions

```bash
sudo chown -R www-data:www-data /var/www/html/phpipam-app
sudo find /var/www/html/phpipam-app -type d -exec chmod 755 {} \;
sudo find /var/www/html/phpipam-app -type f -exec chmod 644 {} \;
```

### 4.3 Copy and Edit the Configuration File

Navigate into the phpIPAM directory, copy the distribution configuration file, and open it for editing:

```bash
cd /var/www/html/phpipam-app
sudo cp config.dist.php config.php
sudo nano config.php
```

Update the database section with your remote MySQL details and the hashed password:

```php
/**
 * Database connection details
 ******************************/
$db['host'] = 'YOUR_MYSQL_SERVER_IP_OR_FQDN';  // Replace with IP or FQDN
$db['user'] = '';
$db['pass'] = '';
$db['name'] = 'db_phpipam';
$db['port'] = 3306;
```

Save and exit your editor.

---
## Step 5: Configure Apache Virtual Host for phpIPAM

1. **Create a New Apache Virtual Host Configuration File:**
    
    ```bash
    sudo nano /etc/apache2/sites-available/phpipam.conf
    ```
    
2. **Insert the following configuration, ensuring the DocumentRoot points to your phpIPAM installation:**
    
    ```apache
    <VirtualHost *:80>
        ServerAdmin admin@example.com
        DocumentRoot /var/www/html/phpipam-app
    
        <Directory /var/www/html/phpipam-app>
            Options Indexes FollowSymLinks MultiViews
            AllowOverride All
            Require all granted
        </Directory>
    
        ErrorLog ${APACHE_LOG_DIR}/phpipam_error.log
        CustomLog ${APACHE_LOG_DIR}/phpipam_access.log combined
    </VirtualHost>
    ```
    
    > **Note:** Replace `admin@example.com` with your actual administrator email.
    
3. **Disable the default Apache site(s) to avoid conflicts:**
    
    ```bash
    sudo a2dissite 000-default.conf
    sudo mv /var/www/html/index.html /var/www/html/index.html.bak
    ```
    
4. **Enable the phpIPAM site and required modules:**
    
    ```bash
    sudo a2ensite phpipam.conf
    sudo a2enmod rewrite
    ```
    
5. **Reload or restart Apache:**
    
    ```bash
    sudo systemctl reload apache2
    ```
    

---
## Step 6: Finalize the phpIPAM Installation via the Web Interface

1. **Browse to your server IP or domain name:**

	Open your web browser and navigate to:

	```html
    http://YOUR_SERVER_IP_OR_FQDN/
    ```

2. **Follow the on-screen installation instructions:**

	The installer will run prerequisite checks, verify database connectivity using the settings in your `config.php`, and guide you through the remaining configuration steps.

    You will see the "Welcome to phpipam installation wizard!" screen.

    1. Select the "New phpipam installation" button
    2. Select the "Automatic database installation" button
    3. Enter the MySQL Username `local_phpipam`
    4. Enter your MySQL password for the above username
    5. Near the bottom center, select the "Show advance options" button
    6. Uncheck "create new database"
    7. On the bottom right, select the "Install phpipam database" button
---     
# TO BE COMPLETED! More hardening steps require testing.
---

3. **Complete the installation:**

    After successfully completing the installer, you should see the phpIPAM dashboard rather than the Apache default page.