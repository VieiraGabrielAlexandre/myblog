import os, json, hashlib, uuid, datetime, re
import boto3

TABLE = os.environ["COMMENTS_TABLE"]
ddb = boto3.resource("dynamodb").Table(TABLE)

_slug_re = re.compile(r"[^a-z0-9\-]+")
def norm_slug(s: str) -> str:
    s = (s or "").strip().lower().replace(" ", "-")
    s = _slug_re.sub("-", s)
    return re.sub(r"-{2,}", "-", s).strip("-")

def now_iso():
    # formato fixo (segundos) pra ordem lexicográfica estável
    return datetime.datetime.utcnow().replace(microsecond=0).isoformat() + "Z"

def handler(event, context):
    try:
        slug = (event.get("pathParameters") or {}).get("slug")
        body = json.loads(event.get("body") or "{}")

        author = (body.get("author") or "").strip()
        content = (body.get("content") or "").strip()
        email = (body.get("email") or "").strip().lower()

        if not slug or not author or not content:
            return {"statusCode": 400, "body": "Campos obrigatórios: author, content"}

        slug = norm_slug(slug)
        if len(author) > 80: author = author[:80]
        if len(content) > 5000: content = content[:5000]

        ts = now_iso()
        cid = str(uuid.uuid4())
        email_hash = hashlib.md5(email.encode("utf-8")).hexdigest() if email else None

        item = {
            "pk": f"POST#{slug}",
            "sk": f"COMMENT#{ts}#{cid}",
            "id": cid,
            "author": author,
            "content": content,
            "createdAt": ts,
            "status": "pending"
        }
        if email_hash:
            item["emailHash"] = email_hash

        ddb.put_item(Item=item)

        return {
            "statusCode": 201,
            "headers": {"content-type": "application/json"},
            "body": json.dumps(item)
        }
    except Exception as e:
        print("ERROR", e)
        return {"statusCode": 500, "body": "Internal Server Error"}
