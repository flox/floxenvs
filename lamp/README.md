# LAMP Stack with WordPress - Flox Environment

This Flox environment provides a complete LAMP (Linux/Apache/MariaDB/PHP) stack with WordPress pre-configured and ready to use.

## What's Included

- **Apache HTTP Server** 2.4.65 - Web server
- **MariaDB** 11.4.8 - MySQL-compatible database
- **PHP** 8.4.13 - Server-side scripting language
- **WordPress** (Latest) - Content management system

## Quick Start

### 1. Activate the Environment

```bash
cd /private/tmp/lamp
flox activate
```

On first activation, the environment will automatically:
- Download the latest WordPress from wordpress.org
- Initialize MariaDB database
- Create WordPress database and user
- Generate wp-config.php with secure keys
- Configure Apache for PHP support

### 2. Start the Services

**Option A: Using Flox Services (Recommended)**

```bash
flox services start
```

Check service status:
```bash
flox services status
```

Stop services:
```bash
flox services stop
```

**Option B: Manual Start**

```bash
# Start MariaDB
mysqld --datadir="$FLOX_ENV_CACHE/mysql-data" --socket="$FLOX_ENV_CACHE/mysql.sock" &

# Start Apache
httpd -f "$FLOX_ENV_CACHE/apache-conf/httpd.conf" -DFOREGROUND &
```

### 3. Access WordPress

Open your browser and visit:

```
http://localhost:8080
```

Complete the WordPress installation wizard with your preferred settings.

## Configuration

### Database Credentials

- **Database Name**: `wordpress`
- **Database User**: `wordpress`
- **Database Password**: `wordpress`
- **Database Host**: `localhost` (via socket)
- **Socket Path**: `$FLOX_ENV_CACHE/mysql.sock`

### Server Settings

- **Web Server Port**: `8080`
- **Document Root**: `$FLOX_ENV_CACHE/www`
- **Apache Logs**: `$FLOX_ENV_CACHE/apache-logs/`
- **Apache Config**: `$FLOX_ENV_CACHE/apache-conf/httpd.conf`

### Environment Variables

You can customize these in `.flox/env/manifest.toml`:

```toml
[vars]
WORDPRESS_DB_NAME = "wordpress"
WORDPRESS_DB_USER = "wordpress"
WORDPRESS_DB_PASSWORD = "wordpress"
WORDPRESS_PORT = "8080"
MYSQL_PORT = "3306"
```

## File Locations

All WordPress files and database data are stored in the Flox cache directory:

- WordPress files: `$FLOX_ENV_CACHE/www/`
- MySQL data: `$FLOX_ENV_CACHE/mysql-data/`
- Apache logs: `$FLOX_ENV_CACHE/apache-logs/`
- Temp files: `$FLOX_ENV_CACHE/tmp/`

To find the exact path:
```bash
echo $FLOX_ENV_CACHE
```

## Common Tasks

### Access MySQL CLI

```bash
mysql --socket="$FLOX_ENV_CACHE/mysql.sock" -u wordpress -pwordpress wordpress
```

### View Apache Error Logs

```bash
tail -f $FLOX_ENV_CACHE/apache-logs/error.log
```

### View Apache Access Logs

```bash
tail -f $FLOX_ENV_CACHE/apache-logs/access.log
```

### Edit WordPress Files

```bash
cd $FLOX_ENV_CACHE/www
# Edit any WordPress files here
```

### Backup WordPress

```bash
# Backup WordPress files
tar -czf wordpress-backup.tar.gz $FLOX_ENV_CACHE/www

# Backup database
mysqldump --socket="$FLOX_ENV_CACHE/mysql.sock" -u wordpress -pwordpress wordpress > wordpress-db-backup.sql
```

### Reset Everything

To start fresh, remove the cache directory:

```bash
# Make sure services are stopped first
flox services stop

# Remove cache
rm -rf .flox/cache/www .flox/cache/mysql-data

# Reactivate to reinitialize
flox activate
```

## Troubleshooting

### Port Already in Use

If port 8080 is already in use, edit `.flox/env/manifest.toml` and change the `WORDPRESS_PORT` variable, then restart services.

### MariaDB Won't Start

Check if the socket file or PID file exists:
```bash
rm -f $FLOX_ENV_CACHE/mysql.sock $FLOX_ENV_CACHE/mysql.pid
```

### Apache Won't Start

Check the error log:
```bash
cat $FLOX_ENV_CACHE/apache-logs/error.log
```

Common issues:
- PHP module not loading: Ensure PHP is installed in the environment
- Permission errors: Check directory permissions in `$FLOX_ENV_CACHE`

### WordPress Shows Database Connection Error

1. Ensure MariaDB is running:
   ```bash
   ps aux | grep mysqld
   ```

2. Test database connection:
   ```bash
   mysql --socket="$FLOX_ENV_CACHE/mysql.sock" -u wordpress -pwordpress -e "USE wordpress;"
   ```

3. Check wp-config.php has correct socket path:
   ```bash
   grep DB_HOST $FLOX_ENV_CACHE/www/wp-config.php
   ```

## Development Tips

### Install WordPress Plugins/Themes

Navigate to the WordPress admin panel at `http://localhost:8080/wp-admin` and use the built-in installer, or:

```bash
cd $FLOX_ENV_CACHE/www/wp-content/plugins
# Extract plugin here

cd $FLOX_ENV_CACHE/www/wp-content/themes
# Extract theme here
```

### Enable WordPress Debug Mode

Edit `$FLOX_ENV_CACHE/www/wp-config.php` and change:
```php
define( 'WP_DEBUG', true );
define( 'WP_DEBUG_LOG', true );
define( 'WP_DEBUG_DISPLAY', false );
```

Debug log will be at: `$FLOX_ENV_CACHE/www/wp-content/debug.log`

## Security Notes

This setup is intended for local development only. For production use:

1. Change the default database password
2. Set up proper root password for MariaDB:
   ```bash
   mariadb-secure-installation
   ```
3. Configure firewall rules
4. Use HTTPS with proper SSL certificates
5. Update WordPress regularly

## Additional Resources

- [WordPress Documentation](https://wordpress.org/documentation/)
- [MariaDB Documentation](https://mariadb.com/kb/en/)
- [Apache HTTP Server Documentation](https://httpd.apache.org/docs/)
- [PHP Documentation](https://www.php.net/docs.php)
- [Flox Documentation](https://flox.dev/docs)
