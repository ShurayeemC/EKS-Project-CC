FROM python@sha256:e55523f127124e5edc03ba201e3dbbc85172a2ec40d8651ac752364b23dfd733 AS builder

WORKDIR /app

COPY . .

#-------Runtime stage-------#

FROM python@sha256:e55523f127124e5edc03ba201e3dbbc85172a2ec40d8651ac752364b23dfd733

WORKDIR /app

COPY --from=builder /app/index.html /app 

RUN addgroup --system group && adduser --system user

RUN chown -R user:group /app

USER user

CMD ["python", "-m", "http.server", "3000"]