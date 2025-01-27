#!/bin/bash

# WordPress Site Cleanup Script
# This script helps clean a virus-infected WordPress site and migrate it to a new server.

# Variables (User can modify these)
OLD_SITE_DIR="/var/www/old-site"          # Path to the old WordPress site
NEW_SITE_DIR="/var/www/new-site"          # Path to the new WordPress site
DB_NAME="new_wp_db"                       # New database name
DB_USER="new_wp_user"                     # New database user
DB_PASS="new_wp_password"                 # New database password
BACKUP_DIR="/backups"                     # Directory to store backups

# Step 1: Draw the list of plugins and themes from the old site
echo "Step 1: Listing plugins and themes from the old site..."
wp --path=$OLD_SITE_DIR plugin list --format=csv > $BACKUP_DIR/plugins.csv
wp --path=$OLD_SITE_DIR theme list --format=csv > $BACKUP_DIR/themes.csv
echo "Plugins and themes list saved to $BACKUP_DIR."

# Step 2: Extract the SQL dump of the database
echo "Step 2: Exporting the database..."
read -p "Enter the old database name: " OLD_DB_NAME
read -p "Enter the old database user: " OLD_DB_USER
read -p "Enter the old database password: " OLD_DB_PASS
mysqldump -u $OLD_DB_USER -p$OLD_DB_PASS $OLD_DB_NAME > $BACKUP_DIR/old-site-db.sql
echo "Database exported to $BACKUP_DIR/old-site-db.sql."

# Step 3: Clean the database
echo "Step 3: Cleaning the database..."
read -p "Do you want to manually clean the database? (y/n): " CLEAN_DB
if [ "$CLEAN_DB" == "y" ]; then
    echo "Please manually clean the database file at $BACKUP_DIR/old-site-db.sql."
    read -p "Press Enter to continue after cleaning..."
else
    echo "Using automated cleaning tools..."
    # Example: Remove spam comments and unused tables
    wp db optimize --path=$OLD_SITE_DIR
    wp db repair --path=$OLD_SITE_DIR
    echo "Database cleaned automatically."
fi

# Step 4: Scan the wp-content folder for viruses
echo "Step 4: Scanning wp-content folder for viruses..."
read -p "Do you want to scan for viruses? (y/n): " SCAN_VIRUS
if [ "$SCAN_VIRUS" == "y" ]; then
    echo "Scanning wp-content folder..."
    clamscan -r $OLD_SITE_DIR/wp-content --log=$BACKUP_DIR/clamscan.log
    echo "Scan complete. Check the log file at $BACKUP_DIR/clamscan.log."
    read -p "Review the log and delete suspicious files manually. Press Enter to continue..."
else
    echo "Skipping virus scan."
fi

# Step 5: Install a fresh, clean copy of WordPress on a new server
echo "Step 5: Installing a fresh copy of WordPress..."
mkdir -p $NEW_SITE_DIR
cd $NEW_SITE_DIR
wp core download
wp config create --dbname=$DB_NAME --dbuser=$DB_USER --dbpass=$DB_PASS
echo "Fresh WordPress installation complete at $NEW_SITE_DIR."

# Step 6: Install clean copies of plugins and themes
echo "Step 6: Installing clean plugins and themes..."
while IFS=, read -r name status version; do
    if [ "$name" != "name" ]; then
        wp plugin install $name --activate
    fi
done < $BACKUP_DIR/plugins.csv

while IFS=, read -r name status version; do
    if [ "$name" != "name" ]; then
        wp theme install $name
    fi
done < $BACKUP_DIR/themes.csv
echo "Plugins and themes installed."

# Step 7: Import the cleaned-up database
echo "Step 7: Importing the cleaned database..."
mysql -u $DB_USER -p$DB_PASS $DB_NAME < $BACKUP_DIR/old-site-db.sql
wp search-replace "http://old-site.com" "http://new-site.com" --path=$NEW_SITE_DIR
echo "Database imported and URLs updated."

# Step 8: Copy over the cleaned-up wp-content/uploads folder
echo "Step 8: Copying wp-content/uploads folder..."
rsync -av $OLD_SITE_DIR/wp-content/uploads/ $NEW_SITE_DIR/wp-content/uploads/
echo "Uploads folder copied."

# Step 9: Harden the new WordPress installation
echo "Step 9: Hardening the new WordPress installation..."
wp config set DISALLOW_FILE_EDIT true --path=$NEW_SITE_DIR
chmod 755 $NEW_SITE_DIR
find $NEW_SITE_DIR -type d -exec chmod 755 {} \;
find $NEW_SITE_DIR -type f -exec chmod 644 {} \;
echo "WordPress installation hardened."

# Step 10: Final malware scan
echo "Step 10: Performing a final malware scan..."
read -p "Do you want to perform a final malware scan? (y/n): " FINAL_SCAN
if [ "$FINAL_SCAN" == "y" ]; then
    clamscan -r $NEW_SITE_DIR --log=$BACKUP_DIR/final-clamscan.log
    echo "Final scan complete. Check the log file at $BACKUP_DIR/final-clamscan.log."
else
    echo "Skipping final malware scan."
fi

echo "WordPress site cleanup and migration complete!"
