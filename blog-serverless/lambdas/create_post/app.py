import os, json, re, datetime, uuid
import boto3
from boto3.dynamodb.conditions import Key

TABLE = os.environ["POSTS_TABLE"]
ADMIN_TOKEN = os.environ.get("ADMIN_TOKEN", "")  # token simples para publicar
ddb = boto3.resource("dynamodb").Table(TABLE)

_slug_cleanup_re = re.compile(r"[^a-z0-9\-]+")
def slugify(text: str) -> str:
    s = (text or "").strip().lower()
    s = re.sub(r"\s+", "-", s)
    s = _slug_cleanup_re.sub("-", s)
    s = re.sub(r"-{2,}", "-", s).strip("-")
    return s or str(uuid.uuid4())

def json_body(event):
    try:
        return json.loads(event.get("body") or "{}")
    except Exception:
        return {}

def iso_now():
    return datetime.datetime.utcnow().replace(microsecond=0).isoformat() + "Z"

def as_str_list(v):
    if v is None: return []
    if isinstance(v, str):
        # aceitar "aws, serverless"
        return [x.strip() for x in v.split(",") if x.strip()]
    if isinstance(v, list):
        return [str(x).strip() for x in v if str(x).strip()]
    return []

def handler(event, context):
    # Auth simples via header X-ADMIN-TOKEN (pode trocar por Cognito depois)
    token = (event.get("headers") or {}).get("x-admin-token") or (event.get("headers") or {}).get("X-Admin-Token")
    if ADMIN_TOKEN and token != ADMIN_TOKEN:
        return {"statusCode": 401, "body": "Unauthorized"}

    body = json_body(event)
    title = (body.get("title") or "").strip()
    content = (body.get("content") or "").strip()
    slug = (body.get("slug") or "").strip().lower() or slugify(title)
    status = (body.get("status") or "published").strip().lower()
    if status not in ("draft", "published"):
        status = "published"

    if not title or not content:
        return {"statusCode": 400, "body": "Campos obrigatórios: title, content"}

    tags = as_str_list(body.get("tags"))
    author = (body.get("author") or "").strip() or "Autor"
    cover = (body.get("coverUrl") or "").strip() or None

    now = iso_now()
    # item principal do post (cada versão com SK META#timestamp)
    item = {
        "pk": f"POST#{slug}",
        "sk": f"META#{now}",
        "slug": slug,
        "title": title,
        "content": content,
        "author": author,
        "tags": tags,
        "coverUrl": cover,
        "status": status,
        "publishedAt": now,
        "updatedAt": now,
    }

    # se já existir publicado e quiser atualizar "latest", basta inserir nova versão.
    try:
        ddb.put_item(Item=item)
        return {
            "statusCode": 201,
            "headers": {"content-type": "application/json"},
            "body": json.dumps(item),
        }
    except Exception as e:
        print("ERROR", e)
        return {"statusCode": 500, "body": "Internal Server Error"}
