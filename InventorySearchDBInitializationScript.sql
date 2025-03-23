-- #####################
-- Ensure Necessary Schemas Exist
-- #####################

-- Create `core` schema if it doesn't exist
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'core')
BEGIN
    EXEC('CREATE SCHEMA core');
    PRINT 'Schema "core" created successfully.';
END
ELSE
BEGIN
    PRINT 'Schema "core" already exists. Skipping creation.';
END;

-- Create `audit` schema if it doesn't exist
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'audit')
BEGIN
    EXEC('CREATE SCHEMA audit');
    PRINT 'Schema "audit" created successfully.';
END
ELSE
BEGIN
    PRINT 'Schema "audit" already exists. Skipping creation.';
END;

-- Create `config` schema if it doesn't exist
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'config')
BEGIN
    EXEC('CREATE SCHEMA config');
    PRINT 'Schema "config" created successfully.';
END
ELSE
BEGIN
    PRINT 'Schema "config" already exists. Skipping creation.';
END;

-- #####################
-- END Ensure Necessary Schemas Exist
-- #####################

-- #####################
-- BEGIN 1.1.1: Define Database Variables
-- #####################


-- Database name and file paths (modifiable for different environments)
DECLARE @DatabaseName NVARCHAR(128) = 'InventorySearchDB';
DECLARE @DataFilePath NVARCHAR(255) = 'C:\SQLData\InventorySearchDB.mdf';
DECLARE @LogFilePath NVARCHAR(255) = 'C:\SQLData\InventorySearchDB_log.ldf';

-- Define deployment environment (e.g., Development, Testing, Production)
DECLARE @Environment NVARCHAR(50) = 'Development';  -- Set as needed (options: 'Development', 'Testing', 'Production')

-- Environment-specific flags (configurable settings for environment needs)
DECLARE @EnableTDE BIT = CASE WHEN @Environment = 'Production' THEN 1 ELSE 0 END;
DECLARE @EnableRLS BIT = CASE WHEN @Environment IN ('Testing', 'Production') THEN 1 ELSE 0 END;
DECLARE @EnableQueryStore BIT = CASE WHEN @Environment = 'Production' THEN 1 ELSE 0 END;

-- Reporting configuration flags
DECLARE @EnableDetailedReporting BIT = 1;  -- Set to 1 to enable detailed reporting features by default

-- Output setup summary for logging and tracking
PRINT 'Database variables initialized:';
PRINT ' - Database Name: ' + @DatabaseName;
PRINT ' - Environment: ' + @Environment;
PRINT ' - Enable TDE: ' + CAST(@EnableTDE AS NVARCHAR(1));
PRINT ' - Enable RLS: ' + CAST(@EnableRLS AS NVARCHAR(1));
PRINT ' - Enable Query Store: ' + CAST(@EnableQueryStore AS NVARCHAR(1));
PRINT ' - Enable Detailed Reporting: ' + CAST(@EnableDetailedReporting AS NVARCHAR(1));

-- #####################
-- END 1.1.1: Define Database Variables
-- #####################

-- #####################
-- BEGIN 1.1.2: Validate Database Variables and Paths
-- #####################

-- 1. Validate database name: Must contain only alphanumeric characters or underscores, and be under 128 characters
IF @DatabaseName LIKE '%[^a-zA-Z0-9_]%' OR LEN(@DatabaseName) > 128
BEGIN
    PRINT 'Error: Database name must contain only alphanumeric characters or underscores, and be under 128 characters.';
    THROW 51000, 'Validation failed: Invalid database name.', 1;
END;

-- 2. Validate or set up data file path
DECLARE @DataPathExists INT, @LogPathExists INT;

-- Check if custom data path exists
EXEC xp_fileexist @DataFilePath, @DataPathExists OUTPUT;

IF @DataPathExists = 0
BEGIN
    -- Set to SQL Server default directory if custom path is inaccessible
    DECLARE @DefaultDataPath NVARCHAR(255) = (SELECT physical_name FROM sys.master_files WHERE database_id = 1 AND type = 0);
    SET @DataFilePath = CONCAT(@DefaultDataPath, @DatabaseName, '.mdf');
    PRINT 'Custom data file path inaccessible. Using SQL Server default directory: ' + @DataFilePath;
END
ELSE
BEGIN
    PRINT 'Data file path is accessible: ' + @DataFilePath;
END;

-- 3. Validate or set up log file path
EXEC xp_fileexist @LogFilePath, @LogPathExists OUTPUT;

IF @LogPathExists = 0
BEGIN
    -- Set to SQL Server default directory if custom log path is inaccessible
    DECLARE @DefaultLogPath NVARCHAR(255) = (SELECT physical_name FROM sys.master_files WHERE database_id = 1 AND type = 1);
    SET @LogFilePath = CONCAT(@DefaultLogPath, @DatabaseName, '_log.ldf');
    PRINT 'Custom log file path inaccessible. Using SQL Server default directory: ' + @LogFilePath;
END
ELSE
BEGIN
    PRINT 'Log file path is accessible: ' + @LogFilePath;
END;

-- Output validation success message
PRINT 'Validation completed successfully: Database name and paths are set and valid.';

-- #####################
-- END 1.1.2: Validate Database Variables and Paths
-- #####################

-- #####################
-- BEGIN 1.1.3: Create Database if Not Exists
-- #####################

