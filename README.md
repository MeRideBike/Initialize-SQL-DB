# Initialize-SQL-DB
This script sets up the foundational environment for a "generic" Inventory-Search SQL Server Database. 

It begins by verifying the existence of three key schemas — core, audit, and config — creating them if they don't already exist, which helps enforce logical separation of concerns within the database (e.g., business logic in core, logging in audit, and settings in config). It then defines environment-aware configuration variables, including the database name, file locations for the data and log files, and a label for the deployment environment (e.g., Development, Testing, or Production).

Based on the selected environment, it enables or disables key features such as:

Transparent Data Encryption (TDE) – enabled only in Production for security.

Row-Level Security (RLS) – enabled in Testing and Production for access control.

Query Store – activated in Production for performance monitoring and tuning.

Detailed Reporting (partial in the snippet) – likely toggled for deeper insight during certain deployments.

This setup ensures that deployments are consistent, secure, and tailored to the needs of different environments, minimizing manual steps and errors during initialization. If you'd like, I can review the rest of the script and provide a full summary of its behavior.
