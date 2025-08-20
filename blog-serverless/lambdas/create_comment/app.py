import os, json, hashlib, uuid, datetime
import boto3

TABLE = os.environ["COMMENTS_TABLE"]
ddb = boto3.resource("dynamodb").Table(TABLE)

def handler(event, context):
    try:
        slug = (event.get("pathParameters") or {}).get("slug")
        body = json.loads(event.get("body") or "{}")

        if not slug or not body.get("author") or not body.get("content"):
            return {"statusCode": 400, "body": "Campos obrigatórios: author, content"}

        now = datetime.datetime.utcnow().isoformat() + "Z"
        cid = str(uuid.uuid4())
        email = (body.get("email") or "").strip().lower()
        email_hash = hashlib.md5(email.encode("utf-8")).hexdigest() if email else None

        item = {
            "pk": f"POST#{slug}",
            "sk": f"COMMENT#{now}#{cid}",
            "id": cid,
            "author": body["author"],
            "emailHash": email_hash,
            "content": body["content"],
            "createdAt": now,
            "status": "pending"
        }
        ddb.put_item(Item=item)

        return {"statusCode": 201, "headers": {"content-type": "application/json"}, "body": json.dumps(item)}
    except Exception as e:
        print("ERROR", e)
        return {"statusCode": 500, "body": "Internal Server Error"}