-- Check if the database already exists
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = @DatabaseName)
BEGIN
    -- Create database with specified data and log paths
    DECLARE @CreateDatabaseSQL NVARCHAR(MAX) = '
        CREATE DATABASE [' + @DatabaseName + ']
        ON PRIMARY 
        (
            NAME = N''' + @DatabaseName + ''', 
            FILENAME = N''' + @DataFilePath + '''
        )
        LOG ON 
        (
            NAME = N''' + @DatabaseName + '_log'', 
            FILENAME = N''' + @LogFilePath + '''
        );
    ';

    EXEC sp_executesql @CreateDatabaseSQL;

    PRINT 'Database "' + @DatabaseName + '" created successfully with data and log files at specified paths.';
END
ELSE
BEGIN
    PRINT 'Database "' + @DatabaseName + '" already exists. Skipping creation step.';
END;

-- #####################
-- END 1.1.3: Create Database if Not Exists
-- #####################

-- #####################
-- BEGIN 1.1.4: Set Initial Recovery Model
-- #####################

-- Ensure context is set to master for modifying the database
USE [master];

-- Set recovery model based on environment setting
DECLARE @SetRecoveryModelSQL NVARCHAR(MAX);

IF @Environment = 'Production'
BEGIN
    SET @SetRecoveryModelSQL = 'ALTER DATABASE [' + @DatabaseName + '] SET RECOVERY FULL;';
    PRINT 'Setting database recovery model to FULL for production environment...';
END
ELSE
BEGIN
    SET @SetRecoveryModelSQL = 'ALTER DATABASE [' + @DatabaseName + '] SET RECOVERY SIMPLE;';
    PRINT 'Setting database recovery model to SIMPLE for development or testing environment...';
END;

-- Execute the dynamic SQL
EXEC sp_executesql @SetRecoveryModelSQL;

PRINT 'Recovery model set successfully.';

-- #####################
-- END 1.1.4: Set Initial Recovery Model
-- #####################

-- #####################
-- BEGIN 1.1.5: Log Preliminary Setup Results
-- #####################

-- Output final summary of preliminary setup configuration
PRINT 'Preliminary Setup Summary:';
PRINT ' - Database Name: ' + @DatabaseName;
PRINT ' - Data File Path: ' + @DataFilePath;
PRINT ' - Log File Path: ' + @LogFilePath;
PRINT ' - Environment: ' + @Environment;

-- Output recovery model based on environment setting
IF @Environment = 'Production'
    PRINT ' - Recovery Model: FULL (Production Environment)';
ELSE
    PRINT ' - Recovery Model: SIMPLE (Development/Testing Environment)';

PRINT 'Preliminary setup completed successfully.';

-- #####################
-- END 1.1.5: Log Preliminary Setup Results
-- #####################

-- #####################
-- BEGIN 1.2.1: Create `core` Schema for Primary Entities
-- #####################

-- Create `core` schema if it doesn't already exist
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'core')
BEGIN
    EXEC('CREATE SCHEMA core');
    PRINT 'Schema "core" created successfully for primary entities.';
END
ELSE
BEGIN
    PRINT 'Schema "core" already exists. Skipping creation step.';
END;

-- #####################
-- END 1.2.1: Create `core` Schema for Primary Entities
-- #####################

-- #####################
-- BEGIN 1.2.2: Create `config` Schema for System-Wide Settings
-- #####################

-- Create `config` schema if it doesn't already exist
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'config')
BEGIN
    EXEC('CREATE SCHEMA config');
    PRINT 'Schema "config" created successfully for system-wide settings.';
END
ELSE
BEGIN
    PRINT 'Schema "config" already exists. Skipping creation step.';
END;

-- #####################
-- END 1.2.2: Create `config` Schema for System-Wide Settings
-- #####################

-- #####################
-- BEGIN 1.2.3: Create `audit` Schema for Logging and Activity Tracking
-- #####################

-- Create `audit` schema if it doesn't already exist
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'audit')
BEGIN
    EXEC('CREATE SCHEMA audit');
    PRINT 'Schema "audit" created successfully for logging and activity tracking.';
END
ELSE
BEGIN
    PRINT 'Schema "audit" already exists. Skipping creation step.';
END;

-- #####################
-- END 1.2.3: Create `audit` Schema for Logging and Activity Tracking
-- #####################

-- #####################
-- BEGIN 1.3.1: Define Environment Variable and Set Environment-Specific Flags
-- #####################

-- Assign the environment variable to control specific settings (options: Development, Testing, Production)
SET @Environment = 'Development';

-- Set environment-specific flags for configurations (TDE, RLS, Query Store)
SET @EnableTDE = CASE WHEN @Environment = 'Production' THEN 1 ELSE 0 END;
SET @EnableRLS = CASE WHEN @Environment IN ('Testing', 'Production') THEN 1 ELSE 0 END;
SET @EnableQueryStore = 1;  -- Enable Query Store universally, but manage it per environment in later configurations

-- Output environment and flag configuration for logging
PRINT 'Environment and flags configured:';
PRINT ' - Environment: ' + @Environment;
PRINT ' - Enable TDE: ' + CAST(@EnableTDE AS NVARCHAR(1));
PRINT ' - Enable RLS: ' + CAST(@EnableRLS AS NVARCHAR(1));
PRINT ' - Enable Query Store: ' + CAST(@EnableQueryStore AS NVARCHAR(1));

-- #####################
-- END 1.3.1: Define Environment Variable and Set Environment-Specific Flags
-- #####################

-- #####################
-- BEGIN 1.3.2: Apply Environment-Specific Configurations (TDE, RLS, etc.)
-- #####################

-- Ensure master database context for encryption setup
USE [master];

-- 1. Set up Transparent Data Encryption (TDE) universally, enabling only in Production if specified
IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
BEGIN
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'StrongMasterKeyPassword!123';
    PRINT 'Master key created successfully.';
END;

IF NOT EXISTS (SELECT * FROM sys.certificates WHERE name = 'InventorySearchCert')
BEGIN
    CREATE CERTIFICATE InventorySearchCert WITH SUBJECT = 'Inventory Search Database Encryption';
    PRINT 'Certificate created successfully.';
END;

-- Configure TDE for InventorySearchDB
USE [InventorySearchDB];
IF NOT EXISTS (SELECT * FROM sys.dm_database_encryption_keys WHERE database_id = DB_ID(@DatabaseName))
BEGIN
    CREATE DATABASE ENCRYPTION KEY WITH ALGORITHM = AES_256 ENCRYPTION BY SERVER CERTIFICATE InventorySearchCert;
    IF @EnableTDE = 1
    BEGIN
        ALTER DATABASE [InventorySearchDB] SET ENCRYPTION ON;
        PRINT 'TDE enabled for InventorySearchDB in Production environment.';
    END
    ELSE
    BEGIN
        PRINT 'TDE setup completed, but not enabled in non-Production environment.';
    END;
END
ELSE
BEGIN
    PRINT 'Database encryption key already exists.';
END;

-- 2. Apply Row-Level Security (RLS) configuration universally but enable later in environment-specific tables
IF @EnableRLS = 1
BEGIN
    PRINT 'Row-Level Security (RLS) will be configured for specific tables in later steps.';
END;

-- 3. Enable Query Store universally for reporting and tracking
ALTER DATABASE [InventorySearchDB] SET QUERY_STORE = ON;
PRINT 'Query Store enabled for InventorySearchDB for all environments.';

-- #####################
-- END 1.3.2: Apply Environment-Specific Configurations (TDE, RLS, etc.)
-- #####################

-- #####################
-- BEGIN 1.3.3: Log Environment Configuration Status
-- #####################

-- Output a summary of environment configuration
PRINT 'Environment Configuration Summary:';
PRINT ' - Environment: ' + @Environment;

-- Transparent Data Encryption (TDE) Status
IF @EnableTDE = 1
    PRINT ' - Transparent Data Encryption (TDE): Enabled';
ELSE
    PRINT ' - Transparent Data Encryption (TDE): Not enabled for non-Production environments';

-- Row-Level Security (RLS) Status
IF @EnableRLS = 1
    PRINT ' - Row-Level Security (RLS): Enabled for applicable tables';
ELSE
    PRINT ' - Row-Level Security (RLS): Not enabled';

-- Query Store Status
PRINT ' - Query Store: Enabled for all environments';

PRINT 'Environment-specific configuration completed successfully.';

-- #####################
-- END 1.3.3: Log Environment Configuration Status
-- #####################

-- #####################
-- BEGIN 1.4.1: Set Compatibility Level According to SQL Server Version
-- #####################

-- Get SQL Server version and set appropriate compatibility level
DECLARE @SQLVersion INT = CONVERT(INT, SERVERPROPERTY('ProductMajorVersion'));
DECLARE @CompatibilityLevel INT;

-- Set compatibility level based on SQL Server version
IF @SQLVersion >= 15  -- SQL Server 2019
    SET @CompatibilityLevel = 150;
ELSE IF @SQLVersion = 14  -- SQL Server 2017
    SET @CompatibilityLevel = 140;
ELSE IF @SQLVersion = 13  -- SQL Server 2016
    SET @CompatibilityLevel = 130;
ELSE
    SET @CompatibilityLevel = 120;  -- Default for older versions

-- Apply the compatibility level to the database
DECLARE @SetCompatibilitySQL NVARCHAR(100) = 'ALTER DATABASE [' + @DatabaseName + '] SET COMPATIBILITY_LEVEL = ' + CAST(@CompatibilityLevel AS NVARCHAR(3));
EXEC sp_executesql @SetCompatibilitySQL;

PRINT 'Database compatibility level set to ' + CAST(@CompatibilityLevel AS NVARCHAR(3)) + ' based on SQL Server version ' + CAST(@SQLVersion AS NVARCHAR(3));

-- #####################
-- END 1.4.1: Set Compatibility Level According to SQL Server Version
-- #####################

-- #####################
-- BEGIN 1.4.2: Enable ANSI Settings (ANSI_NULLS, ANSI_PADDING, QUOTED_IDENTIFIER)
-- #####################

-- Set ANSI_NULLS, ANSI_PADDING, and QUOTED_IDENTIFIER to ON for the database
ALTER DATABASE [InventorySearchDB] SET ANSI_NULLS ON;
ALTER DATABASE [InventorySearchDB] SET ANSI_PADDING ON;
ALTER DATABASE [InventorySearchDB] SET QUOTED_IDENTIFIER ON;

PRINT 'ANSI settings enabled: ANSI_NULLS, ANSI_PADDING, QUOTED_IDENTIFIER set to ON.';

-- #####################
-- END 1.4.2: Enable ANSI Settings (ANSI_NULLS, ANSI_PADDING, QUOTED_IDENTIFIER)
-- #####################

-- #####################
-- BEGIN 1.4.3: Log Compatibility and ANSI Settings Status
-- #####################

-- Log compatibility level setting
DECLARE @CurrentCompatibilityLevel INT = (SELECT compatibility_level FROM sys.databases WHERE name = @DatabaseName);
PRINT 'Database compatibility level confirmed as ' + CAST(@CurrentCompatibilityLevel AS NVARCHAR(3)) + '.';

-- Log ANSI settings
PRINT 'ANSI settings status:';
PRINT ' - ANSI_NULLS: ON';
PRINT ' - ANSI_PADDING: ON';
PRINT ' - QUOTED_IDENTIFIER: ON';

PRINT 'Compatibility and ANSI settings configured successfully.';

-- #####################
-- END 1.4.3: Log Compatibility and ANSI Settings Status
-- #####################

-- #####################
-- BEGIN 1.5.1: Validate Required Permissions for Current User
-- #####################

-- Check if the current user has sysadmin or dbcreator roles
DECLARE @IsSysAdmin BIT = ISNULL(IS_SRVROLEMEMBER('sysadmin'), 0);
DECLARE @IsDBCreator BIT = ISNULL(IS_SRVROLEMEMBER('dbcreator'), 0);

-- Validate permissions and output result
IF @IsSysAdmin = 1 OR @IsDBCreator = 1
BEGIN
    PRINT 'Permission check passed: Current user has sufficient permissions (sysadmin or dbcreator).';
END
ELSE
BEGIN
    PRINT 'Error: Insufficient permissions. Current user must be a sysadmin or dbcreator to run this script.';
    THROW 51003, 'Permission check failed: Insufficient permissions for database setup.', 1;
END;

-- #####################
-- END 1.5.1: Validate Required Permissions for Current User
-- #####################

-- #####################
-- BEGIN 1.5.2: Create Initial Roles (Admin, Internal, Public)
-- #####################

-- Create Admin role if it doesn't exist
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE type = 'R' AND name = 'Admin')
BEGIN
    CREATE ROLE [Admin];
    PRINT 'Role "Admin" created successfully.';
END
ELSE
BEGIN
    PRINT 'Role "Admin" already exists. Skipping creation.';
END;

-- Create Internal role if it doesn't exist
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE type = 'R' AND name = 'Internal')
BEGIN
    CREATE ROLE [Internal];
    PRINT 'Role "Internal" created successfully.';
END
ELSE
BEGIN
    PRINT 'Role "Internal" already exists. Skipping creation.';
END;

-- Create Public role if it doesn't exist
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE type = 'R' AND name = 'Public')
BEGIN
    CREATE ROLE [Public];
    PRINT 'Role "Public" created successfully.';
END
ELSE
BEGIN
    PRINT 'Role "Public" already exists. Skipping creation.';
END;

-- #####################
-- END 1.5.2: Create Initial Roles (Admin, Internal, Public)
-- #####################

-- #####################
-- BEGIN 1.5.3: Output and Log Role Setup Status
-- #####################

-- Check existence of each role and output confirmation
PRINT 'Role Setup Summary:';

IF EXISTS (SELECT * FROM sys.database_principals WHERE type = 'R' AND name = 'Admin')
    PRINT ' - Admin role: Confirmed';
ELSE
    PRINT ' - Admin role: Not found';

IF EXISTS (SELECT * FROM sys.database_principals WHERE type = 'R' AND name = 'Internal')
    PRINT ' - Internal role: Confirmed';
ELSE
    PRINT ' - Internal role: Not found';

IF EXISTS (SELECT * FROM sys.database_principals WHERE type = 'R' AND name = 'Public')
    PRINT ' - Public role: Confirmed';
ELSE
    PRINT ' - Public role: Not found';

PRINT 'Initial roles verification completed.';

-- #####################
-- END 1.5.3: Output and Log Role Setup Status
-- #####################

-- #####################
-- Ensure `core` Schema Exists
-- #####################

-- Create `core` schema if it doesn't exist
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'core')
BEGIN
    EXEC('CREATE SCHEMA core');
    PRINT 'Schema "core" created successfully.';
END
ELSE
BEGIN
    PRINT 'Schema "core" already exists. Skipping creation.';
END;

-- #####################
-- END Ensure `core` Schema Exists
-- #####################

-- #####################
-- BEGIN 2.1: Create `Type` Table with Enhanced Security and Configurability
-- #####################

-- Create `Type` table in `core` schema if it doesn't already exist
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Type' AND schema_id = SCHEMA_ID('core'))
BEGIN
    CREATE TABLE core.Type (
        TypeId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
        ParentTypeId UNIQUEIDENTIFIER NULL,
        TypeName NVARCHAR(255) NOT NULL UNIQUE,
        MetaData NVARCHAR(MAX) NULL,  -- JSON data stored as NVARCHAR for flexibility
        MetaDataSearch AS CAST(MetaData AS NVARCHAR(MAX)) PERSISTED,  -- For computed searchability
        RoleLevel AS JSON_VALUE(MetaData, '$.RoleLevel') PERSISTED,   -- Extract RoleLevel if needed
        ActiveStatus AS JSON_VALUE(MetaData, '$.Active') PERSISTED,   -- Derived Active status
        CreatedBy UNIQUEIDENTIFIER NOT NULL,
        CreatedAt DATETIME DEFAULT GETUTCDATE(),
        UpdatedBy UNIQUEIDENTIFIER NULL,
        UpdatedAt DATETIME DEFAULT GETUTCDATE(),
        CONSTRAINT FK_Type_ParentType FOREIGN KEY (ParentTypeId) REFERENCES core.Type(TypeId)
            ON DELETE NO ACTION ON UPDATE NO ACTION  -- Prevent cascading to avoid cycles
    );

    -- Apply data masking to the MetaData column for added security
    PRINT 'Applying dynamic data masking to MetaData column in core.Type table...';
    ALTER TABLE core.Type ALTER COLUMN MetaData ADD MASKED WITH (FUNCTION = 'default()');
    
    PRINT 'Table "core.Type" created successfully with security and data masking configurations.';
END
ELSE
BEGIN
    -- Apply dynamic data masking to MetaData if the table exists but MetaData isn't yet masked
    IF COLUMNPROPERTY(OBJECT_ID('core.Type'), 'MetaData', 'IsMasked') = 0
    BEGIN
        PRINT 'Adding dynamic data masking to MetaData column in existing "core.Type" table...';
        ALTER TABLE core.Type ALTER COLUMN MetaData NVARCHAR(MAX) MASKED WITH (FUNCTION = 'default()');
    END
    ELSE
    BEGIN
        PRINT 'Table "core.Type" already exists with MetaData column masked. Skipping creation and masking.';
    END
END;

-- #####################
-- END 2.1: Create `Type` Table with Enhanced Security and Configurability
-- #####################


-- #####################
-- BEGIN 2.2: Create `Entity` Table
-- #####################

-- Create `Entity` table in `core` schema if it doesn't already exist
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Entity' AND schema_id = SCHEMA_ID('core'))
BEGIN
    CREATE TABLE core.Entity (
        EntityId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
        ParentEntityId UNIQUEIDENTIFIER NULL,
        TypeId UNIQUEIDENTIFIER NOT NULL,
        Name NVARCHAR(255) NOT NULL,
        MetaData NVARCHAR(MAX) MASKED WITH (FUNCTION = 'default()') NULL,  -- JSON data with dynamic masking
        MetaDataSearch AS CAST(MetaData AS NVARCHAR(MAX)) PERSISTED,       -- For computed searchability
        TenantId AS JSON_VALUE(MetaData, '$.tenantId') PERSISTED,          -- Derived tenant ID
        CreatedBy UNIQUEIDENTIFIER NOT NULL,
        CreatedAt DATETIME DEFAULT GETUTCDATE(),
        UpdatedBy UNIQUEIDENTIFIER NULL,
        UpdatedAt DATETIME DEFAULT GETUTCDATE(),
        CONSTRAINT FK_Entity_ParentEntity FOREIGN KEY (ParentEntityId) REFERENCES core.Entity(EntityId)
            ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT FK_Entity_Type FOREIGN KEY (TypeId) REFERENCES core.Type(TypeId)
    );
    PRINT 'Table "core.Entity" created successfully with MetaData configured for dynamic masking.';
END
ELSE
BEGIN
    -- Apply dynamic data masking to MetaData if the table exists but MetaData isn't yet masked
    IF COLUMNPROPERTY(OBJECT_ID('core.Entity'), 'MetaData', 'IsMasked') = 0
    BEGIN
        PRINT 'Adding dynamic data masking to MetaData column in existing "core.Entity" table...';
        ALTER TABLE core.Entity ALTER COLUMN MetaData NVARCHAR(MAX) MASKED WITH (FUNCTION = 'default()');
    END
    ELSE
    BEGIN
        PRINT 'Table "core.Entity" already exists with MetaData column masked. Skipping creation and masking.';
    END
END;

-- #####################
-- END 2.2: Create `Entity` Table
-- #####################


-- #####################
-- BEGIN 2.3: Create `Attribute` Table
-- #####################

-- Create `Attribute` table in `core` schema if it doesn't already exist
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Attribute' AND schema_id = SCHEMA_ID('core'))
BEGIN
    CREATE TABLE core.Attribute (
        AttributeId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
        EntityId UNIQUEIDENTIFIER NOT NULL,
        ParentAttributeId UNIQUEIDENTIFIER NULL,
        FieldName NVARCHAR(255) NOT NULL,
        FieldValue NVARCHAR(MAX) NULL,
        MetaData NVARCHAR(MAX) NULL,  -- JSON data stored as NVARCHAR for additional attribute details
		MetaDataSearch AS CAST(MetaData AS NVARCHAR(MAX)) PERSISTED,   -- For computed searchability
        CreatedBy UNIQUEIDENTIFIER NOT NULL,
        CreatedAt DATETIME DEFAULT GETUTCDATE(),
        UpdatedBy UNIQUEIDENTIFIER NULL,
        UpdatedAt DATETIME DEFAULT GETUTCDATE(),
        CONSTRAINT FK_Attribute_Entity FOREIGN KEY (EntityId) REFERENCES core.Entity(EntityId)
            ON DELETE CASCADE ON UPDATE CASCADE,
        CONSTRAINT FK_Attribute_ParentAttribute FOREIGN KEY (ParentAttributeId) REFERENCES core.Attribute(AttributeId)
            ON DELETE NO ACTION ON UPDATE NO ACTION
    );
    PRINT 'Table "core.Attribute" created successfully for entity-specific metadata.';
END
ELSE
BEGIN
    -- Apply dynamic data masking to MetaData if the table exists but MetaData isn't yet masked
    IF COLUMNPROPERTY(OBJECT_ID('core.Attribute'), 'MetaData', 'IsMasked') = 0
    BEGIN
        PRINT 'Adding dynamic data masking to MetaData column in existing "core.Attribute" table...';
        ALTER TABLE core.Attribute ALTER COLUMN MetaData NVARCHAR(MAX) MASKED WITH (FUNCTION = 'default()');
    END
    ELSE
    BEGIN
        PRINT 'Table "core.Attribute" already exists with MetaData column masked. Skipping creation and masking.';
    END
END;

-- #####################
-- END 2.3: Create `Attribute` Table
-- #####################

-- #####################
-- BEGIN 2.4: Create `Relationship` Table
-- #####################

-- Create `Relationship` table in `core` schema if it doesn't already exist
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Relationship' AND schema_id = SCHEMA_ID('core'))
BEGIN
    CREATE TABLE core.Relationship (
        RelationshipId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
        ParentEntityId UNIQUEIDENTIFIER NOT NULL,
        ChildEntityId UNIQUEIDENTIFIER NOT NULL,
        TypeId UNIQUEIDENTIFIER NOT NULL,
        MetaData NVARCHAR(MAX) NULL,  -- JSON data stored as NVARCHAR for additional relationship details
		MetaDataSearch AS CAST(MetaData AS NVARCHAR(MAX)) PERSISTED,   -- For computed searchability
        CreatedBy UNIQUEIDENTIFIER NOT NULL,
        CreatedAt DATETIME DEFAULT GETUTCDATE(),
        UpdatedBy UNIQUEIDENTIFIER NULL,
        UpdatedAt DATETIME DEFAULT GETUTCDATE(),
        
        -- Foreign key constraints
        CONSTRAINT FK_Relationship_ParentEntity FOREIGN KEY (ParentEntityId) REFERENCES core.Entity(EntityId)
            ON DELETE CASCADE ON UPDATE CASCADE,
        CONSTRAINT FK_Relationship_ChildEntity FOREIGN KEY (ChildEntityId) REFERENCES core.Entity(EntityId)
            ON DELETE NO ACTION ON UPDATE NO ACTION,  -- Avoid multiple cascade paths
        CONSTRAINT FK_Relationship_Type FOREIGN KEY (TypeId) REFERENCES core.Type(TypeId)
    );
    PRINT 'Table "core.Relationship" created successfully to define entity connections.';
END
ELSE
BEGIN
    -- Apply dynamic data masking to MetaData if the table exists but MetaData isn't yet masked
    IF COLUMNPROPERTY(OBJECT_ID('core.Relationship'), 'MetaData', 'IsMasked') = 0
    BEGIN
        PRINT 'Adding dynamic data masking to MetaData column in existing "core.Relationship" table...';
        ALTER TABLE core.Relationship ALTER COLUMN MetaData NVARCHAR(MAX) MASKED WITH (FUNCTION = 'default()');
    END
    ELSE
    BEGIN
        PRINT 'Table "core.Relationship" already exists with MetaData column masked. Skipping creation and masking.';
    END
END;

-- #####################
-- END 2.4: Create `Relationship` Table
-- #####################

-- #####################
-- BEGIN 2.5: Create `Activity` Table
-- #####################

-- Create `Activity` table in `audit` schema if it doesn't already exist
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Activity' AND schema_id = SCHEMA_ID('audit'))
BEGIN
    CREATE TABLE audit.Activity (
        ActivityId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
        ParentActivityId UNIQUEIDENTIFIER NULL,
        EntityId UNIQUEIDENTIFIER NULL,
        TypeId UNIQUEIDENTIFIER NULL,
        OldValue NVARCHAR(MAX) NULL,
        NewValue NVARCHAR(MAX) NULL,
        ErrorMessage NVARCHAR(MAX) NULL,
        ErrorCode NVARCHAR(50) NULL,
        ErrorSeverity NVARCHAR(50) NULL,
        SchemaVersion NVARCHAR(50) NULL,
        MetaData NVARCHAR(MAX) NULL,  -- JSON data stored as NVARCHAR for additional relationship details
		MetaDataSearch AS CAST(MetaData AS NVARCHAR(MAX)) PERSISTED,   -- For computed searchability
        ChangeDescription NVARCHAR(MAX) NULL,
        ChangeType NVARCHAR(50) NULL,
        PerformedBy UNIQUEIDENTIFIER NOT NULL,
        PerformedAt DATETIME DEFAULT GETUTCDATE(),
        
        -- Foreign key constraints
        CONSTRAINT FK_Activity_ParentActivity FOREIGN KEY (ParentActivityId) REFERENCES audit.Activity(ActivityId)
            ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT FK_Activity_Entity FOREIGN KEY (EntityId) REFERENCES core.Entity(EntityId)
            ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT FK_Activity_Type FOREIGN KEY (TypeId) REFERENCES core.Type(TypeId)
    );
    PRINT 'Table "audit.Activity" created successfully to track actions and changes for auditing.';
END
ELSE
BEGIN
    -- Apply dynamic data masking to MetaData if the table exists but MetaData isn't yet masked
    IF COLUMNPROPERTY(OBJECT_ID('audit.Activity'), 'MetaData', 'IsMasked') = 0
    BEGIN
        PRINT 'Adding dynamic data masking to MetaData column in existing "audit.Activity" table...';
        ALTER TABLE audit.Activity ALTER COLUMN MetaData NVARCHAR(MAX) MASKED WITH (FUNCTION = 'default()');
    END
    ELSE
    BEGIN
        PRINT 'Table "audit.Activity" already exists with MetaData column masked. Skipping creation and masking.';
    END
END;

-- #####################
-- END 2.5: Create `Activity` Table
-- #####################

-- #####################
-- BEGIN 2.6: Create `Configuration` Table
-- #####################

-- Create `Configuration` table in `config` schema if it doesn't already exist
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Configuration' AND schema_id = SCHEMA_ID('config'))
BEGIN
    CREATE TABLE config.Configuration (
        ConfigId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
        ParentConfigId UNIQUEIDENTIFIER NULL,
        ConfigKey NVARCHAR(255) NOT NULL UNIQUE,
        ConfigValue NVARCHAR(MAX) NULL,
        ConfigData NVARCHAR(MAX) NULL,  -- JSON data stored as NVARCHAR for flexible settings
		ConfigDataSearch AS CAST(ConfigData AS NVARCHAR(MAX)) PERSISTED,   -- For computed searchability
        CreatedBy UNIQUEIDENTIFIER NOT NULL,
        CreatedAt DATETIME DEFAULT GETUTCDATE(),
        UpdatedBy UNIQUEIDENTIFIER NULL,
        UpdatedAt DATETIME DEFAULT GETUTCDATE(),
        CONSTRAINT FK_Configuration_ParentConfig FOREIGN KEY (ParentConfigId) REFERENCES config.Configuration(ConfigId)
            ON DELETE NO ACTION ON UPDATE NO ACTION
    );
    PRINT 'Table "config.Configuration" created successfully for system-wide settings.';
END
ELSE
BEGIN
    -- Apply dynamic data masking to MetaData if the table exists but MetaData isn't yet masked
    IF COLUMNPROPERTY(OBJECT_ID('config.Configuration'), 'MetaData', 'IsMasked') = 0
    BEGIN
        PRINT 'Adding dynamic data masking to MetaData column in existing "config.Configuration" table...';
        ALTER TABLE config.Configuration ALTER COLUMN MetaData NVARCHAR(MAX) MASKED WITH (FUNCTION = 'default()');
    END
    ELSE
    BEGIN
        PRINT 'Table "config.Configuration" already exists with MetaData column masked. Skipping creation and masking.';
    END
END;

-- #####################
-- END 2.6: Create `Configuration` Table
-- #####################

-- #####################
-- BEGIN 3.1: Index Setup for Core Tables
-- #####################

BEGIN TRY
    -- Indexes for `Type` table
    IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID('core.Type') AND name = 'IDX_Type_TypeName')
    BEGIN
        CREATE NONCLUSTERED INDEX IDX_Type_TypeName ON core.Type (TypeName);
        PRINT 'Success: Index "IDX_Type_TypeName" created on "core.Type" for optimized type searches.';
    END
    ELSE
    BEGIN
        PRINT 'Info: Index "IDX_Type_TypeName" already exists on "core.Type". Skipping creation.';
    END

    -- Indexes for `Entity` table
    IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID('core.Entity') AND name = 'IDX_Entity_TypeId')
    BEGIN
        CREATE NONCLUSTERED INDEX IDX_Entity_TypeId ON core.Entity (TypeId);
        PRINT 'Success: Index "IDX_Entity_TypeId" created on "core.Entity" to optimize entity-type lookups.';
    END
    ELSE
    BEGIN
        PRINT 'Info: Index "IDX_Entity_TypeId" already exists on "core.Entity". Skipping creation.';
    END

    -- Indexes for `Attribute` table
    IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID('core.Attribute') AND name = 'IDX_Attribute_EntityId')
    BEGIN
        CREATE NONCLUSTERED INDEX IDX_Attribute_EntityId ON core.Attribute (EntityId);
        PRINT 'Success: Index "IDX_Attribute_EntityId" created on "core.Attribute" for optimized attribute lookups by entity.';
    END
    ELSE
    BEGIN
        PRINT 'Info: Index "IDX_Attribute_EntityId" already exists on "core.Attribute". Skipping creation.';
    END

    -- Indexes for `Relationship` table
    IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID('core.Relationship') AND name = 'IDX_Relationship_ParentEntityId_ChildEntityId')
    BEGIN
        CREATE NONCLUSTERED INDEX IDX_Relationship_ParentEntityId_ChildEntityId ON core.Relationship (ParentEntityId, ChildEntityId);
        PRINT 'Success: Index "IDX_Relationship_ParentEntityId_ChildEntityId" created on "core.Relationship" to optimize relationship lookups.';
    END
    ELSE
    BEGIN
        PRINT 'Info: Index "IDX_Relationship_ParentEntityId_ChildEntityId" already exists on "core.Relationship". Skipping creation.';
    END

    -- Indexes for `Activity` table in `audit` schema
    IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID('audit.Activity') AND name = 'IDX_Activity_EntityId')
    BEGIN
        CREATE NONCLUSTERED INDEX IDX_Activity_EntityId ON audit.Activity (EntityId);
        PRINT 'Success: Index "IDX_Activity_EntityId" created on "audit.Activity" for optimized activity tracking by entity.';
    END
    ELSE
    BEGIN
        PRINT 'Info: Index "IDX_Activity_EntityId" already exists on "audit.Activity". Skipping creation.';
    END

    PRINT 'Index setup for core tables completed successfully.';
END TRY
BEGIN CATCH
    PRINT 'Error: Index creation failed on one or more tables. Error details: ' + ERROR_MESSAGE();
END CATCH;

-- #####################
-- END 3.1: Index Setup for Core Tables
-- #####################

-- #####################
-- Create ErrorLog Table if it doesn't already exist
-- #####################

IF OBJECT_ID('audit.ErrorLog', 'U') IS NULL
BEGIN
    CREATE TABLE audit.ErrorLog (
        ErrorId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        ErrorMessage NVARCHAR(4000),
        ErrorCode INT,
        ErrorSeverity NVARCHAR(50),
        ErrorContext NVARCHAR(255),
        SqlStatement NVARCHAR(MAX),
        LoggedAt DATETIME DEFAULT GETUTCDATE()
    );
    PRINT 'Table "audit.ErrorLog" created successfully to capture error details.';
END
ELSE
BEGIN
    PRINT 'Table "audit.ErrorLog" already exists. Skipping creation.';
END;

GO

-- #####################
-- Create LogError Stored Procedure
-- #####################

-- Drop existing LogError procedure if it exists
IF OBJECT_ID('LogError', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE LogError;
    PRINT 'Existing LogError procedure dropped.';
END
GO

-- Create the LogError stored procedure
CREATE PROCEDURE LogError
    @ErrorMessage NVARCHAR(4000),
    @ErrorCode INT,
    @ErrorSeverity NVARCHAR(50),
    @ErrorContext NVARCHAR(255),
    @SqlStatement NVARCHAR(MAX) = NULL
AS
BEGIN
    -- Insert the error details into the ErrorLog table
    INSERT INTO audit.ErrorLog (ErrorMessage, ErrorCode, ErrorSeverity, ErrorContext, SqlStatement, LoggedAt)
    VALUES (@ErrorMessage, @ErrorCode, @ErrorSeverity, @ErrorContext, @SqlStatement, GETUTCDATE());

    PRINT 'Error logged successfully in "audit.ErrorLog".';
END;

GO

-- #####################
-- BEGIN 3.2.1.1: Create `AddEntity` Stored Procedure
-- #####################

-- Drop the existing AddEntity procedure if it already exists
IF OBJECT_ID('AddEntity', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE AddEntity;
    PRINT 'Existing AddEntity procedure dropped.';
END
GO

-- Create the AddEntity stored procedure
CREATE PROCEDURE AddEntity
    @JsonData NVARCHAR(MAX),         -- JSON data for entity insertion
    @UserRoleId UNIQUEIDENTIFIER      -- User role for validating access rights
AS
BEGIN
    -- Variable declarations
    DECLARE @Sql NVARCHAR(MAX);                                   -- SQL command to execute dynamically
    DECLARE @EntityId UNIQUEIDENTIFIER = NEWID();                 -- Unique ID for new entity, using NEWID() for compatibility
    DECLARE @TypeId UNIQUEIDENTIFIER;                             -- Parsed TypeId from JSON data
    DECLARE @Name NVARCHAR(255);                                  -- Parsed Name from JSON data
    DECLARE @AssociatedEntityId UNIQUEIDENTIFIER;                 -- Associated EntityId (if any) from JSON data
    DECLARE @MetaData NVARCHAR(MAX);                              -- Parsed metadata from JSON data
    DECLARE @CreatedBy UNIQUEIDENTIFIER = CONVERT(UNIQUEIDENTIFIER, SESSION_CONTEXT(N'UserId'));  -- User ID initiating action

    PRINT 'Starting AddEntity procedure. Validating permissions and data...';

    -- Check user role for permission to insert entities
    IF NOT EXISTS (SELECT 1 FROM UserRoles WHERE UserRoleId = @UserRoleId AND CanInsertEntities = 1)
    BEGIN
        PRINT 'Access Denied: User role does not have permission to insert entities.';
        RAISERROR('Access Denied: User role does not have permission to insert entities.', 16, 1);
        RETURN;
    END

    PRINT 'Access validated. Parsing and validating JSON data...';

    -- Parse JSON data into variables
    SET @TypeId = JSON_VALUE(@JsonData, '$.TypeId');
    SET @Name = JSON_VALUE(@JsonData, '$.Name');
    SET @AssociatedEntityId = JSON_VALUE(@JsonData, '$.AssociatedEntityId');
    SET @MetaData = JSON_QUERY(@JsonData, '$.MetaData');

    -- Validate required fields
    IF @TypeId IS NULL OR @Name IS NULL
    BEGIN
        PRINT 'Validation Error: TypeId and Name are required fields.';
        RAISERROR('Validation Error: TypeId and Name are required fields.', 16, 1);
        RETURN;
    END

    PRINT 'Required fields are present. Checking for duplicate entity...';

    -- Check if an entity with the same TypeId and Name already exists
    IF EXISTS (SELECT 1 FROM core.Entity WHERE TypeId = @TypeId AND Name = @Name)
    BEGIN
        PRINT 'Error: An entity with the specified TypeId and Name already exists.';
        RAISERROR('Duplicate Entry: An entity with the specified TypeId and Name already exists.', 16, 1);
        RETURN;
    END

    BEGIN TRY
        PRINT 'No duplicates found. Beginning transaction for entity insertion...';
        BEGIN TRANSACTION;  -- Start transaction

        -- Construct and execute INSERT statement securely
        SET @Sql = 'INSERT INTO core.Entity (EntityId, TypeId, Name, AssociatedEntityId, MetaData, CreatedBy, CreatedAt) ' +
                   'VALUES (@EntityId, @TypeId, @Name, @AssociatedEntityId, @MetaData, @CreatedBy, GETUTCDATE());';

        EXEC sp_executesql @Sql,
            N'@EntityId UNIQUEIDENTIFIER, @TypeId UNIQUEIDENTIFIER, @Name NVARCHAR(255), @AssociatedEntityId UNIQUEIDENTIFIER, @MetaData NVARCHAR(MAX), @CreatedBy UNIQUEIDENTIFIER',
            @EntityId=@EntityId, @TypeId=@TypeId, @Name=@Name, @AssociatedEntityId=@AssociatedEntityId, @MetaData=@MetaData, @CreatedBy=@CreatedBy;

        COMMIT TRANSACTION;  -- Commit if successful
        PRINT 'Entity record created successfully. Transaction committed.';
    END TRY
    BEGIN CATCH
        -- Error handling with rollback and logging
        ROLLBACK TRANSACTION;  -- Rollback on error
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorCode INT = ERROR_NUMBER();
        DECLARE @ErrorSeverity NVARCHAR(50) = ERROR_SEVERITY();

        PRINT 'Error encountered during entity insertion: ' + @ErrorMessage;

        -- Log the error details into the ErrorLog table
        EXEC LogError @ErrorMessage, @ErrorCode, @ErrorSeverity, 'AddEntity Procedure', @Sql;
        
        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH
END;

GO

-- Confirmation message after creating AddEntity
PRINT 'AddEntity stored procedure created successfully.';

-- #####################
-- END 3.2.1.1: Create `AddEntity` Stored Procedure
-- #####################

-- #####################
-- BEGIN 3.2.1.2: Create `UpdateEntity` Stored Procedure
-- #####################

-- Drop the existing UpdateEntity procedure if it already exists
IF OBJECT_ID('UpdateEntity', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE UpdateEntity;
    PRINT 'Existing UpdateEntity procedure dropped.';
END
GO

-- Create the UpdateEntity stored procedure
CREATE PROCEDURE UpdateEntity
    @JsonData NVARCHAR(MAX),         -- JSON data containing updated entity information
    @UserRoleId UNIQUEIDENTIFIER      -- User role for validating access rights
AS
BEGIN
    -- Variable declarations
    DECLARE @Sql NVARCHAR(MAX);                                   -- SQL command to execute dynamically
    DECLARE @EntityId UNIQUEIDENTIFIER;                           -- EntityId from JSON data for the entity to update
    DECLARE @TypeId UNIQUEIDENTIFIER;                             -- Updated TypeId from JSON data
    DECLARE @Name NVARCHAR(255);                                  -- Updated Name from JSON data
    DECLARE @AssociatedEntityId UNIQUEIDENTIFIER;                 -- Updated AssociatedEntityId (if any) from JSON data
    DECLARE @MetaData NVARCHAR(MAX);                              -- Updated metadata from JSON data
    DECLARE @UpdatedBy UNIQUEIDENTIFIER = CONVERT(UNIQUEIDENTIFIER, SESSION_CONTEXT(N'UserId'));  -- User ID initiating action

    PRINT 'Starting UpdateEntity procedure. Validating permissions and data...';

    -- Check user role for permission to update entities
    IF NOT EXISTS (SELECT 1 FROM UserRoles WHERE UserRoleId = @UserRoleId AND CanUpdateEntities = 1)
    BEGIN
        PRINT 'Access Denied: User role does not have permission to update entities.';
        RAISERROR('Access Denied: User role does not have permission to update entities.', 16, 1);
        RETURN;
    END

    PRINT 'Access validated. Parsing and validating JSON data...';

    -- Parse JSON data into variables
    SET @EntityId = JSON_VALUE(@JsonData, '$.EntityId');
    SET @TypeId = JSON_VALUE(@JsonData, '$.TypeId');
    SET @Name = JSON_VALUE(@JsonData, '$.Name');
    SET @AssociatedEntityId = JSON_VALUE(@JsonData, '$.AssociatedEntityId');
    SET @MetaData = JSON_QUERY(@JsonData, '$.MetaData');

    -- Validate required fields
    IF @EntityId IS NULL OR @TypeId IS NULL OR @Name IS NULL
    BEGIN
        PRINT 'Validation Error: EntityId, TypeId, and Name are required fields.';
        RAISERROR('Validation Error: EntityId, TypeId, and Name are required fields.', 16, 1);
        RETURN;
    END

    PRINT 'Required fields are present. Checking for existence of entity...';

    -- Check if the specified entity exists
    IF NOT EXISTS (SELECT 1 FROM core.Entity WHERE EntityId = @EntityId)
    BEGIN
        PRINT 'Error: The specified entity does not exist.';
        RAISERROR('Entity Not Found: The specified entity does not exist.', 16, 1);
        RETURN;
    END

    BEGIN TRY
        PRINT 'Entity exists. Beginning transaction for entity update...';
        BEGIN TRANSACTION;  -- Start transaction

        -- Construct and execute UPDATE statement securely
        SET @Sql = 'UPDATE core.Entity ' +
                   'SET TypeId = @TypeId, Name = @Name, AssociatedEntityId = @AssociatedEntityId, MetaData = @MetaData, UpdatedBy = @UpdatedBy, UpdatedAt = GETUTCDATE() ' +
                   'WHERE EntityId = @EntityId;';

        EXEC sp_executesql @Sql,
            N'@EntityId UNIQUEIDENTIFIER, @TypeId UNIQUEIDENTIFIER, @Name NVARCHAR(255), @AssociatedEntityId UNIQUEIDENTIFIER, @MetaData NVARCHAR(MAX), @UpdatedBy UNIQUEIDENTIFIER',
            @EntityId=@EntityId, @TypeId=@TypeId, @Name=@Name, @AssociatedEntityId=@AssociatedEntityId, @MetaData=@MetaData, @UpdatedBy=@UpdatedBy;

        COMMIT TRANSACTION;  -- Commit if successful
        PRINT 'Entity record updated successfully. Transaction committed.';
    END TRY
    BEGIN CATCH
        -- Error handling with rollback and logging
        ROLLBACK TRANSACTION;  -- Rollback on error
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorCode INT = ERROR_NUMBER();
        DECLARE @ErrorSeverity NVARCHAR(50) = ERROR_SEVERITY();

        PRINT 'Error encountered during entity update: ' + @ErrorMessage;

        -- Log the error details into the ErrorLog table
        EXEC LogError @ErrorMessage, @ErrorCode, @ErrorSeverity, 'UpdateEntity Procedure', @Sql;
        
        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH
END;

GO

-- Confirmation message after creating UpdateEntity
PRINT 'UpdateEntity stored procedure created successfully.';

-- #####################
-- END 3.2.1.2: Create `UpdateEntity` Stored Procedure
-- #####################

-- #####################
-- BEGIN 3.2.1.3: Create `DeleteEntity` Stored Procedure
-- #####################

-- Drop the existing DeleteEntity procedure if it already exists
IF OBJECT_ID('DeleteEntity', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE DeleteEntity;
    PRINT 'Existing DeleteEntity procedure dropped.';
END
GO

-- Create the DeleteEntity stored procedure
CREATE PROCEDURE DeleteEntity
    @EntityId UNIQUEIDENTIFIER,       -- EntityId of the entity to delete
    @UserRoleId UNIQUEIDENTIFIER      -- User role for validating access rights
AS
BEGIN
    -- Variable declarations
    DECLARE @Sql NVARCHAR(MAX);                                   -- SQL command to execute dynamically
    DECLARE @DeletedBy UNIQUEIDENTIFIER = CONVERT(UNIQUEIDENTIFIER, SESSION_CONTEXT(N'UserId'));  -- User ID initiating action

    PRINT 'Starting DeleteEntity procedure. Validating permissions and data...';

    -- Check user role for permission to delete entities
    IF NOT EXISTS (SELECT 1 FROM UserRoles WHERE UserRoleId = @UserRoleId AND CanDeleteEntities = 1)
    BEGIN
        PRINT 'Access Denied: User role does not have permission to delete entities.';
        RAISERROR('Access Denied: User role does not have permission to delete entities.', 16, 1);
        RETURN;
    END

    PRINT 'Access validated. Checking existence of specified entity...';

    -- Check if the specified entity exists
    IF NOT EXISTS (SELECT 1 FROM core.Entity WHERE EntityId = @EntityId)
    BEGIN
        PRINT 'Error: The specified entity does not exist.';
        RAISERROR('Entity Not Found: The specified entity does not exist.', 16, 1);
        RETURN;
    END

    BEGIN TRY
        PRINT 'Entity exists. Beginning transaction for entity deletion...';
        BEGIN TRANSACTION;  -- Start transaction

        -- Construct and execute DELETE statement securely
        SET @Sql = 'DELETE FROM core.Entity WHERE EntityId = @EntityId;';

        EXEC sp_executesql @Sql,
            N'@EntityId UNIQUEIDENTIFIER',
            @EntityId=@EntityId;

        COMMIT TRANSACTION;  -- Commit if successful
        PRINT 'Entity record deleted successfully. Transaction committed.';
    END TRY
    BEGIN CATCH
        -- Error handling with rollback and logging
        ROLLBACK TRANSACTION;  -- Rollback on error
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorCode INT = ERROR_NUMBER();
        DECLARE @ErrorSeverity NVARCHAR(50) = ERROR_SEVERITY();

        PRINT 'Error encountered during entity deletion: ' + @ErrorMessage;

        -- Log the error details into the ErrorLog table
        EXEC LogError @ErrorMessage, @ErrorCode, @ErrorSeverity, 'DeleteEntity Procedure', @Sql;
        
        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH
END;

GO

-- Confirmation message after creating DeleteEntity
PRINT 'DeleteEntity stored procedure created successfully.';

-- #####################
-- END 3.2.1.3: Create `DeleteEntity` Stored Procedure
-- #####################

-- #####################
-- BEGIN 3.2.1.4: Create `SelectEntity` Stored Procedure
-- #####################

-- Drop the existing SelectEntity procedure if it already exists
IF OBJECT_ID('SelectEntity', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE SelectEntity;
    PRINT 'Existing SelectEntity procedure dropped.';
END
GO

-- Create the SelectEntity stored procedure
CREATE PROCEDURE SelectEntity
    @EntityId UNIQUEIDENTIFIER = NULL,  -- Optional EntityId filter
    @TypeId UNIQUEIDENTIFIER = NULL,    -- Optional TypeId filter
    @Name NVARCHAR(255) = NULL,         -- Optional Name filter
    @UserRoleId UNIQUEIDENTIFIER        -- User role for validating access rights
AS
BEGIN
    -- Variable declarations
    DECLARE @Sql NVARCHAR(MAX);                                   -- SQL command to execute dynamically

    PRINT 'Starting SelectEntity procedure. Validating permissions...';

    -- Check user role for permission to view entities
    IF NOT EXISTS (SELECT 1 FROM UserRoles WHERE UserRoleId = @UserRoleId AND CanViewEntities = 1)
    BEGIN
        PRINT 'Access Denied: User role does not have permission to view entities.';
        RAISERROR('Access Denied: User role does not have permission to view entities.', 16, 1);
        RETURN;
    END

    PRINT 'Access validated. Constructing query for entity retrieval...';

    -- Construct the SELECT query with optional filters
    SET @Sql = 'SELECT * FROM core.Entity WHERE 1=1';

    -- Apply filters if provided
    IF @EntityId IS NOT NULL
        SET @Sql += ' AND EntityId = @EntityId';

    IF @TypeId IS NOT NULL
        SET @Sql += ' AND TypeId = @TypeId';

    IF @Name IS NOT NULL
        SET @Sql += ' AND Name LIKE ''%'' + @Name + ''%''';

    BEGIN TRY
        PRINT 'Executing query for entity retrieval...';

        -- Execute the constructed SELECT query with filters
        EXEC sp_executesql @Sql,
            N'@EntityId UNIQUEIDENTIFIER, @TypeId UNIQUEIDENTIFIER, @Name NVARCHAR(255)',
            @EntityId=@EntityId, @TypeId=@TypeId, @Name=@Name;

        PRINT 'Entity retrieval successful.';
    END TRY
    BEGIN CATCH
        -- Error handling and logging
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorCode INT = ERROR_NUMBER();
        DECLARE @ErrorSeverity NVARCHAR(50) = ERROR_SEVERITY();

        PRINT 'Error encountered during entity retrieval: ' + @ErrorMessage;

        -- Log the error details into the ErrorLog table
        EXEC LogError @ErrorMessage, @ErrorCode, @ErrorSeverity, 'SelectEntity Procedure', @Sql;
        
        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH
END;

GO

-- Confirmation message after creating SelectEntity
PRINT 'SelectEntity stored procedure created successfully.';

-- #####################
-- END 3.2.1.4: Create `SelectEntity` Stored Procedure
-- #####################
-- #####################
-- BEGIN 3.2.2.1: Create `GetEntitySummaryReport` Stored Procedure with Advanced Date Filtering
-- #####################

-- Drop the existing GetEntitySummaryReport procedure if it already exists
IF OBJECT_ID('GetEntitySummaryReport', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE GetEntitySummaryReport;
    PRINT 'Existing GetEntitySummaryReport procedure dropped.';
END
GO

-- Create a type for date ranges to support multiple date range filtering
IF TYPE_ID('DateRangeTableType') IS NULL
BEGIN
    CREATE TYPE DateRangeTableType AS TABLE (
        StartDate DATETIME,
        EndDate DATETIME
    );
    PRINT 'Table type "DateRangeTableType" created for handling multiple date ranges.';
END;
GO

-- Create the GetEntitySummaryReport stored procedure with advanced date filtering
CREATE PROCEDURE GetEntitySummaryReport
    @TypeId UNIQUEIDENTIFIER = NULL,               -- Optional TypeId filter
    @CreatedBy UNIQUEIDENTIFIER = NULL,            -- Optional CreatedBy filter
    @CreatedAt DATETIME = NULL,                    -- Optional single CreatedAt date filter
    @CreatedAtRanges DateRangeTableType READONLY,  -- Optional multiple CreatedAt date ranges
    @UpdatedAt DATETIME = NULL,                    -- Optional single UpdatedAt date filter
    @UpdatedAtRanges DateRangeTableType READONLY   -- Optional multiple UpdatedAt date ranges
AS
BEGIN
    -- Variable declarations
    DECLARE @Sql NVARCHAR(MAX);                                   -- SQL command to execute dynamically

    PRINT 'Starting GetEntitySummaryReport procedure. Constructing query with advanced date filtering...';

    -- Construct the SELECT query with optional filters
    SET @Sql = 'SELECT TypeId, COUNT(*) AS EntityCount, MIN(CreatedAt) AS FirstCreatedAt, MAX(CreatedAt) AS LastCreatedAt, ' +
               'MIN(UpdatedAt) AS FirstUpdatedAt, MAX(UpdatedAt) AS LastUpdatedAt ' +
               'FROM core.Entity WHERE 1=1';

    -- Apply filters if provided
    IF @TypeId IS NOT NULL
        SET @Sql += ' AND TypeId = @TypeId';

    IF @CreatedBy IS NOT NULL
        SET @Sql += ' AND CreatedBy = @CreatedBy';

    IF @CreatedAt IS NOT NULL
        SET @Sql += ' AND CreatedAt = @CreatedAt';

    IF @UpdatedAt IS NOT NULL
        SET @Sql += ' AND UpdatedAt = @UpdatedAt';

    -- Apply CreatedAt date ranges if provided
    IF EXISTS (SELECT 1 FROM @CreatedAtRanges)
    BEGIN
        SET @Sql += ' AND EXISTS (SELECT 1 FROM @CreatedAtRanges AS CR ' +
                    'WHERE core.Entity.CreatedAt BETWEEN CR.StartDate AND CR.EndDate)';
    END

    -- Apply UpdatedAt date ranges if provided
    IF EXISTS (SELECT 1 FROM @UpdatedAtRanges)
    BEGIN
        SET @Sql += ' AND EXISTS (SELECT 1 FROM @UpdatedAtRanges AS UR ' +
                    'WHERE core.Entity.UpdatedAt BETWEEN UR.StartDate AND UR.EndDate)';
    END

    -- Group by TypeId for summary
    SET @Sql += ' GROUP BY TypeId';

    BEGIN TRY
        PRINT 'Executing entity summary report query with advanced date filtering...';

        -- Execute the constructed SELECT query with filters
        EXEC sp_executesql @Sql,
            N'@TypeId UNIQUEIDENTIFIER, @CreatedBy UNIQUEIDENTIFIER, @CreatedAt DATETIME, @UpdatedAt DATETIME, @CreatedAtRanges DateRangeTableType READONLY, @UpdatedAtRanges DateRangeTableType READONLY',
            @TypeId=@TypeId, @CreatedBy=@CreatedBy, @CreatedAt=@CreatedAt, @UpdatedAt=@UpdatedAt, @CreatedAtRanges=@CreatedAtRanges, @UpdatedAtRanges=@UpdatedAtRanges;

        PRINT 'Entity summary report generated successfully with advanced date filtering.';
    END TRY
    BEGIN CATCH
        -- Error handling and logging
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorCode INT = ERROR_NUMBER();
        DECLARE @ErrorSeverity NVARCHAR(50) = ERROR_SEVERITY();

        PRINT 'Error encountered during entity summary report generation: ' + @ErrorMessage;

        -- Log the error details into the ErrorLog table
        EXEC LogError @ErrorMessage, @ErrorCode, @ErrorSeverity, 'GetEntitySummaryReport Procedure', @Sql;
        
        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH
END;

GO

-- Confirmation message after creating GetEntitySummaryReport
PRINT 'GetEntitySummaryReport stored procedure created successfully with advanced date filtering.';

-- #####################
-- END 3.2.2.1: Create `GetEntitySummaryReport` Stored Procedure with Advanced Date Filtering
-- #####################

-- #####################
-- BEGIN 3.2.2.2: Create `GetEntityActivityLogReport` Stored Procedure
-- #####################

-- Drop the existing GetEntityActivityLogReport procedure if it already exists
IF OBJECT_ID('GetEntityActivityLogReport', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE GetEntityActivityLogReport;
    PRINT 'Existing GetEntityActivityLogReport procedure dropped.';
END
GO

-- Create a type for date ranges to support multiple date range filtering in activity logs
IF TYPE_ID('ActivityDateRangeTableType') IS NULL
BEGIN
    CREATE TYPE ActivityDateRangeTableType AS TABLE (
        StartDate DATETIME,
        EndDate DATETIME
    );
    PRINT 'Table type "ActivityDateRangeTableType" created for handling multiple date ranges in activity logs.';
END;
GO

-- Create the GetEntityActivityLogReport stored procedure
CREATE PROCEDURE GetEntityActivityLogReport
    @EntityId UNIQUEIDENTIFIER = NULL,               -- Optional filter by EntityId
    @ActivityType NVARCHAR(50) = NULL,               -- Optional filter by ActivityType (e.g., INSERT, UPDATE, DELETE)
    @PerformedBy UNIQUEIDENTIFIER = NULL,            -- Optional filter by user who performed the activity
    @PerformedAt DATETIME = NULL,                    -- Optional single date filter for activity date
    @PerformedAtRanges ActivityDateRangeTableType READONLY  -- Optional multiple date ranges for activity date filtering
AS
BEGIN
    -- Variable declarations
    DECLARE @Sql NVARCHAR(MAX);                                   -- SQL command to execute dynamically

    PRINT 'Starting GetEntityActivityLogReport procedure. Constructing query with configurable date and activity filtering...';

    -- Construct the SELECT query with optional filters
    SET @Sql = 'SELECT ActivityId, EntityId, TypeId, ActivityType, OldValue, NewValue, PerformedBy, PerformedAt, MetaData ' +
               'FROM audit.ActivityLog WHERE 1=1';

    -- Apply filters if provided
    IF @EntityId IS NOT NULL
        SET @Sql += ' AND EntityId = @EntityId';

    IF @ActivityType IS NOT NULL
        SET @Sql += ' AND ActivityType = @ActivityType';

    IF @PerformedBy IS NOT NULL
        SET @Sql += ' AND PerformedBy = @PerformedBy';

    IF @PerformedAt IS NOT NULL
        SET @Sql += ' AND PerformedAt = @PerformedAt';

    -- Apply PerformedAt date ranges if provided
    IF EXISTS (SELECT 1 FROM @PerformedAtRanges)
    BEGIN
        SET @Sql += ' AND EXISTS (SELECT 1 FROM @PerformedAtRanges AS DR ' +
                    'WHERE audit.ActivityLog.PerformedAt BETWEEN DR.StartDate AND DR.EndDate)';
    END

    -- Order by PerformedAt for chronological listing
    SET @Sql += ' ORDER BY PerformedAt';

    BEGIN TRY
        PRINT 'Executing activity log report query with advanced filtering...';

        -- Execute the constructed SELECT query with filters
        EXEC sp_executesql @Sql,
            N'@EntityId UNIQUEIDENTIFIER, @ActivityType NVARCHAR(50), @PerformedBy UNIQUEIDENTIFIER, @PerformedAt DATETIME, @PerformedAtRanges ActivityDateRangeTableType READONLY',
            @EntityId=@EntityId, @ActivityType=@ActivityType, @PerformedBy=@PerformedBy, @PerformedAt=@PerformedAt, @PerformedAtRanges=@PerformedAtRanges;

        PRINT 'Entity activity log report generated successfully with advanced filtering.';
    END TRY
    BEGIN CATCH
        -- Error handling and logging
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorCode INT = ERROR_NUMBER();
        DECLARE @ErrorSeverity NVARCHAR(50) = ERROR_SEVERITY();

        PRINT 'Error encountered during activity log report generation: ' + @ErrorMessage;

        -- Log the error details into the ErrorLog table
        EXEC LogError @ErrorMessage, @ErrorCode, @ErrorSeverity, 'GetEntityActivityLogReport Procedure', @Sql;
        
        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH
END;

GO

-- Confirmation message after creating GetEntityActivityLogReport
PRINT 'GetEntityActivityLogReport stored procedure created successfully with advanced filtering.';

-- #####################
-- END 3.2.2.2: Create `GetEntityActivityLogReport` Stored Procedure
-- #####################

-- #####################
-- BEGIN 3.2.2.3: Create `GetEntityRelationshipReport` Stored Procedure
-- #####################

-- Drop the existing GetEntityRelationshipReport procedure if it already exists
IF OBJECT_ID('GetEntityRelationshipReport', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE GetEntityRelationshipReport;
    PRINT 'Existing GetEntityRelationshipReport procedure dropped.';
END
GO

-- Create the GetEntityRelationshipReport stored procedure
CREATE PROCEDURE GetEntityRelationshipReport
    @EntityId UNIQUEIDENTIFIER = NULL,           -- Optional filter for a specific entity
    @RelationshipTypeId UNIQUEIDENTIFIER = NULL, -- Optional filter by relationship type
    @FromEntityId UNIQUEIDENTIFIER = NULL,       -- Optional filter for originating entity in relationships
    @ToEntityId UNIQUEIDENTIFIER = NULL          -- Optional filter for target entity in relationships
AS
BEGIN
    -- Variable declarations
    DECLARE @Sql NVARCHAR(MAX);                                   -- SQL command to execute dynamically

    PRINT 'Starting GetEntityRelationshipReport procedure. Constructing query with entity relationship filtering...';

    -- Construct the SELECT query with optional filters
    SET @Sql = 'SELECT RelationshipId, FromEntityId, ToEntityId, RelationshipTypeId, RelationshipStatus, MetaData, CreatedAt ' +
               'FROM core.Relationship WHERE 1=1';

    -- Apply filters if provided
    IF @EntityId IS NOT NULL
        SET @Sql += ' AND (FromEntityId = @EntityId OR ToEntityId = @EntityId)';

    IF @RelationshipTypeId IS NOT NULL
        SET @Sql += ' AND RelationshipTypeId = @RelationshipTypeId';

    IF @FromEntityId IS NOT NULL
        SET @Sql += ' AND FromEntityId = @FromEntityId';

    IF @ToEntityId IS NOT NULL
        SET @Sql += ' AND ToEntityId = @ToEntityId';

    -- Order by CreatedAt for chronological relationship details
    SET @Sql += ' ORDER BY CreatedAt';

    BEGIN TRY
        PRINT 'Executing entity relationship report query...';

        -- Execute the constructed SELECT query with filters
        EXEC sp_executesql @Sql,
            N'@EntityId UNIQUEIDENTIFIER, @RelationshipTypeId UNIQUEIDENTIFIER, @FromEntityId UNIQUEIDENTIFIER, @ToEntityId UNIQUEIDENTIFIER',
            @EntityId=@EntityId, @RelationshipTypeId=@RelationshipTypeId, @FromEntityId=@FromEntityId, @ToEntityId=@ToEntityId;

        PRINT 'Entity relationship report generated successfully.';
    END TRY
    BEGIN CATCH
        -- Error handling and logging
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorCode INT = ERROR_NUMBER();
        DECLARE @ErrorSeverity NVARCHAR(50) = ERROR_SEVERITY();

        PRINT 'Error encountered during entity relationship report generation: ' + @ErrorMessage;

        -- Log the error details into the ErrorLog table
        EXEC LogError @ErrorMessage, @ErrorCode, @ErrorSeverity, 'GetEntityRelationshipReport Procedure', @Sql;
        
        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH
END;

GO

-- Confirmation message after creating GetEntityRelationshipReport
PRINT 'GetEntityRelationshipReport stored procedure created successfully with relationship filtering.';

-- #####################
-- END 3.2.2.3: Create `GetEntityRelationshipReport` Stored Procedure
-- #####################

-- #####################
-- BEGIN 3.2.3.1: Create `RebuildIndexes` Stored Procedure
-- #####################

-- Drop the existing RebuildIndexes procedure if it already exists
IF OBJECT_ID('RebuildIndexes', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE RebuildIndexes;
    PRINT 'Existing RebuildIndexes procedure dropped.';
END
GO

-- Create the RebuildIndexes stored procedure
CREATE PROCEDURE RebuildIndexes
    @TableName NVARCHAR(255) = NULL,       -- Optional: specify a table to rebuild indexes
    @FragmentationThreshold FLOAT = 30.0   -- Minimum fragmentation level to trigger a rebuild (default is 30%)
AS
BEGIN
    -- Variable declarations
    DECLARE @Sql NVARCHAR(MAX);                                   -- SQL command to execute dynamically
    DECLARE @IndexName NVARCHAR(255);                             -- Index name
    DECLARE @SchemaName NVARCHAR(255);                            -- Schema name
    DECLARE @CurrentTableName NVARCHAR(255);                      -- Table name

    PRINT 'Starting RebuildIndexes procedure. Checking for fragmented indexes...';

    -- Construct the query to get fragmented indexes
    SET @Sql = '
    SELECT OBJECT_SCHEMA_NAME(IPS.object_id) AS SchemaName,
           OBJECT_NAME(IPS.object_id) AS TableName,
           SI.name AS IndexName,
           IPS.avg_fragmentation_in_percent AS Fragmentation
    FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, ''LIMITED'') AS IPS
    INNER JOIN sys.indexes AS SI ON IPS.object_id = SI.object_id AND IPS.index_id = SI.index_id
    WHERE IPS.avg_fragmentation_in_percent >= @FragmentationThreshold
    AND IPS.index_id > 0';  -- Avoid heap tables with no clustered index

    -- Add optional filter for specific table
    IF @TableName IS NOT NULL
        SET @Sql += ' AND OBJECT_NAME(IPS.object_id) = @TableName';

    -- Execute the query to find fragmented indexes
    DECLARE @FragmentedIndexes TABLE (SchemaName NVARCHAR(255), TableName NVARCHAR(255), IndexName NVARCHAR(255), Fragmentation FLOAT);
    INSERT INTO @FragmentedIndexes (SchemaName, TableName, IndexName, Fragmentation)
    EXEC sp_executesql @Sql, N'@FragmentationThreshold FLOAT, @TableName NVARCHAR(255)', @FragmentationThreshold=@FragmentationThreshold, @TableName=@TableName;

    -- Loop through each fragmented index and rebuild
    DECLARE index_cursor CURSOR FOR
        SELECT SchemaName, TableName, IndexName
        FROM @FragmentedIndexes;

    OPEN index_cursor;

    FETCH NEXT FROM index_cursor INTO @SchemaName, @CurrentTableName, @IndexName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        PRINT 'Rebuilding index: ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@CurrentTableName) + '.' + QUOTENAME(@IndexName);

        -- Construct the rebuild command
        SET @Sql = 'ALTER INDEX ' + QUOTENAME(@IndexName) + ' ON ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@CurrentTableName) + ' REBUILD';

        -- Execute the rebuild command
        EXEC sp_executesql @Sql;

        FETCH NEXT FROM index_cursor INTO @SchemaName, @CurrentTableName, @IndexName;
    END

    CLOSE index_cursor;
    DEALLOCATE index_cursor;

    PRINT 'RebuildIndexes procedure completed successfully.';
END;

GO

-- Confirmation message after creating RebuildIndexes
PRINT 'RebuildIndexes stored procedure created successfully.';

-- #####################
-- END 3.2.3.1: Create `RebuildIndexes` Stored Procedure
-- #####################

-- #####################
-- BEGIN 3.2.3.2: Create `ArchiveOldLogs` Stored Procedure
-- #####################

-- Drop the existing ArchiveOldLogs procedure if it already exists
IF OBJECT_ID('ArchiveOldLogs', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE ArchiveOldLogs;
    PRINT 'Existing ArchiveOldLogs procedure dropped.';
END
GO

-- Create archive tables if they do not exist
IF OBJECT_ID('audit.ActivityLogArchive', 'U') IS NULL
BEGIN
    CREATE TABLE audit.ActivityLogArchive (
        ActivityId UNIQUEIDENTIFIER PRIMARY KEY,
        EntityId UNIQUEIDENTIFIER,
        TypeId UNIQUEIDENTIFIER,
        ActivityType NVARCHAR(50),
        OldValue NVARCHAR(MAX),
        NewValue NVARCHAR(MAX),
        PerformedBy UNIQUEIDENTIFIER,
        PerformedAt DATETIME,
        MetaData NVARCHAR(MAX)
    );
    PRINT 'Table "audit.ActivityLogArchive" created for archiving activity logs.';
END;

IF OBJECT_ID('audit.ErrorLogArchive', 'U') IS NULL
BEGIN
    CREATE TABLE audit.ErrorLogArchive (
        ErrorId UNIQUEIDENTIFIER PRIMARY KEY,
        ErrorMessage NVARCHAR(4000),
        ErrorCode INT,
        ErrorSeverity NVARCHAR(50),
        ErrorContext NVARCHAR(255),
        SqlStatement NVARCHAR(MAX),
        LoggedAt DATETIME
    );
    PRINT 'Table "audit.ErrorLogArchive" created for archiving error logs.';
END;
GO

-- Create the ArchiveOldLogs stored procedure
CREATE PROCEDURE ArchiveOldLogs
    @RetentionPeriodDays INT = 90,    -- Number of days to retain logs, default is 90 days
    @Archive BIT = 1                  -- Flag to indicate archiving (1) or direct deletion (0)
AS
BEGIN
    DECLARE @CutoffDate DATETIME = DATEADD(DAY, -@RetentionPeriodDays, GETUTCDATE());
    DECLARE @Sql NVARCHAR(MAX);

    PRINT 'Starting ArchiveOldLogs procedure. Processing logs older than ' + CONVERT(NVARCHAR, @CutoffDate);

    -- Archive or delete old ActivityLog records
    IF @Archive = 1
    BEGIN
        PRINT 'Archiving old ActivityLog records...';
        INSERT INTO audit.ActivityLogArchive (ActivityId, EntityId, TypeId, ActivityType, OldValue, NewValue, PerformedBy, PerformedAt, MetaData)
        SELECT ActivityId, EntityId, TypeId, ActivityType, OldValue, NewValue, PerformedBy, PerformedAt, MetaData
        FROM audit.ActivityLog
        WHERE PerformedAt < @CutoffDate;

        PRINT 'Deleting archived ActivityLog records...';
        DELETE FROM audit.ActivityLog
        WHERE PerformedAt < @CutoffDate;
    END
    ELSE
    BEGIN
        PRINT 'Deleting old ActivityLog records without archiving...';
        DELETE FROM audit.ActivityLog
        WHERE PerformedAt < @CutoffDate;
    END

    -- Archive or delete old ErrorLog records
    IF @Archive = 1
    BEGIN
        PRINT 'Archiving old ErrorLog records...';
        INSERT INTO audit.ErrorLogArchive (ErrorId, ErrorMessage, ErrorCode, ErrorSeverity, ErrorContext, SqlStatement, LoggedAt)
        SELECT ErrorId, ErrorMessage, ErrorCode, ErrorSeverity, ErrorContext, SqlStatement, LoggedAt
        FROM audit.ErrorLog
        WHERE LoggedAt < @CutoffDate;

        PRINT 'Deleting archived ErrorLog records...';
        DELETE FROM audit.ErrorLog
        WHERE LoggedAt < @CutoffDate;
    END
    ELSE
    BEGIN
        PRINT 'Deleting old ErrorLog records without archiving...';
        DELETE FROM audit.ErrorLog
        WHERE LoggedAt < @CutoffDate;
    END

    PRINT 'ArchiveOldLogs procedure completed successfully.';
END;

GO

-- Confirmation message after creating ArchiveOldLogs
PRINT 'ArchiveOldLogs stored procedure created successfully with configurable retention period.';

-- #####################
-- END 3.2.3.2: Create `ArchiveOldLogs` Stored Procedure
-- #####################

-- #####################
-- BEGIN 3.2.3.3: Create `ClearTempData` Stored Procedure
-- #####################

-- Drop the existing ClearTempData procedure if it already exists
IF OBJECT_ID('ClearTempData', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE ClearTempData;
    PRINT 'Existing ClearTempData procedure dropped.';
END
GO

-- Create the ClearTempData stored procedure
CREATE PROCEDURE ClearTempData
    @TableNames NVARCHAR(MAX)        -- Comma-separated list of table names to clear
AS
BEGIN
    -- Variable declarations
    DECLARE @Sql NVARCHAR(MAX);                                   -- SQL command to execute dynamically
    DECLARE @TableName NVARCHAR(255);                             -- Individual table name

    PRINT 'Starting ClearTempData procedure. Clearing specified temporary tables...';

    -- Iterate over comma-separated list of table names
    DECLARE table_cursor CURSOR FOR
        SELECT TRIM(value) AS TableName
        FROM STRING_SPLIT(@TableNames, ',');

    OPEN table_cursor;

    FETCH NEXT FROM table_cursor INTO @TableName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        PRINT 'Clearing data from temporary table: ' + QUOTENAME(@TableName);

        -- Construct and execute DELETE statement for each table
        SET @Sql = 'DELETE FROM ' + QUOTENAME(@TableName);

        BEGIN TRY
            EXEC sp_executesql @Sql;
            PRINT 'Data cleared successfully from ' + QUOTENAME(@TableName) + '.';
        END TRY
        BEGIN CATCH
            DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
            DECLARE @ErrorCode INT = ERROR_NUMBER();
            DECLARE @ErrorSeverity NVARCHAR(50) = ERROR_SEVERITY();

            PRINT 'Error encountered while clearing data from ' + QUOTENAME(@TableName) + ': ' + @ErrorMessage;

            -- Log the error details into the ErrorLog table
            EXEC LogError @ErrorMessage, @ErrorCode, @ErrorSeverity, 'ClearTempData Procedure', @Sql;

            RAISERROR(@ErrorMessage, 16, 1);
        END CATCH

        FETCH NEXT FROM table_cursor INTO @TableName;
    END

    CLOSE table_cursor;
    DEALLOCATE table_cursor;

    PRINT 'ClearTempData procedure completed successfully.';
END;

GO

-- Confirmation message after creating ClearTempData
PRINT 'ClearTempData stored procedure created successfully for managing temporary data tables.';

-- #####################
-- END 3.2.3.3: Create `ClearTempData` Stored Procedure
-- #####################

-- #####################
-- BEGIN 3.2.4.1: Create `ApplyDataMasking` Stored Procedure
-- #####################

-- Drop the existing ApplyDataMasking procedure if it already exists
IF OBJECT_ID('ApplyDataMasking', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE ApplyDataMasking;
    PRINT 'Existing ApplyDataMasking procedure dropped.';
END
GO

-- Create the ApplyDataMasking stored procedure
CREATE PROCEDURE ApplyDataMasking
    @TableName NVARCHAR(255),        -- Table name to apply data masking
    @ColumnName NVARCHAR(255),       -- Column name to apply data masking
    @MaskingType NVARCHAR(50) = 'default'   -- Masking type (default, email, custom string)
AS
BEGIN
    DECLARE @Sql NVARCHAR(MAX);                                   -- SQL command to execute dynamically

    PRINT 'Starting ApplyDataMasking procedure. Applying masking on specified column...';

    -- Define masking expression based on type
    IF @MaskingType = 'email'
        SET @Sql = 'ALTER TABLE ' + QUOTENAME(@TableName) + ' ALTER COLUMN ' + QUOTENAME(@ColumnName) + ' ADD MASKED WITH (FUNCTION = ''email()'')';
    ELSE IF @MaskingType = 'custom string'
        SET @Sql = 'ALTER TABLE ' + QUOTENAME(@TableName) + ' ALTER COLUMN ' + QUOTENAME(@ColumnName) + ' ADD MASKED WITH (FUNCTION = ''partial(1, "XXXX", 1)'')';
    ELSE
        SET @Sql = 'ALTER TABLE ' + QUOTENAME(@TableName) + ' ALTER COLUMN ' + QUOTENAME(@ColumnName) + ' ADD MASKED WITH (FUNCTION = ''default()'')';

    -- Execute the masking command
    BEGIN TRY
        EXEC sp_executesql @Sql;
        PRINT 'Data masking applied successfully on ' + QUOTENAME(@TableName) + '.' + QUOTENAME(@ColumnName) + ' with ' + @MaskingType + ' masking type.';
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorCode INT = ERROR_NUMBER();
        DECLARE @ErrorSeverity NVARCHAR(50) = ERROR_SEVERITY();

        PRINT 'Error encountered while applying data masking on ' + QUOTENAME(@TableName) + '.' + QUOTENAME(@ColumnName) + ': ' + @ErrorMessage;

        -- Log the error details into the ErrorLog table
        EXEC LogError @ErrorMessage, @ErrorCode, @ErrorSeverity, 'ApplyDataMasking Procedure', @Sql;

        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH
END;

GO

-- Confirmation message after creating ApplyDataMasking
PRINT 'ApplyDataMasking stored procedure created successfully for data protection.';

-- #####################
-- END 3.2.4.1: Create `ApplyDataMasking` Stored Procedure
-- #####################

-- #####################
-- BEGIN 3.2.4.2: Create `SetupRowLevelSecurity` Stored Procedure with Enhanced Consistency
-- #####################

-- Drop the existing SetupRowLevelSecurity procedure if it already exists
IF OBJECT_ID('core.SetupRowLevelSecurity', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE core.SetupRowLevelSecurity;
    PRINT 'Existing SetupRowLevelSecurity procedure dropped.';
END
GO

-- Drop the security predicate function if it already exists
IF OBJECT_ID('core.fn_UserCanAccessEntity', 'IF') IS NOT NULL
BEGIN
    DROP FUNCTION core.fn_UserCanAccessEntity;
    PRINT 'Existing security predicate function fn_UserCanAccessEntity dropped.';
END
GO

-- Create the security predicate function for row-level security
PRINT 'Creating security predicate function core.fn_UserCanAccessEntity...';
GO
CREATE FUNCTION core.fn_UserCanAccessEntity(@EntityId UNIQUEIDENTIFIER)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
(
    SELECT 1 AS AccessGranted
    FROM core.Entity AS UserEntity
    JOIN core.Relationship AS Rel ON UserEntity.EntityId = Rel.ChildEntityId
    JOIN core.Type AS RoleType ON Rel.TypeId = RoleType.TypeId
    WHERE Rel.ParentEntityId = @EntityId
      AND UserEntity.EntityId = CONVERT(UNIQUEIDENTIFIER, SESSION_CONTEXT(N'UserId'))
      AND RoleType.TypeName = 'UserRole'
);
GO
PRINT 'Security predicate function core.fn_UserCanAccessEntity created successfully.';
GO

-- Create the SetupRowLevelSecurity stored procedure
CREATE PROCEDURE core.SetupRowLevelSecurity
    @TableName NVARCHAR(255),              -- Table name to apply RLS
    @PolicyName NVARCHAR(255) = NULL       -- Optional name for RLS policy
AS
BEGIN
    DECLARE @Sql NVARCHAR(MAX);                                   -- SQL command to execute dynamically
    DECLARE @EffectivePolicyName NVARCHAR(255);                   -- Policy name

    -- Generate default policy name if none provided
    SET @EffectivePolicyName = ISNULL(@PolicyName, 'rls_policy_' + @TableName);

    PRINT 'Starting SetupRowLevelSecurity procedure. Configuring RLS for table ' + QUOTENAME(@TableName) + '...';

    -- Drop existing security policy if it exists
    IF EXISTS (SELECT * FROM sys.security_policies WHERE name = @EffectivePolicyName)
    BEGIN
        SET @Sql = 'DROP SECURITY POLICY ' + QUOTENAME(@EffectivePolicyName);
        EXEC sp_executesql @Sql;
        PRINT 'Existing security policy ' + @EffectivePolicyName + ' dropped.';
    END

    BEGIN TRY
        -- Apply RLS policy
        SET @Sql = 'CREATE SECURITY POLICY ' + QUOTENAME(@EffectivePolicyName) +
                   ' ADD FILTER PREDICATE core.fn_UserCanAccessEntity(' + QUOTENAME(@TableName) + '.EntityId) ' +
                   ' ON ' + QUOTENAME(@TableName);

        EXEC sp_executesql @Sql;
        PRINT 'Row-Level Security policy ' + @EffectivePolicyName + ' applied to ' + QUOTENAME(@TableName) + ' successfully.';
    END TRY
    BEGIN CATCH
        -- Error handling and logging
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorCode INT = ERROR_NUMBER();
        DECLARE @ErrorSeverity NVARCHAR(50) = ERROR_SEVERITY();

        PRINT 'Error encountered during RLS setup on ' + QUOTENAME(@TableName) + ': ' + @ErrorMessage;

        -- Log the error details into the ErrorLog table
        EXEC LogError @ErrorMessage, @ErrorCode, @ErrorSeverity, 'SetupRowLevelSecurity Procedure', @Sql;

        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH
END;

GO

-- Confirmation message after creating SetupRowLevelSecurity
PRINT 'SetupRowLevelSecurity stored procedure created successfully for Row-Level Security configuration with consistent error handling and logging.';

-- #####################
-- END 3.2.4.2: Create `SetupRowLevelSecurity` Stored Procedure
-- #####################

-- #####################
-- BEGIN 3.2.4.3: Create `EnableTransparentDataEncryption` Stored Procedure
-- #####################

-- Drop the existing EnableTransparentDataEncryption procedure if it already exists
IF OBJECT_ID('EnableTransparentDataEncryption', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE EnableTransparentDataEncryption;
    PRINT 'Existing EnableTransparentDataEncryption procedure dropped.';
END
GO

-- Create the EnableTransparentDataEncryption stored procedure
CREATE PROCEDURE EnableTransparentDataEncryption
    @DatabaseName NVARCHAR(255),                      -- Target database for TDE
    @BackupCertificatePath NVARCHAR(255)              -- Path to store the encryption certificate backup
AS
BEGIN
    DECLARE @Sql NVARCHAR(MAX);                       -- SQL command for dynamic execution
    DECLARE @EncryptionCertificate NVARCHAR(255);     -- Certificate name
    DECLARE @DatabaseKey NVARCHAR(255);               -- Database master key name

    -- Define certificate and key names based on database
    SET @DatabaseKey = 'DatabaseKey_' + @DatabaseName;
    SET @EncryptionCertificate = 'EncryptionCert_' + @DatabaseName;

    PRINT 'Starting EnableTransparentDataEncryption procedure for database ' + QUOTENAME(@DatabaseName) + '.';

    BEGIN TRY
        -- Step 1: Create Database Master Key if it does not exist
        IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
        BEGIN
            SET @Sql = 'USE ' + QUOTENAME(@DatabaseName) + '; CREATE MASTER KEY ENCRYPTION BY PASSWORD = ''StrongPasswordHere!'';';
            EXEC sp_executesql @Sql;
            PRINT 'Database Master Key created for encryption.';
        END
        ELSE
            PRINT 'Database Master Key already exists.';

        -- Step 2: Create Encryption Certificate if it does not exist
        IF NOT EXISTS (SELECT * FROM sys.certificates WHERE name = @EncryptionCertificate)
        BEGIN
            SET @Sql = 'USE ' + QUOTENAME(@DatabaseName) + '; CREATE CERTIFICATE ' + QUOTENAME(@EncryptionCertificate) +
                       ' WITH SUBJECT = ''Database Encryption Certificate'';';
            EXEC sp_executesql @Sql;
            PRINT 'Encryption certificate created: ' + @EncryptionCertificate;

            -- Backup the certificate
            SET @Sql = 'BACKUP CERTIFICATE ' + QUOTENAME(@EncryptionCertificate) +
                       ' TO FILE = ''' + @BackupCertificatePath + '\' + @EncryptionCertificate + '.cer''' +
                       ' WITH PRIVATE KEY (FILE = ''' + @BackupCertificatePath + '\' + @EncryptionCertificate + '.pvk'', ' +
                       'ENCRYPTION BY PASSWORD = ''StrongBackupPasswordHere!'');';
            EXEC sp_executesql @Sql;
            PRINT 'Encryption certificate backed up to ' + @BackupCertificatePath;
        END
        ELSE
            PRINT 'Encryption certificate already exists.';

        -- Step 3: Enable TDE on the database
        SET @Sql = 'USE ' + QUOTENAME(@DatabaseName) + '; ALTER DATABASE ' + QUOTENAME(@DatabaseName) + ' SET ENCRYPTION ON;';
        EXEC sp_executesql @Sql;
        PRINT 'Transparent Data Encryption enabled on database ' + QUOTENAME(@DatabaseName) + '.';

    END TRY
    BEGIN CATCH
        -- Error handling and logging
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorCode INT = ERROR_NUMBER();
        DECLARE @ErrorSeverity NVARCHAR(50) = ERROR_SEVERITY();

        PRINT 'Error encountered during TDE setup on database ' + QUOTENAME(@DatabaseName) + ': ' + @ErrorMessage;

        -- Log the error details into the ErrorLog table
        EXEC LogError @ErrorMessage, @ErrorCode, @ErrorSeverity, 'EnableTransparentDataEncryption Procedure', @Sql;

        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH
END;

GO

-- Confirmation message after creating EnableTransparentDataEncryption
PRINT 'EnableTransparentDataEncryption stored procedure created successfully with encryption and backup steps.';

-- #####################
-- END 3.2.4.3: Create `EnableTransparentDataEncryption` Stored Procedure
-- #####################

-- #####################
-- BEGIN 3.2.5.1: Create `ArchiveOldRecords` Stored Procedure
-- #####################

-- Drop the existing ArchiveOldRecords procedure if it already exists
IF OBJECT_ID('ArchiveOldRecords', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE ArchiveOldRecords;
    PRINT 'Existing ArchiveOldRecords procedure dropped.';
END
GO

-- Create the ArchiveOldRecords stored procedure
CREATE PROCEDURE ArchiveOldRecords
    @RetentionDate DATETIME,                      -- Archive records older than this date
    @TableName NVARCHAR(255)                      -- Target table for archiving
AS
BEGIN
    DECLARE @ArchiveTable NVARCHAR(255);          -- Archive table name
    DECLARE @Sql NVARCHAR(MAX);                   -- SQL command for dynamic execution

    -- Define archive table name based on original table name
    SET @ArchiveTable = @TableName + '_Archive';

    PRINT 'Starting ArchiveOldRecords procedure for table ' + QUOTENAME(@TableName) + '...';

    -- Ensure archive table exists; create it if necessary
    IF OBJECT_ID(@ArchiveTable, 'U') IS NULL
    BEGIN
        PRINT 'Creating archive table ' + QUOTENAME(@ArchiveTable) + ' for archiving purposes...';
        SET @Sql = 'SELECT * INTO ' + QUOTENAME(@ArchiveTable) +
                   ' FROM ' + QUOTENAME(@TableName) + ' WHERE 1 = 0';
        EXEC sp_executesql @Sql;
        PRINT 'Archive table ' + QUOTENAME(@ArchiveTable) + ' created successfully.';
    END

    -- Move records older than the specified retention date to the archive table
    BEGIN TRY
        PRINT 'Archiving records from ' + QUOTENAME(@TableName) + ' to ' + QUOTENAME(@ArchiveTable) + '...';
        SET @Sql = 'INSERT INTO ' + QUOTENAME(@ArchiveTable) +
                   ' SELECT * FROM ' + QUOTENAME(@TableName) +
                   ' WHERE DateColumn < @RetentionDate';
        EXEC sp_executesql @Sql, N'@RetentionDate DATETIME', @RetentionDate;

        PRINT 'Deleting archived records from ' + QUOTENAME(@TableName) + '...';
        SET @Sql = 'DELETE FROM ' + QUOTENAME(@TableName) + ' WHERE DateColumn < @RetentionDate';
        EXEC sp_executesql @Sql, N'@RetentionDate DATETIME', @RetentionDate;

        PRINT 'Records successfully archived from ' + QUOTENAME(@TableName) + ' to ' + QUOTENAME(@ArchiveTable) + '.';
    END TRY
    BEGIN CATCH
        -- Error handling and logging
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorCode INT = ERROR_NUMBER();
        DECLARE @ErrorSeverity NVARCHAR(50) = ERROR_SEVERITY();

        PRINT 'Error encountered during archiving from ' + QUOTENAME(@TableName) + ': ' + @ErrorMessage;

        -- Log the error details into the ErrorLog table
        EXEC LogError @ErrorMessage, @ErrorCode, @ErrorSeverity, 'ArchiveOldRecords Procedure', @Sql;

        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH
END;

GO

-- Confirmation message after creating ArchiveOldRecords
PRINT 'ArchiveOldRecords stored procedure created successfully for data archiving.';

-- #####################
-- END 3.2.5.1: Create `ArchiveOldRecords` Stored Procedure
-- #####################

-- #####################
-- BEGIN 4.1.1.1: Define Initial User Roles with Comprehensive MetaData
-- #####################

PRINT 'Starting comprehensive role setup with security and performance optimizations for Type.MetaData...';

-- Define a fixed unique identifier to represent the initialization script
DECLARE @DBInitializationScriptId UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000001';

-- Step 1: Define Initial User Roles with MetaData and CreatedBy field
BEGIN TRY
    -- Check and insert "Application Admin" role if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM core.Type WHERE TypeName = 'Application Admin')
    BEGIN
        INSERT INTO core.Type (TypeName, MetaData, CreatedBy) VALUES
        ('Application Admin', JSON_QUERY('{
            "Category": "Role",
            "Permissions": {
                "CanCreate": true,
                "CanEdit": true,
                "CanView": true,
                "CanDelete": true,
                "CanImpersonate": false
            },
            "RoleLevel": "High",
            "Restrictions": null,
            "ImpersonationAllowed": false,
            "Active": true,
            "StatusNote": "Full access across the system",
            "CreatedAt": "' + CONVERT(NVARCHAR, GETUTCDATE(), 126) + '",
            "UpdatedAt": "' + CONVERT(NVARCHAR, GETUTCDATE(), 126) + '",
            "LastUpdatedBy": null
        }'), @DBInitializationScriptId);
        PRINT 'Role "Application Admin" inserted successfully.';
    END

    -- Check and insert "IT Admin" role if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM core.Type WHERE TypeName = 'IT Admin')
    BEGIN
        INSERT INTO core.Type (TypeName, MetaData, CreatedBy) VALUES
        ('IT Admin', JSON_QUERY('{
            "Category": "Role",
            "Permissions": {
                "CanCreate": true,
                "CanEdit": true,
                "CanView": true,
                "CanDelete": true,
                "CanImpersonate": true
            },
            "RoleLevel": "High",
            "Restrictions": "No access to user financial data",
            "ImpersonationAllowed": true,
            "Active": true,
            "StatusNote": "Full access with impersonation",
            "CreatedAt": "' + CONVERT(NVARCHAR, GETUTCDATE(), 126) + '",
            "UpdatedAt": "' + CONVERT(NVARCHAR, GETUTCDATE(), 126) + '",
            "LastUpdatedBy": null
        }'), @DBInitializationScriptId);
        PRINT 'Role "IT Admin" inserted successfully.';
    END

    -- Check and insert "Internal User" role if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM core.Type WHERE TypeName = 'Internal User')
    BEGIN
        INSERT INTO core.Type (TypeName, MetaData, CreatedBy) VALUES
        ('Internal User', JSON_QUERY('{
            "Category": "Role",
            "Permissions": {
                "CanCreate": true,
                "CanEdit": true,
                "CanView": true,
                "CanDelete": false,
                "CanImpersonate": false
            },
            "RoleLevel": "Medium",
            "Restrictions": "No deletion permissions",
            "ImpersonationAllowed": false,
            "Active": true,
            "StatusNote": "General internal access",
            "CreatedAt": "' + CONVERT(NVARCHAR, GETUTCDATE(), 126) + '",
            "UpdatedAt": "' + CONVERT(NVARCHAR, GETUTCDATE(), 126) + '",
            "LastUpdatedBy": null
        }'), @DBInitializationScriptId);
        PRINT 'Role "Internal User" inserted successfully.';
    END

    -- Check and insert "Public User" role if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM core.Type WHERE TypeName = 'Public User')
    BEGIN
        INSERT INTO core.Type (TypeName, MetaData, CreatedBy) VALUES
        ('Public User', JSON_QUERY('{
            "Category": "Role",
            "Permissions": {
                "CanCreate": false,
                "CanEdit": false,
                "CanView": true,
                "CanDelete": false,
                "CanImpersonate": false
            },
            "RoleLevel": "Low",
            "Restrictions": "View-only access",
            "ImpersonationAllowed": false,
            "Active": true,
            "StatusNote": "Read-only access for general users",
            "CreatedAt": "' + CONVERT(NVARCHAR, GETUTCDATE(), 126) + '",
            "UpdatedAt": "' + CONVERT(NVARCHAR, GETUTCDATE(), 126) + '",
            "LastUpdatedBy": null
        }'), @DBInitializationScriptId);
        PRINT 'Role "Public User" inserted successfully.';
    END

    -- Check and insert "Impersonated User" role if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM core.Type WHERE TypeName = 'Impersonated User')
    BEGIN
        INSERT INTO core.Type (TypeName, MetaData, CreatedBy) VALUES
        ('Impersonated User', JSON_QUERY('{
            "Category": "Role",
            "Permissions": {
                "CanCreate": false,
                "CanEdit": false,
                "CanView": true,
                "CanDelete": false,
                "CanImpersonate": false
            },
            "RoleLevel": "Low",
            "Restrictions": "Impersonation-only access",
            "ImpersonationAllowed": false,
            "Active": false,
            "StatusNote": "Used only for impersonation scenarios",
            "CreatedAt": "' + CONVERT(NVARCHAR, GETUTCDATE(), 126) + '",
            "UpdatedAt": "' + CONVERT(NVARCHAR, GETUTCDATE(), 126) + '",
            "LastUpdatedBy": null
        }'), @DBInitializationScriptId);
        PRINT 'Role "Impersonated User" inserted successfully.';
    END

    PRINT 'Role types defined successfully in the Types table with comprehensive MetaData.';
END TRY
BEGIN CATCH
    DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @ErrorCode INT = ERROR_NUMBER();
    DECLARE @ErrorSeverity NVARCHAR(50) = ERROR_SEVERITY();

    PRINT 'Error encountered while defining role types: ' + @ErrorMessage;

    IF OBJECT_ID('core.LogError', 'P') IS NOT NULL
    BEGIN
        EXEC core.LogError @ErrorMessage, @ErrorCode, @ErrorSeverity, 'Define User Roles as Types with Comprehensive MetaData', NULL;
    END

    RAISERROR(@ErrorMessage, 16, 1);
END CATCH;

-- #####################
-- END 4.1.1.1: Define Initial User Roles with Comprehensive MetaData
-- #####################

-- #####################
-- BEGIN: Create Error Log Table and LogError Procedure in core schema
-- #####################

-- Step 1: Create ErrorLog table in audit schema if it doesn't exist
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'audit')
BEGIN
    EXEC sp_executesql N'CREATE SCHEMA audit';
    PRINT 'Audit schema created successfully.';
END;

IF OBJECT_ID('audit.ErrorLog', 'U') IS NULL
BEGIN
    CREATE TABLE audit.ErrorLog (
        LogId INT IDENTITY(1,1) PRIMARY KEY,
        ErrorMessage NVARCHAR(4000),
        ErrorCode INT,
        ErrorSeverity NVARCHAR(50),
        ErrorContext NVARCHAR(255),
        ErrorTime DATETIME DEFAULT GETDATE()
    );
    PRINT 'ErrorLog table created successfully in audit schema.';
END

-- Step 2: Create LogError procedure in core schema
IF OBJECT_ID('core.LogError', 'P') IS NULL
BEGIN
    EXEC sp_executesql N'
        CREATE PROCEDURE core.LogError
            @ErrorMessage NVARCHAR(4000),
            @ErrorCode INT,
            @ErrorSeverity NVARCHAR(50),
            @ErrorContext NVARCHAR(255),
            @AdditionalInfo NVARCHAR(4000) = NULL
        AS
        BEGIN
            INSERT INTO audit.ErrorLog (ErrorMessage, ErrorCode, ErrorSeverity, ErrorContext)
            VALUES (@ErrorMessage, @ErrorCode, @ErrorSeverity, @ErrorContext);

            PRINT ''Error logged to audit.ErrorLog.'';
        END
    ';
    PRINT 'LogError procedure created successfully in core schema.';
END

-- #####################
-- END: Create Error Log Table and LogError Procedure in core schema


---- #####################
---- BEGIN 4.1.1.2: Apply Dynamic Data Masking on MetaData Column with Comprehensive Dependency Handling
---- #####################
---- Step 4.1.1.2: Manage Dependencies for RoleLevel Column in core.Type

--BEGIN TRY
--    PRINT 'Starting dependency management for RoleLevel column in core.Type table...';

--    -- Drop or modify dependencies based on search results

--    -- 1. Stored Procedures
--    IF OBJECT_ID('core.AddEntity', 'P') IS NOT NULL
--    BEGIN
--        PRINT 'Dropping stored procedure core.AddEntity due to dependency on RoleLevel...';
--        DROP PROCEDURE core.AddEntity;
--    END

--    IF OBJECT_ID('core.ApplyDataMasking', 'P') IS NOT NULL
--    BEGIN
--        PRINT 'Dropping stored procedure core.ApplyDataMasking due to dependency on RoleLevel...';
--        DROP PROCEDURE core.ApplyDataMasking;
--    END

--    IF OBJECT_ID('core.ArchiveOldLogs', 'P') IS NOT NULL
--    BEGIN
--        PRINT 'Dropping stored procedure core.ArchiveOldLogs due to dependency on RoleLevel...';
--        DROP PROCEDURE core.ArchiveOldLogs;
--    END

--    IF OBJECT_ID('core.AssignUserRole', 'P') IS NOT NULL
--    BEGIN
--        PRINT 'Dropping stored procedure core.AssignUserRole due to dependency on RoleLevel...';
--        DROP PROCEDURE core.AssignUserRole;
--    END

--    IF OBJECT_ID('core.GetEntityActivityLogReport', 'P') IS NOT NULL
--    BEGIN
--        PRINT 'Dropping stored procedure core.GetEntityActivityLogReport due to dependency on RoleLevel...';
--        DROP PROCEDURE core.GetEntityActivityLogReport;
--    END

--    IF OBJECT_ID('core.GetEntityRelationshipReport', 'P') IS NOT NULL
--    BEGIN
--        PRINT 'Dropping stored procedure core.GetEntityRelationshipReport due to dependency on RoleLevel...';
--        DROP PROCEDURE core.GetEntityRelationshipReport;
--    END

--    IF OBJECT_ID('core.GetEntitySummaryReport', 'P') IS NOT NULL
--    BEGIN
--        PRINT 'Dropping stored procedure core.GetEntitySummaryReport due to dependency on RoleLevel...';
--        DROP PROCEDURE core.GetEntitySummaryReport;
--    END

--    IF OBJECT_ID('core.SelectEntity', 'P') IS NOT NULL
--    BEGIN
--        PRINT 'Dropping stored procedure core.SelectEntity due to dependency on RoleLevel...';
--        DROP PROCEDURE core.SelectEntity;
--    END

--    IF OBJECT_ID('core.UpdateEntity', 'P') IS NOT NULL
--    BEGIN
--        PRINT 'Dropping stored procedure core.UpdateEntity due to dependency on RoleLevel...';
--        DROP PROCEDURE core.UpdateEntity;
--    END

--    -- 2. Functions
--    IF OBJECT_ID('core.fn_UserCanAccessEntity', 'IF') IS NOT NULL
--    BEGIN
--        PRINT 'Dropping function core.fn_UserCanAccessEntity due to dependency on RoleLevel...';
--        DROP FUNCTION core.fn_UserCanAccessEntity;
--    END

--    -- 3. Triggers
--    IF OBJECT_ID('core.trg_Type_LogChanges', 'TR') IS NOT NULL
--    BEGIN
--        PRINT 'Dropping trigger core.trg_Type_LogChanges due to dependency on RoleLevel...';
--        DROP TRIGGER core.trg_Type_LogChanges;
--    END

--    -- 4. Table Dependencies
--    -- Verify AssignUserRole is a table before attempting to alter it
--    IF OBJECT_ID('core.AssignUserRole', 'U') IS NOT NULL
--    BEGIN
--        PRINT 'Removing direct dependency on RoleLevel in core.AssignUserRole table...';
--        ALTER TABLE core.AssignUserRole DROP COLUMN RoleLevel;
--    END

--    PRINT 'Removing direct dependency on RoleLevel in core.Type table...';
--    ALTER TABLE core.Type DROP COLUMN RoleLevel;

--    -- Log the successful removal of dependencies
--    PRINT 'All dependencies for RoleLevel have been successfully managed. Proceeding with dynamic data masking setup.';

--    -- Add dynamic data masking to sensitive fields in MetaData column
--    ALTER TABLE core.Type ALTER COLUMN MetaData ADD MASKED WITH (FUNCTION = 'default()');

--END TRY
--BEGIN CATCH
--    -- Error handling and logging
--    SET @ErrorMessage = ERROR_MESSAGE();
--    SET @ErrorCode = ERROR_NUMBER();
--    SET @ErrorSeverity = ERROR_SEVERITY();

--    -- Log error to ErrorLog if exists
--    IF OBJECT_ID('core.LogError', 'P') IS NOT NULL
--    BEGIN
--        EXEC core.LogError 
--            @ErrorMessage = @ErrorMessage,
--            @ErrorCode = @ErrorCode,
--            @ErrorSeverity = @ErrorSeverity,
--            @ErrorContext = 'Step 4.1.1.2 - RoleLevel Dependency Management';
--    END
--    ELSE
--    BEGIN
--        PRINT 'Error encountered during dependency management for RoleLevel: ' + @ErrorMessage;
--    END
--END CATCH;


---- #####################
---- END 4.1.1.2: Apply Dynamic Data Masking on MetaData Column with Comprehensive Dependency Handling
---- #####################
---- Step 4.1.1.3: Manage Dependencies and Ensure MetaData Column Consistency

--BEGIN TRY
--    PRINT 'Starting dependency management for MetaData column in core.Type and core.Entity tables...';

--    -- Drop or modify dependencies based on search results

--    -- 1. Stored Procedures
--    IF OBJECT_ID('core.AddEntity', 'P') IS NOT NULL
--    BEGIN
--        PRINT 'Dropping stored procedure core.AddEntity due to dependency on MetaData...';
--        DROP PROCEDURE core.AddEntity;
--    END

--    IF OBJECT_ID('core.ArchiveOldLogs', 'P') IS NOT NULL
--    BEGIN
--        PRINT 'Dropping stored procedure core.ArchiveOldLogs due to dependency on MetaData...';
--        DROP PROCEDURE core.ArchiveOldLogs;
--    END

--    IF OBJECT_ID('core.DeleteEntity', 'P') IS NOT NULL
--    BEGIN
--        PRINT 'Dropping stored procedure core.DeleteEntity due to dependency on MetaData...';
--        DROP PROCEDURE core.DeleteEntity;
--    END

--    IF OBJECT_ID('core.UpdateEntity', 'P') IS NOT NULL
--    BEGIN
--        PRINT 'Dropping stored procedure core.UpdateEntity due to dependency on MetaData...';
--        DROP PROCEDURE core.UpdateEntity;
--    END

--    -- 2. Table Dependencies
--    -- Verify Entity has the MetaData column before attempting to drop or create it
--    IF COLUMNPROPERTY(OBJECT_ID('core.Entity', 'U'), 'MetaData', 'ColumnId') IS NOT NULL
--    BEGIN
--        PRINT 'Removing direct dependency on MetaData in core.Entity table...';
--        ALTER TABLE core.Entity DROP COLUMN MetaData;
--    END
--    ELSE
--    BEGIN
--        PRINT 'Column MetaData does not exist in core.Entity table; adding MetaData with dynamic masking...';
--        ALTER TABLE core.Entity ADD MetaData NVARCHAR(MAX) MASKED WITH (FUNCTION = 'default()');
--    END

--    -- Verify Type has the MetaData column before attempting to drop or create it
--    IF COLUMNPROPERTY(OBJECT_ID('core.Type', 'U'), 'MetaData', 'ColumnId') IS NOT NULL
--    BEGIN
--        PRINT 'Removing direct dependency on MetaData in core.Type table...';
--        ALTER TABLE core.Type DROP COLUMN MetaData;
--    END
--    ELSE
--    BEGIN
--        PRINT 'Column MetaData does not exist in core.Type table; adding MetaData with dynamic masking...';
--        ALTER TABLE core.Type ADD MetaData NVARCHAR(MAX) MASKED WITH (FUNCTION = 'default()');
--    END

--    -- Log the successful removal or creation of MetaData column with security masking
--    PRINT 'All dependencies for MetaData have been successfully managed and dynamic data masking applied where necessary.';

--END TRY
--BEGIN CATCH
--    -- Error handling and logging
--    SET @ErrorMessage = ERROR_MESSAGE();
--    SET @ErrorCode = ERROR_NUMBER();
--    SET @ErrorSeverity = ERROR_SEVERITY();

--    -- Log error to ErrorLog if exists
--    IF OBJECT_ID('audit.LogError', 'P') IS NOT NULL
--    BEGIN
--        EXEC audit.LogError 
--            @ErrorMessage = @ErrorMessage,
--            @ErrorCode = @ErrorCode,
--            @ErrorSeverity = @ErrorSeverity,
--            @ErrorContext = 'Step 4.1.1.3 - MetaData Dependency Management';
--    END
--    ELSE
--    BEGIN
--        PRINT 'Error encountered during dependency management for MetaData: ' + @ErrorMessage;
--    END
--END CATCH;
