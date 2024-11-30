#!/bin/bash

echo "***************************************************************************************"
echo "Welcome to the DynamoDB JSON Data Exporter"
echo "This script will export your DynamoDB data to multiple JSON files"
echo "Before starting, make sure your AWS configuration is correct and that 'jq' is installed"
echo "Please enter the AWS region: "
read -e aws_region_name

echo "Please enter the AWS profile name: "
read -e aws_profile_name

# Get the list of tables
table_list=$(aws dynamodb list-tables --region $aws_region_name --profile $aws_profile_name --output json | jq -r '.TableNames[]')

echo "The following tables were found:"
echo "$table_list"

echo "Do you want to export data from all DynamoDB tables? [Y/N]"
read -e needExport

echo "Wich is the limit of items to be fetched?"
read -e batch_limit

if [[ "$needExport" == "Y" || "$needExport" == "y" ]]
then
    max_items=$batch_limit
    total_start_time="$(date -u +%s)"

    for table_name in $table_list
    do
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
                response=$(aws dynamodb scan --table-name "$table_name" --region "$aws_region_name" --profile "$aws_profile_name" --output json --limit $max_items)
            else
                # Subsequent scans with ExclusiveStartKey
                response=$(aws dynamodb scan --table-name "$table_name" --region "$aws_region_name" --profile "$aws_profile_name" --output json --limit $max_items --starting-token "$ExclusiveStartKey")
            fi

            echo "$response" > "./$table_name/data/$index.json"

            # Extract LastEvaluatedKey
            ExclusiveStartKey=$(echo "$response" | jq -r '.LastEvaluatedKey')

            if [ "$ExclusiveStartKey" == "null" ] || [ -z "$ExclusiveStartKey" ]; then
                # No more data
                break
            fi

            ((index+=1))
            echo "Created dataset ${index} for table $table_name"
        done

        table_export_end_time="$(date -u +%s)"
        echo "Took $(($table_export_end_time-$table_start_time)) seconds to export data from table $table_name"

        # Split records for batch insertion
        for filename in "$table_name/data/"*.json; do
            file=${filename##*/}
            jq '.Items' "$filename" | jq -cM --argjson sublen '25' 'range(0; (length / $sublen) | ceil) as $i | .[$i*$sublen:$i*$sublen+$sublen]' | split -l 1 - "$table_name/ScriptForDataImport/${file%.*}_"
        done

        for filename in "$table_name/ScriptForDataImport/"*; do
            echo "Processing ${filename##*/}"
            jq "{\"$table_name\": [.[] | {PutRequest: {Item: .}}]}" "$filename" > "$filename.txt"
            rm "$filename"
        done

        table_import_end_time="$(date -u +%s)"
        echo "Took $(($table_import_end_time-$table_export_end_time)) seconds to generate insertion scripts for table $table_name"

        echo "Processing completed for table $table_name"
        echo "***************************************************************************************"
    done

    total_end_time="$(date -u +%s)"
    echo "A total of $(($total_end_time-$total_start_time)) seconds were used to complete the function"

else
    echo "Export canceled."
fi