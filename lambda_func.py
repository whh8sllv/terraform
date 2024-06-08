import boto3

s3 = boto3.client('s3')

def lambda_handler(event, context):
    try:
        
        source_bucket = 'my-s3-start'
        
        object_key = event['Records'][0]['s3']['object']['key']
              
        destination_bucket = 'my-s3-finish'
        
        source_object_path = f"s3://{source_bucket}/{object_key}"
        
        destination_object_path = f"s3://{destination_bucket}/{object_key}"
        
        copy_source = {'Bucket': source_bucket, 'Key': object_key}
        s3.copy_object(CopySource=copy_source, Bucket=destination_bucket, Key=object_key)
        
        print(f"Copied object from source bucket '{source_bucket}' to destination bucket '{destination_bucket}'")
        print(f"Source object path: {source_object_path}")
        print(f"Destination object path: {destination_object_path}")
        
        return {
            'statusCode': 200,
            'body': 'File copied successfully'
        }
    except Exception as e:
        print(f"Error: {e}")
        return {
            'statusCode': 500,
            'body': 'Error copying file'
        }