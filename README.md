
# DynamoDB Data Migrator

This script allows you to migrate data between DynamoDB tables from one AWS account to another. It automates the process of exporting data from a source account and importing it into a target account.

## Prerequisites

1. Ensure you have AWS CLI installed and configured with profiles for both source and target accounts.
2. Install `jq` for JSON parsing. You can install it using your package manager:
   ```bash
   sudo apt-get install jq # Ubuntu/Debian
   brew install jq         # macOS
   ```
3. Make sure the AWS IAM permissions allow DynamoDB operations (`scan`, `batch-write-item`) in both accounts.

## How to Use

### 1. Make the Script Executable

Save the script in a file (e.g., `dynamodb_migrator.sh`) and make it executable:
```bash
chmod +x dynamodb_migrator.sh
```

### 2. Run the Script

Execute the script:
```bash
./dynamodb_migrator.sh
```

### 3. Follow the Prompts

The script will guide you through the following steps:
- Enter the AWS region and profile name for the source account.
- Enter the AWS region and profile name for the target account.
- View the list of DynamoDB tables in the source account.
- Confirm whether you want to migrate data from all tables.

### 4. Migration Process

For each table:
1. Data is scanned from the source DynamoDB table in batches.
2. The data is saved locally in JSON files.
3. Data is prepared for import by splitting it into smaller batches (maximum of 25 items per batch).
4. Data is imported into the target DynamoDB table using `batch-write-item`.

### Output

The script displays progress logs, including:
- Export time for each table.
- Preparation time for data.
- Import time for each table.

### Features
- Handles large tables with pagination.
- Automatically splits items into batches of 25 for DynamoDB's batch write limits.
- Logs the migration progress and time taken for each step.

### Example Output
```
***************************************************************************************
Welcome to the DynamoDB Data Migrator
This script will export your DynamoDB data from one AWS account and import it into another.
Before starting, make sure your AWS configurations are correct and that 'jq' is installed.
Please enter the AWS region of the source account:
us-east-1
Please enter the AWS profile name of the source account:
source-profile
...
Processing table: ExampleTable
Took 120 seconds to export data from table ExampleTable
Took 30 seconds to prepare data for table ExampleTable
Importing data for table: ExampleTable
Took 60 seconds to import data for table ExampleTable
Processing completed for table ExampleTable
***************************************************************************************
```