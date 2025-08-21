api_url = "https://tcr0w2el0l.execute-api.sa-east-1.amazonaws.com"
cloudfront_domain = "d3ulh4f5ptvhiz.cloudfront.net"
comments_table = "blog-comments"
front_bucket = "meu-blog-front-da31f887"
posts_table = "blog-posts"

# na raiz do seu projeto de front (pasta com index.html, assets etc.)
aws s3 sync ./public s3://<front_bucket> --delete

# invalidar cache (quando fizer atualização)
aws cloudfront create-invalidation \
  --distribution-id <DIST_ID> \
  --paths "/*"


token do create post: pfmwe2n439r8723nnefds

dist id: EE8FTMX1X5KK6

aws cloudfront create-invalidation --distribution-id EE8FTMX1X5KK6 --paths "/*"
