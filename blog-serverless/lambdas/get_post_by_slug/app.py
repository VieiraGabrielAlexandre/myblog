import os, json
import boto3
from boto3.dynamodb.conditions import Key

TABLE = os.environ["POSTS_TABLE"]
ddb = boto3.resource("dynamodb").Table(TABLE)

def handler(event, context):
    try:
        slug = (event.get("pathParameters") or {}).get("slug")
        if not slug:
            return {"statusCode": 400, "body": "slug é obrigatório"}

        # pk = POST#<slug>, buscar o item META mais recente
        res = ddb.query(
            KeyConditionExpression=Key("pk").eq(f"POST#{slug}") & Key("sk").begins_with("META#"),
            ScanIndexForward=False,  # mais recente primeiro
            Limit=1
        )
        items = res.get("Items") or []
        if not items:
            return {"statusCode": 404, "body": "Post não encontrado"}

        post = items[0]
        return {
            "statusCode": 200,
            "headers": {"content-type": "application/json"},
            "body": json.dumps(post)
        }
    except Exception as e:
        print("ERROR", e)
        return {"statusCode": 500, "body": "Internal Server Error"}
