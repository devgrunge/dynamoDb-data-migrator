#!/bin/bash

echo "***************************************************************************************"
echo "Welcome to the DynamoDB Data Migrator"
echo "This script will export your DynamoDB data from one AWS account and import it into another."
echo "Before starting, make sure your AWS configurations are correct and that 'jq' is installed."

# Prompt for source AWS details
echo "Please enter the AWS region of the source account: "
read source_aws_region

echo "Please enter the AWS profile name of the source account: "
read source_aws_profile

# Prompt for target AWS details
echo "Please enter the AWS region of the target account: "
read target_aws_region

echo "Please enter the AWS profile name of the target account: "
read target_aws_profile

# Get the list of tables from the source account
table_list=$(aws dynamodb list-tables --region "$source_aws_region" --profile "$source_aws_profile" --output json | jq -r '.TableNames[]')

echo "The following tables were found in the source account:"
echo "$table_list"

echo "Do you want to migrate data from all DynamoDB tables? [Y/N]"
read needExport

if [[ "$needExport" == "Y" || "$needExport" == "y" ]]; then
    max_items=100
    total_start_time="$(date -u +%s)"

    for table_name in $table_list; do
        echo "Processing table: $table_name"
        table_start_time="$(date -u +%s)"

        # Create necessary directories
        mkdir -p "$table_name/data"
        mkdir -p "$table_name/ScriptForDataImport"

        # Initialize pagination variable
        ExclusiveStartKey=""
        index=0

        while true; do
            if [ -z "$ExclusiveStartKey" ]; then
                # First scan without ExclusiveStartKey
                response=$(aws dynamodb scan --table-name "$table_name" --region "$source_aws_region" --profile "$source_aws_profile" --output json --limit "$max_items")
            else
                # Subsequent scans with ExclusiveStartKey
                response=$(aws dynamodb scan --table-name "$table_name" --region "$source_aws_region" --profile "$source_aws_profile" --output json --limit "$max_items" --exclusive-start-key "$ExclusiveStartKey")
            fi

            # Save the response to a file
            echo "$response" > "./$table_name/data/$index.json"

            # Extract LastEvaluatedKey
            LastEvaluatedKey=$(echo "$response" | jq '.LastEvaluatedKey')

            if [ "$LastEvaluatedKey" == "null" ] || [ -z "$LastEvaluatedKey" ]; then
                # No more data
                break
            else
                # Set ExclusiveStartKey for the next iteration
                ExclusiveStartKey="$LastEvaluatedKey"
            fi

            ((index+=1))
            echo "Created dataset ${index} for table $table_name"
        done

        table_export_end_time="$(date -u +%s)"
        echo "Took $(($table_export_end_time-$table_start_time)) seconds to export data from table $table_name"

        # Prepare data for batch write
        for filename in "$table_name/data/"*.json; do
            file=${filename##*/}
            # Extract items and prepare for batch write
            jq -c '.Items[]' "$filename" >> "$table_name/ScriptForDataImport/all_items.jsonl"
        done

        table_prepare_end_time="$(date -u +%s)"
        echo "Took $(($table_prepare_end_time-$table_export_end_time)) seconds to prepare data for table $table_name"

        # Import data into target account
        echo "Importing data for table: $table_name"

        # Split items into batches of 25
        split -l 25 "$table_name/ScriptForDataImport/all_items.jsonl" "$table_name/ScriptForDataImport/batch_"

        for batch_file in "$table_name/ScriptForDataImport/batch_"*; do
            # Prepare batch write request
            items=$(jq -s '.' "$batch_file")
            batch_request="{\"$table_name\": []}"
            batch_request=$(echo "$batch_request" | jq ".\"$table_name\" += ($items | map({PutRequest: {Item: .}}))")
            # Save batch request to a temp file
            echo "$batch_request" > batch_request.json

            # Perform batch write to target account
            aws dynamodb batch-write-item --region "$target_aws_region" --profile "$target_aws_profile" --request-items file://batch_request.json

            # Remove temp files
            rm -f "$batch_file" batch_request.json
        done

        # Clean up intermediate files
        rm -f "$table_name/ScriptForDataImport/all_items.jsonl"

        table_import_end_time="$(date -u +%s)"
        echo "Took $(($table_import_end_time-$table_prepare_end_time)) seconds to import data for table $table_name"

        echo "Processing completed for table $table_name"
        echo "***************************************************************************************"
    done

    total_end_time="$(date -u +%s)"
    echo "A total of $(($total_end_time-$total_start_time)) seconds were used to complete the data migration"

else
    echo "Data migration canceled."
fi