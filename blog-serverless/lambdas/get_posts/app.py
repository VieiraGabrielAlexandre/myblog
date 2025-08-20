import os, json, base64
import boto3
from boto3.dynamodb.conditions import Key

TABLE = os.environ["POSTS_TABLE"]
ddb = boto3.resource("dynamodb").Table(TABLE)

def handler(event, context):
    try:
        params = event.get("queryStringParameters") or {}
        limit = int(params.get("limit", 10))
        cursor_b64 = params.get("cursor")

        kwargs = {
            "IndexName": "GSI1",
            "KeyConditionExpression": Key("status").eq("published"),
            "ScanIndexForward": False,  # mais recentes primeiro
            "Limit": limit
        }
        if cursor_b64:
            kwargs["ExclusiveStartKey"] = json.loads(base64.b64decode(cursor_b64).decode("utf-8"))

        res = ddb.query(**kwargs)
        next_cur = base64.b64encode(json.dumps(res.get("LastEvaluatedKey")).encode("utf-8")).decode("utf-8") if res.get("LastEvaluatedKey") else None

        return {
            "statusCode": 200,
            "headers": {"content-type": "application/json"},
            "body": json.dumps({"items": res.get("Items", []), "nextCursor": next_cur})
        }
    except Exception as e:
        print("ERROR", e)
        return {"statusCode": 500, "body": "Internal Server Error"}
