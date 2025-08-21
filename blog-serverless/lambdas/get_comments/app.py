import os, json, base64
import boto3
from boto3.dynamodb.conditions import Key, Attr

TABLE = os.environ["COMMENTS_TABLE"]  # deve ser "blog-comments"
ddb = boto3.resource("dynamodb").Table(TABLE)

def decode_cursor(c):
    try:
        return json.loads(base64.urlsafe_b64decode(c.encode("utf-8")).decode("utf-8"))
    except Exception:
        return None

def encode_cursor(k):
    return base64.urlsafe_b64encode(json.dumps(k).encode("utf-8")).decode("utf-8")

def handler(event, context):
    qp = event.get("queryStringParameters") or {}
    pp = event.get("pathParameters") or {}
    slug = (qp.get("slug") or pp.get("slug") or "").strip()
    if not slug:
        return {"statusCode": 400, "body": "slug é obrigatório"}

    limit = 20
    try:
        if qp.get("limit"):
            limit = max(1, min(50, int(qp["limit"])))
    except Exception:
        pass

    # opcional: só "approved" (mude default se quiser)
    status_filter = (qp.get("status") or "").strip().lower()  # "approved", "pending", etc.

    cursor = qp.get("cursor")
    eks = decode_cursor(cursor) if cursor else None

    print("DEBUG TABLE=", TABLE)
    print("DEBUG slug=", slug, "limit=", limit, "status_filter=", status_filter)
    print("DEBUG raw cursor=", cursor)
    print("DEBUG decoded eks type=", type(eks).__name__, "value=", eks)

    # pk=POST#<slug> e sk começa com COMMENT#
    key_expr = Key("pk").eq(f"POST#{slug}") & Key("sk").begins_with("COMMENT#")

    params = {
        "KeyConditionExpression": key_expr,
        "ScanIndexForward": False,  # mais recente primeiro
        "Limit": limit,
    }

    # filtro por status (opcional)
    if status_filter:
        params["FilterExpression"] = Attr("status").eq(status_filter)

    # só inclui ExclusiveStartKey se for dict válido e não-vazio
    if isinstance(eks, dict):
        eks_clean = {k: v for k, v in eks.items() if v is not None}
        if eks_clean:
            params["ExclusiveStartKey"] = eks_clean

    print("DEBUG query params keys=", list(params.keys()))
    res = ddb.query(**params)

    items = res.get("Items") or []
    out = {
        "items": items,
        "nextCursor": encode_cursor(res["LastEvaluatedKey"]) if "LastEvaluatedKey" in res else None
    }
    return {
        "statusCode": 200,
        "headers": {"content-type": "application/json"},
        "body": json.dumps(out)
    }
